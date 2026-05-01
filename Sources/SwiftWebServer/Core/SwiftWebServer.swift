//
//  SwiftWebServer.swift
//  SwiftWebServer
//
//  Core web server implementation
//

import Foundation

/// Represents the current status of the web server
public enum ServerStatus {
    /// Server is stopped and not accepting connections
    case stopped
    /// Server is in the process of starting up
    case starting
    /// Server is running and accepting connections on the specified port
    case running(port: UInt)
    /// Server encountered an error with the specified error message
    case error(String)
}

/// A lightweight, Swift-based HTTP web server with middleware support
///
/// SwiftWebServer provides a simple yet powerful API for creating HTTP servers with:
/// - Route handling with path parameters
/// - Middleware system for request/response processing
/// - Static file serving
/// - Built-in support for common HTTP methods
/// - Configurable CORS, logging, authentication, and more
///
/// Example usage:
/// ```swift
/// let server = SwiftWebServer()
///
/// // Add middleware
/// server.use(LoggerMiddleware())
/// server.use(CORSMiddleware())
///
/// // Define routes
/// server.get("/hello") { req, res in
///     res.send("Hello, World!")
/// }
///
/// // Start server
/// try server.start(port: 8080)
/// ```
final public class SwiftWebServer {
    // completion arrays (kept for backward compatibility)
    typealias RouteHandler = (Request, Response) -> Void
    var routeHandlers: [String: RouteHandler]?

    // new router system
    internal let router = Router()

    // middleware system
    private let middlewareManager = MiddlewareManager()

    // static file serving
    private var staticDirectories: [String] = []

    // server status
    private var _status: ServerStatus = .stopped
    private var _currentPort: UInt = 0

    // store connections
    static var connections = [CFData: Connection]()

    var ipv4cfsocket: CFSocket!
    var ipv6cfsocket: CFSocket!
    var socketsource4: CFRunLoopSource!
    var socketsource6: CFRunLoopSource!

    /// Initialize a new SwiftWebServer instance
    ///
    /// Creates a new server instance ready to accept route definitions and middleware.
    /// The server is not started until `start()` or `listen()` is called.
    public init() {
        routeHandlers = [String: RouteHandler]()
    }

    /// Initialize server with a default port (for convenience)
    ///
    /// - Parameter port: The port number to use when starting the server
    /// - Note: The port is not used until `start()` or `listen()` is called
    public convenience init(port: UInt) {
        self.init()
    }

    // MARK: - Public Status API

    /// Current server status
    ///
    /// Returns the current status of the server, which can be:
    /// - `.stopped`: Server is not running
    /// - `.starting`: Server is in the process of starting
    /// - `.running(port)`: Server is running on the specified port
    /// - `.error(message)`: Server encountered an error
    public var status: ServerStatus {
        return _status
    }

    /// Current port the server is running on (0 if not running)
    ///
    /// - Returns: The port number if the server is running, 0 otherwise
    public var currentPort: UInt {
        return _currentPort
    }

    /// Whether the server is currently running
    ///
    /// - Returns: `true` if the server is accepting connections, `false` otherwise
    public var isRunning: Bool {
        if case .running = _status {
            return true
        }
        return false
    }

    /// Get a list of registered routes
    ///
    /// - Returns: Array of route patterns that have been registered with the server
    public var registeredRoutes: [String] {
        guard let handlers = routeHandlers else { return [] }
        return Array(handlers.keys)
    }

    /// Get a list of static directories being served
    ///
    /// - Returns: Array of directory paths that are being served as static content
    public var staticDirectoriesServed: [String] {
        return staticDirectories
    }

    /// Internal access to middleware manager for Connection class
    internal var middlewareManagerInternal: MiddlewareManager {
        return middlewareManager
    }

    /// Start listening on `port`, optionally constrained to a specific bind address.
    ///
    /// - Parameters:
    ///   - port: TCP port to listen on.
    ///   - host: Optional bind host. When `nil` (the default), the server binds
    ///     both an IPv4 socket on `INADDR_ANY` and an IPv6 socket on
    ///     `in6addr_any` — i.e. all interfaces, the original behavior. Pass a
    ///     specific value to restrict the bind:
    ///     - `"localhost"` — dual-stack loopback (`127.0.0.1` + `::1`). Use this
    ///       for any flow that should be reachable only from the same machine
    ///       (OAuth callbacks, IPC, dev tooling). Strongly recommended over
    ///       `nil` whenever LAN reachability is not desired.
    ///     - `"127.0.0.1"` — IPv4 loopback only.
    ///     - `"::1"` — IPv6 loopback only.
    ///     - `"0.0.0.0"` — IPv4 all interfaces only.
    ///     - `"::"` — IPv6 all interfaces only.
    ///     - Any other IPv4 or IPv6 literal — single-family bind on that address.
    ///   - completion: Called once the listener has finished its setup
    ///     attempt. Inspect ``status`` to determine whether it succeeded.
    ///
    /// - Note: Hostnames other than `"localhost"` are not resolved; pass
    ///   IP literals.
    public func listen(_ port: UInt, host: String? = nil, completion: () -> Void) {
        // Update status to starting
        _status = .starting
        _currentPort = port

        // Resolve the requested bind into one or both address families.
        let bind: BindRequest
        do {
            bind = try BindRequest.resolve(host: host)
        } catch let error as BindResolveError {
            _status = .error(error.message)
            return
        } catch {
            _status = .error("Invalid bind host: \(error.localizedDescription)")
            return
        }

        // prepare reuse address
        let intTrue: UInt32 = 1
        let unsafeIntTrue = withUnsafePointer(to: intTrue) { truePointer in
            return truePointer
        }

        var context = CFSocketContext(version: 0,
                                      info: UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque()),
                                      retain: nil,
                                      release: nil,
                                      copyDescription: nil)

        // create ipv4 socket (only if requested)
        if bind.ipv4 != nil {
            ipv4cfsocket = CFSocketCreate(kCFAllocatorDefault,
                                          PF_INET,
                                          SOCK_STREAM,
                                          IPPROTO_TCP,
                                          CFSocketCallBackType.acceptCallBack.rawValue,
                                          { (socket, _, address, data, info) in
                                            let swiftWebServer = Unmanaged<SwiftWebServer>.fromOpaque(info!).takeUnretainedValue()
                                            swiftWebServer.handleConnect(socket: socket!, address: address!, data: data!)
                                          },
                                          &context)

            guard ipv4cfsocket != nil else {
                _status = .error("Failed to create IPv4 socket")
                return
            }
        }

        // create ipv6 socket (only if requested)
        if bind.ipv6 != nil {
            ipv6cfsocket = CFSocketCreate(kCFAllocatorDefault,
                                          PF_INET6,
                                          SOCK_STREAM,
                                          IPPROTO_TCP,
                                          CFSocketCallBackType.acceptCallBack.rawValue,
                                          { (socket, _, address, data, info) in
                                            let swiftWebServer = Unmanaged<SwiftWebServer>.fromOpaque(info!).takeUnretainedValue()
                                            swiftWebServer.handleConnect(socket: socket!, address: address!, data: data!)
                                          },
                                          &context)

            // IPv6 socket creation failure is not critical when IPv4 is also requested
            if ipv6cfsocket == nil && ipv4cfsocket == nil {
                _status = .error("Failed to create IPv6 socket")
                return
            }
        }

        // set reuse address for ipv4
        if ipv4cfsocket != nil {
            setsockopt(CFSocketGetNative(ipv4cfsocket), SOL_SOCKET, SO_REUSEADDR, unsafeIntTrue, socklen_t(MemoryLayout<UInt32>.size))
        }

        // set reuse address for ipv6 (only if socket exists)
        if ipv6cfsocket != nil {
            setsockopt(CFSocketGetNative(ipv6cfsocket), SOL_SOCKET, SO_REUSEADDR, unsafeIntTrue, socklen_t(MemoryLayout<UInt32>.size))
        }

        // bind ipv4 socket
        if let ipv4Address = bind.ipv4, ipv4cfsocket != nil {
            var ipv4addr = sockaddr_in()
            ipv4addr.sin_family = sa_family_t(AF_INET)
            ipv4addr.sin_port = in_port_t(port).bigEndian
            ipv4addr.sin_addr = ipv4Address
            let ipv4data = withUnsafePointer(to: &ipv4addr) {
                $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<sockaddr_in>.size) {
                    Data(bytes: $0, count: MemoryLayout<sockaddr_in>.size)
                }
            }

            let ipv4bindResult = CFSocketSetAddress(ipv4cfsocket, ipv4data as CFData)
            if ipv4bindResult != CFSocketError.success {
                print("ipv4 bind error: \(ipv4bindResult)")
                _status = .error("Failed to bind IPv4 socket on port \(port)")
                return
            }
        }

        // bind ipv6 socket (only if socket was created successfully)
        if let ipv6Address = bind.ipv6, ipv6cfsocket != nil {
            var ipv6addr = sockaddr_in6()
            ipv6addr.sin6_family = sa_family_t(AF_INET6)
            ipv6addr.sin6_port = in_port_t(port).bigEndian
            ipv6addr.sin6_addr = ipv6Address
            let ipv6data = withUnsafePointer(to: &ipv6addr) {
                $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<sockaddr_in6>.size) {
                    Data(bytes: $0, count: MemoryLayout<sockaddr_in6>.size)
                }
            }

            let ipv6bindResult = CFSocketSetAddress(ipv6cfsocket, ipv6data as CFData)
            if ipv6bindResult != CFSocketError.success {
                print("ipv6 bind error: \(ipv6bindResult)")
                // IPv6 binding failure is non-critical only if we also have an IPv4 socket
                if ipv4cfsocket != nil {
                    print("Continuing with IPv4 only")
                    CFSocketInvalidate(ipv6cfsocket)
                    ipv6cfsocket = nil
                } else {
                    _status = .error("Failed to bind IPv6 socket on port \(port)")
                    return
                }
            }
        }

        // listening on a socket by adding the socket to a run loop.
        if ipv4cfsocket != nil {
            socketsource4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv4cfsocket, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), socketsource4, CFRunLoopMode.defaultMode)
        }

        if ipv6cfsocket != nil {
            socketsource6 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv6cfsocket, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), socketsource6, CFRunLoopMode.defaultMode)
        }

        // Update status to running
        _status = .running(port: port)

        // callback
        completion()
    }

    public func close() {
        // Remove run loop sources if they exist
        if let source4 = socketsource4 {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source4, CFRunLoopMode.defaultMode)
            socketsource4 = nil
        }

        if let source6 = socketsource6 {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source6, CFRunLoopMode.defaultMode)
            socketsource6 = nil
        }

        // Invalidate sockets if they exist
        if ipv4cfsocket != nil {
            CFSocketInvalidate(ipv4cfsocket)
            ipv4cfsocket = nil
        }

        if ipv6cfsocket != nil {
            CFSocketInvalidate(ipv6cfsocket)
            ipv6cfsocket = nil
        }

        // close all connections inside connections
        for connection in SwiftWebServer.connections {
            connection.value.disconnect()
        }
        SwiftWebServer.connections.removeAll()

        // Update status to stopped
        _status = .stopped
        _currentPort = 0
    }

    func handleConnect(socket: CFSocket, address: CFData, data: UnsafeRawPointer) {
        // The data parameter contains the native handle of the accepted socket
        let childSocketNativeHandle = data.load(as: CFSocketNativeHandle.self)

        let connection = Connection(nativeSocketHandle: childSocketNativeHandle, server: self)
        SwiftWebServer.connections[address] = connection
    }
}

// MARK: - Middleware Support
public extension SwiftWebServer {
    /// Add global middleware that applies to all requests
    /// Usage: server.use(LoggerMiddleware())
    @discardableResult
    func use(_ middleware: Middleware) -> SwiftWebServer {
        middlewareManager.addGlobal(middleware)
        return self
    }

    /// Add route-specific middleware
    /// Usage: server.use("/api", AuthMiddleware())
    @discardableResult
    func use(_ path: String, _ middleware: Middleware) -> SwiftWebServer {
        let routeMiddleware = RouteMiddleware(middleware: middleware, path: path)
        middlewareManager.addRoute(routeMiddleware)
        return self
    }

    /// Add method and path specific middleware
    /// Usage: server.use(.post, "/api/secure", AuthMiddleware())
    @discardableResult
    func use(_ method: HTTPMethod, _ path: String, _ middleware: Middleware) -> SwiftWebServer {
        let routeMiddleware = RouteMiddleware(middleware: middleware, path: path, method: method)
        middlewareManager.addRoute(routeMiddleware)
        return self
    }
}

// MARK: make routes for server
// TODO: use factory pattern to handle CURD operations.
public extension SwiftWebServer {

    /// Generate route key for method and path
    private func routeKey(method: HTTPMethod, path: String) -> String {
        return "\(method.rawValue) \(path)"
    }
    func get(_ path: String, completion: @escaping (Request, Response) -> Void) {
        // Add to new router system (supports path parameters)
        router.get(path, handler: completion)

        // Keep legacy support for exact path matching
        let key = routeKey(method: .get, path: path)
        self.routeHandlers?[key] = completion
    }

    /// GET route with middleware
    func get(_ path: String, _ middleware: Middleware..., handler: @escaping (Request, Response) -> Void) {
        // Add route-specific middleware
        for mw in middleware {
            let routeMiddleware = RouteMiddleware(middleware: mw, path: path, method: .get)
            middlewareManager.addRoute(routeMiddleware)
        }

        // Add the route handler
        get(path, completion: handler)
    }

    func post(_ path: String, completion: @escaping (Request, Response) -> Void) {
        // Add to new router system (supports path parameters)
        router.post(path, handler: completion)

        // Keep legacy support for exact path matching
        let key = routeKey(method: .post, path: path)
        self.routeHandlers?[key] = completion
    }

    /// POST route with middleware
    func post(_ path: String, _ middleware: Middleware..., handler: @escaping (Request, Response) -> Void) {
        // Add route-specific middleware
        for mw in middleware {
            let routeMiddleware = RouteMiddleware(middleware: mw, path: path, method: .post)
            middlewareManager.addRoute(routeMiddleware)
        }

        // Add the route handler
        post(path, completion: handler)
    }

    func put(_ path: String, completion: @escaping (Request, Response) -> Void) {
        // Add to new router system (supports path parameters)
        router.put(path, handler: completion)

        // Keep legacy support for exact path matching
        let key = routeKey(method: .put, path: path)
        self.routeHandlers?[key] = completion
    }

    /// PUT route with middleware
    func put(_ path: String, _ middleware: Middleware..., handler: @escaping (Request, Response) -> Void) {
        // Add route-specific middleware
        for mw in middleware {
            let routeMiddleware = RouteMiddleware(middleware: mw, path: path, method: .put)
            middlewareManager.addRoute(routeMiddleware)
        }

        // Add the route handler
        put(path, completion: handler)
    }

    func delete(_ path: String, completion: @escaping (Request, Response) -> Void) {
        // Add to new router system (supports path parameters)
        router.delete(path, handler: completion)

        // Keep legacy support for exact path matching
        let key = routeKey(method: .delete, path: path)
        self.routeHandlers?[key] = completion
    }

    /// DELETE route with middleware
    func delete(_ path: String, _ middleware: Middleware..., handler: @escaping (Request, Response) -> Void) {
        // Add route-specific middleware
        for mw in middleware {
            let routeMiddleware = RouteMiddleware(middleware: mw, path: path, method: .delete)
            middlewareManager.addRoute(routeMiddleware)
        }

        // Add the route handler
        delete(path, completion: handler)
    }
}

// MARK: - Static file serving
extension SwiftWebServer {

    /// Add a directory to serve static files from
    /// Enables serving static files from the specified directory
    public func use(staticDirectory: String) {
        let absolutePath = URL(fileURLWithPath: staticDirectory).path
        if !staticDirectories.contains(absolutePath) {
            staticDirectories.append(absolutePath)
        }
    }

    /// Check if a file exists in any of the static directories
    internal func findStaticFile(for path: String) -> String? {
        // Remove leading slash if present
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        // If path is empty or just "/", try to serve index.html
        let filePath = cleanPath.isEmpty ? "index.html" : cleanPath

        print("Looking for static file: '\(filePath)' in directories: \(staticDirectories)")

        for directory in staticDirectories {
            // First try the full path as requested
            let fullPath = URL(fileURLWithPath: directory).appendingPathComponent(filePath).path
            print("Checking path: \(fullPath)")
            if FileManager.default.fileExists(atPath: fullPath) {
                print("Found static file at: \(fullPath)")
                return fullPath
            }

            // If not found and path contains subdirectories, try just the filename
            // This handles cases where Xcode flattens directory structure in app bundle
            if filePath.contains("/") {
                let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                let flatPath = URL(fileURLWithPath: directory).appendingPathComponent(fileName).path
                print("Checking flattened path: \(flatPath)")
                if FileManager.default.fileExists(atPath: flatPath) {
                    print("Found static file at flattened path: \(flatPath)")
                    return flatPath
                }
            }
        }

        print("Static file not found: \(filePath)")
        return nil
    }
}
