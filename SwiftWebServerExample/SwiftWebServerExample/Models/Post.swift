//
//  Post.swift
//  SwiftWebServerExample
//
//  SwiftData model for Post entity
//

import Foundation
import SwiftData

@Model
final class Post {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var excerpt: String
    var isPublished: Bool
    var viewCount: Int
    var createdAt: Date
    var updatedAt: Date
    var publishedAt: Date?
    
    // Relationships
    @Relationship var author: User?
    @Relationship(deleteRule: .cascade, inverse: \Comment.post) var comments: [Comment] = []
    
    init(title: String, content: String, author: User) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.excerpt = String(content.prefix(200))
        self.isPublished = false
        self.viewCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.author = author
    }
    
    // Computed properties
    var wordCount: Int {
        return content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    var readingTime: Int {
        // Assuming 200 words per minute reading speed
        return max(1, wordCount / 200)
    }
    
    var publishedCommentsCount: Int {
        return comments.filter { $0.isApproved }.count
    }
    
    // Methods
    func publish() {
        self.isPublished = true
        self.publishedAt = Date()
        self.updatedAt = Date()
    }
    
    func unpublish() {
        self.isPublished = false
        self.publishedAt = nil
        self.updatedAt = Date()
    }
    
    func incrementViewCount() {
        self.viewCount += 1
    }
    
    func updateContent(title: String? = nil, content: String? = nil) {
        if let title = title {
            self.title = title
        }
        if let content = content {
            self.content = content
            self.excerpt = String(content.prefix(200))
        }
        self.updatedAt = Date()
    }
}

// MARK: - Codable for API responses
extension Post: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, content, excerpt, isPublished, viewCount
        case createdAt, updatedAt, publishedAt, wordCount, readingTime
        case author, commentsCount
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let title = try container.decode(String.self, forKey: .title)
        let content = try container.decode(String.self, forKey: .content)
        
        // Create a temporary user for decoding - this should be handled differently in real apps
        let tempUser = User(username: "temp", email: "temp@example.com", passwordHash: "", firstName: "Temp", lastName: "User")
        
        self.init(title: title, content: content, author: tempUser)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.excerpt = try container.decode(String.self, forKey: .excerpt)
        self.isPublished = try container.decode(Bool.self, forKey: .isPublished)
        self.viewCount = try container.decode(Int.self, forKey: .viewCount)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(excerpt, forKey: .excerpt)
        try container.encode(isPublished, forKey: .isPublished)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(publishedAt, forKey: .publishedAt)
        try container.encode(wordCount, forKey: .wordCount)
        try container.encode(readingTime, forKey: .readingTime)
        try container.encode(publishedCommentsCount, forKey: .commentsCount)
        
        if let author = author {
            try container.encode(UserResponse(from: author), forKey: .author)
        }
    }
}

// MARK: - API Response Models
struct PostResponse: Codable {
    let id: UUID
    let title: String
    let content: String
    let excerpt: String
    let isPublished: Bool
    let viewCount: Int
    let wordCount: Int
    let readingTime: Int
    let createdAt: Date
    let updatedAt: Date
    let publishedAt: Date?
    let author: UserResponse?
    let commentsCount: Int
    
    init(from post: Post) {
        self.id = post.id
        self.title = post.title
        self.content = post.content
        self.excerpt = post.excerpt
        self.isPublished = post.isPublished
        self.viewCount = post.viewCount
        self.wordCount = post.wordCount
        self.readingTime = post.readingTime
        self.createdAt = post.createdAt
        self.updatedAt = post.updatedAt
        self.publishedAt = post.publishedAt
        self.author = post.author.map { UserResponse(from: $0) }
        self.commentsCount = post.publishedCommentsCount
    }
}

struct PostSummaryResponse: Codable {
    let id: UUID
    let title: String
    let excerpt: String
    let isPublished: Bool
    let viewCount: Int
    let readingTime: Int
    let createdAt: Date
    let publishedAt: Date?
    let authorName: String
    let commentsCount: Int
    
    init(from post: Post) {
        self.id = post.id
        self.title = post.title
        self.excerpt = post.excerpt
        self.isPublished = post.isPublished
        self.viewCount = post.viewCount
        self.readingTime = post.readingTime
        self.createdAt = post.createdAt
        self.publishedAt = post.publishedAt
        self.authorName = post.author?.fullName ?? "Unknown"
        self.commentsCount = post.publishedCommentsCount
    }
}

struct CreatePostRequest: Codable {
    let title: String
    let content: String
    let isPublished: Bool?
    
    func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PostValidationError.titleRequired
        }
        guard title.count <= 200 else {
            throw PostValidationError.titleTooLong
        }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PostValidationError.contentRequired
        }
        guard content.count <= 50000 else {
            throw PostValidationError.contentTooLong
        }
    }
}

struct UpdatePostRequest: Codable {
    let title: String?
    let content: String?
    let isPublished: Bool?
    
    func validate() throws {
        if let title = title {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PostValidationError.titleRequired
            }
            guard title.count <= 200 else {
                throw PostValidationError.titleTooLong
            }
        }
        if let content = content {
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PostValidationError.contentRequired
            }
            guard content.count <= 50000 else {
                throw PostValidationError.contentTooLong
            }
        }
    }
}

enum PostValidationError: Error, LocalizedError {
    case titleRequired
    case titleTooLong
    case contentRequired
    case contentTooLong
    
    var errorDescription: String? {
        switch self {
        case .titleRequired:
            return "Post title is required"
        case .titleTooLong:
            return "Post title must be 200 characters or less"
        case .contentRequired:
            return "Post content is required"
        case .contentTooLong:
            return "Post content must be 50,000 characters or less"
        }
    }
}
