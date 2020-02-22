import Authentication
import Crypto
import FluentPostgreSQL
import Vapor

final class UserToken: PostgreSQLModel {
    static func create(userID: User.ID) throws -> UserToken {
        let string = try CryptoRandom().generateData(count: 16).base64EncodedString()
        return .init(token: string, userID: userID)
    }
    
    static var deletedAtKey: TimestampKey? { return \.expiresAt }
    static var createdAtKey: TimestampKey? { return \.createdAt }
    static var updatedAtKey: TimestampKey? { return \.updatedAt }
    
    var id: Int?
    var token: String
    var userID: User.ID
    var expiresAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    
    init(id: Int? = nil, token: String, userID: User.ID) {
        self.id = id
        self.token = token
        if let interval = Environment.get("TOKEN_EXPIRATION_INTERVAL"), let time = Double(interval) {
            self.expiresAt = Date.init(timeInterval: time, since: .init())
        } else {
            self.expiresAt = Date.init(timeInterval: 60 * 60 * 5, since: .init())
        }
        self.userID = userID
    }
}

extension UserToken {
    var user: Parent<UserToken, User> {
        return parent(\.userID)
    }
}

extension UserToken: Token {
    typealias UserType = User
    
    static var tokenKey: WritableKeyPath<UserToken, String> {
        return \.token
    }
    
    static var userIDKey: WritableKeyPath<UserToken, User.ID> {
        return \.userID
    }
}

extension UserToken: Migration {
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(UserToken.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.token)
            builder.field(for: \.userID)
            builder.field(for: \.expiresAt)
            builder.field(for: \.createdAt)
            builder.field(for: \.updatedAt)
            
            builder.reference(from: \.userID, to: \User.id, onDelete: .cascade)
        }
    }
}

extension UserToken: Content { }
extension UserToken: Parameter { }
