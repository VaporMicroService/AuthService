import Authentication
import FluentPostgreSQL
import Imperial
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    //Load Environment
    Environment.dotenv(filename: "\(try Environment.detect().name).env")
    // Register providers first
    try services.register(FluentPostgreSQLProvider())
    try services.register(AuthenticationProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    //Regiuster cache for request
    services.register(RequestCache())
    
    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(SessionsMiddleware.self) // Enables sessions.
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    middlewares.use(SessionsMiddleware.self) // Imperial session management
    services.register(middlewares)

    let psqlConfig: PostgreSQLDatabaseConfig!
    if let url = Environment.get("PSQL_DATABASE_URL") {
        psqlConfig = PostgreSQLDatabaseConfig(url: url, transport: .unverifiedTLS)
    } else {
        psqlConfig = try PostgreSQLDatabaseConfig.default()
    }
    // Configure a PostgreSQL database
    let postgre = PostgreSQLDatabase(config: psqlConfig)
    // Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    databases.enableLogging(on: .psql)
    databases.add(database: postgre, as: .psql)
    services.register(databases)

    /// Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .psql)
    migrations.add(model: UserToken.self, database: .psql)
    services.register(migrations)
    
    var commandConfig = CommandConfig.default()
    commandConfig.useFluentCommands()
    services.register(commandConfig)
    
    config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
}
