//
//  ImperialController.swift
//  App
//
//  Created by Szymon Lorenz on 27/10/19.
//

import Foundation
import Vapor
import Imperial
import Authentication

/// Creates new users and logs them in.
struct ImperialController {
    
    //MARK: Boot
    func boot(router: Router) throws {
        guard let facebookCallbackURL = Environment.get("FACEBOOK_CALLBACK_URI") else {
            fatalError("Facebook callback URL not set")
        }
        try router.oAuth(from: Facebook.self, authenticate: "login-facebook", callback: facebookCallbackURL,
                         scope: [], completion: processFacebookLogin)
    }
    
    //MARK: Facebook
    func processFacebookLogin(request: Request, token: String) throws -> Future<ResponseEncodable> {
        return try Facebook.getUserInfo(on: request).flatMap(to: ResponseEncodable.self) { userInfo in
            return User.query(on: request).filter(\.externalId == userInfo.id).first()
                                          .flatMap(to: ResponseEncodable.self) { foundUser in
                guard let existingUser = foundUser else {
                    return self.buildAndSaveNewUser(request: request, userInfo: userInfo)
                }
                return self.AuthenticateExistingUser(request: request, user: existingUser)
            }
        }
    }

    private func buildAndSaveNewUser(request: Request, userInfo: FacebookUserInfo) -> Future<ResponseEncodable> {
        let user = User(name: userInfo.name, email: userInfo.email, passwordHash: UUID().uuidString)
        user.externalId = userInfo.id
        user.externalService = "facebook"
        return user.save(on: request).map(to: ResponseEncodable.self) { user in
            let token = try UserToken.create(userID: user.requireID())
            return token.save(on: request)
        }
    }

    private func AuthenticateExistingUser(request: Request, user: User) -> Future<ResponseEncodable> {
        return user.save(on: request).map(to: ResponseEncodable.self) { user in
            let token = try UserToken.create(userID: user.requireID())
            return token.save(on: request)
        }
    }
}

struct FacebookUserInfo: Content {
    let id: String
    let email: String
    let name: String
}

extension Facebook {
    static func getUserInfo(on request: Request) throws -> Future<FacebookUserInfo> {
        let token = try request.accessToken()
        let facebookUserAPIURL = "https://graph.facebook.com/v3.2/me?fields=id,name,email&access_token=\(token)"
        return try request.client().get(facebookUserAPIURL).map(to: FacebookUserInfo.self) { response in
            guard response.http.status == .ok else {
                if response.http.status == .unauthorized {
                    throw Abort.redirect(to: "/login-facebook")
                } else {
                    throw Abort(.internalServerError)
                }
            }
            return try response.content.syncDecode(FacebookUserInfo.self)
        }
    }
}
