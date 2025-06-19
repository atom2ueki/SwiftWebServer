//
//  LoggerMiddleware.swift
//  SwiftWebServer
//
//  Logger middleware for request/response logging
//

import Foundation

/// Logger level enumeration
public enum LoggerLevel {
    case none
    case basic
    case detailed
}

/// Configuration for Logger middleware
public struct LoggerOptions {
    public let level: LoggerLevel
    public let includeHeaders: Bool
    public let includeBody: Bool
    public let customLogger: ((String) -> Void)?

    public init(
        level: LoggerLevel = .basic,
        includeHeaders: Bool = false,
        includeBody: Bool = false,
        customLogger: ((String) -> Void)? = nil
    ) {
        self.level = level
        self.includeHeaders = includeHeaders
        self.includeBody = includeBody
        self.customLogger = customLogger
    }

    /// Default options
    public static let `default` = LoggerOptions()
}

/// Logger middleware for request/response logging
public class LoggerMiddleware: BaseMiddleware, ConfigurableMiddleware {
    public typealias Options = LoggerOptions

    private let options: LoggerOptions

    public required init(options: LoggerOptions = .default) {
        self.options = options
        super.init()
    }

    public convenience override init() {
        self.init(options: .default)
    }

    public override func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        let startTime = Date()

        // Log request
        if options.level != .none {
            logRequest(request)
        }

        // Continue to next middleware
        try next()

        // Log response
        if options.level != .none {
            let duration = Date().timeIntervalSince(startTime)
            logResponse(request, response, duration: duration)
        }
    }

    private func logRequest(_ request: Request) {
        var logMessage = "→ \(request.method) \(request.path)"

        if options.level == .detailed {
            logMessage += " HTTP/\(request.httpVersion)"

            if options.includeHeaders && !request.headers.isEmpty {
                logMessage += "\n  Headers:"
                for (key, value) in request.headers {
                    logMessage += "\n    \(key): \(value)"
                }
            }

            if options.includeBody, let bodyString = request.bodyString, !bodyString.isEmpty {
                logMessage += "\n  Body: \(bodyString)"
            }
        }

        log(logMessage)
    }

    private func logResponse(_ request: Request, _ response: Response, duration: TimeInterval) {
        let durationMs = Int(duration * 1000)
        var logMessage = "← \(response.statusCode.rawValue) \(request.method) \(request.path) (\(durationMs)ms)"

        if options.level == .detailed {
            if options.includeHeaders && !response.headers.isEmpty {
                logMessage += "\n  Headers:"
                for (key, value) in response.headers {
                    logMessage += "\n    \(key): \(value)"
                }
            }
        }

        log(logMessage)
    }

    private func log(_ message: String) {
        if let customLogger = options.customLogger {
            customLogger(message)
        } else {
            print(message)
        }
    }
}
