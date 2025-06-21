//
//  WebServerManager.swift
//  SwiftWebServerExample
//
//  Web server configuration and management
//

import Foundation
import SwiftWebServer
import Observation
import UIKit

@Observable
final class WebServerManager {
    private var server: SwiftWebServer?
    internal let dataManager: DataManager
    private var tokenCleanupTimer: Timer?

    // Server status
    var isRunning: Bool = false
    var currentPort: UInt = 0
    var serverStatus: String = "Stopped"
    var logMessages: [LogMessage] = []
    
    // Configuration
    private let defaultPort: UInt = 8080
    private let maxLogMessages = 1000
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
        setupServer()
    }
    
    // MARK: - Server Setup
    
    private func setupServer() {
        server = SwiftWebServer()
        guard let server = server else { return }
        
        // Configure middleware in order
        configureMiddleware(server)
        
        // Configure routes
        configureRoutes(server)
    }
    
    private func configureMiddleware(_ server: SwiftWebServer) {
        // 1. Logger Middleware - First to log all requests
        server.use(LoggerMiddleware(options: LoggerOptions(
            level: .detailed,
            includeHeaders: true,
            includeBody: false,
            customLogger: { [weak self] message in
                self?.addLogMessage(message, type: .info)
            }
        )))
        
        // 2. CORS Middleware - Enable cross-origin requests
        server.use(CORSMiddleware(options: CORSOptions(
            allowedOrigins: .any,
            allowedMethods: [.get, .post, .put, .delete, .options],
            allowedHeaders: [.contentType, .authorization, .accept],
            exposedHeaders: [.contentLength, .etag],
            allowCredentials: true,
            maxAge: 86400 // 24 hours
        )))
        
        // 3. Cookie Middleware - Parse and handle cookies
        server.use(CookieMiddleware())
        
        // 4. Body Parser Middleware - Parse request bodies
        server.use(BodyParser(options: BodyParserOptions(
            maxBodySize: 10 * 1024 * 1024, // 10MB
            parseJSON: true,
            parseURLEncoded: true,
            parseMultipart: true
        )))
        
        // 5. ETag Middleware - Handle conditional requests
        server.use(ETagMiddleware(options: ETagOptions(
            strategy: .strong
        )))
        
        // Static file serving
        server.use(staticDirectory: "./public")
    }
    
    // MARK: - Route Configuration
    
    private func configureRoutes(_ server: SwiftWebServer) {
        // Favicon handler (prevents 404 errors)
        server.get("/favicon.ico") { req, res in
            res.status(.notFound).send("")
        }

        // API Health check
        server.get("/api/health") { [weak self] req, res in
            self?.handleHealthCheck(req, res)
        }
        
        // API Info
        server.get("/api/info") { [weak self] req, res in
            self?.handleServerInfo(req, res)
        }
        
        // Authentication routes
        server.post("/api/auth/login") { [weak self] req, res in
            self?.handleLogin(req, res)
        }
        
        server.post("/api/auth/logout") { [weak self] req, res in
            self?.handleLogout(req, res)
        }

        // Protected routes with authentication - MUST be defined BEFORE route handlers
        let authMiddleware = BearerTokenMiddleware(options: BearerTokenOptions(
            validator: { [weak self] token in
                print("🔐 BearerTokenMiddleware validator called with token: \(token.prefix(10))...")
                guard let self = self else {
                    print("🔐 BearerTokenMiddleware validator: self is nil")
                    return false
                }
                let authToken = self.dataManager.validateAuthToken(token)
                let isValid = authToken != nil
                print("🔐 BearerTokenMiddleware validator: token validation result = \(isValid)")
                if let authToken = authToken {
                    print("🔐 BearerTokenMiddleware validator: found valid token for user \(authToken.user?.username ?? "unknown")")
                } else {
                    print("🔐 BearerTokenMiddleware validator: token not found or invalid")
                }
                return isValid
            }
        ))

        // Token info endpoint (protected)
        server.get("/api/auth/token-info", authMiddleware) { [weak self] req, res in
            self?.handleTokenInfo(req, res)
        }

        print("🔧 Registering auth middleware for protected routes...")
        server.use(.post, "/api/posts", authMiddleware)
        server.use(.put, "/api/posts/{id}", authMiddleware)
        server.use(.delete, "/api/posts/{id}", authMiddleware)
        server.use(.post, "/api/posts/{postId}/comments", authMiddleware)
        server.use(.put, "/api/comments/{id}", authMiddleware)
        server.use(.delete, "/api/comments/{id}", authMiddleware)
        server.use(.get, "/api/admin/stats", authMiddleware)

        // User routes
        server.get("/api/users") { [weak self] req, res in
            self?.handleGetUsers(req, res)
        }

        server.post("/api/users") { [weak self] req, res in
            self?.handleCreateUser(req, res)
        }

        server.get("/api/users/{id}") { [weak self] req, res in
            self?.handleGetUser(req, res)
        }

        server.put("/api/users/{id}") { [weak self] req, res in
            self?.handleUpdateUser(req, res)
        }

        server.delete("/api/users/{id}") { [weak self] req, res in
            self?.handleDeleteUser(req, res)
        }

        // Post routes
        server.get("/api/posts") { [weak self] req, res in
            self?.handleGetPosts(req, res)
        }

        server.post("/api/posts") { [weak self] req, res in
            self?.handleCreatePost(req, res)
        }

        server.get("/api/posts/{id}") { [weak self] req, res in
            self?.handleGetPost(req, res)
        }

        server.put("/api/posts/{id}") { [weak self] req, res in
            self?.handleUpdatePost(req, res)
        }

        server.delete("/api/posts/{id}") { [weak self] req, res in
            self?.handleDeletePost(req, res)
        }

        // Comment routes
        server.get("/api/posts/{postId}/comments") { [weak self] req, res in
            self?.handleGetComments(req, res)
        }

        server.post("/api/posts/{postId}/comments") { [weak self] req, res in
            self?.handleCreateComment(req, res)
        }

        server.get("/api/comments/{id}") { [weak self] req, res in
            self?.handleGetComment(req, res)
        }

        server.put("/api/comments/{id}") { [weak self] req, res in
            self?.handleUpdateComment(req, res)
        }

        server.delete("/api/comments/{id}") { [weak self] req, res in
            self?.handleDeleteComment(req, res)
        }

        server.put("/api/comments/{id}/approve", authMiddleware) { [weak self] req, res in
            self?.handleApproveComment(req, res)
        }

        // Admin routes (protected)
        server.get("/api/admin/stats") { [weak self] req, res in
            self?.handleAdminStats(req, res)
        }

        // Advanced features demo routes
        server.get("/api/demo/etag") { [weak self] req, res in
            self?.handleETagDemo(req, res)
        }

        server.get("/api/demo/cookies") { [weak self] req, res in
            self?.handleCookieDemo(req, res)
        }

        server.post("/api/demo/upload") { [weak self] req, res in
            self?.handleFileUploadDemo(req, res)
        }

        server.get("/api/demo/cors") { [weak self] req, res in
            self?.handleCORSDemo(req, res)
        }

        server.get("/api/demo/error") { [weak self] req, res in
            self?.handleErrorDemo(req, res)
        }
    }
    
    // MARK: - Server Control
    
    func startServer(port: UInt = 0) {
        let serverPort = port == 0 ? defaultPort : port

        server?.listen(serverPort) {
            self.isRunning = true
            self.currentPort = serverPort
            self.serverStatus = "Running on localhost:\(serverPort)"
            self.addLogMessage("Server started on localhost:\(serverPort) (accessible via localhost)", type: .success)

            // Start token cleanup timer
            self.startTokenCleanupTimer()

            // Haptic feedback for server start
            DispatchQueue.main.async {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    func stopServer() {
        server?.close()
        isRunning = false
        currentPort = 0
        serverStatus = "Stopped"

        // Stop token cleanup timer
        stopTokenCleanupTimer()

        addLogMessage("Server stopped", type: .info)

        // Haptic feedback for server stop
        DispatchQueue.main.async {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    func restartServer() {
        stopServer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startServer(port: self.defaultPort)
        }
    }
    
    // MARK: - Logging

    func addLogMessage(_ message: String, type: LogType) {
        let logMessage = LogMessage(
            timestamp: Date(),
            message: message,
            type: type
        )
        
        DispatchQueue.main.async {
            self.logMessages.insert(logMessage, at: 0)
            
            // Keep only the most recent messages
            if self.logMessages.count > self.maxLogMessages {
                self.logMessages = Array(self.logMessages.prefix(self.maxLogMessages))
            }
        }
    }
    
    func clearLogs() {
        logMessages.removeAll()
    }

    // MARK: - Token Cleanup Service

    private func startTokenCleanupTimer() {
        // Clean up expired tokens every 30 minutes
        tokenCleanupTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.performTokenCleanup()
        }

        // Perform initial cleanup
        performTokenCleanup()
    }

    private func stopTokenCleanupTimer() {
        tokenCleanupTimer?.invalidate()
        tokenCleanupTimer = nil
    }

    private func performTokenCleanup() {
        do {
            let initialCount = dataManager.totalAuthTokens
            try dataManager.cleanupExpiredTokens()
            let finalCount = dataManager.totalAuthTokens
            let cleanedCount = initialCount - finalCount

            if cleanedCount > 0 {
                addLogMessage("Cleaned up \(cleanedCount) expired auth tokens", type: .info)
            }
        } catch {
            addLogMessage("Failed to cleanup expired tokens: \(error)", type: .warning)
        }
    }
    
    // MARK: - API Route Handlers
}

// MARK: - Log Message Model

struct LogMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

enum LogType {
    case info
    case success
    case warning
    case error

    var color: String {
        switch self {
        case .info: return "blue"
        case .success: return "green"
        case .warning: return "orange"
        case .error: return "red"
        }
    }

    var icon: String {
        switch self {
        case .info: return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

// Extension to make LogType conform to RawRepresentable for the menu
extension LogType: RawRepresentable {
    public var rawValue: String {
        switch self {
        case .info: return "info"
        case .success: return "success"
        case .warning: return "warning"
        case .error: return "error"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "info": self = .info
        case "success": self = .success
        case "warning": self = .warning
        case "error": self = .error
        default: return nil
        }
    }
}
