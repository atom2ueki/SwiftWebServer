//
//  SwiftWebServerError.swift
//  SwiftWebServer
//
//  Comprehensive error handling for SwiftWebServer
//

import Foundation

/// Comprehensive error types for SwiftWebServer operations
/// This enum provides a unified interface to all SwiftWebServer errors while
/// maintaining modular error organization internally
public enum SwiftWebServerError: Error, LocalizedError, CustomStringConvertible {

    // MARK: - Connection Errors
    case connectionFailed(reason: String)

    // MARK: - Request/Response Errors
    case invalidRequest(reason: String)
    case malformedRequest
    case requestTooLarge(size: Int, maxSize: Int)
    case unsupportedHTTPMethod(method: String)
    case invalidHTTPVersion(version: String)
    case missingRequiredHeaders([String])
    case invalidHeaders(reason: String)

    // MARK: - File System Errors
    case fileNotFound(path: String)
    case fileReadError(path: String, reason: String)

    // MARK: - Route Errors
    case routeNotFound(path: String, method: String)
    case routeHandlerError(path: String, error: Error)

    // MARK: - Content Errors
    case jsonParsingError(reason: String)
    case contentEncodingError(reason: String)

    // MARK: - Middleware Errors
    case middlewareError(error: MiddlewareError)

    // MARK: - Internal Errors
    case internalServerError(reason: String)
    case unexpectedError(error: Error)

    // MARK: - LocalizedError Implementation
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"

        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        case .malformedRequest:
            return "Malformed HTTP request"
        case .requestTooLarge(let size, let maxSize):
            return "Request too large: \(size) bytes (max: \(maxSize) bytes)"
        case .unsupportedHTTPMethod(let method):
            return "Unsupported HTTP method: \(method)"
        case .invalidHTTPVersion(let version):
            return "Invalid HTTP version: \(version)"
        case .missingRequiredHeaders(let headers):
            return "Missing required headers: \(headers.joined(separator: ", "))"
        case .invalidHeaders(let reason):
            return "Invalid headers: \(reason)"

        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileReadError(let path, let reason):
            return "Failed to read file \(path): \(reason)"

        case .routeNotFound(let path, let method):
            return "Route not found: \(method) \(path)"
        case .routeHandlerError(let path, let error):
            return "Route handler error for \(path): \(error.localizedDescription)"

        case .jsonParsingError(let reason):
            return "JSON parsing error: \(reason)"
        case .contentEncodingError(let reason):
            return "Content encoding error: \(reason)"

        case .middlewareError(let error):
            return "Middleware error: \(error.localizedDescription)"

        case .internalServerError(let reason):
            return "Internal server error: \(reason)"
        case .unexpectedError(let error):
            return "Unexpected error: \(error.localizedDescription)"
        }
    }

    // MARK: - CustomStringConvertible Implementation
    public var description: String {
        return errorDescription ?? "Unknown SwiftWebServer error"
    }

    // MARK: - HTTP Status Code Mapping
    public var httpStatusCode: HTTPStatusCode {
        switch self {
        case .connectionFailed:
            return .serviceUnavailable
        case .invalidRequest, .malformedRequest, .unsupportedHTTPMethod, .invalidHTTPVersion, .invalidHeaders:
            return .badRequest
        case .requestTooLarge:
            return .requestEntityTooLarge
        case .missingRequiredHeaders:
            return .badRequest
        case .fileNotFound:
            return .notFound
        case .fileReadError:
            return .internalServerError
        case .routeNotFound:
            return .notFound
        case .routeHandlerError:
            return .internalServerError
        case .jsonParsingError, .contentEncodingError:
            return .badRequest
        case .middlewareError:
            return .internalServerError
        case .internalServerError, .unexpectedError:
            return .internalServerError
        }
    }

    // MARK: - Error Response Body
    public var errorResponseBody: String {
        let errorData: [String: Any] = [
            "error": true,
            "code": httpStatusCode.rawValue,
            "status": httpStatusCode.reasonPhrase,
            "message": errorDescription ?? "Unknown error",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: errorData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        // Fallback to simple format if JSON serialization fails
        return """
        {
            "error": true,
            "code": \(httpStatusCode.rawValue),
            "status": "\(httpStatusCode.reasonPhrase)",
            "message": "\(errorDescription ?? "Unknown error")",
            "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
    }
}
