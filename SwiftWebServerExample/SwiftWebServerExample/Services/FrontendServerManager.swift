//
//  FrontendServerManager.swift
//  SwiftWebServerExample
//
//  Frontend server for serving static web files that call backend APIs
//

import Foundation
import SwiftWebServer
import Observation

@Observable
final class FrontendServerManager {
    private var server: SwiftWebServer?
    
    // Server status
    var isRunning: Bool = false
    var currentPort: UInt = 0
    var serverStatus: String = "Stopped"
    var logMessages: [LogMessage] = []
    
    // Configuration
    private let defaultPort: UInt = 3000
    private let maxLogMessages = 1000
    
    // Backend server reference for API calls
    private weak var backendServerManager: WebServerManager?
    
    init(backendServerManager: WebServerManager) {
        self.backendServerManager = backendServerManager
        setupServer()
    }
    
    // MARK: - Server Setup
    
    private func setupServer() {
        server = SwiftWebServer()
        guard let server = server else { return }
        
        // Configure middleware
        configureMiddleware(server)
        
        // Configure routes
        configureRoutes(server)
    }
    
    private func configureMiddleware(_ server: SwiftWebServer) {
        // Logger Middleware
        server.use(LoggerMiddleware(options: LoggerOptions(
            level: .detailed,
            includeHeaders: false,
            includeBody: false,
            customLogger: { [weak self] message in
                self?.addLogMessage(message, type: .info)
            }
        )))

        // CORS Middleware for frontend-backend communication
        server.use(CORSMiddleware(options: CORSOptions(
            allowedOrigins: .any,
            allowedMethods: [.get, .post, .put, .delete, .options],
            allowedHeaders: [.contentType, .authorization, .accept],
            exposedHeaders: [.contentLength],
            allowCredentials: true,
            maxAge: 86400
        )))

        // Cookie Middleware - Required for handling cookies in cross-origin scenarios
        server.use(CookieMiddleware())

        // Static file serving from public directory (for assets only: CSS, JS, images, etc.)
        // HTML files are served through route handlers, not static file serving
        let publicPath = getPublicDirectoryPath()
        addLogMessage("Configuring static directory for assets: \(publicPath)", type: .info)
        server.use(staticDirectory: publicPath)
    }
    
    private func configureRoutes(_ server: SwiftWebServer) {
        // Root route - serve index.html
        server.get("/") { [weak self] req, res in
            self?.serveHtmlPage("index.html", req, res)
        }

        // HTML page routes
        server.get("/login") { [weak self] req, res in
            self?.addLogMessage("Login page requested", type: .info)
            self?.serveHtmlPage("login.html", req, res)
        }

        server.get("/admin") { [weak self] req, res in
            self?.addLogMessage("Admin page requested", type: .info)
            self?.serveHtmlPage("admin.html", req, res)
        }

        server.get("/post") { [weak self] req, res in
            self?.serveHtmlPage("post.html", req, res)
        }

        // Path parameter route for blog posts: /post/{id}
        server.get("/post/{id}") { [weak self] req, res in
            self?.serveHtmlPage("post.html", req, res)
        }

        // Configuration endpoint for frontend
        server.get("/config.json") { [weak self] req, res in
            self?.handleConfigRequest(req, res)
        }
    }
    
    // MARK: - Server Control
    
    func startServer(port: UInt = 0) {
        let serverPort = port == 0 ? defaultPort : port

        server?.listen(serverPort) {
            self.isRunning = true
            self.currentPort = serverPort
            self.serverStatus = "Running on localhost:\(serverPort)"
            self.addLogMessage("Frontend server started on localhost:\(serverPort) (accessible via localhost)", type: .success)
        }
    }
    
    func stopServer() {
        server?.close()
        isRunning = false
        currentPort = 0
        serverStatus = "Stopped"
        addLogMessage("Frontend server stopped", type: .info)
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
    
    // MARK: - Helper Methods

    private func getPublicDirectoryPath() -> String {
        // The public files are now bundled with the app, so we serve from the app bundle
        if let bundlePath = Bundle.main.resourcePath {
            addLogMessage("Using app bundle resources at: \(bundlePath)", type: .info)
            return bundlePath
        }

        // Development fallback: try to find the source directory
        let sourceFile = #file
        let sourceURL = URL(fileURLWithPath: sourceFile)

        // Navigate from Services/FrontendServerManager.swift to the SwiftWebServerExample directory
        let projectDir = sourceURL
            .deletingLastPathComponent()  // Remove FrontendServerManager.swift
            .deletingLastPathComponent()  // Remove Services/

        let publicPath = projectDir.appendingPathComponent("public").path

        if FileManager.default.fileExists(atPath: publicPath) {
            addLogMessage("Found public directory at: \(publicPath)", type: .info)
            return publicPath
        }

        // Final fallback
        addLogMessage("Public directory not found, using current directory", type: .error)
        return "."
    }

    // MARK: - Request Handlers

    private func serveHtmlPage(_ fileName: String, _ req: Request, _ res: Response) {
        let publicPath = getPublicDirectoryPath()
        let filePath = URL(fileURLWithPath: publicPath).appendingPathComponent(fileName).path

        addLogMessage("Attempting to serve \(fileName) from: \(filePath)", type: .info)

        if FileManager.default.fileExists(atPath: filePath) {
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                res.html(content)
                addLogMessage("Successfully served \(fileName)", type: .success)
            } catch {
                addLogMessage("Failed to read \(fileName): \(error.localizedDescription)", type: .error)
                res.internalServerError("Failed to load page")
            }
        } else {
            addLogMessage("\(fileName) not found at: \(filePath)", type: .error)
            res.notFound("Page not found")
        }
    }

    private func handleConfigRequest(_ req: Request, _ res: Response) {
        let backendPort = backendServerManager?.currentPort ?? 8080
        let config = [
            "apiBase": "http://localhost:\(backendPort)",
            "backendUrl": "http://localhost:\(backendPort)",
            "frontendPort": currentPort,
            "backendPort": backendPort
        ] as [String : Any]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            res.json(jsonString)
        } catch {
            res.internalServerError("Failed to generate config")
        }
    }
}
