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
/// ## Concurrency
///
/// `SwiftWebServer` is `@MainActor`-isolated, which makes it conformant to
/// `Sendable` automatically and matches what the runtime already requires:
/// the listener installs its `CFSocket` accept callbacks on the *current*
/// `CFRunLoop`, so `listen()` and `close()` must be invoked from a thread
/// that's actively running its run loop (in practice: the main thread on
/// iOS/macOS apps).
///
/// Per-request work — reading the request body, running middleware, dispatching
/// to a route handler, writing the response — runs on a background dispatch
/// queue inside `Connection`. The configuration state that the request path
/// reads (routes, middleware, static directories) is annotated
/// `nonisolated(unsafe)` because it is configured once before `listen()` and
/// then treated as read-only. Mutating it after `listen()` is undefined.
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
@MainActor
final public class SwiftWebServer {
    // completion arrays (kept for backward compatibility)
    typealias RouteHandler = (Request, Response) -> Void
    // Configuration state read by per-request `Connection` work that lives
    // on a background queue. Mutate only during configuration (before
    // `listen()`); reads are safe because the post-`listen()` state is
    // effectively immutable.
    nonisolated(unsafe) var routeHandlers: [String: RouteHandler]?

    // new router system
    nonisolated(unsafe) internal let router = Router()

    // middleware system
    nonisolated(unsafe) private let middlewareManager = MiddlewareManager()

    // static file serving
    nonisolated(unsafe) private var staticDirectories: [String] = []

    // server status
    private var _status: ServerStatus = .stopped
    private var _currentPort: UInt = 0

    // store connections — owned by the listener accept callback and the
    // Connection's own teardown on the bg queue. The dispatch hop from
    // `Connection.disconnect()` already serializes mutation to main.
    nonisolated(unsafe) static var connections = [CFData: Connection]()

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

    /// Internal access to middleware manager for Connection class.
    /// Read by `Connection` from a background queue during request handling.
    nonisolated internal var middlewareManagerInternal: MiddlewareManager {
        return middlewareManager
    }

    /// Asserts that configuration mutators (route registration, middleware,
    /// static directories) are called before `listen()`. The state they touch
    /// is annotated `nonisolated(unsafe)` because `Connection` reads it from
    /// a background queue during request handling — mutating after `listen()`
    /// is undefined behavior. This precondition turns "undefined" into a
    /// clean crash with a clear message.
    fileprivate func assertNotRunning(_ method: StaticString = #function) {
        precondition(
            !isRunning,
            "SwiftWebServer.\(method) must be called before listen() — configuration is read-only after the server starts."
        )
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
    ///   - completion: Called only after the listener has successfully reached
    ///     ``status`` `.running`. On any setup failure (invalid host, socket
    ///     creation failure, bind failure) the function returns without
    ///     invoking the closure; inspect ``status`` to detect that case.
    ///
    /// - Note: Hostnames other than `"localhost"` are not resolved; pass
    ///   IP literals.
    public func listen(_ port: UInt, host: String? = nil, completion: () -> Void) {
        _status = .starting

        // Resolve the requested bind into one or both address families.
        // We do this before touching `_currentPort` so an invalid host
        // doesn't leave a stale port in `currentPort` while `status` is `.error`.
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
                                            // CFSocket accept callbacks fire on the run loop the source
                                            // was added to, which `listen()` requires to be the main run
                                            // loop. Assert that isolation so we can call into the
                                            // @MainActor-isolated `handleConnect`.
                                            MainActor.assumeIsolated {
                                                let swiftWebServer = Unmanaged<SwiftWebServer>.fromOpaque(info!).takeUnretainedValue()
                                                swiftWebServer.handleConnect(socket: socket!, address: address!, data: data!)
                                            }
                                          },
                                          &context)

            guard ipv4cfsocket != nil else {
                failStartup("Failed to create IPv4 socket")
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
                                            // Same as the IPv4 callback above: this fires on the run loop
                                            // the source was added to, which `listen()` requires to be
                                            // the main run loop. Assert that isolation so we can call
                                            // into the @MainActor-isolated `handleConnect`.
                                            MainActor.assumeIsolated {
                                                let swiftWebServer = Unmanaged<SwiftWebServer>.fromOpaque(info!).takeUnretainedValue()
                                                swiftWebServer.handleConnect(socket: socket!, address: address!, data: data!)
                                            }
                                          },
                                          &context)

            // IPv6 socket creation failure is fatal whenever the caller
            // explicitly asked for IPv6. The only path where we forgive it
            // is the legacy `host == nil` dual-stack ANY case, where IPv4
            // alone is acceptable on IPv6-disabled hosts.
            if ipv6cfsocket == nil {
                if bind.ipv6Required || ipv4cfsocket == nil {
                    failStartup("Failed to create IPv6 socket")
                    return
                }
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
                failStartup("Failed to bind IPv4 socket on port \(port)")
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
                // IPv6 bind failure is fatal whenever the caller explicitly
                // asked for it. Only the legacy `host == nil` path can
                // silently fall back to IPv4-only, since that path's contract
                // never promised dual-stack.
                if bind.ipv6Required || ipv4cfsocket == nil {
                    failStartup("Failed to bind IPv6 socket on port \(port)")
                    return
                }
                print("Continuing with IPv4 only")
                CFSocketInvalidate(ipv6cfsocket)
                ipv6cfsocket = nil
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

        // Now that the bind succeeded, publish the running port. Setting
        // this earlier would leak a stale port if any prior step had failed.
        _currentPort = port
        _status = .running(port: port)

        // callback
        completion()
    }

    /// Set `_status = .error(message)` and tear down any partially-built
    /// listener resources so a failed `listen()` doesn't leak sockets or
    /// run-loop sources. Also resets `_currentPort` so callers honoring
    /// the doc contract ("0 if not running") see a consistent value.
    private func failStartup(_ message: String) {
        if let source4 = socketsource4 {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source4, CFRunLoopMode.defaultMode)
            socketsource4 = nil
        }
        if let source6 = socketsource6 {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source6, CFRunLoopMode.defaultMode)
            socketsource6 = nil
        }
        if ipv4cfsocket != nil {
            CFSocketInvalidate(ipv4cfsocket)
            ipv4cfsocket = nil
        }
        if ipv6cfsocket != nil {
            CFSocketInvalidate(ipv6cfsocket)
            ipv6cfsocket = nil
        }
        _currentPort = 0
        _status = .error(message)
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
        assertNotRunning()
        middlewareManager.addGlobal(middleware)
        return self
    }

    /// Add route-specific middleware
    /// Usage: server.use("/api", AuthMiddleware())
    @discardableResult
    func use(_ path: String, _ middleware: Middleware) -> SwiftWebServer {
        assertNotRunning()
        let routeMiddleware = RouteMiddleware(middleware: middleware, path: path)
        middlewareManager.addRoute(routeMiddleware)
        return self
    }

    /// Add method and path specific middleware
    /// Usage: server.use(.post, "/api/secure", AuthMiddleware())
    @discardableResult
    func use(_ method: HTTPMethod, _ path: String, _ middleware: Middleware) -> SwiftWebServer {
        assertNotRunning()
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
        assertNotRunning()
        // Add to new router system (supports path parameters)
        router.get(path, handler: completion)

        // Keep legacy support for exact path matching
        let key = routeKey(method: .get, path: path)
        self.routeHandlers?[key] = completion
    }

    /// GET route with middleware
    func get(_ path: String, _ middleware: Middleware..., handler: @escaping (Request, Response) -> Void) {
        // Trap before mutating the middleware manager — the base method's
        // precondition fires after the middleware insertions otherwise.
        assertNotRunning()
        // Add route-specific middleware
        for mw in middleware {
            let routeMiddleware = RouteMiddleware(middleware: mw, path: path, method: .get)
            middlewareManager.addRoute(routeMiddleware)
        }

        // Add the route handler
        get(path, completion: handler)
    }

    func post(_ path: String, completion: @escaping (Request, Response) -> Void) {
        assertNotRunning()
        // Add to new router system (supports path parameters)
        router.post(path, handler: completion)

        // Keep legacy support for exact path matching
        let key = routeKey(method: .post, path: path)
        self.routeHandlers?[key] = completion
    }

    /// POST route with middleware
    func post(_ path: String, _ middleware: Middleware..., handler: @escaping (Request, Response) -> Void) {
        assertNotRunning()
        // Add route-specific middleware
        for mw in middleware {
            let routeMiddleware = RouteMiddleware(middleware: mw, path: path, method: .post)
            middlewareManager.addRoute(routeMiddleware)
        }

        // Add the route handler
        post(path, completion: handler)
    }

    func put(_ path: String, completion: @escaping (Request, Response) -> Void) {
        assertNotRunning()
        // Add to new router system (supports path parameters)
        router.put(path, handler: completion)

        // Keep legacy support for exact path matching
        let key = routeKey(method: .put, path: path)
        self.routeHandlers?[key] = completion
    }

    /// PUT route with middleware
    func put(_ path: String, _ middleware: Middleware..., handler: @escaping (Request, Response) -> Void) {
        assertNotRunning()
        // Add route-specific middleware
        for mw in middleware {
            let routeMiddleware = RouteMiddleware(middleware: mw, path: path, method: .put)
            middlewareManager.addRoute(routeMiddleware)
        }

        // Add the route handler
        put(path, completion: handler)
    }

    func delete(_ path: String, completion: @escaping (Request, Response) -> Void) {
        assertNotRunning()
        // Add to new router system (supports path parameters)
        router.delete(path, handler: completion)

        // Keep legacy support for exact path matching
        let key = routeKey(method: .delete, path: path)
        self.routeHandlers?[key] = completion
    }

    /// DELETE route with middleware
    func delete(_ path: String, _ middleware: Middleware..., handler: @escaping (Request, Response) -> Void) {
        assertNotRunning()
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
        assertNotRunning()
        let absolutePath = URL(fileURLWithPath: staticDirectory).path
        if !staticDirectories.contains(absolutePath) {
            staticDirectories.append(absolutePath)
        }
    }

    /// Check if a file exists in any of the static directories.
    /// Called from `Connection`'s background-queue request path; the
    /// `staticDirectories` array is annotated `nonisolated(unsafe)` and is
    /// expected to be configured before `listen()`.
    nonisolated internal func findStaticFile(for path: String) -> String? {
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
