//
//  DataOverviewView.swift
//  SwiftWebServerExample
//
//  Data overview and management interface
//

import SwiftUI
import SwiftData

struct DataOverviewView: View {
    @Bindable var dataManager: DataManager
    @State private var selectedSection = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Data Overview")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Real-time stats
                HStack(spacing: 16) {
                    StatBadge(label: "Users", value: dataManager.totalUsers, color: .blue)
                    StatBadge(label: "Posts", value: dataManager.totalPosts, color: .green)
                    StatBadge(label: "Comments", value: dataManager.totalComments, color: .orange)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            // Section Picker
            Picker("Section", selection: $selectedSection) {
                Text("Users").tag(0)
                Text("Posts").tag(1)
                Text("Comments").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            // Content
            TabView(selection: $selectedSection) {
                UsersListView(dataManager: dataManager)
                    .tag(0)
                
                PostsListView(dataManager: dataManager)
                    .tag(1)
                
                CommentsListView(dataManager: dataManager)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct UsersListView: View {
    @Bindable var dataManager: DataManager
    
    var body: some View {
        List(dataManager.users, id: \.id) { user in
            UserRowView(user: user)
        }
        .listStyle(.plain)
        .overlay {
            if dataManager.users.isEmpty {
                ContentUnavailableView(
                    "No Users",
                    systemImage: "person.3",
                    description: Text("Create some sample data to see users here")
                )
            }
        }
    }
}

struct UserRowView: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.headline)
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(isActive: user.isActive)
                    
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("\(user.posts.count)", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(user.comments.count)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Created \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PostsListView: View {
    @Bindable var dataManager: DataManager
    
    var body: some View {
        List(dataManager.posts, id: \.id) { post in
            PostRowView(post: post)
        }
        .listStyle(.plain)
        .overlay {
            if dataManager.posts.isEmpty {
                ContentUnavailableView(
                    "No Posts",
                    systemImage: "doc.text",
                    description: Text("Create some sample data to see posts here")
                )
            }
        }
    }
}

struct PostRowView: View {
    let post: Post
    
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
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    PublishStatusBadge(isPublished: post.isPublished)
                    
                    if let author = post.author {
                        Text("by \(author.fullName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Label("\(post.viewCount)", systemImage: "eye")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(post.comments.count)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(post.readingTime) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Created \(post.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CommentsListView: View {
    @Bindable var dataManager: DataManager
    
    var body: some View {
        List(dataManager.comments, id: \.id) { comment in
            CommentRowView(comment: comment)
        }
        .listStyle(.plain)
        .overlay {
            if dataManager.comments.isEmpty {
                ContentUnavailableView(
                    "No Comments",
                    systemImage: "bubble.left",
                    description: Text("Create some sample data to see comments here")
                )
            }
        }
    }
}

struct CommentRowView: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(comment.content)
                        .font(.body)
                        .lineLimit(4)
                    
                    if let author = comment.author {
                        Text("by \(author.fullName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    ApprovalStatusBadge(isApproved: comment.isApproved)
                    
                    if comment.isReply {
                        Text("Reply")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
            
            HStack {
                if let post = comment.post {
                    Text("on \"\(post.title)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text("Created \(comment.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}



#Preview {
    DataOverviewView(dataManager: DataManager(modelContext: ModelContext(try! ModelContainer(for: User.self, Post.self, Comment.self))))
}
