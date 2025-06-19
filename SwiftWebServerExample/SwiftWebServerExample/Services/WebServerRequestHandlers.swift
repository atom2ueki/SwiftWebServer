//
//  WebServerRequestHandlers.swift
//  SwiftWebServerExample
//
//  Request handlers for the web server
//

import Foundation
import SwiftWebServer

extension WebServerManager {

    // MARK: - Helper Methods

    private func jsonError(_ message: String) -> String {
        return "{\"error\": \"\(message)\"}"
    }

    private func jsonMessage(_ message: String) -> String {
        return "{\"message\": \"\(message)\"}"
    }

    // MARK: - Health & Info Handlers
    
    func handleHealthCheck(_ req: Request, _ res: Response) {
        let healthData = [
            "status": "healthy",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "uptime": isRunning ? "running" : "stopped",
            "port": currentPort,
            "version": "1.0.0"
        ] as [String : Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: healthData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            res.json(jsonString)
        } catch {
            res.internalServerError("Failed to generate health check")
        }
    }
    
    func handleServerInfo(_ req: Request, _ res: Response) {
        let serverInfo = [
            "name": "SwiftWebServer Example",
            "version": "1.0.0",
            "framework": "SwiftWebServer",
            "features": [
                "middleware_support",
                "routing",
                "authentication",
                "static_files",
                "cors",
                "logging",
                "etag_caching",
                "cookie_management",
                "body_parsing"
            ],
            "statistics": [
                "total_users": dataManager.totalUsers,
                "total_posts": dataManager.totalPosts,
                "total_comments": dataManager.totalComments,
                "published_posts": dataManager.publishedPosts,
                "approved_comments": dataManager.approvedComments
            ]
        ] as [String : Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: serverInfo)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            res.json(jsonString)
        } catch {
            res.internalServerError("Failed to generate server info")
        }
    }
    
    // MARK: - Authentication Handlers
    
    func handleLogin(_ req: Request, _ res: Response) {
        guard let jsonBody = req.jsonBody else {
            res.badRequest("Invalid request body")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonBody)
            let loginRequest = try JSONDecoder().decode(LoginRequest.self, from: data)
            
            if let user = dataManager.authenticateUser(username: loginRequest.username, password: loginRequest.password) {
                do {
                    // Create persistent auth token
                    let authToken = try dataManager.createAuthToken(for: user, expiresIn: 3600, deviceInfo: req.header("User-Agent"))
                    let response = LoginResponse(authToken: authToken, user: user)

                    let responseData = try JSONEncoder().encode(response)
                    let responseString = String(data: responseData, encoding: .utf8) ?? "{}"

                    // Set authentication cookie with domain and path for cross-origin access
                    res.cookie("auth_token", authToken.token, attributes: CookieAttributes(
                        domain: "localhost", // Allow access from both localhost:3000 and localhost:8080
                        path: "/", // Make cookie available to all paths
                        expires: authToken.expiresAt,
                        secure: false, // Set to true in production with HTTPS
                        httpOnly: false, // Allow JavaScript access for frontend auth checks
                        sameSite: .lax
                    ))

                    res.json(responseString)
                    addLogMessage("User \(user.username) logged in with token \(authToken.token.prefix(10))...", type: .success)
                } catch {
                    res.internalServerError("Failed to create authentication token")
                    addLogMessage("Failed to create auth token for user: \(user.username)", type: .error)
                }
            } else {
                res.unauthorized("Invalid credentials")
                addLogMessage("Failed login attempt for username: \(loginRequest.username)", type: .warning)
            }
        } catch {
            res.badRequest("Invalid request format")
        }
    }
    
    func handleLogout(_ req: Request, _ res: Response) {
        // Try to revoke the token if present
        if let tokenString = req.cookie("auth_token") {
            do {
                try dataManager.revokeAuthToken(tokenString)
                addLogMessage("Auth token revoked: \(tokenString.prefix(10))...", type: .info)
            } catch {
                addLogMessage("Failed to revoke auth token: \(error)", type: .warning)
            }
        }

        // Clear authentication cookie with same domain and path as login
        res.cookie("auth_token", "", attributes: CookieAttributes(
            domain: "localhost", // Match login cookie domain
            path: "/", // Match login cookie path
            expires: Date(timeIntervalSince1970: 0),
            httpOnly: false // Match login cookie settings
        ))

        res.json(jsonMessage("Logged out successfully"))
        addLogMessage("User logged out", type: .info)
    }
    
    // MARK: - User Handlers
    
    func handleGetUsers(_ req: Request, _ res: Response) {
        let users = dataManager.users.map { UserResponse(from: $0) }
        
        do {
            let jsonData = try JSONEncoder().encode(users)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            res.json(jsonString)
        } catch {
            res.internalServerError("Failed to encode users")
        }
    }
    
    func handleCreateUser(_ req: Request, _ res: Response) {
        guard let jsonBody = req.jsonBody else {
            res.badRequest("Invalid request body")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonBody)
            let createRequest = try JSONDecoder().decode(CreateUserRequest.self, from: data)
            let user = try dataManager.createUser(request: createRequest)
            let response = UserResponse(from: user)
            
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            
            res.status(.created).json(responseString)
            addLogMessage("User created: \(user.username)", type: .success)
        } catch let error as ValidationError {
            res.badRequest(error.localizedDescription)
        } catch let error as DataManagerError {
            res.conflict(error.localizedDescription)
        } catch {
            res.internalServerError("Failed to create user")
        }
    }
    
    func handleGetUser(_ req: Request, _ res: Response) {
        guard let idString = req.pathParameters["id"],
              let id = UUID(uuidString: idString) else {
            res.badRequest("Invalid user ID")
            return
        }

        guard let user = dataManager.getUser(by: id) else {
            res.notFound("User not found")
            return
        }
        
        do {
            let response = UserResponse(from: user)
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            res.json(responseString)
        } catch {
            res.internalServerError("Failed to encode user")
        }
    }
    
    func handleUpdateUser(_ req: Request, _ res: Response) {
        guard let idString = req.pathParameters["id"],
              let id = UUID(uuidString: idString) else {
            res.badRequest("Invalid user ID")
            return
        }

        guard let user = dataManager.getUser(by: id) else {
            res.notFound("User not found")
            return
        }

        guard let jsonBody = req.jsonBody else {
            res.badRequest("Invalid request body")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonBody)
            let updateRequest = try JSONDecoder().decode(UpdateUserRequest.self, from: data)
            try dataManager.updateUser(user, request: updateRequest)
            
            let response = UserResponse(from: user)
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            
            res.json(responseString)
            addLogMessage("User updated: \(user.username)", type: .success)
        } catch let error as ValidationError {
            res.badRequest(error.localizedDescription)
        } catch let error as DataManagerError {
            res.conflict(error.localizedDescription)
        } catch {
            res.internalServerError("Failed to update user")
        }
    }
    
    func handleDeleteUser(_ req: Request, _ res: Response) {
        guard let idString = req.pathParameters["id"],
              let id = UUID(uuidString: idString) else {
            res.badRequest("Invalid user ID")
            return
        }

        guard let user = dataManager.getUser(by: id) else {
            res.notFound("User not found")
            return
        }
        
        do {
            try dataManager.deleteUser(user)
            res.status(.noContent).send("")
            addLogMessage("User deleted: \(user.username)", type: .info)
        } catch {
            res.internalServerError("Failed to delete user")
        }
    }
    
    // MARK: - Admin Handlers
    
    func handleAdminStats(_ req: Request, _ res: Response) {
        let stats = [
            "users": [
                "total": dataManager.totalUsers,
                "active": dataManager.users.filter { $0.isActive }.count
            ],
            "posts": [
                "total": dataManager.totalPosts,
                "published": dataManager.publishedPosts,
                "draft": dataManager.totalPosts - dataManager.publishedPosts
            ],
            "comments": [
                "total": dataManager.totalComments,
                "approved": dataManager.approvedComments,
                "pending": dataManager.totalComments - dataManager.approvedComments
            ],
            "auth_tokens": [
                "total": dataManager.totalAuthTokens,
                "active": dataManager.activeAuthTokens,
                "expired": dataManager.totalAuthTokens - dataManager.activeAuthTokens
            ],
            "server": [
                "uptime": isRunning ? "running" : "stopped",
                "port": currentPort,
                "log_messages": logMessages.count
            ]
        ] as [String : Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: stats)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            res.json(jsonString)
        } catch {
            res.internalServerError("Failed to generate stats")
        }
    }
}

// MARK: - Request/Response Models

struct LoginRequest: Codable {
    let username: String
    let password: String
}


