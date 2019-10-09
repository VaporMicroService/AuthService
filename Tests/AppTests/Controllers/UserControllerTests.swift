//
//  UserController.swift
//  AppTests
//
//  Created by Szymon Lorenz on 11/8/19.
//

import Foundation
import Vapor
import XCTest
import FluentPostgreSQL
@testable import App

final class UserControllerTests: XCTestCase {
    static let allTests = [
        ("testUsersLogin", testUsersLogin),
        ("testUsersLoginNotFound", testUsersLoginNotFound),
        ("testUsersLoginWrongPassword", testUsersLoginWrongPassword),
        ("testUsersCreate", testUsersCreate),
        ("testUsersCreateAlreadyExisting", testUsersCreateAlreadyExisting),
        ("testUsersRetrive", testUsersRetrive),
        ("testUsersRetriveNotAuthenticated", testUsersRetriveNotAuthenticated),
        ("testUsersDelete", testUsersRetrive),
        ("testUsersDeleteNotAuthenticated", testUsersRetriveNotAuthenticated),
    ]
    
    let uri = "/api/users/"
    var app: Application!
    var conn: PostgreSQLConnection!
    
    override func setUp() {
        try! Application.reset()
        app = try! Application.testable()
        conn = try! app.newConnection(to: .psql).wait()
    }
    
    override func tearDown() {
        conn.close()
        try? app.syncShutdownGracefully()
    }
    
    func testUsersLogin() throws {
        let userName = "TestUser"
        let user = try User.create(name: userName, on: conn)
        let credentials = BasicAuthorization(username: user.email, password: "password")
        var tokenHeaders = HTTPHeaders()
        tokenHeaders.basicAuthorization = credentials
        let tokenResponse = try app.sendRequest(to: "\(uri)login", method: .POST, headers: tokenHeaders)
        let token = try tokenResponse.content.syncDecode(UserToken.self)
        
        XCTAssertEqual(tokenResponse.http.status.code, 200)
        XCTAssertNotNil(token)
    }
    
    func testUsersLoginNotFound() throws {
        let credentials = BasicAuthorization(username: "nil@test.com", password: "password")
        var tokenHeaders = HTTPHeaders()
        tokenHeaders.basicAuthorization = credentials
        let tokenResponse = try app.sendRequest(to: "\(uri)login", method: .POST, headers: tokenHeaders)
        
        XCTAssertEqual(tokenResponse.http.status.code, 401)
    }
    
    func testUsersLoginWrongPassword() throws {
        let userName = "TestUser"
        let user = try User.create(name: userName, on: conn)
        let credentials = BasicAuthorization(username: user.email, password: "empty_string")
        var tokenHeaders = HTTPHeaders()
        tokenHeaders.basicAuthorization = credentials
        let tokenResponse = try app.sendRequest(to: "\(uri)login", method: .POST, headers: tokenHeaders)
        XCTAssertEqual(tokenResponse.http.status.code, 401)
    }
    
    func testUsersCreate() throws {
        let body = UserController.CreateRequest(name: "ABC", email: "abc@test.com", password: "password", verifyPassword: "password")
        let response = try app.sendRequest(to: "\(uri)create", method: .POST, body: body)
        let userResponse = try response.content.syncDecode(UserController.UserResponse.self)
        
        XCTAssertNotNil(userResponse.id)
        XCTAssertEqual(userResponse.name, body.name)
        XCTAssertEqual(userResponse.email, body.email)
    }
    
    func testUsersCreateAlreadyExisting() throws {
        let body = UserController.CreateRequest(name: "ABC", email: "abc@test.com", password: "password", verifyPassword: "password")
        let response = try app.sendRequest(to: "\(uri)create", method: .POST, body: body)
        let userResponse = try response.content.syncDecode(UserController.UserResponse.self)
        
        XCTAssertNotNil(userResponse.id)
        XCTAssertEqual(userResponse.name, body.name)
        XCTAssertEqual(userResponse.email, body.email)
        
        let response2 = try app.sendRequest(to: "\(uri)create", method: .POST, body: body)
        XCTAssertEqual(response2.http.status.code, 500)
        XCTAssertTrue(String(data: response2.http.body.data!, encoding: .utf8)!.contains("duplicate key value violates unique constraint"))
    }
    
    func testUsersRetrive() throws {
        let userName = "TestUser"
        let user = try User.create(name: userName, on: conn)
        let userResponse = try app.getResponse(to: "\(uri)\(try user.requireID())", decodeTo: UserController.UserResponse.self, userToLogin: user)
        
        XCTAssertEqual(userResponse.name, userName)
        XCTAssertEqual(userResponse.id, user.id)
    }
    
    func testUsersRetriveNotAuthenticated() throws {
        let userName = "TestUser"
        let user = try User.create(name: userName, on: conn)
        let response = try app.sendRequest(to: "\(uri)\(try user.requireID())", method: .GET)
        XCTAssertEqual(response.http.status.code, 401)
    }
    
    func testUsersDelete() throws {
        let userName = "TestUser"
        let user = try User.create(name: userName, on: conn)
        let response = try app.sendRequest(to: "\(uri)\(try user.requireID())", method: .DELETE, userToLogin: user)
        XCTAssertEqual(response.http.status.code, 200)
        XCTAssertNil(try User.find(user.requireID(), on: conn).wait())
    }
    
    func testUsersDeleteNotAuthenticated() throws {
        let userName = "TestUser"
        let user = try User.create(name: userName, on: conn)
        let response = try app.sendRequest(to: "\(uri)\(try user.requireID())", method: .DELETE)
        XCTAssertEqual(response.http.status.code, 401)
        XCTAssertNotNil(try User.find(user.requireID(), on: conn).wait())
    }
    
    func testUsersTokenIsValid() throws {
        let userName = "TestUser"
        let user = try User.create(name: userName, on: conn)
        let response = try app.sendRequest(to: "\(uri)/id", method: .GET, userToLogin: user)
        XCTAssertEqual(response.http.status.code, 200)
        let userResponse = try response.content.syncDecode(UserController.ObjectIdentifier.self)
        XCTAssertEqual(userResponse.id, try user.requireID())
    }
    
    func testUsersTokenNotAuthenticated() throws {
        let userName = "TestUser"
        let _ = try User.create(name: userName, on: conn)
        let response = try app.sendRequest(to: "\(uri)/id", method: .GET)
        XCTAssertEqual(response.http.status.code, 401)
    }
}
