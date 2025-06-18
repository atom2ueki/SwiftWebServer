//
//  CORSMiddleware.swift
//  SwiftWebServer
//
//  CORS middleware for handling Cross-Origin Resource Sharing
//

import Foundation

/// CORS origin configuration
public enum CORSOrigin {
    case any
    case specific(String)
    case list([String])

    public var stringValues: [String] {
        switch self {
        case .any:
            return ["*"]
        case .specific(let origin):
            return [origin]
        case .list(let origins):
            return origins
        }
    }
}

/// Configuration for CORS middleware
public struct CORSOptions {
    public let allowedOrigins: CORSOrigin
    public let allowedMethods: [HTTPMethod]
    public let allowedHeaders: [HTTPHeader]
    public let exposedHeaders: [HTTPHeader]
    public let allowCredentials: Bool
    public let maxAge: Int?

    public init(
        allowedOrigins: CORSOrigin = .any,
        allowedMethods: [HTTPMethod] = [.get, .post, .put, .delete, .options],
        allowedHeaders: [HTTPHeader] = [.contentType, .authorization],
        exposedHeaders: [HTTPHeader] = [],
        allowCredentials: Bool = false,
        maxAge: Int? = nil
    ) {
        self.allowedOrigins = allowedOrigins
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.exposedHeaders = exposedHeaders
        self.allowCredentials = allowCredentials
        self.maxAge = maxAge
    }
    
    public static let `default` = CORSOptions()

    // MARK: - Convenience Initializers

    /// Create CORS options allowing any origin
    public static func allowAny(
        methods: [HTTPMethod] = [.get, .post, .put, .delete, .options],
        headers: [HTTPHeader] = [.contentType, .authorization]
    ) -> CORSOptions {
        return CORSOptions(
            allowedOrigins: .any,
            allowedMethods: methods,
            allowedHeaders: headers
        )
    }

    /// Create CORS options for a specific origin
    public static func allowOrigin(
        _ origin: String,
        methods: [HTTPMethod] = [.get, .post, .put, .delete, .options],
        headers: [HTTPHeader] = [.contentType, .authorization]
    ) -> CORSOptions {
        return CORSOptions(
            allowedOrigins: .specific(origin),
            allowedMethods: methods,
            allowedHeaders: headers
        )
    }

    /// Create CORS options for multiple origins
    public static func allowOrigins(
        _ origins: [String],
        methods: [HTTPMethod] = [.get, .post, .put, .delete, .options],
        headers: [HTTPHeader] = [.contentType, .authorization]
    ) -> CORSOptions {
        return CORSOptions(
            allowedOrigins: .list(origins),
            allowedMethods: methods,
            allowedHeaders: headers
        )
    }
}

/// CORS middleware for handling Cross-Origin Resource Sharing
public class CORSMiddleware: BaseMiddleware, ConfigurableMiddleware {
    public typealias Options = CORSOptions
    
    private let options: CORSOptions
    
    public required init(options: CORSOptions = .default) {
        self.options = options
        super.init()
    }
    
    public convenience override init() {
        self.init(options: .default)
    }
    
    public override func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        // Set CORS headers
        setCORSHeaders(request: request, response: response)
        
        // Handle preflight requests
        if request.method == .options {
            response.status(.ok).send("")
            return
        }
        
        try next()
    }
    
    private func setCORSHeaders(request: Request, response: Response) {
        // Access-Control-Allow-Origin
        let requestOrigin = request.header(.origin) ?? "*"
        let allowedOriginStrings = options.allowedOrigins.stringValues

        if allowedOriginStrings.contains("*") || allowedOriginStrings.contains(requestOrigin) {
            response.header(.accessControlAllowOrigin, requestOrigin)
        }

        // Access-Control-Allow-Methods
        let methodStrings = options.allowedMethods.map { $0.rawValue }
        response.header(.accessControlAllowMethods, methodStrings.joined(separator: ", "))

        // Access-Control-Allow-Headers
        let headerStrings = options.allowedHeaders.map { $0.name }
        response.header(.accessControlAllowHeaders, headerStrings.joined(separator: ", "))

        // Access-Control-Expose-Headers
        if !options.exposedHeaders.isEmpty {
            let exposedHeaderStrings = options.exposedHeaders.map { $0.name }
            response.header(.accessControlExposeHeaders, exposedHeaderStrings.joined(separator: ", "))
        }

        // Access-Control-Allow-Credentials
        if options.allowCredentials {
            response.header(.accessControlAllowCredentials, "true")
        }

        // Access-Control-Max-Age
        if let maxAge = options.maxAge {
            response.header(.accessControlMaxAge, String(maxAge))
        }
    }
}
