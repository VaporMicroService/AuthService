//
//  ExternalAuthControllerTests.swift
//  AppTests
//
//  Created by Szymon Lorenz on 6/11/19.
//

import Foundation
import Vapor
import XCTest
import FluentPostgreSQL
@testable import App

final class ExternalAuthControllerTests: XCTestCase {
    static let allTests = [
        ("testFacebookLogin", testFacebookLogin),
        ("testFacebookLoginExistingUser", testFacebookLoginExistingUser),
        ("testFacebookLoginWrongToken", testFacebookLoginWrongToken),
    ]
    
    let fbToken = "EAAUV9TmOZAP0BAEQZCg5pZALNjKgk5XZAUBOoicXdLRiZCJO4d4qH2jDpDZBx0ieOC8kGzRQKAXAbGFwP3jdk6ZA0lWCeEWCweX4bWUQNr3wBk9T00QWUQmX1Hm3zYI8h36MnRoUPEQLpZCAbxvWjZAGzPWmZA0ufsyzCMwzTZBn8GSlf5lRMQgCe41hZBhARY19QxOdaG3RsTXqVCZBrtM7J1jpl"
    let uri = "/users/"
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
    
    func testFacebookLogin() throws {
        let tokenResponse = try app.sendRequest(to: "\(uri)login-facebook/\(fbToken)", method: .GET)
        let token = try tokenResponse.content.syncDecode(UserToken.self)
        
        XCTAssertEqual(tokenResponse.http.status.code, 200)
        XCTAssertNotNil(token)
    }
    
    func testFacebookLoginExistingUser() throws {
        let tokenResponse = try app.sendRequest(to: "\(uri)login-facebook/\(fbToken)", method: .GET)
        let token = try tokenResponse.content.syncDecode(UserToken.self)
        
        XCTAssertEqual(tokenResponse.http.status.code, 200)
        XCTAssertNotNil(token)
        
        let tokenResponse2 = try app.sendRequest(to: "\(uri)login-facebook/\(fbToken)", method: .GET)
        let token2 = try tokenResponse2.content.syncDecode(UserToken.self)
        
        XCTAssertEqual(tokenResponse2.http.status.code, 200)
        XCTAssertNotNil(token2)
        
        XCTAssert(token.userID == token2.userID)
    }
    
    func testFacebookLoginWrongToken() throws {
        let response = try app.sendRequest(to: "\(uri)login-facebook/icXdLRiZCJO4d4qH2jDpDZBx0ieOC8kGzRQKAXAbGFwP3jdk6ZA0lWCeEWCweX4bWUQNr3wBk9T00QWUQmX1", method: .GET)
        XCTAssertEqual(response.http.status.code, 400)
    }
}
