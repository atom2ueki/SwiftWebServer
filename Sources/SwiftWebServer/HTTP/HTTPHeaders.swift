//
//  HTTPHeaders.swift
//  SwiftWebServer
//
//  HTTP header name constants and utilities
//

import Foundation

/// HTTP header names enumeration
public enum HTTPHeader: String, CaseIterable, CustomStringConvertible {

    // MARK: - General Headers
    case cacheControl = "Cache-Control"
    case connection = "Connection"
    case date = "Date"

    // MARK: - Request Headers
    case accept = "Accept"
    case acceptEncoding = "Accept-Encoding"
    case acceptLanguage = "Accept-Language"
    case authorization = "Authorization"
    case host = "Host"
    case userAgent = "User-Agent"
    case cookie = "Cookie"
    case origin = "Origin"

    // MARK: - Response Headers
    case etag = "ETag"
    case location = "Location"
    case server = "Server"
    case setCookie = "Set-Cookie"

    // MARK: - Entity Headers
    case contentLength = "Content-Length"
    case contentType = "Content-Type"
    case lastModified = "Last-Modified"

    // MARK: - CORS Headers
    case accessControlAllowOrigin = "Access-Control-Allow-Origin"
    case accessControlAllowMethods = "Access-Control-Allow-Methods"
    case accessControlAllowHeaders = "Access-Control-Allow-Headers"
    case accessControlExposeHeaders = "Access-Control-Expose-Headers"
    case accessControlAllowCredentials = "Access-Control-Allow-Credentials"
    case accessControlMaxAge = "Access-Control-Max-Age"
    case accessControlRequestMethod = "Access-Control-Request-Method"
    case accessControlRequestHeaders = "Access-Control-Request-Headers"

    // MARK: - ETag Headers
    case ifNoneMatch = "If-None-Match"
    case ifModifiedSince = "If-Modified-Since"

    // MARK: - Properties

    /// The header name string
    public var name: String {
        return rawValue
    }

    /// Case-insensitive header name for comparison
    public var lowercaseName: String {
        return rawValue.lowercased()
    }

    // MARK: - CustomStringConvertible
    public var description: String {
        return rawValue
    }
}

// MARK: - Static Methods
public extension HTTPHeader {

    /// Find header by name (case-insensitive)
    static func from(name: String) -> HTTPHeader? {
        let lowercaseName = name.lowercased()
        return HTTPHeader.allCases.first { $0.lowercaseName == lowercaseName }
    }

    /// Common request headers
    static let commonRequestHeaders: [HTTPHeader] = [
        .accept, .acceptEncoding, .acceptLanguage, .authorization,
        .contentType, .contentLength, .host, .userAgent, .cookie
    ]

    /// Common response headers
    static let commonResponseHeaders: [HTTPHeader] = [
        .contentType, .contentLength, .server, .date, .etag,
        .lastModified, .cacheControl, .setCookie
    ]

    /// CORS headers
    static let corsHeaders: [HTTPHeader] = [
        .accessControlAllowOrigin, .accessControlAllowMethods,
        .accessControlAllowHeaders, .accessControlExposeHeaders,
        .accessControlAllowCredentials, .accessControlMaxAge,
        .accessControlRequestMethod, .accessControlRequestHeaders, .origin
    ]
}

// MARK: - HTTPHeaders Collection

/// Type-safe HTTP headers collection
public class HTTPHeaders: Sequence {
    private var storage: [String: String] = [:]

    public init() {}

    /// Set header value using HTTPHeader enum
    public func set(_ header: HTTPHeader, value: String) {
        storage[header.lowercaseName] = value
    }

    /// Get header value using HTTPHeader enum
    public func get(_ header: HTTPHeader) -> String? {
        return storage[header.lowercaseName]
    }

    /// Set header value using string (for compatibility)
    public func set(_ name: String, value: String) {
        storage[name.lowercased()] = value
    }

    /// Get header value using string (for compatibility)
    public func get(_ name: String) -> String? {
        return storage[name.lowercased()]
    }

    /// Remove header
    public func remove(_ header: HTTPHeader) {
        storage.removeValue(forKey: header.lowercaseName)
    }

    /// Remove header by name
    public func remove(_ name: String) {
        storage.removeValue(forKey: name.lowercased())
    }

    /// Check if header exists
    public func contains(_ header: HTTPHeader) -> Bool {
        return storage[header.lowercaseName] != nil
    }

    /// Check if header exists by name
    public func contains(_ name: String) -> Bool {
        return storage[name.lowercased()] != nil
    }

    /// Get all headers as dictionary
    public var allHeaders: [String: String] {
        return storage
    }

    /// Check if headers collection is empty
    public var isEmpty: Bool {
        return storage.isEmpty
    }

    /// Remove header by key name (for compatibility)
    public func removeValue(forKey key: String) {
        storage.removeValue(forKey: key.lowercased())
    }

    /// Subscript access using HTTPHeader enum
    public subscript(header: HTTPHeader) -> String? {
        get { return get(header) }
        set {
            if let value = newValue {
                set(header, value: value)
            } else {
                remove(header)
            }
        }
    }

    /// Subscript access using string
    public subscript(name: String) -> String? {
        get { return get(name) }
        set {
            if let value = newValue {
                set(name, value: value)
            } else {
                remove(name)
            }
        }
    }

    // MARK: - Sequence Protocol

    public func makeIterator() -> Dictionary<String, String>.Iterator {
        return storage.makeIterator()
    }
}
