# SwiftWebServer

A lightweight, Swift-based HTTP web server with middleware support.

## Features

- 🚀 **Lightweight & Fast**: Minimal overhead with efficient request handling
- 🔧 **Middleware System**: Extensible middleware architecture for request/response processing
- 🛣️ **Route Handling**: Support for path parameters (`/users/{id}`) and multiple HTTP methods
- 🦾 **Body Parsing**: JSON and form data parsing middleware
- 📁 **Static File Serving**: Built-in static file serving with automatic MIME type detection
- 🍪 **Cookie Support**: Full cookie parsing and setting capabilities with secure attributes
- 🔒 **Authentication**: Bearer token authentication middleware with JWT support
- 🌐 **CORS Support**: Cross-Origin Resource Sharing middleware with configurable options
- 📝 **Logging**: Configurable request/response logging with detailed output options
- 🏷️ **ETag Support**: Conditional requests with 304 Not Modified responses for caching
- 🔄 **HTTP Redirects**: Support for temporary and permanent redirects with proper status codes
- 🎯 **Error Handling**: Comprehensive error responses with proper HTTP status codes
- 📱 **SwiftUI Integration**: Native iOS/macOS integration with example application

## Demo (Blog WebApp)
![SwiftWebServer Demo](https://github.com/atom2ueki/SwiftWebServer/raw/main/demo.gif)

## Quick Start

### Installation

Add SwiftWebServer to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atom2ueki/SwiftWebServer.git", from: "1.0.0")
]
```

### Basic Usage

```swift
import SwiftWebServer

let server = SwiftWebServer()

// Add middleware
server.use(LoggerMiddleware())
server.use(CORSMiddleware())

// Define routes
server.get("/hello") { req, res in
    res.send("Hello, World!")
}

server.get("/users/{id}") { req, res in
    let userId = req.pathParameters["id"] ?? "unknown"
    res.json("""
    {
        "userId": "\(userId)",
        "message": "User details"
    }
    """)
}

// Start server
try server.start(port: 8080)
print("Server running on http://localhost:8080")
```

## Architecture Overview

SwiftWebServer follows a middleware-based architecture where requests flow through a chain of middleware functions before reaching route handlers, and responses flow back through the same chain.

### Request/Response Workflow

The diagram above shows how requests flow through SwiftWebServer:

1. **Client Request**: HTTP request arrives at the server
2. **Connection Handler**: Accepts and manages the connection
3. **Request Parsing**: Parses HTTP headers, method, path, and body
4. **Middleware Chain**: Request flows through registered middleware in order
5. **Route Matching**: Attempts to find a matching route handler
6. **Static Files**: If no route matches, checks for static files
7. **Response Processing**: Generates response through middleware chain
8. **Client Response**: Sends final HTTP response back to client

### Middleware Architecture

Middleware functions are the core of SwiftWebServer's extensibility. Each middleware can:

- **Inspect and modify** incoming requests
- **Add functionality** like authentication, logging, or parsing
- **Short-circuit** the request chain (e.g., for authentication failures)
- **Process responses** on the way back to the client

#### Middleware Execution Order

```
Request  →  [Middleware 1]  →  [Middleware 2]  →  [Route Handler]
Response ←  [Middleware 1]  ←  [Middleware 2]  ←  [Route Handler]
```

Middleware executes in the order it's registered using `server.use()`, and response processing happens in reverse order.

## Built-in Middleware

SwiftWebServer comes with several built-in middleware components:

### BodyParser
Parses JSON and form data from request bodies.

```swift
server.use(BodyParser())

server.post("/api/users") { req, res in
    if let jsonBody = req.jsonBody {
        // Handle JSON data
        let userData = jsonBody
    } else if let formBody = req.formBody {
        // Handle form data
        let name = formBody["name"]
    }
}
```

### LoggerMiddleware
Logs incoming requests and outgoing responses with configurable detail levels.

```swift
// Basic logging
server.use(LoggerMiddleware())

// Detailed logging with headers
server.use(LoggerMiddleware(options: LoggerOptions(
    level: .detailed,
    includeHeaders: true
)))
```

### CORSMiddleware
Handles Cross-Origin Resource Sharing (CORS) headers for web applications.

```swift
// Default CORS settings
server.use(CORSMiddleware())

// Custom CORS configuration
server.use(CORSMiddleware(options: CORSOptions(
    allowedOrigins: ["https://myapp.com"],
    allowedMethods: [.get, .post, .put],
    allowedHeaders: [.contentType, .authorization],
    allowCredentials: true
)))
```

### CookieMiddleware
Parses incoming cookies and provides methods for setting response cookies.

```swift
server.use(CookieMiddleware())

// In route handlers
server.get("/login") { req, res in
    // Read cookies
    let sessionId = req.cookie("sessionId")

    // Set cookies
    res.cookie("sessionId", "abc123", attributes: CookieAttributes(
        expires: Date().addingTimeInterval(3600),
        httpOnly: true,
        secure: true
    ))
}
```

### BearerTokenMiddleware
Provides Bearer token authentication for protected routes with JWT support.

```swift
let authMiddleware = BearerTokenMiddleware(options: BearerTokenOptions(
    validator: { token in
        // Validate token against your auth system
        return token == "valid-api-key" || validateJWT(token)
    }
))

// Apply to specific routes
server.get("/protected", middleware: [authMiddleware]) { req, res in
    // Access authenticated user info
    if let authToken = req.middlewareStorage["authToken"] as? String {
        res.json("""{"message": "Access granted", "token": "\(authToken)"}""")
    } else {
        res.json("""{"message": "Access granted"}""")
    }
}
```

### ETagMiddleware
Implements conditional requests with ETag support for caching.

```swift
server.use(ETagMiddleware(options: ETagOptions(
    strategy: .strong  // or .weak
)))

// In route handlers
server.get("/data") { req, res in
    let content = generateDynamicContent()
    res.sendWithETag(content, contentType: .applicationJson)
}
```

## Creating Custom Middleware

The middleware system is designed to be easily extensible. You can create custom middleware by implementing the `BaseMiddleware` class or the `ConfigurableMiddleware` protocol.

### Simple Middleware Example

```swift
import SwiftWebServer

/// Custom middleware that adds a request timestamp
class TimestampMiddleware: BaseMiddleware {

    override func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        // Add timestamp to request
        let timestamp = Date().timeIntervalSince1970
        request.middlewareStorage["timestamp"] = timestamp

        // Add custom header to response
        response.header("X-Request-Timestamp", "\(timestamp)")

        // Continue to next middleware
        try next()

        // Post-processing (after route handler)
        print("Request processed in \(Date().timeIntervalSince1970 - timestamp) seconds")
    }
}

// Usage
server.use(TimestampMiddleware())
```

### Middleware Data Sharing

Middleware can share data through the request's `middlewareStorage` dictionary:

```swift
// In authentication middleware
class AuthMiddleware: BaseMiddleware {
    override func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        // Validate token and store user info
        if let user = validateAndGetUser(from: request) {
            request.middlewareStorage["currentUser"] = user
            request.middlewareStorage["isAuthenticated"] = true
        }
        try next()
    }
}

// In route handler
server.get("/profile") { req, res in
    if let user = req.middlewareStorage["currentUser"] as? User {
        res.json(user.toJSON())
    } else {
        res.status(.unauthorized).json(["error": "Not authenticated"])
    }
}
```

### Configurable Middleware Example

```swift
/// Configuration options for rate limiting
public struct RateLimitOptions {
    public let maxRequests: Int
    public let windowSeconds: Int
    public let message: String

    public init(maxRequests: Int = 100, windowSeconds: Int = 60, message: String = "Rate limit exceeded") {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
        self.message = message
    }

    public static let `default` = RateLimitOptions()
}

/// Rate limiting middleware
public class RateLimitMiddleware: BaseMiddleware, ConfigurableMiddleware {
    public typealias Options = RateLimitOptions

    private let options: RateLimitOptions
    private var requestCounts: [String: (count: Int, resetTime: Date)] = [:]
    private let queue = DispatchQueue(label: "rateLimit", attributes: .concurrent)

    public required init(options: RateLimitOptions = .default) {
        self.options = options
        super.init()
    }

    public convenience override init() {
        self.init(options: .default)
    }

    public override func execute(request: Request, response: Response, next: @escaping NextFunction) throws {
        let clientIP = request.clientIP ?? "unknown"
        let now = Date()

        let shouldAllow = queue.sync {
            if let entry = requestCounts[clientIP] {
                if now > entry.resetTime {
                    // Reset window
                    requestCounts[clientIP] = (count: 1, resetTime: now.addingTimeInterval(TimeInterval(options.windowSeconds)))
                    return true
                } else if entry.count < options.maxRequests {
                    // Increment count
                    requestCounts[clientIP] = (count: entry.count + 1, resetTime: entry.resetTime)
                    return true
                } else {
                    // Rate limit exceeded
                    return false
                }
            } else {
                // First request from this IP
                requestCounts[clientIP] = (count: 1, resetTime: now.addingTimeInterval(TimeInterval(options.windowSeconds)))
                return true
            }
        }

        if shouldAllow {
            try next()
        } else {
            response.status(.tooManyRequests).send(options.message)
        }
    }
}

// Usage
server.use(RateLimitMiddleware(options: RateLimitOptions(
    maxRequests: 50,
    windowSeconds: 60,
    message: "Too many requests. Please try again later."
)))
```

## Routing

SwiftWebServer supports flexible routing with path parameters and multiple HTTP methods.

### Basic Routes

```swift
// HTTP Methods
server.get("/users") { req, res in res.send("Get all users") }
server.post("/users") { req, res in res.send("Create user") }
server.put("/users/{id}") { req, res in res.send("Update user") }
server.delete("/users/{id}") { req, res in res.send("Delete user") }
```

### Path Parameters

```swift
// Single parameter
server.get("/users/{id}") { req, res in
    let userId = req.pathParameters["id"] ?? "unknown"
    res.send("User ID: \(userId)")
}

// Multiple parameters
server.get("/users/{userId}/posts/{postId}") { req, res in
    let userId = req.pathParameters["userId"] ?? "unknown"
    let postId = req.pathParameters["postId"] ?? "unknown"
    res.json("""
    {
        "userId": "\(userId)",
        "postId": "\(postId)"
    }
    """)
}
```

### Query Parameters

```swift
server.get("/search") { req, res in
    let query = req.queryParameters["q"] ?? ""
    let page = Int(req.queryParameters["page"] ?? "1") ?? 1

    res.json("""
    {
        "query": "\(query)",
        "page": \(page),
        "results": []
    }
    """)
}
```

### Static File Serving

```swift
// Serve files from a directory
server.use(staticDirectory: "./public")

// Multiple static directories
server.use(staticDirectory: "./assets")
server.use(staticDirectory: "./uploads")
```

## API Reference

### SwiftWebServer Class

#### Initialization
```swift
let server = SwiftWebServer()           // Basic initialization
let server = SwiftWebServer(port: 8080) // With default port
```

#### Server Control
```swift
try server.start(port: 8080)    // Start server on specified port
server.stop()                   // Stop the server
server.status                   // Get current server status (.stopped, .starting, .running, .stopping)
server.currentPort              // Get current port (0 if not running)
server.isRunning                // Check if server is running
```

#### Middleware
```swift
server.use(middleware)                    // Add middleware
server.use(staticDirectory: "./public")   // Serve static files
```

#### Route Definition
```swift
server.get(pattern, handler)      // GET route
server.post(pattern, handler)     // POST route
server.put(pattern, handler)      // PUT route
server.delete(pattern, handler)   // DELETE route
```

### Request Object

The `Request` object provides access to all incoming request data:

```swift
// Basic properties
req.method                    // HTTPMethod (.get, .post, etc.)
req.path                      // Request path ("/users/123")
req.httpVersion              // HTTP version ("HTTP/1.1")
req.headers                  // HTTPHeaders object
req.body                     // Raw request body as Data?
req.bodyString               // Request body as String?

// Parsed data
req.pathParameters           // Path parameters ["id": "123"]
req.queryParameters          // Query parameters ["page": "1"]
req.cookies                  // Parsed cookies ["session": "abc123"]
req.jsonBody                 // Parsed JSON body (if BodyParser middleware is used)
req.formBody                 // Parsed form data (if BodyParser middleware is used)
req.middlewareStorage        // Generic storage for middleware data sharing

// Convenience methods
req.header("Content-Type")   // Get header by name
req.header(.contentType)     // Get header by enum
req.cookie("sessionId")      // Get cookie by name
req.contentType              // Parsed content type
req.contentLength            // Content length as Int?
req.userAgent                // User-Agent header
req.host                     // Host header
req.clientIP                 // Client IP address
req.isSecure                 // Whether request is HTTPS
req.accepts(.applicationJson) // Check if client accepts content type
```

### Response Object

The `Response` object provides methods for sending responses:

```swift
// Status codes
res.status(.ok)                    // Set status code
res.status(200)                    // Set status code by number

// Headers
res.header("Content-Type", "application/json")  // Set header
res.header(.contentType, "application/json")    // Set header by enum

// Response methods
res.send("Hello World")            // Send text response
res.json("""{"key": "value"}""")   // Send JSON response
res.html("<h1>Hello</h1>")         // Send HTML response
res.file("./public/index.html")    // Send file

// Cookies
res.cookie("name", "value")        // Set cookie
res.cookie("session", "abc123", attributes: CookieAttributes(
    expires: Date().addingTimeInterval(3600),
    httpOnly: true,
    secure: true
))
res.clearCookie("session")         // Clear cookie

// ETag support (with ETagMiddleware)
res.sendWithETag(content, contentType: .applicationJson)
res.notModified()                  // Send 304 Not Modified

// Redirects
res.redirect("/new-path")          // Temporary redirect (302)
res.redirect("/new-path", permanent: true)  // Permanent redirect (301)
res.redirectPermanent("/new-path") // Permanent redirect (301)
res.redirectTemporary("/new-path") // Temporary redirect (302)
res.redirectTemporaryPreserveMethod("/new-path")  // 307 redirect
res.redirectPermanentPreserveMethod("/new-path")  // 308 redirect

// Error responses with messages
res.badRequest("Invalid input data")
res.notFound("Resource not found")
res.internalServerError("Something went wrong")

// Method chaining
res.status(.ok)
   .header(.contentType, "application/json")
   .json("""{"message": "Success"}""")
```

## Complete Example

Here's a comprehensive example showing a REST API with authentication, logging, and error handling:

```swift
import SwiftWebServer

let server = SwiftWebServer()

// Add middleware in order
server.use(LoggerMiddleware(options: LoggerOptions(level: .detailed)))
server.use(CORSMiddleware())
server.use(CookieMiddleware())
server.use(BodyParser())
server.use(ETagMiddleware())

// Authentication middleware for protected routes
let authMiddleware = BearerTokenMiddleware(options: BearerTokenOptions(
    validator: { token in
        // Validate token against your auth system
        return validateJWT(token) || validateDatabaseToken(token)
    }
))

// Public routes
server.get("/") { req, res in
    res.html("""
    <h1>Welcome to SwiftWebServer</h1>
    <p>A lightweight HTTP server for Swift</p>
    """)
}

server.get("/api/status") { req, res in
    res.sendWithETag("""
    {
        "status": "healthy",
        "timestamp": "\(Date().iso8601Formatted())",
        "version": "1.0.0"
    }
    """, contentType: .applicationJson)
}

// Protected routes
server.get("/api/users", middleware: [authMiddleware]) { req, res in
    let page = Int(req.queryParameters["page"] ?? "1") ?? 1
    let limit = Int(req.queryParameters["limit"] ?? "10") ?? 10

    res.json("""
    {
        "users": [],
        "pagination": {
            "page": \(page),
            "limit": \(limit),
            "total": 0
        }
    }
    """)
}

server.post("/api/users", middleware: [authMiddleware]) { req, res in
    guard let jsonBody = req.jsonBody,
          let userData = jsonBody as? [String: Any],
          let name = userData["name"] as? String else {
        res.status(.badRequest).json("""{"error": "Invalid user data"}""")
        return
    }

    // Create user logic here
    let userId = UUID().uuidString

    res.status(.created).json("""
    {
        "id": "\(userId)",
        "name": "\(name)",
        "created": "\(Date().iso8601Formatted())"
    }
    """)
}

// Error handling
server.get("/api/error") { req, res in
    res.status(.internalServerError).json("""
    {
        "error": "Something went wrong",
        "timestamp": "\(Date().iso8601Formatted())"
    }
    """)
}

// Serve static files
server.use(staticDirectory: "./public")

// Start server
do {
    try server.start(port: 8080)
    print("🚀 Server running on http://localhost:8080")
    print("📊 Status endpoint: http://localhost:8080/api/status")
    print("🔒 Protected endpoint: http://localhost:8080/api/users (requires Bearer token)")

    // Keep the server running
    RunLoop.current.run()
} catch {
    print("❌ Failed to start server: \(error)")
}
```

## Example Application

The SwiftWebServerExample project demonstrates a comprehensive blog application with both frontend and backend servers, featuring a native SwiftUI interface:

### Architecture

- **Backend Server (Port 8080)**: REST API with JWT authentication, user management, and blog posts
- **Frontend Server (Port 3000)**: Serves static HTML/CSS/JS files with responsive design
- **SwiftUI Dashboard**: Native iOS interface with server controls and data management
- **SwiftData Integration**: Modern data persistence with automatic relationship management

### Key Features

- **Blog Interface**: Public blog page with responsive design and post details
- **Admin Login**: Secure login with JWT token authentication
- **Admin Dashboard**: Clean blog management interface for authenticated users
- **Session Management**: Automatic token cleanup and session tracking
- **Real-time Logging**: Request/response logging with filtering and haptic feedback
- **Data Management**: Native SwiftUI interface for managing users, posts, and comments
- **Dual Server Setup**: Separate frontend and backend servers for realistic deployment

### SwiftUI Console Features

- **Dashboard Layout**: Card-based interface with server status and data management
- **Server Controls**: Start/stop servers with real-time status updates
- **Data Management**: Create, edit, and delete users, posts, and comments
- **Session Monitoring**: View and manage active authentication tokens
- **Console Logging**: Real-time request/response logs with filtering options
- **Haptic Feedback**: Enhanced user experience with tactile feedback

### Authentication Flow

1. Users access the blog at `http://localhost:3000/`
2. Admin login is available at `http://localhost:3000/login.html`
3. JWT tokens are issued upon successful authentication
4. Admin dashboard at `http://localhost:3000/admin.html` validates tokens
5. Automatic logout when tokens expire
6. Session management through SwiftUI interface

### Running the Example

1. Open `SwiftWebServerExample.xcodeproj` in Xcode
2. Run the project on iOS Simulator or device (iOS 17.0+)
3. Start both servers using the dashboard controls
4. Access the blog at `http://localhost:3000/`
5. Use demo credentials: `johndoe` / `password123`
6. Manage data through the native SwiftUI interface

### Development Setup

1. Clone the repository
2. Open in Xcode or use Swift Package Manager
3. Run tests: `swift test`
4. Build: `swift build`

### Requirements

- **iOS**: 17.0+ (for SwiftUI example app)
- **macOS**: 14.0+ (for command-line usage)
- **Xcode**: 15.0+
- **Swift**: 5.9+

## Recent Updates

### Version 1.0.0 Features

- ✅ **Session Management**: Automatic JWT token cleanup and session tracking
- ✅ **Enhanced Authentication**: Improved Bearer token middleware with detailed error responses
- ✅ **SwiftUI Integration**: Native iOS dashboard with haptic feedback and real-time updates
- ✅ **SwiftData Support**: Modern data persistence with automatic relationship management
- ✅ **Responsive Design**: Mobile-first web interface with adaptive layouts
- ✅ **Error Handling**: Comprehensive error responses with proper HTTP status codes
- ✅ **Middleware Improvements**: Enhanced logging, CORS, and cookie handling
- ✅ **HTTP Redirects**: Full support for temporary and permanent redirects

## Testing

SwiftWebServer includes comprehensive unit tests for all middleware and core functionality:

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter SwiftWebServerTests

# Run with verbose output
swift test --verbose
```

### Test Coverage

- ✅ **Core Server**: Server lifecycle, routing, and request handling
- ✅ **Middleware**: All built-in middleware components
- ✅ **HTTP Methods**: GET, POST, PUT, DELETE, and other HTTP methods
- ✅ **Path Parameters**: Route matching and parameter extraction
- ✅ **Authentication**: Bearer token validation and error handling
- ✅ **CORS**: Cross-origin request handling
- ✅ **Cookie Management**: Cookie parsing and setting
- ✅ **Error Handling**: Proper error responses and status codes

## Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Guidelines

1. **Code Style**: Follow Swift conventions and use SwiftLint
2. **Testing**: Add tests for new features and bug fixes
3. **Documentation**: Update README and inline documentation
4. **Compatibility**: Maintain backward compatibility when possible

## License

This project is licensed under the MIT License - see the LICENSE file for details.
