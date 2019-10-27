import Authentication
import FluentPostgreSQL
import Vapor

final class User: PostgreSQLModel {
    var id: Int?
    var externalId: String?
    var externalService: String?
    var name: String
    var email: String
    var passwordHash: String
    
    init(id: Int? = nil, name: String, email: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email
        self.passwordHash = passwordHash
    }
}

extension User: PasswordAuthenticatable {
    static var usernameKey: WritableKeyPath<User, String> {
        return \.email
    }
    
    static var passwordKey: WritableKeyPath<User, String> {
        return \.passwordHash
    }
}

extension User: TokenAuthenticatable {
    typealias TokenType = UserToken
}

extension User: SessionAuthenticatable { }

extension User: Migration {
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(User.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.name)
            builder.field(for: \.email)
            builder.field(for: \.passwordHash)
            
            builder.unique(on: \.email)
        }
    }
}

extension User: Content { }
extension User: Parameter { }
