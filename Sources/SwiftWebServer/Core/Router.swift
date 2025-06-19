//
//  Router.swift
//  SwiftWebServer
//
//  Dedicated router system for handling route matching and parameter extraction
//

import Foundation

/// Route definition with pattern matching support
///
/// Represents a single route with its HTTP method, URL pattern, and handler function.
/// Supports path parameters using the format `/users/{id}` where `{id}` becomes
/// a parameter accessible in the request.
///
/// Example:
/// ```swift
/// let route = Route(method: .get, pattern: "/users/{id}") { req, res in
///     let userId = req.pathParameters["id"]
///     res.send("User ID: \(userId ?? "unknown")")
/// }
/// ```
public struct Route {
    /// The HTTP method this route responds to
    public let method: HTTPMethod
    /// The URL pattern with optional path parameters
    public let pattern: String
    /// The handler function to execute when this route matches
    public let handler: (Request, Response) -> Void
    /// Parsed path segments for efficient matching
    public let pathSegments: [PathSegment]

    /// Initialize a new route
    ///
    /// - Parameters:
    ///   - method: The HTTP method for this route
    ///   - pattern: The URL pattern (e.g., "/users/{id}")
    ///   - handler: The function to execute when this route matches
    public init(method: HTTPMethod, pattern: String, handler: @escaping (Request, Response) -> Void) {
        self.method = method
        self.pattern = pattern
        self.handler = handler
        self.pathSegments = PathSegment.parse(pattern: pattern)
    }

    /// Check if this route matches the given request
    ///
    /// Compares the request's method and path against this route's pattern.
    /// Extracts path parameters if the route matches.
    ///
    /// - Parameter request: The incoming HTTP request
    /// - Returns: RouteMatch with extracted parameters if matched, nil otherwise
    public func matches(request: Request) -> RouteMatch? {
        guard request.method == method else { return nil }

        let requestSegments = request.path.split(separator: "/").map(String.init)
        guard requestSegments.count == pathSegments.count else { return nil }

        var pathParameters: [String: String] = [:]

        for (index, segment) in pathSegments.enumerated() {
            let requestSegment = requestSegments[index]

            switch segment {
            case .literal(let value):
                if value != requestSegment {
                    return nil
                }
            case .parameter(let name):
                pathParameters[name] = requestSegment
            }
        }

        return RouteMatch(route: self, pathParameters: pathParameters)
    }
}

/// Result of a successful route match
public struct RouteMatch {
    public let route: Route
    public let pathParameters: [String: String]
}

/// Path segment types for route pattern matching
public enum PathSegment: Equatable {
    case literal(String)
    case parameter(String)

    /// Parse a route pattern into path segments
    /// Example: "/user/{id}/posts/{postId}" -> [.literal("user"), .parameter("id"), .literal("posts"), .parameter("postId")]
    public static func parse(pattern: String) -> [PathSegment] {
        let segments = pattern.split(separator: "/").map(String.init)
        return segments.map { segment in
            if segment.hasPrefix("{") && segment.hasSuffix("}") {
                let paramName = String(segment.dropFirst().dropLast())
                return .parameter(paramName)
            } else {
                return .literal(segment)
            }
        }
    }
}

/// Main router class for managing routes and route matching
///
/// The Router is responsible for storing route definitions and finding
/// the appropriate route handler for incoming requests. It supports
/// path parameters and maintains routes in registration order.
///
/// Example:
/// ```swift
/// let router = Router()
/// router.addRoute(method: .get, pattern: "/users/{id}") { req, res in
///     // Handle user request
/// }
///
/// if let match = router.findRoute(for: request) {
///     match.route.handler(request, response)
/// }
/// ```
public class Router {
    private var routes: [Route] = []

    /// Initialize a new router
    public init() {}

    /// Add a route to the router
    ///
    /// Registers a new route with the specified method, pattern, and handler.
    /// Routes are matched in the order they are added.
    ///
    /// - Parameters:
    ///   - method: The HTTP method for this route
    ///   - pattern: The URL pattern (supports path parameters like "/users/{id}")
    ///   - handler: The function to execute when this route matches
    public func addRoute(method: HTTPMethod, pattern: String, handler: @escaping (Request, Response) -> Void) {
        let route = Route(method: method, pattern: pattern, handler: handler)
        routes.append(route)
    }

    /// Find a matching route for the given request
    ///
    /// Searches through registered routes to find the first one that matches
    /// the request's method and path. Returns the match with extracted parameters.
    ///
    /// - Parameter request: The incoming HTTP request
    /// - Returns: RouteMatch if a matching route is found, nil otherwise
    public func findRoute(for request: Request) -> RouteMatch? {
        for route in routes {
            if let match = route.matches(request: request) {
                return match
            }
        }
        return nil
    }

    /// Get all registered routes
    ///
    /// - Returns: Array of all routes registered with this router
    public var allRoutes: [Route] {
        return routes
    }

    /// Remove all routes
    ///
    /// Clears all registered routes from the router.
    public func clearRoutes() {
        routes.removeAll()
    }

    /// Remove routes matching specific criteria
    public func removeRoutes(method: HTTPMethod? = nil, pattern: String? = nil) {
        routes.removeAll { route in
            if let method = method, route.method != method {
                return false
            }
            if let pattern = pattern, route.pattern != pattern {
                return false
            }
            return true
        }
    }
}

// MARK: - Convenience Methods

public extension Router {
    /// Add a GET route
    func get(_ pattern: String, handler: @escaping (Request, Response) -> Void) {
        addRoute(method: .get, pattern: pattern, handler: handler)
    }

    /// Add a POST route
    func post(_ pattern: String, handler: @escaping (Request, Response) -> Void) {
        addRoute(method: .post, pattern: pattern, handler: handler)
    }

    /// Add a PUT route
    func put(_ pattern: String, handler: @escaping (Request, Response) -> Void) {
        addRoute(method: .put, pattern: pattern, handler: handler)
    }

    /// Add a DELETE route
    func delete(_ pattern: String, handler: @escaping (Request, Response) -> Void) {
        addRoute(method: .delete, pattern: pattern, handler: handler)
    }

    /// Add a PATCH route
    func patch(_ pattern: String, handler: @escaping (Request, Response) -> Void) {
        addRoute(method: .patch, pattern: pattern, handler: handler)
    }
}
