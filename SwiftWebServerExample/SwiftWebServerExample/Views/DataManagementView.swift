//
//  DataManagementView.swift
//  SwiftWebServerExample
//
//  Unified native data management interface (merged CMS and Data views)
//

import SwiftUI
import SwiftData

struct DataManagementView: View {
    @Bindable var webServerManager: WebServerManager
    @Bindable var dataManager: DataManager
    
    @State private var selectedSection = 0 // 0 = Overview, 1 = Users, 2 = Posts, 3 = Comments

    @State private var showingCreateSampleData = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Data Management")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))

            Divider()

            VStack(spacing: 0) {
                // Section Picker
                Picker("Section", selection: $selectedSection) {
                    Text("Overview").tag(0)
                    Text("Users").tag(1)
                    Text("Posts").tag(2)
                    Text("Comments").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                
                // Content
                Group {
                    switch selectedSection {
                    case 0:
                        DataOverviewSection(dataManager: dataManager, showingCreateSampleData: $showingCreateSampleData)
                    case 1:
                        UsersManagementSection(dataManager: dataManager)
                    case 2:
                        PostsManagementSection(dataManager: dataManager)
                    case 3:
                        CommentsManagementSection(dataManager: dataManager)
                    default:
                        EmptyView()
                    }
                }
            }
        }

        .alert("Create Sample Data", isPresented: $showingCreateSampleData) {
            Button("Create") {
                Task {
                    do {
                        try dataManager.createSampleData()
                    } catch {
                        print("Error creating sample data: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will create sample users, posts, and comments for testing the API.")
        }
    }
}

// MARK: - Data Overview Section

struct DataOverviewSection: View {
    let dataManager: DataManager
    @Binding var showingCreateSampleData: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Statistics Cards
                HStack(spacing: 16) {
                    StatCard(title: "Users", count: dataManager.totalUsers, icon: "person.3.fill", color: .blue)
                    StatCard(title: "Posts", count: dataManager.totalPosts, icon: "doc.text.fill", color: .green)
                    StatCard(title: "Comments", count: dataManager.totalComments, icon: "bubble.left.fill", color: .orange)
                }
                .padding(.horizontal, 16)
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Activity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    if dataManager.totalUsers == 0 {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No data available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Create some sample data to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Create Sample Data") {
                                showingCreateSampleData = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        // Show recent items
                        LazyVStack(spacing: 8) {
                            ForEach(dataManager.users.prefix(3), id: \.id) { user in
                                RecentItemRow(
                                    title: user.username,
                                    subtitle: "User • \(user.email)",
                                    icon: "person.circle.fill",
                                    color: .blue
                                )
                            }
                            
                            ForEach(dataManager.posts.prefix(3), id: \.id) { post in
                                RecentItemRow(
                                    title: post.title,
                                    subtitle: "Post • \(post.content.prefix(50))...",
                                    icon: "doc.text.fill",
                                    color: .green
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Recent Item Row

struct RecentItemRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Placeholder Management Sections

struct UsersManagementSection: View {
    let dataManager: DataManager
    
    var body: some View {
        List {
            ForEach(dataManager.users, id: \.id) { user in
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.username)
                        .font(.headline)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteUsers)
        }
    }
    
    private func deleteUsers(offsets: IndexSet) {
        for index in offsets {
            let user = dataManager.users[index]
            try? dataManager.deleteUser(user)
        }
    }
}

struct PostsManagementSection: View {
    let dataManager: DataManager
    
    var body: some View {
        List {
            ForEach(dataManager.posts, id: \.id) { post in
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title)
                        .font(.headline)
                    Text(post.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deletePosts)
        }
    }
    
    private func deletePosts(offsets: IndexSet) {
        for index in offsets {
            let post = dataManager.posts[index]
            try? dataManager.deletePost(post)
        }
    }
}

struct CommentsManagementSection: View {
    let dataManager: DataManager

    var body: some View {
        List {
            if dataManager.comments.isEmpty {
                Text("No comments available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(dataManager.comments.enumerated()), id: \.element.id) { index, comment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(comment.content)
                            .font(.headline)
                        if let post = comment.post {
                            Text("On: \(post.title)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteComments)
            }
        }
    }

    private func deleteComments(offsets: IndexSet) {
        for index in offsets {
            if index < dataManager.comments.count {
                let comment = dataManager.comments[index]
                try? dataManager.deleteComment(comment)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, Post.self, Comment.self, configurations: config)
    let context = ModelContext(container)

    let dataManager = DataManager(modelContext: context)
    let webServerManager = WebServerManager(dataManager: dataManager)

    DataManagementView(
        webServerManager: webServerManager,
        dataManager: dataManager
    )
}
