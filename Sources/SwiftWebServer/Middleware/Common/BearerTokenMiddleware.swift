//
//  BearerTokenMiddleware.swift
//  SwiftWebServer
//
//  Bearer Token authentication middleware
//

import Foundation

/// Configuration for Bearer Token middleware
public struct BearerTokenOptions {
    public let tokenHeader: HTTPHeader
    public let tokenPrefix: String?
    public let validator: (String) throws -> Bool

    public init(
        tokenHeader: HTTPHeader = .authorization,
        tokenPrefix: String? = "Bearer ",
        validator: @escaping (String) throws -> Bool
    ) {
        self.tokenHeader = tokenHeader
        self.tokenPrefix = tokenPrefix
        self.validator = validator
    }
}

/// Bearer Token authentication middleware
/// Auth middleware: checks Authorization header for Bearer token
public class BearerTokenMiddleware: BaseMiddleware, ConfigurableMiddleware {
    public typealias Options = BearerTokenOptions

    private let options: BearerTokenOptions

    public required init(options: BearerTokenOptions) {
        self.options = options
        super.init()
    }

    public override func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        print("BearerTokenMiddleware: Processing request for \(request.method.rawValue) \(request.path)")

        guard let authHeader = request.header(options.tokenHeader) else {
            print("BearerTokenMiddleware: No Authorization header found")
            try response.status(.unauthorized).json(["error": "Missing or invalid Authorization header"])
            return
        }

        print("BearerTokenMiddleware: Authorization header found: \(authHeader)")

        // Check if header starts with Bearer prefix
        guard let prefix = options.tokenPrefix, authHeader.hasPrefix(prefix) else {
            print("BearerTokenMiddleware: Authorization header doesn't start with Bearer prefix")
            try response.status(.unauthorized).json(["error": "Missing or invalid Authorization header"])
            return
        }

        // Extract token after 'Bearer '
        let token = String(authHeader.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)

        guard !token.isEmpty else {
            print("BearerTokenMiddleware: Token is empty after extracting from header")
            try response.status(.unauthorized).json(["error": "Missing or invalid Authorization header"])
            return
        }

        print("BearerTokenMiddleware: Extracted token: \(token)")

        // Validate token
        do {
            let isValid = try options.validator(token)
            if !isValid {
                print("BearerTokenMiddleware: Token validation failed")
                try response.status(.unauthorized).json([
                    "error": "Invalid or expired token",
                    "code": "TOKEN_INVALID",
                    "message": "Please log in again"
                ])
                return
            }
        } catch {
            print("BearerTokenMiddleware: Token validation threw error: \(error)")
            try response.status(.unauthorized).json([
                "error": "Invalid or expired token",
                "code": "TOKEN_INVALID",
                "message": "Please log in again"
            ])
            return
        }

        print("BearerTokenMiddleware: Token validation successful, setting authToken")
        // Store token in request for later use
        request.authToken = token

        try next()
    }
}

// MARK: - Request Extensions for Bearer Token Middleware

extension Request {
    private static let authTokenKey = "BearerTokenMiddleware.authToken"

    /// The authenticated token (set by BearerTokenMiddleware)
    /// Contains the validated bearer token for authenticated requests
    public var authToken: String? {
        get {
            return middlewareStorage[Request.authTokenKey] as? String
        }
        set {
            middlewareStorage[Request.authTokenKey] = newValue
        }
    }
}
