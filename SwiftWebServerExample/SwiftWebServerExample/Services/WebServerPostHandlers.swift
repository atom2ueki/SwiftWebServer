//
//  WebServerPostHandlers.swift
//  SwiftWebServerExample
//
//  Post and Comment request handlers for the web server
//

import Foundation
import SwiftWebServer

extension WebServerManager {
    
    // MARK: - Post Handlers
    
    func handleGetPosts(_ req: Request, _ res: Response) {
        let publishedOnly = req.query("published") == "true"
        let authorId = req.query("author")
        
        var posts: [Post]
        
        if let authorIdString = authorId, let authorUUID = UUID(uuidString: authorIdString) {
            // Get posts by specific author
            guard let author = dataManager.getUser(by: authorUUID) else {
                res.badRequest("Invalid author ID")
                return
            }
            posts = dataManager.getPostsByAuthor(author)
        } else if publishedOnly {
            // Get only published posts
            posts = dataManager.getPublishedPosts()
        } else {
            // Get all posts
            posts = dataManager.posts
        }
        
        let response = posts.map { PostSummaryResponse(from: $0) }
        
        do {
            let jsonData = try JSONEncoder().encode(response)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            res.json(jsonString)
        } catch {
            res.internalServerError("Failed to encode posts")
        }
    }
    
    func handleCreatePost(_ req: Request, _ res: Response) {
        // Get authenticated user from token
        guard let authToken = req.authToken,
              let user = getUserFromToken(authToken) else {
            res.unauthorized("Authentication required")
            return
        }

        guard let jsonBody = req.jsonBody else {
            res.badRequest("Invalid request body")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonBody)
            let createRequest = try JSONDecoder().decode(CreatePostRequest.self, from: data)
            let post = try dataManager.createPost(request: createRequest, author: user)
            let response = PostResponse(from: post)
            
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            
            res.status(.created).json(responseString)
            addLogMessage("Post created: \(post.title) by \(user.username)", type: .success)
        } catch let error as PostValidationError {
            res.badRequest(error.localizedDescription)
        } catch {
            res.internalServerError("Failed to create post")
        }
    }
    
    func handleGetPost(_ req: Request, _ res: Response) {
        guard let idString = req.pathParameters["id"],
              let id = UUID(uuidString: idString) else {
            res.badRequest("Invalid post ID")
            return
        }

        guard let post = dataManager.getPost(by: id) else {
            res.notFound("Post not found")
            return
        }
        
        // Increment view count
        do {
            try dataManager.incrementPostViewCount(post)
        } catch {
            // Log error but don't fail the request
            addLogMessage("Failed to increment view count for post \(post.id)", type: .warning)
        }
        
        do {
            let response = PostResponse(from: post)
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            res.json(responseString)
        } catch {
            res.internalServerError("Failed to encode post")
        }
    }
    
    func handleUpdatePost(_ req: Request, _ res: Response) {
        guard let idString = req.pathParameters["id"],
              let id = UUID(uuidString: idString) else {
            res.badRequest("Invalid post ID")
            return
        }

        guard let post = dataManager.getPost(by: id) else {
            res.notFound("Post not found")
            return
        }

        // Check if user owns the post or is admin
        guard let authToken = req.authToken,
              let user = getUserFromToken(authToken),
              post.author?.id == user.id else {
            res.forbidden("You can only edit your own posts")
            return
        }

        guard let jsonBody = req.jsonBody else {
            res.badRequest("Invalid request body")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonBody)
            let updateRequest = try JSONDecoder().decode(UpdatePostRequest.self, from: data)
            try dataManager.updatePost(post, request: updateRequest)
            
            let response = PostResponse(from: post)
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            
            res.json(responseString)
            addLogMessage("Post updated: \(post.title) by \(user.username)", type: .success)
        } catch let error as PostValidationError {
            res.badRequest(error.localizedDescription)
        } catch {
            res.internalServerError("Failed to update post")
        }
    }
    
    func handleDeletePost(_ req: Request, _ res: Response) {
        guard let idString = req.pathParameters["id"],
              let id = UUID(uuidString: idString) else {
            res.badRequest("Invalid post ID")
            return
        }

        guard let post = dataManager.getPost(by: id) else {
            res.notFound("Post not found")
            return
        }

        // Check if user owns the post or is admin
        guard let authToken = req.authToken,
              let user = getUserFromToken(authToken),
              post.author?.id == user.id else {
            res.forbidden("You can only delete your own posts")
            return
        }

        do {
            try dataManager.deletePost(post)
            res.status(.noContent).send("")
            addLogMessage("Post deleted: \(post.title) by \(user.username)", type: .info)
        } catch {
            res.internalServerError("Failed to delete post")
        }
    }
    
    // MARK: - Comment Handlers
    
    func handleGetComments(_ req: Request, _ res: Response) {
        guard let postIdString = req.pathParameters["postId"],
              let postId = UUID(uuidString: postIdString) else {
            res.badRequest("Invalid post ID")
            return
        }

        guard let post = dataManager.getPost(by: postId) else {
            res.notFound("Post not found")
            return
        }
        
        let includeUnapproved = req.query("include_unapproved") == "true"
        let comments = dataManager.getCommentsByPost(post, includeUnapproved: includeUnapproved)
        
        // Group comments with their replies
        let commentsWithReplies = comments.map { CommentWithRepliesResponse(from: $0) }
        
        do {
            let jsonData = try JSONEncoder().encode(commentsWithReplies)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            res.json(jsonString)
        } catch {
            res.internalServerError("Failed to encode comments")
        }
    }
    
    func handleCreateComment(_ req: Request, _ res: Response) {
        guard let authToken = req.authToken,
              let user = getUserFromToken(authToken) else {
            res.unauthorized("Authentication required")
            return
        }

        guard let postIdString = req.pathParameters["postId"],
              let postId = UUID(uuidString: postIdString) else {
            res.badRequest("Invalid post ID")
            return
        }

        guard let jsonBody = req.jsonBody else {
            res.badRequest("Invalid request body")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonBody)
            var createRequest = try JSONDecoder().decode(CreateCommentRequest.self, from: data)
            createRequest = CreateCommentRequest(
                content: createRequest.content,
                postId: postId, // Use the post ID from the URL
                parentCommentId: createRequest.parentCommentId
            )
            
            let comment = try dataManager.createComment(request: createRequest, author: user)
            let response = CommentResponse(from: comment)
            
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            
            res.status(.created).json(responseString)
            addLogMessage("Comment created on post \(postId) by \(user.username)", type: .success)
        } catch let error as CommentValidationError {
            res.badRequest(error.localizedDescription)
        } catch {
            res.internalServerError("Failed to create comment")
        }
    }
    
    func handleGetComment(_ req: Request, _ res: Response) {
        guard let idString = req.pathParameters["id"],
              let id = UUID(uuidString: idString) else {
            res.badRequest("Invalid comment ID")
            return
        }

        guard let comment = dataManager.getComment(by: id) else {
            res.notFound("Comment not found")
            return
        }
        
        do {
            let response = CommentWithRepliesResponse(from: comment)
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            res.json(responseString)
        } catch {
            res.internalServerError("Failed to encode comment")
        }
    }
    
    func handleUpdateComment(_ req: Request, _ res: Response) {
        guard let idString = req.pathParameters["id"],
              let id = UUID(uuidString: idString) else {
            res.badRequest("Invalid comment ID")
            return
        }

        guard let comment = dataManager.getComment(by: id) else {
            res.notFound("Comment not found")
            return
        }

        // Check if user owns the comment
        guard let authToken = req.authToken,
              let user = getUserFromToken(authToken),
              comment.author?.id == user.id else {
            res.forbidden("You can only edit your own comments")
            return
        }

        guard let jsonBody = req.jsonBody else {
            res.badRequest("Invalid request body")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonBody)
            let updateRequest = try JSONDecoder().decode(UpdateCommentRequest.self, from: data)
            try dataManager.updateComment(comment, request: updateRequest)
            
            let response = CommentResponse(from: comment)
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            
            res.json(responseString)
            addLogMessage("Comment updated by \(user.username)", type: .success)
        } catch let error as CommentValidationError {
            res.badRequest(error.localizedDescription)
        } catch {
            res.internalServerError("Failed to update comment")
        }
    }
    
    func handleDeleteComment(_ req: Request, _ res: Response) {
        guard let idString = req.pathParameters["id"],
              let id = UUID(uuidString: idString) else {
            res.badRequest("Invalid comment ID")
            return
        }

        guard let comment = dataManager.getComment(by: id) else {
            res.notFound("Comment not found")
            return
        }

        // Check if user owns the comment
        guard let authToken = req.authToken,
              let user = getUserFromToken(authToken),
              comment.author?.id == user.id else {
            res.forbidden("You can only delete your own comments")
            return
        }
        
        do {
            try dataManager.deleteComment(comment)
            res.status(.noContent).send("")
            addLogMessage("Comment deleted by \(user.username)", type: .info)
        } catch {
            res.internalServerError("Failed to delete comment")
        }
    }
    
    // MARK: - Helper Methods

    private func jsonError(_ message: String) -> String {
        return "{\"error\": \"\(message)\"}"
    }

    private func getUserFromToken(_ token: String) -> User? {
        if token == "demo-api-key" {
            // Return first user for demo purposes
            return dataManager.users.first
        }
        
        if token.hasPrefix("user-") {
            let userIdString = String(token.dropFirst(5))
            if let userId = UUID(uuidString: userIdString) {
                return dataManager.getUser(by: userId)
            }
        }
        
        return nil
    }
}
