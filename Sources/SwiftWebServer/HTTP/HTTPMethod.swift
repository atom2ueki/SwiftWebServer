import Foundation

/// HTTP methods supported by SwiftWebServer
public enum HTTPMethod: String, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
    case patch = "PATCH"
    
    /// All standard HTTP methods
    public static let allMethods: [HTTPMethod] = HTTPMethod.allCases
    
    /// Common HTTP methods used in REST APIs
    public static let restMethods: [HTTPMethod] = [.get, .post, .put, .delete, .patch]
    
    /// Safe HTTP methods (should not have side effects)
    public static let safeMethods: [HTTPMethod] = [.get, .head, .options]

    /// Idempotent HTTP methods (multiple identical requests should have the same effect)
    public static let idempotentMethods: [HTTPMethod] = [.get, .head, .put, .delete, .options]
    
    /// HTTP methods that typically include a request body
    public static let methodsWithBody: [HTTPMethod] = [.post, .put, .patch]
    
    /// Whether this method is safe (should not have side effects)
    public var isSafe: Bool {
        return HTTPMethod.safeMethods.contains(self)
    }
    
    /// Whether this method is idempotent
    public var isIdempotent: Bool {
        return HTTPMethod.idempotentMethods.contains(self)
    }
    
    /// Whether this method typically includes a request body
    public var hasBody: Bool {
        return HTTPMethod.methodsWithBody.contains(self)
    }
    
    /// Initialize from string (case-insensitive)
    public init?(string: String) {
        self.init(rawValue: string.uppercased())
    }
}

extension HTTPMethod: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}

extension HTTPMethod: Comparable {
    public static func < (lhs: HTTPMethod, rhs: HTTPMethod) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
