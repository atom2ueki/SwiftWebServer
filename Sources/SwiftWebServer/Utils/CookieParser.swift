//
//  CookieParser.swift
//  SwiftWebServer
//
//  Cookie parsing utilities
//

import Foundation

/// Cookie parsing utilities for HTTP Cookie headers
///
/// Provides functionality to parse Cookie headers from HTTP requests
/// according to RFC 6265 specifications.
public struct CookieParser {

    /// Parse Cookie header into a dictionary of name-value pairs
    ///
    /// Parses a Cookie header string and extracts all cookie name-value pairs.
    /// The parser handles multiple cookies separated by semicolons and properly
    /// trims whitespace from names and values.
    ///
    /// Example:
    /// ```swift
    /// let cookieHeader = "sessionId=abc123; theme=dark; lang=en"
    /// let cookies = CookieParser.parseCookies(cookieHeader)
    /// // Result: ["sessionId": "abc123", "theme": "dark", "lang": "en"]
    /// ```
    ///
    /// - Parameter cookieHeader: The Cookie header value to parse
    /// - Returns: Dictionary mapping cookie names to their values
    public static func parseCookies(_ cookieHeader: String) -> [String: String] {
        var cookies: [String: String] = [:]

        let pairs = cookieHeader.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }

        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0]).trimmingCharacters(in: .whitespaces)
                let value = String(keyValue[1]).trimmingCharacters(in: .whitespaces)
                cookies[key] = value
            }
        }

        return cookies
    }
}
