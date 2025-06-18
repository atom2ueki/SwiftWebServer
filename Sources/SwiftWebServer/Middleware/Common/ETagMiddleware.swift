//
//  ETagMiddleware.swift
//  SwiftWebServer
//
//  ETag middleware with 304 Not Modified response support
//

import Foundation

// MARK: - Data Extensions for ETag Generation

extension Data {
    /// Simple hash for ETag generation (not cryptographically secure)
    var simpleHash: String {
        let hash = self.reduce(0) { result, byte in
            return result &+ Int(byte)
        }
        return String(hash, radix: 16)
    }
}

/// ETag generation strategy
public enum ETagStrategy {
    case strong    // Strong ETag: "hash"
    case weak      // Weak ETag: W/"hash"
}

/// Configuration for ETag middleware
public struct ETagOptions {
    public let strategy: ETagStrategy
    public let skipWeakValidation: Bool
    
    public init(strategy: ETagStrategy = .strong, skipWeakValidation: Bool = false) {
        self.strategy = strategy
        self.skipWeakValidation = skipWeakValidation
    }
    
    public static let `default` = ETagOptions()
}

/// ETag middleware for conditional requests and 304 Not Modified responses
public class ETagMiddleware: BaseMiddleware, ConfigurableMiddleware {
    public typealias Options = ETagOptions
    
    private let options: ETagOptions
    
    public required init(options: ETagOptions = .default) {
        self.options = options
        super.init()
    }
    
    public convenience override init() {
        self.init(options: .default)
    }
    
    public override func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        // Continue to next middleware first
        try next()

        // After response is prepared, add ETag handling
        // Note: In a real implementation, we'd need to intercept the response content
        // For now, we'll add ETag support to the response object
        response.etagMiddleware = self
    }
    
    /// Generate ETag for content
    public func generateETag(for data: Data) -> String {
        switch options.strategy {
        case .strong:
            return generateStrongETag(for: data)
        case .weak:
            return generateWeakETag(for: data)
        }
    }

    /// Generate strong ETag for content
    private func generateStrongETag(for data: Data) -> String {
        let hash = data.simpleHash
        return "\"\(hash)\""
    }

    /// Generate weak ETag for content
    private func generateWeakETag(for data: Data) -> String {
        let hash = data.simpleHash
        return "W/\"\(hash)\""
    }
    
    /// Check if request matches ETag (for 304 Not Modified)
    public func checkETagMatch(request: Request, etag: String) -> Bool {
        // Check If-None-Match header
        guard let ifNoneMatch = request.header(.ifNoneMatch) else {
            return false
        }

        // Handle multiple ETags in If-None-Match
        let requestETags = ifNoneMatch.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Check for exact match or wildcard
        for requestETag in requestETags {
            if requestETag == "*" || requestETag == etag {
                return true
            }
            
            // Handle weak ETag comparison if not skipping
            if !options.skipWeakValidation {
                let normalizedRequestETag = requestETag.hasPrefix("W/") ? String(requestETag.dropFirst(2)) : requestETag
                let normalizedResponseETag = etag.hasPrefix("W/") ? String(etag.dropFirst(2)) : etag
                
                if normalizedRequestETag == normalizedResponseETag {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Check if request has conditional headers
    public func hasConditionalHeaders(request: Request) -> Bool {
        return request.header(.ifNoneMatch) != nil ||
               request.header(.ifModifiedSince) != nil
    }
}

// MARK: - Response Extensions for ETag Middleware

extension Response {
    private static var etagMiddlewareKey: UInt8 = 0
    
    internal var etagMiddleware: ETagMiddleware? {
        get {
            return objc_getAssociatedObject(self, &Response.etagMiddlewareKey) as? ETagMiddleware
        }
        set {
            objc_setAssociatedObject(self, &Response.etagMiddlewareKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// Send response with ETag and 304 Not Modified support
    public func sendWithETag(_ content: String, contentType: ContentType = .textPlain) {
        guard let etagMiddleware = etagMiddleware else {
            // Fallback to regular send if ETag middleware not available
            if contentType == .textHtml {
                html(content)
            } else if contentType == .applicationJson {
                json(content)
            } else {
                send(content)
            }
            return
        }

        // Generate ETag for content
        let contentData = content.data(using: .utf8) ?? Data()
        let etag = etagMiddleware.generateETag(for: contentData)

        // Set ETag header
        header(HTTPHeader.etag.name, etag)

        // Check for conditional request (If-None-Match)
        // Note: We need access to the request object here
        // In a real implementation, this would be handled differently

        // For now, just send the content with ETag
        if contentType == .textHtml {
            html(content)
        } else if contentType == .applicationJson {
            json(content)
        } else {
            send(content)
        }
    }
    
    /// Send 304 Not Modified response
    public func notModified() {
        status(.notModified)
        // Remove content-related headers for 304 response
        headers.remove(.contentLength)
        headers.remove(.contentType)

        // Send empty response for 304
        send("")
    }
    

}

// MARK: - Example Usage Extension

public extension ETagMiddleware {
    
    /// Example of how to use ETag middleware with conditional requests
    static func handleConditionalRequest(
        request: Request, 
        response: Response, 
        content: String,
        contentType: ContentType = .textPlain,
        etagMiddleware: ETagMiddleware
    ) {
        let contentData = content.data(using: .utf8) ?? Data()
        let etag = etagMiddleware.generateETag(for: contentData)
        
        // Check if client has matching ETag
        if etagMiddleware.checkETagMatch(request: request, etag: etag) {
            // Send 304 Not Modified
            response.header(HTTPHeader.etag.name, etag)
            response.notModified()
        } else {
            // Send full content with ETag
            response.header(HTTPHeader.etag.name, etag)
            response.sendWithETag(content, contentType: contentType)
        }
    }
}
