import Crypto
import Vapor
import FluentPostgreSQL

/// Creates new users and logs them in.
struct UserController {
    // MARK: Content
    struct CreateRequest: Content {
        var name: String
        var email: String
        var password: String
        var verifyPassword: String
    }
    
    struct UserResponse: Content {
        var id: Int
        var name: String
        var email: String
        
        init(_ user: User) throws {
            self.id = try user.requireID()
            self.name = user.name
            self.email = user.email
        }
    }
    
    struct ObjectIdentifier: Content {
        var id: Int
    }
    
    //MARK: Boot
    func boot(router: Router) throws {
        let usersRoute = router.grouped("users")
        
        let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
        basicAuthGroup.post("create", use: create)
        basicAuthGroup.get("login", use: login)
        
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        tokenAuthGroup.get(User.parameter, use: retrive)
        tokenAuthGroup.delete(User.parameter, use: delete)
        tokenAuthGroup.get("id", use: check)
    }
    
    // MARK: Route handlers
    /// Logs a user in, returning a token for accessing protected endpoints.
    func login(_ req: Request) throws -> Future<UserToken> {
        // get user auth'd by basic auth middleware
        let user = try req.requireAuthenticated(User.self)
        // create new token for this user
        let token = try UserToken.create(userID: user.requireID())
        // save and return token
        return token.save(on: req)
    }
    
    /// Creates a new user.
    func create(_ req: Request) throws -> Future<UserResponse> {
        // decode request content
        return try req.content.decode(CreateRequest.self).flatMap { user -> Future<User> in
            // verify that passwords match
            guard user.password == user.verifyPassword else {
                throw Abort(.badRequest, reason: "Password and verification must match.")
            }
            
            // hash user's password using BCrypt
            let hash = try BCrypt.hash(user.password)
            // save new user
            return User(id: nil, name: user.name, email: user.email, passwordHash: hash)
                .save(on: req)
        }.map { user in
            // map to public user response (omits password hash)
            return try UserResponse(user)
        }
    }
    
    /// Verify user token.
    func check(_ req: Request) throws -> ObjectIdentifier {
        return ObjectIdentifier(id: try req.requireAuthenticated(User.self).requireID())
    }
    
    /// Retrive a user.
    func retrive(_ req: Request) throws -> Future<UserResponse> {
        return try req.parameters.next(User.self).map { try UserResponse($0) }
    }
    
    /// Delete user from database
    func delete(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(User.self).delete(on: req).transform(to: HTTPStatus.ok)
    }
}
