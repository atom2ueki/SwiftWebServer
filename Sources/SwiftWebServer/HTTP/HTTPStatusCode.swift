//
//  HTTPStatusCode.swift
//  SwiftWebServer
//
//  Standard HTTP status codes with descriptions
//

import Foundation

/// Standard HTTP status codes
public enum HTTPStatusCode: Int, CaseIterable, CustomStringConvertible {

    // MARK: - 1xx Informational
    case `continue` = 100

    // MARK: - 2xx Success
    case ok = 200
    case created = 201
    case accepted = 202
    case noContent = 204

    // MARK: - 3xx Redirection
    case movedPermanently = 301
    case found = 302
    case notModified = 304
    case temporaryRedirect = 307
    case permanentRedirect = 308

    // MARK: - 4xx Client Error
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case notFound = 404
    case methodNotAllowed = 405
    case conflict = 409
    case requestEntityTooLarge = 413
    case unsupportedMediaType = 415

    // MARK: - 5xx Server Error
    case internalServerError = 500
    case serviceUnavailable = 503

    // MARK: - Properties

    /// Human-readable reason phrase for the status code
    public var reasonPhrase: String {
        switch self {
        // 1xx Informational
        case .continue: return "Continue"

        // 2xx Success
        case .ok: return "OK"
        case .created: return "Created"
        case .accepted: return "Accepted"
        case .noContent: return "No Content"

        // 3xx Redirection
        case .movedPermanently: return "Moved Permanently"
        case .found: return "Found"
        case .notModified: return "Not Modified"
        case .temporaryRedirect: return "Temporary Redirect"
        case .permanentRedirect: return "Permanent Redirect"

        // 4xx Client Error
        case .badRequest: return "Bad Request"
        case .unauthorized: return "Unauthorized"
        case .forbidden: return "Forbidden"
        case .notFound: return "Not Found"
        case .methodNotAllowed: return "Method Not Allowed"
        case .conflict: return "Conflict"
        case .requestEntityTooLarge: return "Request Entity Too Large"
        case .unsupportedMediaType: return "Unsupported Media Type"

        // 5xx Server Error
        case .internalServerError: return "Internal Server Error"
        case .serviceUnavailable: return "Service Unavailable"
        }
    }

    /// Category of the status code
    public var category: StatusCategory {
        switch rawValue {
        case 100..<200: return .informational
        case 200..<300: return .success
        case 300..<400: return .redirection
        case 400..<500: return .clientError
        case 500..<600: return .serverError
        default: return .unknown
        }
    }

    /// Whether this status code indicates success
    public var isSuccess: Bool {
        return category == .success
    }

    /// Whether this status code indicates an error
    public var isError: Bool {
        return category == .clientError || category == .serverError
    }

    /// Whether this status code indicates a client error
    public var isClientError: Bool {
        return category == .clientError
    }

    /// Whether this status code indicates a server error
    public var isServerError: Bool {
        return category == .serverError
    }

    // MARK: - CustomStringConvertible
    public var description: String {
        return "\(rawValue) \(reasonPhrase)"
    }

    // MARK: - HTTP Response Line
    public func httpResponseLine(version: String = "HTTP/1.1") -> String {
        return "\(version) \(rawValue) \(reasonPhrase)"
    }
}

// MARK: - Status Category
public enum StatusCategory: String, CaseIterable {
    case informational = "Informational"
    case success = "Success"
    case redirection = "Redirection"
    case clientError = "Client Error"
    case serverError = "Server Error"
    case unknown = "Unknown"
}

// MARK: - Convenience Extensions
public extension HTTPStatusCode {

    /// Common success status codes
    static let successCodes: [HTTPStatusCode] = [.ok, .created, .accepted, .noContent]

    /// Common client error status codes
    static let clientErrorCodes: [HTTPStatusCode] = [.badRequest, .unauthorized, .forbidden, .notFound, .methodNotAllowed, .conflict]

    /// Common server error status codes
    static let serverErrorCodes: [HTTPStatusCode] = [.internalServerError, .serviceUnavailable]

    /// Initialize from integer value with fallback
    init(code: Int) {
        self = HTTPStatusCode(rawValue: code) ?? .internalServerError
    }
}
