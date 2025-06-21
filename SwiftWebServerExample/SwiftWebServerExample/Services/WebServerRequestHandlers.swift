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
            "name": "SwiftWebServer Demo",
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
        print("Login request received")
        print("Content-Type: \(req.header("Content-Type") ?? "none")")
        if let bodyData = req.body {
            print("Body: \(String(data: bodyData, encoding: .utf8) ?? "invalid UTF-8")")
        } else {
            print("Body: none")
        }
        print("JSON Body: \(req.jsonBody?.description ?? "none")")

        guard let jsonBody = req.jsonBody else {
            print("No JSON body found in request")
            res.badRequest("Invalid request body")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonBody)
            let loginRequest = try JSONDecoder().decode(LoginRequest.self, from: data)
            
            if let user = dataManager.authenticateUser(username: loginRequest.username, password: loginRequest.password) {
                do {
                    // Get existing valid token or create new one
                    let authToken = try dataManager.getOrCreateAuthToken(for: user, expiresIn: 3600, deviceInfo: req.header("User-Agent"))
                    let response = LoginResponse(authToken: authToken, user: user)

                    // Using Bearer token authentication - no cookies needed
                    try res.json(response)
                    addLogMessage("User \(user.username) logged in with token \(authToken.token.prefix(10))...", type: .success)
                } catch {
                    print("Login error: \(error)")
                    res.internalServerError("Failed to create authentication token")
                    addLogMessage("Failed to create auth token for user: \(user.username) - Error: \(error)", type: .error)
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
        // Try to revoke the token if present in Authorization header
        if let authToken = req.authToken {
            do {
                try dataManager.revokeAuthToken(authToken)
                addLogMessage("Auth token revoked: \(authToken.prefix(10))...", type: .info)
            } catch {
                addLogMessage("Failed to revoke auth token: \(error)", type: .warning)
            }
        }

        res.json(jsonMessage("Logged out successfully"))
        addLogMessage("User logged out", type: .info)
    }

    func handleTokenInfo(_ req: Request, _ res: Response) {
        guard let token = req.authToken,
              let authToken = dataManager.validateAuthToken(token) else {
            res.unauthorized("Invalid token")
            return
        }

        let tokenInfo = [
            "token": authToken.token,
            "expiresAt": authToken.expiresAt.iso8601Formatted(),
            "expiresIn": Int(authToken.remainingTime),
            "isExpired": authToken.isExpired,
            "isValid": authToken.isValid,
            "user": [
                "id": authToken.user?.id.uuidString ?? "",
                "username": authToken.user?.username ?? "",
                "firstName": authToken.user?.firstName ?? "",
                "lastName": authToken.user?.lastName ?? ""
            ]
        ] as [String : Any]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: tokenInfo)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            res.json(jsonString)
        } catch {
            res.internalServerError("Failed to generate token info")
        }
    }

    // MARK: - User Handlers
    
    func handleGetUsers(_ req: Request, _ res: Response) {
        let users = dataManager.users.map { UserResponse(from: $0) }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(users)
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
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let responseData = try encoder.encode(response)
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
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let responseData = try encoder.encode(response)
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
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let responseData = try encoder.encode(response)
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


