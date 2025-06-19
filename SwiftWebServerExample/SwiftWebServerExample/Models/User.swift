//
//  User.swift
//  SwiftWebServerExample
//
//  SwiftData model for User entity
//

import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var username: String
    var email: String
    var passwordHash: String
    var firstName: String
    var lastName: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Post.author) var posts: [Post] = []
    @Relationship(deleteRule: .cascade, inverse: \Comment.author) var comments: [Comment] = []
    
    init(username: String, email: String, passwordHash: String, firstName: String, lastName: String) {
        self.id = UUID()
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.firstName = firstName
        self.lastName = lastName
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Computed properties
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    // Update timestamp
    func updateTimestamp() {
        self.updatedAt = Date()
    }
    
    // Validation
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func isValidUsername(_ username: String) -> Bool {
        return username.count >= 3 && username.count <= 20 && username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}

// MARK: - Codable for API responses
extension User: Codable {
    enum CodingKeys: String, CodingKey {
        case id, username, email, firstName, lastName, isActive, createdAt, updatedAt, fullName
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let username = try container.decode(String.self, forKey: .username)
        let email = try container.decode(String.self, forKey: .email)
        let firstName = try container.decode(String.self, forKey: .firstName)
        let lastName = try container.decode(String.self, forKey: .lastName)
        
        self.init(username: username, email: email, passwordHash: "", firstName: firstName, lastName: lastName)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.isActive = try container.decode(Bool.self, forKey: .isActive)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(fullName, forKey: .fullName)
    }
}

// MARK: - API Response Models
struct UserResponse: Codable {
    let id: UUID
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let fullName: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    let postsCount: Int
    let commentsCount: Int
    
    init(from user: User) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.fullName = user.fullName
        self.isActive = user.isActive
        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
        self.postsCount = user.posts.count
        self.commentsCount = user.comments.count
    }
}

struct CreateUserRequest: Codable {
    let username: String
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    
    func validate() throws {
        guard User.isValidUsername(username) else {
            throw ValidationError.invalidUsername
        }
        guard User.isValidEmail(email) else {
            throw ValidationError.invalidEmail
        }
        guard password.count >= 6 else {
            throw ValidationError.passwordTooShort
        }
        guard !firstName.isEmpty && !lastName.isEmpty else {
            throw ValidationError.nameRequired
        }
    }
}

struct UpdateUserRequest: Codable {
    let email: String?
    let firstName: String?
    let lastName: String?
    let isActive: Bool?
    
    func validate() throws {
        if let email = email, !User.isValidEmail(email) {
            throw ValidationError.invalidEmail
        }
    }
}

enum ValidationError: Error, LocalizedError {
    case invalidUsername
    case invalidEmail
    case passwordTooShort
    case nameRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "Username must be 3-20 characters and contain only letters, numbers, and underscores"
        case .invalidEmail:
            return "Invalid email format"
        case .passwordTooShort:
            return "Password must be at least 6 characters"
        case .nameRequired:
            return "First name and last name are required"
        }
    }
}
