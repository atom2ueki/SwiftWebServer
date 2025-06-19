import Foundation

/// The core middleware protocol that all middleware must implement
/// Middleware functions can modify request/response objects and control the execution flow
public protocol Middleware {
    /// Execute the middleware
    /// - Parameters:
    ///   - request: The HTTP request object
    ///   - response: The HTTP response object
    ///   - next: Function to call to continue to the next middleware
    func execute(request: Request, response: Response, next: @escaping NextFunction) throws
}

/// Type alias for the next function in middleware chain
public typealias NextFunction = () throws -> Void

/// Error thrown when middleware chain is interrupted
public enum MiddlewareError: Error, LocalizedError {
    case chainInterrupted(reason: String)
    case middlewareError(middleware: String, error: Error)
    case invalidMiddleware(reason: String)

    public var errorDescription: String? {
        switch self {
        case .chainInterrupted(let reason):
            return "Middleware chain interrupted: \(reason)"
        case .middlewareError(let middleware, let error):
            return "Error in middleware '\(middleware)': \(error.localizedDescription)"
        case .invalidMiddleware(let reason):
            return "Invalid middleware: \(reason)"
        }
    }
}

/// Manages the execution of middleware chain
public class MiddlewareChain {
    private var middlewares: [Middleware] = []
    private var currentIndex = 0

    /// Add middleware to the chain
    public func add(_ middleware: Middleware) {
        middlewares.append(middleware)
    }

    /// Execute the middleware chain
    /// - Parameters:
    ///   - request: The HTTP request
    ///   - response: The HTTP response
    ///   - completion: Called when chain completes or errors
    public func execute(request: Request, response: Response, completion: @escaping (Error?) -> Void) {
        currentIndex = 0
        executeNext(request: request, response: response, completion: completion)
    }

    private func executeNext(request: Request, response: Response, completion: @escaping (Error?) -> Void) {
        // If we've reached the end of the chain, complete successfully
        guard currentIndex < middlewares.count else {
            completion(nil)
            return
        }

        let middleware = middlewares[currentIndex]
        currentIndex += 1

        let next: NextFunction = { [weak self] in
            self?.executeNext(request: request, response: response, completion: completion)
        }

        do {
            try middleware.execute(request: request, response: response, next: next)
        } catch {
            let middlewareError = MiddlewareError.middlewareError(
                middleware: String(describing: type(of: middleware)),
                error: error
            )
            completion(middlewareError)
        }
    }

    /// Get count of middlewares in chain
    public var count: Int {
        return middlewares.count
    }

    /// Clear all middlewares
    public func clear() {
        middlewares.removeAll()
        currentIndex = 0
    }
}

/// Base class for creating custom middleware
open class BaseMiddleware: Middleware {
    public init() {}

    open func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        // Default implementation just calls next
        try next()
    }
}

/// Middleware that can be configured with options
public protocol ConfigurableMiddleware: Middleware {
    associatedtype Options
    init(options: Options)
}

/// Route-specific middleware container
public struct RouteMiddleware {
    public let middleware: Middleware
    public let path: String?
    public let method: HTTPMethod?

    public init(middleware: Middleware, path: String? = nil, method: HTTPMethod? = nil) {
        self.middleware = middleware
        self.path = path
        self.method = method
    }

    /// Check if this middleware applies to the given request
    public func applies(to request: Request) -> Bool {
        // Check method match
        if let method = self.method, request.method != method {
            return false
        }

        // Check path match
        if let path = self.path {
            // Simple path matching - could be enhanced with pattern matching
            return request.path.hasPrefix(path)
        }

        return true
    }
}

/// Middleware manager for organizing different types of middleware
public class MiddlewareManager {
    private var globalMiddlewares: [Middleware] = []
    private var routeMiddlewares: [RouteMiddleware] = []

    /// Add global middleware that applies to all requests
    public func addGlobal(_ middleware: Middleware) {
        globalMiddlewares.append(middleware)
    }

    /// Add route-specific middleware
    public func addRoute(_ routeMiddleware: RouteMiddleware) {
        routeMiddlewares.append(routeMiddleware)
    }

    /// Build middleware chain for a specific request
    public func buildChain(for request: Request) -> MiddlewareChain {
        let chain = MiddlewareChain()

        // Add global middlewares first
        for middleware in globalMiddlewares {
            chain.add(middleware)
        }

        // Add applicable route middlewares
        for routeMiddleware in routeMiddlewares {
            if routeMiddleware.applies(to: request) {
                chain.add(routeMiddleware.middleware)
            }
        }

        return chain
    }

    /// Clear all middlewares
    public func clear() {
        globalMiddlewares.removeAll()
        routeMiddlewares.removeAll()
    }
}
