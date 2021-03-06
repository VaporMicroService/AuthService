import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    try UserController().boot(router: router)
    try ExternalAuthController().boot(router: router)
}
