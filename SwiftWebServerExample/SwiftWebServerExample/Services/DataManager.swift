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
    var authTokens: [AuthToken] = []
    
    // Statistics
    var totalUsers: Int { users.count }
    var totalPosts: Int { posts.count }
    var totalComments: Int { comments.count }
    var totalAuthTokens: Int { authTokens.count }
    var activeAuthTokens: Int { authTokens.filter { $0.isValid }.count }
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
        loadAuthTokens()
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

    private func loadAuthTokens() {
        do {
            let descriptor = FetchDescriptor<AuthToken>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            self.authTokens = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading auth tokens: \(error)")
            self.authTokens = []
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
        print("🔍 DataManager.createComment called with content: '\(request.content)', postId: \(request.postId), author: \(author.username)")

        do {
            try request.validate()
            print("✅ Comment validation passed")
        } catch {
            print("❌ Comment validation failed: \(error)")
            throw error
        }

        guard let post = getPost(by: request.postId) else {
            print("❌ Post not found with ID: \(request.postId)")
            throw CommentValidationError.postNotFound
        }
        print("✅ Post found: \(post.title)")

        var parentComment: Comment?
        if let parentId = request.parentCommentId {
            parentComment = comments.first { $0.id == parentId }
            if parentComment == nil {
                print("❌ Parent comment not found with ID: \(parentId)")
                throw CommentValidationError.parentCommentNotFound
            }
            print("✅ Parent comment found")
        }

        let comment = Comment(content: request.content, author: author, post: post, parentComment: parentComment)
        print("✅ Comment object created")

        modelContext.insert(comment)
        try modelContext.save()
        print("✅ Comment saved to database")

        comments.insert(comment, at: 0)
        loadUsers() // Refresh to update user's comments count
        loadPosts() // Refresh to update post's comments count
        print("✅ Comment creation completed successfully")
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

    // MARK: - Token Management

    func getOrCreateAuthToken(for user: User, expiresIn: TimeInterval = 3600, deviceInfo: String? = nil) throws -> AuthToken {
        // First check if user has a valid existing token
        if let existingToken = self.authTokens.first(where: { $0.user?.id == user.id && $0.isValid }) {
            // Update last used time and return existing token
            existingToken.updateLastUsed()
            try modelContext.save()
            return existingToken
        }

        // No valid token found, create a new one
        return try createAuthToken(for: user, expiresIn: expiresIn, deviceInfo: deviceInfo)
    }

    func createAuthToken(for user: User, expiresIn: TimeInterval = 3600, deviceInfo: String? = nil) throws -> AuthToken {
        let authToken = AuthToken.createToken(for: user, expiresIn: expiresIn, deviceInfo: deviceInfo)

        modelContext.insert(authToken)
        try modelContext.save()

        self.authTokens.insert(authToken, at: 0)
        return authToken
    }

    func validateAuthToken(_ tokenString: String) -> AuthToken? {
        print("🔍 DataManager.validateAuthToken called with token: \(tokenString.prefix(10))...")
        print("🔍 DataManager: checking \(self.authTokens.count) tokens in memory")

        // First check in memory for performance
        if let token = self.authTokens.first(where: { $0.token == tokenString && $0.isValid }) {
            print("🔍 DataManager: found valid token in memory for user \(token.user?.username ?? "unknown")")
            token.updateLastUsed()
            try? modelContext.save()
            return token
        }

        print("🔍 DataManager: token not found in memory, checking database...")

        // Fallback to database query
        do {
            let predicate = #Predicate<AuthToken> { token in
                token.token == tokenString && !token.isRevoked
            }
            let descriptor = FetchDescriptor<AuthToken>(predicate: predicate)
            let tokens = try modelContext.fetch(descriptor)

            print("🔍 DataManager: found \(tokens.count) tokens in database")

            if let token = tokens.first, token.isValid {
                print("🔍 DataManager: found valid token in database for user \(token.user?.username ?? "unknown")")
                token.updateLastUsed()
                try modelContext.save()

                // Update in-memory array if not present
                if !self.authTokens.contains(where: { $0.id == token.id }) {
                    self.authTokens.insert(token, at: 0)
                }

                return token
            } else if let token = tokens.first {
                if token.isExpired {
                    print("🔍 DataManager: token expired at \(token.expiresAt), current time: \(Date())")
                } else if token.isRevoked {
                    print("🔍 DataManager: token was revoked")
                }
                print("🔍 DataManager: found token in database but it's invalid - expired: \(token.isExpired), revoked: \(token.isRevoked)")
            }
        } catch {
            print("🔍 DataManager: Error validating auth token: \(error)")
        }

        print("🔍 DataManager: token validation failed - no valid token found")
        return nil
    }

    func getUserFromToken(_ tokenString: String) -> User? {
        // First check in memory for performance (avoid re-validation)
        if let token = self.authTokens.first(where: { $0.token == tokenString && $0.isValid }) {
            return token.user
        }

        // Fallback to full validation if not in memory
        guard let authToken = validateAuthToken(tokenString) else { return nil }
        return authToken.user
    }

    func revokeAuthToken(_ tokenString: String) throws {
        if let token = self.authTokens.first(where: { $0.token == tokenString }) {
            token.revoke()
            try modelContext.save()
            return
        }

        // Fallback to database query
        let predicate = #Predicate<AuthToken> { token in
            token.token == tokenString
        }
        let descriptor = FetchDescriptor<AuthToken>(predicate: predicate)
        let tokens = try modelContext.fetch(descriptor)

        if let token = tokens.first {
            token.revoke()
            try modelContext.save()

            // Update in-memory array
            if let index = self.authTokens.firstIndex(where: { $0.id == token.id }) {
                self.authTokens[index] = token
            }
        }
    }

    func revokeAllUserTokens(for user: User) throws {
        let userTokens = self.authTokens.filter { $0.user?.id == user.id && !$0.isRevoked }

        for token in userTokens {
            token.revoke()
        }

        try modelContext.save()
        loadAuthTokens() // Refresh the list
    }

    func cleanupExpiredTokens() throws {
        let expiredTokens = self.authTokens.filter { $0.isExpired || $0.isRevoked }

        for token in expiredTokens {
            modelContext.delete(token)
        }

        try modelContext.save()
        self.authTokens.removeAll { $0.isExpired || $0.isRevoked }
    }

    func extendTokenExpiration(_ tokenString: String, by timeInterval: TimeInterval) throws {
        guard let token = self.authTokens.first(where: { $0.token == tokenString && $0.isValid }) else {
            throw AuthTokenError.tokenNotFound
        }

        token.extend(by: timeInterval)
        try modelContext.save()
    }

    // MARK: - Data Management

    func clearAllData() throws {
        // Delete all auth tokens first
        for token in self.authTokens {
            modelContext.delete(token)
        }

        // Delete all comments (due to relationships)
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
        self.authTokens.removeAll()
        self.comments.removeAll()
        self.posts.removeAll()
        self.users.removeAll()
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
