//
//  User.swift
//  AppTests
//
//  Created by Szymon Lorenz on 11/8/19.
//

import Foundation
import FluentPostgreSQL
import Crypto
@testable import App

extension User {
    static func create(name: String = "Luke",
                       on connection: PostgreSQLConnection) throws -> User {
        let password = try BCrypt.hash("password")
        let user = User(name: name, email: "\(name.lowercased())@test.com", passwordHash: password)
        return try user.save(on: connection).wait()
    }
}
