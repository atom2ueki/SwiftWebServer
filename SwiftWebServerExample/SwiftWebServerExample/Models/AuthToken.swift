//
//  AuthToken.swift
//  SwiftWebServerExample
//
//  SwiftData model for authentication tokens
//

import Foundation
import SwiftData

@Model
final class AuthToken {
    @Attribute(.unique) var id: UUID
    var token: String
    var createdAt: Date
    var expiresAt: Date
    var isRevoked: Bool
    var deviceInfo: String?
    var lastUsedAt: Date?
    
    // Relationships
    @Relationship var user: User?
    
    init(token: String, user: User, expiresIn: TimeInterval = 3600, deviceInfo: String? = nil) {
        self.id = UUID()
        self.token = token
        self.user = user
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(expiresIn)
        self.isRevoked = false
        self.deviceInfo = deviceInfo
        self.lastUsedAt = nil
    }
    
    // Computed properties
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var isValid: Bool {
        return !isRevoked && !isExpired
    }
    
    var remainingTime: TimeInterval {
        return expiresAt.timeIntervalSinceNow
    }
    
    // Methods
    func revoke() {
        self.isRevoked = true
    }
    
    func updateLastUsed() {
        self.lastUsedAt = Date()
    }
    
    func extend(by timeInterval: TimeInterval) {
        self.expiresAt = self.expiresAt.addingTimeInterval(timeInterval)
    }
    
    // Static methods
    static func generateSecureToken() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let tokenLength = 64
        return String((0..<tokenLength).map { _ in characters.randomElement()! })
    }
    
    static func createToken(for user: User, expiresIn: TimeInterval = 3600, deviceInfo: String? = nil) -> AuthToken {
        let tokenString = "swt_\(generateSecureToken())"
        return AuthToken(token: tokenString, user: user, expiresIn: expiresIn, deviceInfo: deviceInfo)
    }
}

// MARK: - Codable for API responses
extension AuthToken: Codable {
    enum CodingKeys: String, CodingKey {
        case id, token, createdAt, expiresAt, isRevoked, deviceInfo, lastUsedAt
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let token = try container.decode(String.self, forKey: .token)
        
        // Create a temporary user - this should not be used in practice
        let tempUser = User(username: "temp", email: "temp@example.com", passwordHash: "", firstName: "Temp", lastName: "User")
        
        self.init(token: token, user: tempUser)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        self.isRevoked = try container.decode(Bool.self, forKey: .isRevoked)
        self.deviceInfo = try container.decodeIfPresent(String.self, forKey: .deviceInfo)
        self.lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(token, forKey: .token)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(isRevoked, forKey: .isRevoked)
        try container.encodeIfPresent(deviceInfo, forKey: .deviceInfo)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
    }
}

// MARK: - API Response Models
struct AuthTokenResponse: Codable {
    let token: String
    let expiresAt: Date
    let expiresIn: Int
    
    init(from authToken: AuthToken) {
        self.token = authToken.token
        self.expiresAt = authToken.expiresAt
        self.expiresIn = Int(authToken.remainingTime)
    }
}

struct LoginResponse: Codable {
    let token: String
    let user: UserResponse
    let expiresIn: Int
    let expiresAt: Date
    
    init(authToken: AuthToken, user: User) {
        self.token = authToken.token
        self.user = UserResponse(from: user)
        self.expiresIn = Int(authToken.remainingTime)
        self.expiresAt = authToken.expiresAt
    }
}

// MARK: - Token Management Errors
enum AuthTokenError: Error, LocalizedError {
    case tokenNotFound
    case tokenExpired
    case tokenRevoked
    case invalidToken
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .tokenNotFound:
            return "Authentication token not found"
        case .tokenExpired:
            return "Authentication token has expired"
        case .tokenRevoked:
            return "Authentication token has been revoked"
        case .invalidToken:
            return "Invalid authentication token"
        case .userNotFound:
            return "User associated with token not found"
        }
    }
}
