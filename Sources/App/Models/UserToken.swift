import Authentication
import Crypto
import FluentPostgreSQL
import Vapor

final class UserToken: PostgreSQLModel {
    static func create(userID: User.ID) throws -> UserToken {
        let string = try CryptoRandom().generateData(count: 16).base64EncodedString()
        return .init(string: string, userID: userID)
    }
    
    static var deletedAtKey: TimestampKey? { return \.expiresAt }
    
    var id: Int?
    var string: String
    var userID: User.ID
    var expiresAt: Date?
    
    init(id: Int? = nil, string: String, userID: User.ID) {
        self.id = id
        self.string = string
        self.expiresAt = Date.init(timeInterval: 60 * 60 * 5, since: .init())
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
        return \.string
    }
    
    static var userIDKey: WritableKeyPath<UserToken, User.ID> {
        return \.userID
    }
}

extension UserToken: Migration {
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(UserToken.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.string)
            builder.field(for: \.userID)
            builder.field(for: \.expiresAt)
            
            builder.reference(from: \.userID, to: \User.id, onDelete: .cascade)
        }
    }
}

extension UserToken: Content { }
extension UserToken: Parameter { }
