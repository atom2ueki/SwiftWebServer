//
//  DataManager.swift
//  SwiftWebServerExample
//
//  Data manager using Observation framework for real-time updates
//

import Foundation
import SwiftData
import Observation
import CryptoKit

@Observable
final class DataManager {
    private var modelContext: ModelContext
    
    // Observable properties for real-time updates
    var users: [User] = []
    var posts: [Post] = []
    var comments: [Comment] = []
    
    // Statistics
    var totalUsers: Int { users.count }
    var totalPosts: Int { posts.count }
    var totalComments: Int { comments.count }
    var publishedPosts: Int { posts.filter { $0.isPublished }.count }
    var approvedComments: Int { comments.filter { $0.isApproved }.count }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadData()
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        loadUsers()
        loadPosts()
        loadComments()
    }
    
    private func loadUsers() {
        do {
            let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            users = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading users: \(error)")
            users = []
        }
    }
    
    private func loadPosts() {
        do {
            let descriptor = FetchDescriptor<Post>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            posts = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading posts: \(error)")
            posts = []
        }
    }
    
    private func loadComments() {
        do {
            let descriptor = FetchDescriptor<Comment>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            comments = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading comments: \(error)")
            comments = []
        }
    }
    
    // MARK: - User Management
    
    func createUser(request: CreateUserRequest) throws -> User {
        try request.validate()
        
        // Check if username or email already exists
        if users.contains(where: { $0.username == request.username }) {
            throw DataManagerError.usernameExists
        }
        if users.contains(where: { $0.email == request.email }) {
            throw DataManagerError.emailExists
        }
        
        // Hash password
        let passwordHash = hashPassword(request.password)
        
        let user = User(
            username: request.username,
            email: request.email,
            passwordHash: passwordHash,
            firstName: request.firstName,
            lastName: request.lastName
        )
        
        modelContext.insert(user)
        try modelContext.save()
        
        users.insert(user, at: 0)
        return user
    }
    
    func getUser(by id: UUID) -> User? {
        return users.first { $0.id == id }
    }
    
    func getUserByUsername(_ username: String) -> User? {
        return users.first { $0.username == username }
    }
    
    func getUserByEmail(_ email: String) -> User? {
        return users.first { $0.email == email }
    }
    
    func updateUser(_ user: User, request: UpdateUserRequest) throws {
        try request.validate()
        
        if let email = request.email, email != user.email {
            if users.contains(where: { $0.email == email && $0.id != user.id }) {
                throw DataManagerError.emailExists
            }
            user.email = email
        }
        
        if let firstName = request.firstName {
            user.firstName = firstName
        }
        
        if let lastName = request.lastName {
            user.lastName = lastName
        }
        
        if let isActive = request.isActive {
            user.isActive = isActive
        }
        
        user.updateTimestamp()
        try modelContext.save()
        loadUsers() // Refresh the list
    }
    
    func deleteUser(_ user: User) throws {
        modelContext.delete(user)
        try modelContext.save()
        users.removeAll { $0.id == user.id }
    }
    
    // MARK: - Post Management
    
    func createPost(request: CreatePostRequest, author: User) throws -> Post {
        try request.validate()
        
        let post = Post(title: request.title, content: request.content, author: author)
        
        if request.isPublished == true {
            post.publish()
        }
        
        modelContext.insert(post)
        try modelContext.save()
        
        posts.insert(post, at: 0)
        loadUsers() // Refresh to update user's posts count
        return post
    }
    
    func getPost(by id: UUID) -> Post? {
        return posts.first { $0.id == id }
    }
    
    func getPublishedPosts() -> [Post] {
        return posts.filter { $0.isPublished }.sorted { $0.publishedAt ?? $0.createdAt > $1.publishedAt ?? $1.createdAt }
    }
    
    func getPostsByAuthor(_ author: User) -> [Post] {
        return posts.filter { $0.author?.id == author.id }.sorted { $0.createdAt > $1.createdAt }
    }
    
    func updatePost(_ post: Post, request: UpdatePostRequest) throws {
        try request.validate()
        
        if let title = request.title {
            post.title = title
        }
        
        if let content = request.content {
            post.content = content
            post.excerpt = String(content.prefix(200))
        }
        
        if let isPublished = request.isPublished {
            if isPublished && !post.isPublished {
                post.publish()
            } else if !isPublished && post.isPublished {
                post.unpublish()
            }
        }
        
        post.updatedAt = Date()
        try modelContext.save()
        loadPosts() // Refresh the list
    }
    
    func deletePost(_ post: Post) throws {
        modelContext.delete(post)
        try modelContext.save()
        posts.removeAll { $0.id == post.id }
        loadUsers() // Refresh to update user's posts count
        loadComments() // Refresh to remove associated comments
    }
    
    func incrementPostViewCount(_ post: Post) throws {
        post.incrementViewCount()
        try modelContext.save()
        // No need to reload entire list for view count update
    }
    
    // MARK: - Comment Management
    
    func createComment(request: CreateCommentRequest, author: User) throws -> Comment {
        try request.validate()
        
        guard let post = getPost(by: request.postId) else {
            throw CommentValidationError.postNotFound
        }
        
        var parentComment: Comment?
        if let parentId = request.parentCommentId {
            parentComment = comments.first { $0.id == parentId }
            if parentComment == nil {
                throw CommentValidationError.parentCommentNotFound
            }
        }
        
        let comment = Comment(content: request.content, author: author, post: post, parentComment: parentComment)
        
        modelContext.insert(comment)
        try modelContext.save()
        
        comments.insert(comment, at: 0)
        loadUsers() // Refresh to update user's comments count
        loadPosts() // Refresh to update post's comments count
        return comment
    }
    
    func getComment(by id: UUID) -> Comment? {
        return comments.first { $0.id == id }
    }
    
    func getCommentsByPost(_ post: Post, includeUnapproved: Bool = false) -> [Comment] {
        let postComments = comments.filter { $0.post?.id == post.id && $0.parentComment == nil }
        
        if includeUnapproved {
            return postComments.sorted { $0.createdAt < $1.createdAt }
        } else {
            return postComments.filter { $0.isApproved }.sorted { $0.createdAt < $1.createdAt }
        }
    }
    
    func getCommentsByAuthor(_ author: User) -> [Comment] {
        return comments.filter { $0.author?.id == author.id }.sorted { $0.createdAt > $1.createdAt }
    }
    
    func updateComment(_ comment: Comment, request: UpdateCommentRequest) throws {
        try request.validate()
        
        comment.updateContent(request.content)
        
        if let isApproved = request.isApproved {
            if isApproved {
                comment.approve()
            } else {
                comment.reject()
            }
        }
        
        try modelContext.save()
        loadComments() // Refresh the list
        loadPosts() // Refresh to update post's comments count
    }
    
    func deleteComment(_ comment: Comment) throws {
        modelContext.delete(comment)
        try modelContext.save()
        comments.removeAll { $0.id == comment.id }
        loadUsers() // Refresh to update user's comments count
        loadPosts() // Refresh to update post's comments count
    }
    
    func approveComment(_ comment: Comment) throws {
        comment.approve()
        try modelContext.save()
        loadComments() // Refresh the list
        loadPosts() // Refresh to update post's comments count
    }
    
    func rejectComment(_ comment: Comment) throws {
        comment.reject()
        try modelContext.save()
        loadComments() // Refresh the list
        loadPosts() // Refresh to update post's comments count
    }
    
    // MARK: - Authentication
    
    func authenticateUser(username: String, password: String) -> User? {
        guard let user = getUserByUsername(username) else { return nil }
        guard user.isActive else { return nil }
        
        let passwordHash = hashPassword(password)
        return user.passwordHash == passwordHash ? user : nil
    }
    
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Sample Data
    
    func createSampleData() throws {
        // Create sample users
        let user1 = try createUser(request: CreateUserRequest(
            username: "johndoe",
            email: "john@example.com",
            password: "password123",
            firstName: "John",
            lastName: "Doe"
        ))
        
        let user2 = try createUser(request: CreateUserRequest(
            username: "janedoe",
            email: "jane@example.com",
            password: "password123",
            firstName: "Jane",
            lastName: "Doe"
        ))
        
        // Create sample posts
        let post1 = try createPost(request: CreatePostRequest(
            title: "Welcome to SwiftWebServer",
            content: "This is a comprehensive example of SwiftWebServer capabilities. It demonstrates routing, middleware, authentication, and data management using SwiftData.",
            isPublished: true
        ), author: user1)
        
        let post2 = try createPost(request: CreatePostRequest(
            title: "Building Modern Web APIs with Swift",
            content: "Learn how to build robust web APIs using Swift and SwiftWebServer. This post covers best practices, middleware usage, and real-world examples.",
            isPublished: true
        ), author: user2)
        
        // Create sample comments
        _ = try createComment(request: CreateCommentRequest(
            content: "Great introduction! Looking forward to more content.",
            postId: post1.id,
            parentCommentId: nil
        ), author: user2)
        
        _ = try createComment(request: CreateCommentRequest(
            content: "Very informative post. The examples are really helpful.",
            postId: post2.id,
            parentCommentId: nil
        ), author: user1)
        
        // Approve all comments
        for comment in comments {
            try approveComment(comment)
        }
    }

    // MARK: - Data Management

    func clearAllData() throws {
        // Delete all comments first (due to relationships)
        for comment in comments {
            modelContext.delete(comment)
        }

        // Delete all posts
        for post in posts {
            modelContext.delete(post)
        }

        // Delete all users
        for user in users {
            modelContext.delete(user)
        }

        try modelContext.save()

        // Clear local arrays
        comments.removeAll()
        posts.removeAll()
        users.removeAll()
    }
}

// MARK: - Errors

enum DataManagerError: Error, LocalizedError {
    case usernameExists
    case emailExists
    case userNotFound
    case postNotFound
    case commentNotFound
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .usernameExists:
            return "Username already exists"
        case .emailExists:
            return "Email already exists"
        case .userNotFound:
            return "User not found"
        case .postNotFound:
            return "Post not found"
        case .commentNotFound:
            return "Comment not found"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}
