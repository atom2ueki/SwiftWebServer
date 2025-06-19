//
//  Request.swift
//  SwiftWebServer
//
//  HTTP Request parsing with validation
//

import Foundation

public class Request {
    public var rawRequest: String
    public var method: HTTPMethod
    public var path: String
    public var httpVersion: String
    public var headers: HTTPHeaders = HTTPHeaders()
    public var body: Data?
    public var queryParameters: [String: String] = [:]
    public var pathParameters: [String: String] = [:]

    /// Generic storage for middleware data
    /// Middleware can use this to attach additional data to requests
    public var middlewareStorage: [String: Any] = [:]

    public init(inputData: Data) throws {
        guard let requestString = String(data: inputData, encoding: .utf8) else {
            throw SwiftWebServerError.invalidRequest(reason: "Unable to decode request as UTF-8")
        }

        self.rawRequest = requestString
        // Initialize required properties with default values
        self.method = .get // Default, will be overridden during parsing
        self.path = ""
        self.httpVersion = ""

        // Parse the request
        try parseRequest(requestString)

        // Parse query parameters using the dedicated parser
        self.queryParameters = QueryParameterParser.parseParametersFromRawRequest(requestString)
    }

    private func parseRequest(_ requestString: String) throws {
        let lines = requestString.components(separatedBy: "\r\n")

        guard !lines.isEmpty else {
            throw SwiftWebServerError.malformedRequest
        }

        // Parse request line (first line)
        try parseRequestLine(lines[0])

        // Parse headers
        var headerEndIndex = 1
        for i in 1..<lines.count {
            let line = lines[i]
            if line.isEmpty {
                headerEndIndex = i
                break
            }
            try parseHeaderLine(line)
        }

        // Parse body if present
        if headerEndIndex + 1 < lines.count {
            let bodyLines = Array(lines[(headerEndIndex + 1)...])
            let bodyString = bodyLines.joined(separator: "\r\n")
            if !bodyString.isEmpty {
                self.body = bodyString.data(using: .utf8)
            }
        }

        // Validate the request
        try validateRequest()
    }

    private func parseRequestLine(_ requestLine: String) throws {
        let components = requestLine.split(separator: " ", maxSplits: 2)

        guard components.count == 3 else {
            throw SwiftWebServerError.malformedRequest
        }

        let methodString = String(components[0]).uppercased()
        guard let httpMethod = HTTPMethod(string: methodString) else {
            throw SwiftWebServerError.unsupportedHTTPMethod(method: methodString)
        }
        self.method = httpMethod

        let fullPath = String(components[1])
        self.httpVersion = String(components[2])

        // Separate path from query string
        if let queryIndex = fullPath.firstIndex(of: "?") {
            self.path = String(fullPath[..<queryIndex])
        } else {
            self.path = fullPath
        }

        // Validate HTTP version
        guard httpVersion.hasPrefix("HTTP/") else {
            throw SwiftWebServerError.invalidHTTPVersion(version: httpVersion)
        }
    }

    private func parseHeaderLine(_ headerLine: String) throws {
        guard let colonIndex = headerLine.firstIndex(of: ":") else {
            throw SwiftWebServerError.invalidHeaders(reason: "Header line missing colon: \(headerLine)")
        }

        let headerName = String(headerLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let headerValue = String(headerLine[headerLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

        guard !headerName.isEmpty else {
            throw SwiftWebServerError.invalidHeaders(reason: "Empty header name")
        }

        headers.set(headerName, value: headerValue)
    }

    /// Set path parameters from route matching
    /// This method is called by the router when a route match is found
    public func setPathParameters(_ parameters: [String: String]) {
        self.pathParameters = parameters
    }

    private func validateRequest() throws {
        // Validate path
        guard !path.isEmpty && path.hasPrefix("/") else {
            throw SwiftWebServerError.invalidRequest(reason: "Invalid path: \(path)")
        }

        // Check for required headers based on method
        if method.hasBody {
            if let contentLength = headers[.contentLength], let length = Int(contentLength) {
                if length > 0 && body == nil {
                    throw SwiftWebServerError.missingRequiredHeaders(["Content-Length with body"])
                }
            }
        }
    }

    // MARK: - Convenience Methods

    /// Get header value using HTTPHeader enum
    public func header(_ header: HTTPHeader) -> String? {
        return headers[header]
    }

    /// Get header value by name (case-insensitive) - for compatibility
    public func header(_ name: String) -> String? {
        return headers[name]
    }

    /// Get content type
    public var contentType: ContentType? {
        guard let contentTypeHeader = headers[.contentType] else { return nil }
        let (contentType, _) = ContentType.parse(headerValue: contentTypeHeader)
        return contentType
    }

    /// Get content length
    public var contentLength: Int? {
        guard let lengthString = headers[.contentLength] else { return nil }
        return Int(lengthString)
    }

    /// Get user agent
    public var userAgent: String? {
        return headers[.userAgent]
    }

    /// Get host
    public var host: String? {
        return headers[.host]
    }

    /// Check if request accepts a specific content type
    public func accepts(_ contentType: ContentType) -> Bool {
        guard let acceptHeader = headers[.accept] else { return true }
        return acceptHeader.contains(contentType.mimeType) || acceptHeader.contains("*/*")
    }

    /// Get body as string
    public var bodyString: String? {
        guard let body = body else { return nil }
        return String(data: body, encoding: .utf8)
    }

    /// Get query parameter
    public func query(_ key: String) -> String? {
        return queryParameters[key]
    }

    /// Get path parameter
    public func param(_ key: String) -> String? {
        return pathParameters[key]
    }

    /// Get all path parameters
    public var params: [String: String] {
        return pathParameters
    }

    /// Check if request is secure (HTTPS)
    public var isSecure: Bool {
        return headers["X-Forwarded-Proto"] == "https" ||
               headers["X-Forwarded-SSL"] == "on" ||
               headers["X-URL-Scheme"] == "https"
    }

    /// Get client IP address
    public var clientIP: String? {
        if let forwardedFor = headers["X-Forwarded-For"] {
            let firstIP = forwardedFor.split(separator: ",").first.map(String.init)
            return firstIP?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return headers["X-Real-IP"] ?? headers["Remote-Addr"]
    }
}
