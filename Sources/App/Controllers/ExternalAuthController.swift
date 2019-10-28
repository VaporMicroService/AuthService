//
//  ExternalAuthController.swift
//  App
//
//  Created by Szymon Lorenz on 27/10/19.
//

import Foundation
import Vapor
import Authentication

/// Creates new users and logs them in.
struct ExternalAuthController {
    // MARK: Content
    struct UserInfo: Content {
        let id: String
        let email: String
        let name: String
    }
    
    struct InspectData: Content {
        var data: Inspect
    }
    
    struct Inspect: Content {
        var app_id: Int
        var type: String
        var application: String
        var expires_at: Int
        var is_valid: Bool
        var issued_at: Int
        var user_id: String
    }
    
    //MARK: Boot
    func boot(router: Router) throws {
        let usersRoute = router.grouped("users")
        usersRoute.get("login-facebook", String.parameter, use: facebookLogin)
    }
    
    //MARK: Facebook
    func facebookLogin(request: Request) throws -> Future<UserToken> {
        let token = try request.parameters.next(String.self)
        return try inspectAccessToken(on: request, token: token).flatMap { inspectData in
            guard inspectData.data.is_valid,
                let facebookAppId = Environment.get("FACEBOOK_APP_ID"),
                facebookAppId == "\(inspectData.data.app_id)" else {
                throw Abort(.internalServerError)
            }
            return try self.getUserInfo(on: request, token: token).flatMap { userInfo in
                return User.query(on: request).filter(\.externalId == userInfo.id).first()
                    .flatMap { foundUser in
                        guard let existingUser = foundUser else {
                            return self.buildAndSaveNewUser(request: request, userInfo: userInfo)
                        }
                        return self.AuthenticateExistingUser(request: request, user: existingUser)
                }
            }
        }
    }
    
    private func inspectAccessToken(on request: Request, token: String) throws -> Future<InspectData> {
        guard let accessToken = Environment.get("FACEBOOK_ACCESS_TOKEN") else {
            throw Abort(.internalServerError)
        }
        let facebookInspectAPIURL = "https://graph.facebook.com/v3.2/debug_token?input_token=\(token)&access_token=\(accessToken)"
        return try request.client().get(facebookInspectAPIURL).map { response in
            guard response.http.status == .ok else {
                if response.http.status == .unauthorized {
                    throw Abort(.unauthorized)
                } else {
                    throw Abort(.internalServerError)
                }
            }
            return try response.content.syncDecode(InspectData.self)
        }
    }
    
    private func getUserInfo(on request: Request, token: String) throws -> Future<UserInfo> {
        let facebookUserAPIURL = "https://graph.facebook.com/v3.2/me?fields=id,name,email&access_token=\(token)"
        return try request.client().get(facebookUserAPIURL).map { response in
            guard response.http.status == .ok else {
                if response.http.status == .unauthorized {
                    throw Abort(.unauthorized)
                } else {
                    throw Abort(.internalServerError)
                }
            }
            return try response.content.syncDecode(UserInfo.self)
        }
    }
    
    private func buildAndSaveNewUser(request: Request, userInfo: UserInfo) -> Future<UserToken> {
        let user = User(name: userInfo.name, email: userInfo.email, passwordHash: UUID().uuidString)
        user.externalId = userInfo.id
        user.externalService = "facebook"
        return user.save(on: request).flatMap { user in
            let token = try UserToken.create(userID: user.requireID())
            return token.save(on: request)
        }
    }
    
    private func AuthenticateExistingUser(request: Request, user: User) -> Future<UserToken> {
        return user.save(on: request).flatMap { user in
            let token = try UserToken.create(userID: user.requireID())
            return token.save(on: request)
        }
    }
}
