//
//  PathParameterParser.swift
//  SwiftWebServer
//
//  Utility for parsing path parameters from URL paths following OpenAPI standards
//

import Foundation

/// Utility class for parsing path parameters from URL paths
/// Supports OpenAPI-style path parameters like '/user/{id}' and '/posts/{postId}/comments/{commentId}'
public class PathParameterParser {

    /// Parse path parameters from a URL path using a route pattern
    /// - Parameters:
    ///   - path: The actual URL path (e.g., "/user/123")
    ///   - pattern: The route pattern (e.g., "/user/{id}")
    /// - Returns: Dictionary of parameter names to values, or nil if path doesn't match pattern
    public static func parseParameters(from path: String, using pattern: String) -> [String: String]? {
        let pathSegments = path.split(separator: "/").map(String.init)
        let patternSegments = pattern.split(separator: "/").map(String.init)

        // Paths must have same number of segments to match
        guard pathSegments.count == patternSegments.count else {
            return nil
        }

        var parameters: [String: String] = [:]

        for (index, patternSegment) in patternSegments.enumerated() {
            let pathSegment = pathSegments[index]

            if isParameterSegment(patternSegment) {
                // Extract parameter name and store value
                let parameterName = extractParameterName(from: patternSegment)
                parameters[parameterName] = pathSegment
            } else {
                // Literal segment must match exactly
                if pathSegment != patternSegment {
                    return nil
                }
            }
        }

        return parameters
    }

    /// Check if a pattern segment is a parameter (enclosed in curly braces)
    /// - Parameter segment: The pattern segment to check
    /// - Returns: True if the segment is a parameter
    public static func isParameterSegment(_ segment: String) -> Bool {
        return segment.hasPrefix("{") && segment.hasSuffix("}")
    }

    /// Extract parameter name from a parameter segment
    /// - Parameter segment: The parameter segment (e.g., "{id}")
    /// - Returns: The parameter name (e.g., "id")
    public static func extractParameterName(from segment: String) -> String {
        guard isParameterSegment(segment) else {
            return segment
        }
        return String(segment.dropFirst().dropLast())
    }

    /// Validate a route pattern for correct parameter syntax
    /// - Parameter pattern: The route pattern to validate
    /// - Returns: True if the pattern is valid
    public static func validatePattern(_ pattern: String) -> Bool {
        let segments = pattern.split(separator: "/").map(String.init)

        for segment in segments {
            if segment.contains("{") || segment.contains("}") {
                // If it contains braces, it must be a valid parameter
                if !isParameterSegment(segment) {
                    return false
                }

                // Parameter name cannot be empty
                let paramName = extractParameterName(from: segment)
                if paramName.isEmpty {
                    return false
                }

                // Parameter name should be valid identifier
                if !isValidParameterName(paramName) {
                    return false
                }
            }
        }

        return true
    }

    /// Check if a parameter name is valid (alphanumeric and underscore only)
    /// - Parameter name: The parameter name to validate
    /// - Returns: True if the name is valid
    public static func isValidParameterName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }

        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return name.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    /// Extract all parameter names from a route pattern
    /// - Parameter pattern: The route pattern
    /// - Returns: Array of parameter names found in the pattern
    public static func extractParameterNames(from pattern: String) -> [String] {
        let segments = pattern.split(separator: "/").map(String.init)
        return segments.compactMap { segment in
            isParameterSegment(segment) ? extractParameterName(from: segment) : nil
        }
    }

    /// Generate a regex pattern from a route pattern for advanced matching
    /// - Parameter pattern: The route pattern
    /// - Returns: A regex pattern string
    public static func generateRegexPattern(from pattern: String) -> String {
        let segments = pattern.split(separator: "/").map(String.init)
        let regexSegments = segments.map { segment in
            if isParameterSegment(segment) {
                return "([^/]+)" // Match any characters except slash
            } else {
                return NSRegularExpression.escapedPattern(for: segment)
            }
        }

        return "^/" + regexSegments.joined(separator: "/") + "$"
    }
}

// MARK: - Path Parameter Errors

/// Errors related to path parameter parsing
public enum PathParameterError: Error, LocalizedError, CustomStringConvertible {
    case invalidPattern(String)
    case invalidParameterName(String)
    case patternMismatch(path: String, pattern: String)

    public var errorDescription: String? {
        switch self {
        case .invalidPattern(let pattern):
            return "Invalid route pattern: \(pattern)"
        case .invalidParameterName(let name):
            return "Invalid parameter name: \(name)"
        case .patternMismatch(let path, let pattern):
            return "Path '\(path)' does not match pattern '\(pattern)'"
        }
    }

    public var description: String {
        return errorDescription ?? "Unknown path parameter error"
    }
}
