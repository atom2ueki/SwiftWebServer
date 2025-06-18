//
//  HTTPDateFormatter.swift
//  SwiftWebServer
//
//  HTTP date formatting utilities with configurable formats, timezones, and locales
//

import Foundation

/// HTTP date format types
public enum HTTPDateFormat {
    case rfc7231    // "EEE, dd MMM yyyy HH:mm:ss 'GMT'" - Standard HTTP date format (RFC 7231)
    case rfc1123    // "EEE, dd MMM yyyy HH:mm:ss 'GMT'" - Same as RFC 7231, alias for clarity
    case rfc850     // "EEEE, dd-MMM-yy HH:mm:ss 'GMT'" - Obsolete format (RFC 850)
    case asctime    // "EEE MMM d HH:mm:ss yyyy" - ANSI C asctime() format
    case iso8601    // "yyyy-MM-dd'T'HH:mm:ss'Z'" - ISO 8601 format
    case custom(String) // Custom format string
    
    /// The format string for this date format
    public var formatString: String {
        switch self {
        case .rfc7231, .rfc1123:
            return "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        case .rfc850:
            return "EEEE, dd-MMM-yy HH:mm:ss 'GMT'"
        case .asctime:
            return "EEE MMM d HH:mm:ss yyyy"
        case .iso8601:
            return "yyyy-MM-dd'T'HH:mm:ss'Z'"
        case .custom(let format):
            return format
        }
    }
    
    /// Default timezone for this format
    public var defaultTimeZone: TimeZone {
        switch self {
        case .rfc7231, .rfc1123, .rfc850:
            return TimeZone(abbreviation: "GMT") ?? TimeZone.current
        case .iso8601:
            return TimeZone(abbreviation: "UTC") ?? TimeZone.current
        case .asctime, .custom:
            return TimeZone.current
        }
    }
}

/// Configuration for HTTP date formatting
public struct HTTPDateFormatterConfig {
    public let format: HTTPDateFormat
    public let timeZone: TimeZone
    public let locale: Locale
    
    public init(
        format: HTTPDateFormat = .rfc7231,
        timeZone: TimeZone? = nil,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) {
        self.format = format
        self.timeZone = timeZone ?? format.defaultTimeZone
        self.locale = locale
    }
    
    /// Default configuration for HTTP headers (RFC 7231)
    public static let httpDefault = HTTPDateFormatterConfig()
    
    /// Configuration for cookie expiration dates
    public static let cookieExpires = HTTPDateFormatterConfig(format: .rfc7231)
    
    /// Configuration for ISO 8601 dates
    public static let iso8601 = HTTPDateFormatterConfig(
        format: .iso8601,
        timeZone: TimeZone(abbreviation: "UTC")
    )
}

/// HTTP date formatting utility with configurable formats, timezones, and locales
public struct HTTPDateFormatter {
    
    // MARK: - Cached Formatters
    
    private static var formatterCache: [String: DateFormatter] = [:]
    private static let cacheQueue = DispatchQueue(label: "atom2ueki.http.date.formatter.cache", attributes: .concurrent)
    
    // MARK: - Public Methods
    
    /// Format date using the specified configuration
    ///
    /// - Parameters:
    ///   - date: The date to format
    ///   - config: The formatting configuration (defaults to HTTP standard format)
    /// - Returns: Formatted date string according to the configuration
    public static func format(_ date: Date, config: HTTPDateFormatterConfig = .httpDefault) -> String {
        let formatter = getFormatter(for: config)
        return formatter.string(from: date)
    }

    /// Format date for HTTP headers (RFC 7231 format)
    ///
    /// Formats the date according to RFC 7231 standard for HTTP headers.
    /// Example output: "Wed, 21 Oct 2015 07:28:00 GMT"
    ///
    /// - Parameter date: The date to format
    /// - Returns: RFC 7231 formatted date string
    public static func formatHTTPDate(_ date: Date) -> String {
        return format(date, config: .httpDefault)
    }

    /// Format date for cookie expiration
    ///
    /// Formats the date for use in Set-Cookie headers' Expires attribute.
    /// Uses the same RFC 7231 format as HTTP headers.
    ///
    /// - Parameter date: The expiration date to format
    /// - Returns: Cookie-compatible date string
    public static func formatCookieExpires(_ date: Date) -> String {
        return format(date, config: .cookieExpires)
    }

    /// Format date as ISO 8601
    ///
    /// Formats the date according to ISO 8601 standard.
    /// Example output: "2015-10-21T07:28:00Z"
    ///
    /// - Parameter date: The date to format
    /// - Returns: ISO 8601 formatted date string
    public static func formatISO8601(_ date: Date) -> String {
        return format(date, config: .iso8601)
    }
    
    /// Parse HTTP date string using common HTTP date formats
    ///
    /// Attempts to parse a date string using multiple HTTP date formats:
    /// - RFC 7231/1123: "Wed, 21 Oct 2015 07:28:00 GMT"
    /// - RFC 850: "Wednesday, 21-Oct-15 07:28:00 GMT"
    /// - ANSI C asctime(): "Wed Oct 21 07:28:00 2015"
    ///
    /// - Parameter dateString: The date string to parse
    /// - Returns: Parsed Date object, or nil if parsing fails
    public static func parseHTTPDate(_ dateString: String) -> Date? {
        let configs: [HTTPDateFormatterConfig] = [
            .httpDefault,
            HTTPDateFormatterConfig(format: .rfc850),
            HTTPDateFormatterConfig(format: .asctime)
        ]

        for config in configs {
            let formatter = getFormatter(for: config)
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
    
    // MARK: - Private Methods
    
    private static func getFormatter(for config: HTTPDateFormatterConfig) -> DateFormatter {
        let cacheKey = "\(config.format.formatString)_\(config.timeZone.identifier)_\(config.locale.identifier)"
        
        return cacheQueue.sync {
            if let cachedFormatter = formatterCache[cacheKey] {
                return cachedFormatter
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = config.format.formatString
            formatter.timeZone = config.timeZone
            formatter.locale = config.locale
            
            formatterCache[cacheKey] = formatter
            return formatter
        }
    }
    
    /// Clear the formatter cache (useful for memory management)
    ///
    /// Removes all cached DateFormatter instances to free up memory.
    /// Formatters will be recreated as needed on subsequent calls.
    /// This operation is thread-safe.
    public static func clearCache() {
        cacheQueue.async(flags: .barrier) {
            formatterCache.removeAll()
        }
    }
}

// MARK: - Convenience Extensions

public extension Date {
    /// Format this date for HTTP headers
    ///
    /// Convenience method to format the date according to RFC 7231 standard.
    ///
    /// - Returns: RFC 7231 formatted date string
    func httpFormatted() -> String {
        return HTTPDateFormatter.formatHTTPDate(self)
    }

    /// Format this date for cookie expiration
    ///
    /// Convenience method to format the date for use in Set-Cookie headers.
    ///
    /// - Returns: Cookie-compatible date string
    func cookieExpiresFormatted() -> String {
        return HTTPDateFormatter.formatCookieExpires(self)
    }

    /// Format this date as ISO 8601
    ///
    /// Convenience method to format the date according to ISO 8601 standard.
    ///
    /// - Returns: ISO 8601 formatted date string
    func iso8601Formatted() -> String {
        return HTTPDateFormatter.formatISO8601(self)
    }
}
