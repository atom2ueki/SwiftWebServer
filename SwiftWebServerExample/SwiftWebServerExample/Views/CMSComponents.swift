//
//  CMSComponents.swift
//  SwiftWebServerExample
//
//  CMS row components and forms
//

import SwiftUI

// MARK: - CMS Row Components

struct CMSUserRow: View {
    let user: User
    @Bindable var dataManager: DataManager
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.headline)
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(isActive: user.isActive)
                    
                    Text("Posts: \(user.posts.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Comments: \(user.comments.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Created: \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Delete") {
                        showingDeleteAlert = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditSheet) {
            EditUserSheet(user: user, dataManager: dataManager)
        }
        .alert("Delete User", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try dataManager.deleteUser(user)
                    } catch {
                        print("Error deleting user: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(user.fullName)? This will also delete all their posts and comments.")
        }
    }
}

struct CMSPostRow: View {
    let post: Post
    @Bindable var dataManager: DataManager
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(post.excerpt)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    if let author = post.author {
                        Text("by \(author.fullName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    PublishStatusBadge(isPublished: post.isPublished)
                    
                    Text("Views: \(post.viewCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Comments: \(post.comments.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(post.readingTime) min read")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Created: \(post.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if post.isPublished, let publishedAt = post.publishedAt {
                    Text("Published: \(publishedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(post.isPublished ? "Unpublish" : "Publish") {
                        Task {
                            do {
                                let updateRequest = UpdatePostRequest(
                                    title: nil,
                                    content: nil,
                                    isPublished: !post.isPublished
                                )
                                try dataManager.updatePost(post, request: updateRequest)
                            } catch {
                                print("Error updating post: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(post.isPublished ? .orange : .green)
                    
                    Button("Edit") {
                        showingEditSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Delete") {
                        showingDeleteAlert = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditSheet) {
            EditPostSheet(post: post, dataManager: dataManager)
        }
        .alert("Delete Post", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try dataManager.deletePost(post)
                    } catch {
                        print("Error deleting post: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(post.title)\"? This will also delete all comments on this post.")
        }
    }
}

struct CMSCommentRow: View {
    let comment: Comment
    @Bindable var dataManager: DataManager
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(comment.content)
                        .font(.body)
                        .lineLimit(4)
                    
                    HStack {
                        if let author = comment.author {
                            Text("by \(author.fullName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let post = comment.post {
                            Text("on \"\(post.title)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        if comment.isReply {
                            Text("(Reply)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    ApprovalStatusBadge(isApproved: comment.isApproved)
                    
                    if comment.replies.count > 0 {
                        Text("Replies: \(comment.replies.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Text("Created: \(comment.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(comment.isApproved ? "Reject" : "Approve") {
                        Task {
                            do {
                                if comment.isApproved {
                                    try dataManager.rejectComment(comment)
                                } else {
                                    try dataManager.approveComment(comment)
                                }
                            } catch {
                                print("Error updating comment: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(comment.isApproved ? .orange : .green)
                    
                    Button("Delete") {
                        showingDeleteAlert = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .alert("Delete Comment", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try dataManager.deleteComment(comment)
                    } catch {
                        print("Error deleting comment: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this comment? This action cannot be undone.")
        }
    }
}

// MARK: - Status Badges

struct StatusBadge: View {
    let isActive: Bool
    
    var body: some View {
        Text(isActive ? "Active" : "Inactive")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(isActive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(isActive ? .green : .red)
            .cornerRadius(8)
    }
}

struct PublishStatusBadge: View {
    let isPublished: Bool
    
    var body: some View {
        Text(isPublished ? "Published" : "Draft")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(isPublished ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
            .foregroundColor(isPublished ? .green : .orange)
            .cornerRadius(8)
    }
}

struct ApprovalStatusBadge: View {
    let isApproved: Bool
    
    var body: some View {
        Text(isApproved ? "Approved" : "Pending")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(isApproved ? Color.green.opacity(0.2) : Color.yellow.opacity(0.2))
            .foregroundColor(isApproved ? .green : .orange)
            .cornerRadius(8)
    }
}
