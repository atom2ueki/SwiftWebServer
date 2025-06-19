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
        
        // Static file serving from public directory
        // Get the path to the public directory relative to the app bundle
        let publicPath = getPublicDirectoryPath()
        addLogMessage("Configuring static directory: \(publicPath)", type: .info)
        server.use(staticDirectory: publicPath)
    }
    
    private func configureRoutes(_ server: SwiftWebServer) {
        // Root route fallback (in case static file serving doesn't work)
        server.get("/") { [weak self] req, res in
            self?.handleRootFallback(req, res)
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

    private func handleRootFallback(_ req: Request, _ res: Response) {
        // Try to serve index.html manually if static file serving fails
        let publicPath = getPublicDirectoryPath()
        let indexPath = URL(fileURLWithPath: publicPath).appendingPathComponent("index.html").path

        addLogMessage("Attempting to serve index.html from: \(indexPath)", type: .info)

        if FileManager.default.fileExists(atPath: indexPath) {
            do {
                let content = try String(contentsOfFile: indexPath, encoding: .utf8)
                res.html(content)
                addLogMessage("Successfully served index.html", type: .success)
            } catch {
                addLogMessage("Failed to read index.html: \(error.localizedDescription)", type: .error)
                res.internalServerError("Failed to load frontend")
            }
        } else {
            addLogMessage("index.html not found at: \(indexPath)", type: .error)
            res.notFound("Frontend not found")
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
