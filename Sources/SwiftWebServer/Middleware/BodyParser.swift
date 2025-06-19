import Foundation

/// Configuration options for BodyParser middleware
public struct BodyParserOptions {
    /// Maximum body size in bytes (default: 1MB)
    public let maxBodySize: Int
    /// Whether to parse JSON bodies
    public let parseJSON: Bool
    /// Whether to parse form-urlencoded bodies
    public let parseURLEncoded: Bool
    /// Whether to parse multipart/form-data bodies
    public let parseMultipart: Bool
    /// Custom content type parsers
    public let customParsers: [String: BodyContentParser]

    public init(
        maxBodySize: Int = 1024 * 1024, // 1MB
        parseJSON: Bool = true,
        parseURLEncoded: Bool = true,
        parseMultipart: Bool = false,
        customParsers: [String: BodyContentParser] = [:]
    ) {
        self.maxBodySize = maxBodySize
        self.parseJSON = parseJSON
        self.parseURLEncoded = parseURLEncoded
        self.parseMultipart = parseMultipart
        self.customParsers = customParsers
    }

    /// Default options
    public static let `default` = BodyParserOptions()
}

/// Protocol for custom body content parsers
public protocol BodyContentParser {
    func parse(data: Data) throws -> Any
}

/// JSON body parser
public struct JSONBodyParser: BodyContentParser {
    public func parse(data: Data) throws -> Any {
        return try JSONSerialization.jsonObject(with: data, options: [])
    }
}

/// URL-encoded form body parser
public struct URLEncodedBodyParser: BodyContentParser {
    public func parse(data: Data) throws -> Any {
        guard let string = String(data: data, encoding: .utf8) else {
            throw BodyParserError.invalidEncoding
        }

        var result: [String: String] = [:]
        let pairs = string.components(separatedBy: "&")

        for pair in pairs {
            let components = pair.components(separatedBy: "=")
            if components.count == 2 {
                let key = components[0].removingPercentEncoding ?? components[0]
                let value = components[1].removingPercentEncoding ?? components[1]
                result[key] = value
            }
        }

        return result
    }
}

/// Errors that can occur during body parsing
public enum BodyParserError: Error, LocalizedError {
    case bodyTooLarge(size: Int, maxSize: Int)
    case unsupportedContentType(String)
    case invalidEncoding
    case parsingFailed(Error)
    case noContentType

    public var errorDescription: String? {
        switch self {
        case .bodyTooLarge(let size, let maxSize):
            return "Request body too large: \(size) bytes (max: \(maxSize) bytes)"
        case .unsupportedContentType(let type):
            return "Unsupported content type: \(type)"
        case .invalidEncoding:
            return "Invalid body encoding"
        case .parsingFailed(let error):
            return "Body parsing failed: \(error.localizedDescription)"
        case .noContentType:
            return "No content type specified"
        }
    }
}

/// BodyParser middleware that parses request bodies based on content type
public class BodyParser: BaseMiddleware, ConfigurableMiddleware {
    public typealias Options = BodyParserOptions

    private let options: BodyParserOptions
    private let jsonParser = JSONBodyParser()
    private let urlEncodedParser = URLEncodedBodyParser()

    public required init(options: BodyParserOptions = .default) {
        self.options = options
        super.init()
    }

    /// Convenience initializer
    public convenience override init() {
        self.init(options: .default)
    }

    public override func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        // Only parse body if there is one
        guard let bodyData = request.body, !bodyData.isEmpty else {
            try next()
            return
        }

        // Check body size
        if bodyData.count > options.maxBodySize {
            throw BodyParserError.bodyTooLarge(size: bodyData.count, maxSize: options.maxBodySize)
        }

        // Get content type
        guard let contentType = request.contentType else {
            // If no content type, just continue without parsing
            try next()
            return
        }

        // Parse based on content type
        do {
            let parsedBody = try parseBody(data: bodyData, contentType: contentType)
            request.parsedBody = parsedBody
        } catch {
            throw BodyParserError.parsingFailed(error)
        }

        try next()
    }

    private func parseBody(data: Data, contentType: ContentType) throws -> Any {
        let mimeType = contentType.mimeType.lowercased()

        // Check custom parsers first
        if let customParser = options.customParsers[mimeType] {
            return try customParser.parse(data: data)
        }

        // Built-in parsers
        switch mimeType {
        case "application/json":
            guard options.parseJSON else {
                throw BodyParserError.unsupportedContentType(mimeType)
            }
            return try jsonParser.parse(data: data)

        case "application/x-www-form-urlencoded":
            guard options.parseURLEncoded else {
                throw BodyParserError.unsupportedContentType(mimeType)
            }
            return try urlEncodedParser.parse(data: data)

        case let type where type.hasPrefix("multipart/"):
            guard options.parseMultipart else {
                throw BodyParserError.unsupportedContentType(mimeType)
            }
            // TODO: Implement multipart parsing
            throw BodyParserError.unsupportedContentType("Multipart parsing not yet implemented")

        default:
            throw BodyParserError.unsupportedContentType(mimeType)
        }
    }
}

/// Extension to Request to support parsed body
extension Request {
    private static let parsedBodyKey = "BodyParser.parsedBody"

    /// The parsed body content (set by BodyParser middleware)
    public var parsedBody: Any? {
        get {
            return middlewareStorage[Request.parsedBodyKey]
        }
        set {
            middlewareStorage[Request.parsedBodyKey] = newValue
        }
    }

    /// Get parsed body as a specific type
    public func body<T>(as type: T.Type) -> T? {
        return parsedBody as? T
    }

    /// Get parsed body as JSON dictionary
    public var jsonBody: [String: Any]? {
        return parsedBody as? [String: Any]
    }

    /// Get parsed body as form data
    public var formBody: [String: String]? {
        return parsedBody as? [String: String]
    }
}
