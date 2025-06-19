//
//  Comment.swift
//  SwiftWebServerExample
//
//  SwiftData model for Comment entity
//

import Foundation
import SwiftData

@Model
final class Comment {
    @Attribute(.unique) var id: UUID
    var content: String
    var isApproved: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship var author: User?
    @Relationship var post: Post?
    @Relationship var parentComment: Comment?
    @Relationship(deleteRule: .cascade, inverse: \Comment.parentComment) var replies: [Comment] = []
    
    init(content: String, author: User, post: Post, parentComment: Comment? = nil) {
        self.id = UUID()
        self.content = content
        self.isApproved = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.author = author
        self.post = post
        self.parentComment = parentComment
    }
    
    // Computed properties
    var isReply: Bool {
        return parentComment != nil
    }
    
    var approvedRepliesCount: Int {
        return replies.filter { $0.isApproved }.count
    }
    
    var wordCount: Int {
        return content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    // Methods
    func approve() {
        self.isApproved = true
        self.updatedAt = Date()
    }
    
    func reject() {
        self.isApproved = false
        self.updatedAt = Date()
    }
    
    func updateContent(_ newContent: String) {
        self.content = newContent
        self.updatedAt = Date()
    }
}

// MARK: - Codable for API responses
extension Comment: Codable {
    enum CodingKeys: String, CodingKey {
        case id, content, isApproved, createdAt, updatedAt
        case author, post, parentComment, repliesCount, wordCount
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let content = try container.decode(String.self, forKey: .content)
        
        // Create temporary objects for decoding - this should be handled differently in real apps
        let tempUser = User(username: "temp", email: "temp@example.com", passwordHash: "", firstName: "Temp", lastName: "User")
        let tempPost = Post(title: "Temp", content: "Temp", author: tempUser)
        
        self.init(content: content, author: tempUser, post: tempPost)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.isApproved = try container.decode(Bool.self, forKey: .isApproved)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(isApproved, forKey: .isApproved)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(approvedRepliesCount, forKey: .repliesCount)
        try container.encode(wordCount, forKey: .wordCount)
        
        if let author = author {
            try container.encode(UserResponse(from: author), forKey: .author)
        }
        
        if let parentComment = parentComment {
            try container.encode(parentComment.id, forKey: .parentComment)
        }
    }
}

// MARK: - API Response Models
struct CommentResponse: Codable {
    let id: UUID
    let content: String
    let isApproved: Bool
    let createdAt: Date
    let updatedAt: Date
    let author: UserResponse?
    let postId: UUID?
    let parentCommentId: UUID?
    let repliesCount: Int
    let wordCount: Int
    
    init(from comment: Comment) {
        self.id = comment.id
        self.content = comment.content
        self.isApproved = comment.isApproved
        self.createdAt = comment.createdAt
        self.updatedAt = comment.updatedAt
        self.author = comment.author.map { UserResponse(from: $0) }
        self.postId = comment.post?.id
        self.parentCommentId = comment.parentComment?.id
        self.repliesCount = comment.approvedRepliesCount
        self.wordCount = comment.wordCount
    }
}

struct CommentWithRepliesResponse: Codable {
    let comment: CommentResponse
    let replies: [CommentResponse]
    
    init(from comment: Comment) {
        self.comment = CommentResponse(from: comment)
        self.replies = comment.replies
            .filter { $0.isApproved }
            .sorted { $0.createdAt < $1.createdAt }
            .map { CommentResponse(from: $0) }
    }
}

struct CreateCommentRequest: Codable {
    let content: String
    let postId: UUID
    let parentCommentId: UUID?
    
    func validate() throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommentValidationError.contentRequired
        }
        guard content.count <= 2000 else {
            throw CommentValidationError.contentTooLong
        }
    }
}

struct UpdateCommentRequest: Codable {
    let content: String
    let isApproved: Bool?
    
    func validate() throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommentValidationError.contentRequired
        }
        guard content.count <= 2000 else {
            throw CommentValidationError.contentTooLong
        }
    }
}

enum CommentValidationError: Error, LocalizedError {
    case contentRequired
    case contentTooLong
    case postNotFound
    case parentCommentNotFound
    case unauthorizedModeration
    
    var errorDescription: String? {
        switch self {
        case .contentRequired:
            return "Comment content is required"
        case .contentTooLong:
            return "Comment content must be 2,000 characters or less"
        case .postNotFound:
            return "Post not found"
        case .parentCommentNotFound:
            return "Parent comment not found"
        case .unauthorizedModeration:
            return "You are not authorized to moderate comments"
        }
    }
}
