//
//  QueryParameterParser.swift
//  SwiftWebServer
//
//  Utility for parsing query parameters from URL query strings
//

import Foundation

/// Utility class for parsing query parameters from URL query strings
/// Handles URL decoding, multiple values, and various query string formats
public class QueryParameterParser {
    
    /// Parse query parameters from a full URL or query string
    /// - Parameter urlString: The full URL or query string to parse
    /// - Returns: Dictionary of parameter names to values
    public static func parseParameters(from urlString: String) -> [String: String] {
        guard let queryString = extractQueryString(from: urlString) else {
            return [:]
        }
        
        return parseQueryString(queryString)
    }
    
    /// Parse query parameters from a raw HTTP request string
    /// - Parameter rawRequest: The raw HTTP request string
    /// - Returns: Dictionary of parameter names to values
    public static func parseParametersFromRawRequest(_ rawRequest: String) -> [String: String] {
        guard let queryIndex = rawRequest.firstIndex(of: "?") else { return [:] }
        
        let queryStart = rawRequest.index(after: queryIndex)
        guard let spaceIndex = rawRequest[queryStart...].firstIndex(of: " ") else { return [:] }
        
        let queryString = String(rawRequest[queryStart..<spaceIndex])
        return parseQueryString(queryString)
    }
    
    /// Parse a query string into parameters
    /// - Parameter queryString: The query string (without the leading '?')
    /// - Returns: Dictionary of parameter names to values
    public static func parseQueryString(_ queryString: String) -> [String: String] {
        guard !queryString.isEmpty else { return [:] }
        
        var parameters: [String: String] = [:]
        let pairs = queryString.split(separator: "&")
        
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            
            if keyValue.count == 2 {
                let key = String(keyValue[0])
                let value = String(keyValue[1])
                
                // URL decode both key and value
                let decodedKey = urlDecode(key) ?? key
                let decodedValue = urlDecode(value) ?? value
                
                parameters[decodedKey] = decodedValue
            } else if keyValue.count == 1 {
                // Handle parameters without values (e.g., "?flag")
                let key = String(keyValue[0])
                let decodedKey = urlDecode(key) ?? key
                parameters[decodedKey] = ""
            }
        }
        
        return parameters
    }
    
    /// Extract query string from a full URL
    /// - Parameter urlString: The full URL
    /// - Returns: The query string portion (without the '?'), or nil if no query string
    public static func extractQueryString(from urlString: String) -> String? {
        guard let queryIndex = urlString.firstIndex(of: "?") else { return nil }
        
        let queryStart = urlString.index(after: queryIndex)
        
        // Handle fragment identifier (#) if present
        if let fragmentIndex = urlString[queryStart...].firstIndex(of: "#") {
            return String(urlString[queryStart..<fragmentIndex])
        } else {
            return String(urlString[queryStart...])
        }
    }
    
    /// URL decode a string
    /// - Parameter string: The string to decode
    /// - Returns: The decoded string, or nil if decoding fails
    public static func urlDecode(_ string: String) -> String? {
        return string.removingPercentEncoding
    }
    
    /// URL encode a string for use in query parameters
    /// - Parameter string: The string to encode
    /// - Returns: The encoded string
    public static func urlEncode(_ string: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? string
    }
    
    /// Build a query string from parameters
    /// - Parameter parameters: Dictionary of parameter names to values
    /// - Returns: The query string (without leading '?')
    public static func buildQueryString(from parameters: [String: String]) -> String {
        let pairs = parameters.map { key, value in
            let encodedKey = urlEncode(key)
            let encodedValue = urlEncode(value)
            return "\(encodedKey)=\(encodedValue)"
        }
        return pairs.joined(separator: "&")
    }
    
    /// Validate query parameter names and values
    /// - Parameter parameters: Dictionary of parameters to validate
    /// - Returns: Array of validation errors, empty if all valid
    public static func validateParameters(_ parameters: [String: String]) -> [QueryParameterError] {
        var errors: [QueryParameterError] = []
        
        for (key, value) in parameters {
            // Check for empty keys
            if key.isEmpty {
                errors.append(.emptyParameterName)
            }
            
            // Check for excessively long keys or values
            if key.count > 1000 {
                errors.append(.parameterNameTooLong(key))
            }
            
            if value.count > 10000 {
                errors.append(.parameterValueTooLong(key, value.count))
            }
        }
        
        return errors
    }
}

// MARK: - Advanced Query Parameter Parsing

public extension QueryParameterParser {
    
    /// Parse query parameters with support for multiple values
    /// - Parameter queryString: The query string to parse
    /// - Returns: Dictionary of parameter names to arrays of values
    static func parseMultiValueParameters(from queryString: String) -> [String: [String]] {
        guard !queryString.isEmpty else { return [:] }
        
        var parameters: [String: [String]] = [:]
        let pairs = queryString.split(separator: "&")
        
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            
            if keyValue.count >= 1 {
                let key = String(keyValue[0])
                let value = keyValue.count == 2 ? String(keyValue[1]) : ""
                
                let decodedKey = urlDecode(key) ?? key
                let decodedValue = urlDecode(value) ?? value
                
                if parameters[decodedKey] != nil {
                    parameters[decodedKey]?.append(decodedValue)
                } else {
                    parameters[decodedKey] = [decodedValue]
                }
            }
        }
        
        return parameters
    }
    
    /// Parse nested query parameters (e.g., "user[name]=John&user[age]=30")
    /// - Parameter queryString: The query string to parse
    /// - Returns: Dictionary representing nested structure
    static func parseNestedParameters(from queryString: String) -> [String: Any] {
        let flatParameters = parseQueryString(queryString)
        var nestedParameters: [String: Any] = [:]
        
        for (key, value) in flatParameters {
            setNestedValue(in: &nestedParameters, key: key, value: value)
        }
        
        return nestedParameters
    }
    
    /// Helper method to set nested values in dictionary
    private static func setNestedValue(in dictionary: inout [String: Any], key: String, value: String) {
        if key.contains("[") && key.contains("]") {
            // Handle nested keys like "user[name]"
            let components = parseNestedKey(key)
            setNestedValueRecursive(in: &dictionary, components: components, value: value)
        } else {
            dictionary[key] = value
        }
    }
    
    /// Parse nested key into components
    private static func parseNestedKey(_ key: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var inBrackets = false
        
        for char in key {
            if char == "[" {
                if !currentComponent.isEmpty {
                    components.append(currentComponent)
                    currentComponent = ""
                }
                inBrackets = true
            } else if char == "]" {
                if inBrackets && !currentComponent.isEmpty {
                    components.append(currentComponent)
                    currentComponent = ""
                }
                inBrackets = false
            } else {
                currentComponent.append(char)
            }
        }
        
        if !currentComponent.isEmpty {
            components.append(currentComponent)
        }
        
        return components
    }
    
    /// Recursively set nested values
    private static func setNestedValueRecursive(in dictionary: inout [String: Any], components: [String], value: String) {
        guard !components.isEmpty else { return }
        
        let key = components[0]
        
        if components.count == 1 {
            dictionary[key] = value
        } else {
            if dictionary[key] == nil {
                dictionary[key] = [String: Any]()
            }
            
            if var nestedDict = dictionary[key] as? [String: Any] {
                let remainingComponents = Array(components.dropFirst())
                setNestedValueRecursive(in: &nestedDict, components: remainingComponents, value: value)
                dictionary[key] = nestedDict
            }
        }
    }
}

// MARK: - Query Parameter Errors

/// Errors related to query parameter parsing
public enum QueryParameterError: Error, LocalizedError, CustomStringConvertible {
    case emptyParameterName
    case parameterNameTooLong(String)
    case parameterValueTooLong(String, Int)
    case invalidEncoding(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyParameterName:
            return "Parameter name cannot be empty"
        case .parameterNameTooLong(let name):
            return "Parameter name too long: \(name)"
        case .parameterValueTooLong(let name, let length):
            return "Parameter value too long for '\(name)': \(length) characters"
        case .invalidEncoding(let value):
            return "Invalid URL encoding: \(value)"
        }
    }
    
    public var description: String {
        return errorDescription ?? "Unknown query parameter error"
    }
}
