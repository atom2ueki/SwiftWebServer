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
        guard let authHeader = request.header(options.tokenHeader) else {
            try response.status(.unauthorized).json(["error": "Missing or invalid Authorization header"])
            return
        }

        // Check if header starts with Bearer prefix
        guard let prefix = options.tokenPrefix, authHeader.hasPrefix(prefix) else {
            try response.status(.unauthorized).json(["error": "Missing or invalid Authorization header"])
            return
        }

        // Extract token after 'Bearer '
        let token = String(authHeader.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        
        guard !token.isEmpty else {
            try response.status(.unauthorized).json(["error": "Missing or invalid Authorization header"])
            return
        }

        // Validate token
        do {
            let isValid = try options.validator(token)
            if !isValid {
                try response.status(.unauthorized).json(["error": "Invalid token"])
                return
            }
        } catch {
            try response.status(.unauthorized).json(["error": "Invalid token"])
            return
        }

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
