//
//  CookieMiddleware.swift
//  SwiftWebServer
//
//  Cookie parsing and handling middleware
//

import Foundation

/// Cookie attributes for Set-Cookie header
public struct CookieAttributes {
    public let domain: String?
    public let path: String?
    public let expires: Date?
    public let maxAge: Int?
    public let secure: Bool
    public let httpOnly: Bool
    public let sameSite: SameSite?

    public enum SameSite: String {
        case strict = "Strict"
        case lax = "Lax"
        case none = "None"
    }

    public init(
        domain: String? = nil,
        path: String? = nil,
        expires: Date? = nil,
        maxAge: Int? = nil,
        secure: Bool = false,
        httpOnly: Bool = false,
        sameSite: SameSite? = nil
    ) {
        self.domain = domain
        self.path = path
        self.expires = expires
        self.maxAge = maxAge
        self.secure = secure
        self.httpOnly = httpOnly
        self.sameSite = sameSite
    }
}

/// Configuration for Cookie middleware
public struct CookieOptions {
    public let secret: String?
    public let signed: Bool

    public init(secret: String? = nil, signed: Bool = false) {
        self.secret = secret
        self.signed = signed
    }

    public static let `default` = CookieOptions()
}

/// Cookie parsing and handling middleware
public class CookieMiddleware: BaseMiddleware, ConfigurableMiddleware {
    public typealias Options = CookieOptions

    private let options: CookieOptions

    public required init(options: CookieOptions = .default) {
        self.options = options
        super.init()
    }

    public convenience override init() {
        self.init(options: .default)
    }

    public override func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        // Parse cookies from request
        if let cookieHeader = request.header(HTTPHeader.cookie.name) {
            request.cookies = CookieParser.parseCookies(cookieHeader)
        } else {
            request.cookies = [:]
        }

        // Add cookie methods to response
        response.cookieMiddleware = self

        try next()
    }

    /// Create Set-Cookie header value
    public func createSetCookieHeader(name: String, value: String, attributes: CookieAttributes = CookieAttributes()) -> String {
        var cookieString = "\(name)=\(value)"

        if let domain = attributes.domain {
            cookieString += "; Domain=\(domain)"
        }

        if let path = attributes.path {
            cookieString += "; Path=\(path)"
        }

        if let expires = attributes.expires {
            cookieString += "; Expires=\(HTTPDateFormatter.formatCookieExpires(expires))"
        }

        if let maxAge = attributes.maxAge {
            cookieString += "; Max-Age=\(maxAge)"
        }

        if attributes.secure {
            cookieString += "; Secure"
        }

        if attributes.httpOnly {
            cookieString += "; HttpOnly"
        }

        if let sameSite = attributes.sameSite {
            cookieString += "; SameSite=\(sameSite.rawValue)"
        }

        return cookieString
    }
}

// MARK: - Request Extensions for Cookie Middleware

extension Request {
    private static let cookiesKey = "CookieMiddleware.cookies"

    /// Parsed cookies from Cookie header
    public var cookies: [String: String] {
        get {
            return middlewareStorage[Request.cookiesKey] as? [String: String] ?? [:]
        }
        set {
            middlewareStorage[Request.cookiesKey] = newValue
        }
    }

    /// Get cookie value by name
    public func cookie(_ name: String) -> String? {
        return cookies[name]
    }
}

// MARK: - Response Extensions for Cookie Middleware

extension Response {
    private static var cookieMiddlewareKey: UInt8 = 0

    internal var cookieMiddleware: CookieMiddleware? {
        get {
            return objc_getAssociatedObject(self, &Response.cookieMiddlewareKey) as? CookieMiddleware
        }
        set {
            objc_setAssociatedObject(self, &Response.cookieMiddlewareKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// Set cookie in response
    @discardableResult
    public func cookie(_ name: String, _ value: String, attributes: CookieAttributes = CookieAttributes()) -> Response {
        guard let cookieMiddleware = cookieMiddleware else {
            print("Warning: CookieMiddleware not initialized. Add CookieMiddleware to your middleware chain.")
            return self
        }

        let cookieHeader = cookieMiddleware.createSetCookieHeader(name: name, value: value, attributes: attributes)

        // Handle multiple Set-Cookie headers
        if let existingCookies = headers[HTTPHeader.setCookie.name] {
            headers[HTTPHeader.setCookie.name] = "\(existingCookies), \(cookieHeader)"
        } else {
            headers[HTTPHeader.setCookie.name] = cookieHeader
        }

        return self
    }

    /// Clear cookie (set with past expiration)
    @discardableResult
    public func clearCookie(_ name: String, attributes: CookieAttributes = CookieAttributes()) -> Response {
        let pastDate = Date(timeIntervalSince1970: 0)
        var clearAttributes = attributes
        clearAttributes = CookieAttributes(
            domain: attributes.domain,
            path: attributes.path,
            expires: pastDate,
            maxAge: 0,
            secure: attributes.secure,
            httpOnly: attributes.httpOnly,
            sameSite: attributes.sameSite
        )
        return cookie(name, "", attributes: clearAttributes)
    }
}
