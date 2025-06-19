//
//  ContentManagementView.swift
//  SwiftWebServerExample
//
//  CMS and content management interface
//

import SwiftUI
import SwiftData
import Foundation
import Network

struct ContentManagementView: View {
    @Bindable var webServerManager: WebServerManager
    @Bindable var dataManager: DataManager
    @State private var selectedContentType = 0
    @State private var showingCreateForm = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with access info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Content Management")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if webServerManager.isRunning {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Web Interface Available:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Local: http://localhost:\(webServerManager.currentPort)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .textSelection(.enabled)
                            
                            if let networkIP = getLocalIPAddress() {
                                Text("Network: http://\(networkIP):\(webServerManager.currentPort)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .textSelection(.enabled)
                            }
                            
                            Text("Server accessible via localhost")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if webServerManager.isRunning {
                    Button("Open in Safari") {
                        if let url = URL(string: "http://localhost:\(webServerManager.currentPort)") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            if webServerManager.isRunning {
                // Content management interface
                VStack(spacing: 0) {
                    // Content type picker
                    Picker("Content Type", selection: $selectedContentType) {
                        Text("Users (\(dataManager.totalUsers))").tag(0)
                        Text("Posts (\(dataManager.totalPosts))").tag(1)
                        Text("Comments (\(dataManager.totalComments))").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    
                    Divider()
                    
                    // Content management area
                    TabView(selection: $selectedContentType) {
                        CMSUsersView(dataManager: dataManager)
                            .tag(0)
                        
                        CMSPostsView(dataManager: dataManager)
                            .tag(1)
                        
                        CMSCommentsView(dataManager: dataManager)
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            } else {
                // Server not running state
                ContentUnavailableView(
                    "Content Management Unavailable",
                    systemImage: "server.rack",
                    description: Text("Start the server to manage content and access the web interface")
                )
            }
        }
    }
    
    // Helper function to get local IP address
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" || name == "en1" || name == "wlan0" || name == "eth0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
}

// MARK: - CMS Views

struct CMSUsersView: View {
    @Bindable var dataManager: DataManager
    @State private var showingCreateUser = false
    @State private var searchText = ""
    
    var filteredUsers: [User] {
        if searchText.isEmpty {
            return dataManager.users
        } else {
            return dataManager.users.filter { user in
                user.fullName.localizedCaseInsensitiveContains(searchText) ||
                user.username.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                
                Spacer()
                
                Button("New User") {
                    showingCreateUser = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            // Users list
            List(filteredUsers, id: \.id) { user in
                CMSUserRow(user: user, dataManager: dataManager)
            }
            .listStyle(.plain)
            .overlay {
                if filteredUsers.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Users" : "No Matching Users",
                        systemImage: "person.3",
                        description: Text(searchText.isEmpty ? "Create some users to get started" : "Try a different search term")
                    )
                }
            }
        }
        .sheet(isPresented: $showingCreateUser) {
            CreateUserSheet(dataManager: dataManager)
        }
    }
}

struct CMSPostsView: View {
    @Bindable var dataManager: DataManager
    @State private var showingCreatePost = false
    @State private var searchText = ""
    @State private var filterPublished: Bool? = nil
    
    var filteredPosts: [Post] {
        var posts = dataManager.posts
        
        // Filter by published status
        if let filterPublished = filterPublished {
            posts = posts.filter { $0.isPublished == filterPublished }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            posts = posts.filter { post in
                post.title.localizedCaseInsensitiveContains(searchText) ||
                post.content.localizedCaseInsensitiveContains(searchText) ||
                post.author?.fullName.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return posts
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search posts...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                
                Menu {
                    Button("All Posts") { filterPublished = nil }
                    Button("Published Only") { filterPublished = true }
                    Button("Drafts Only") { filterPublished = false }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(filterPublished == nil ? "All" : (filterPublished! ? "Published" : "Drafts"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button("New Post") {
                    showingCreatePost = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            // Posts list
            List(filteredPosts, id: \.id) { post in
                CMSPostRow(post: post, dataManager: dataManager)
            }
            .listStyle(.plain)
            .overlay {
                if filteredPosts.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Posts" : "No Matching Posts",
                        systemImage: "doc.text",
                        description: Text(searchText.isEmpty ? "Create some posts to get started" : "Try a different search term")
                    )
                }
            }
        }
        .sheet(isPresented: $showingCreatePost) {
            CreatePostSheet(dataManager: dataManager)
        }
    }
}

struct CMSCommentsView: View {
    @Bindable var dataManager: DataManager
    @State private var searchText = ""
    @State private var filterApproved: Bool? = nil
    
    var filteredComments: [Comment] {
        var comments = dataManager.comments
        
        // Filter by approval status
        if let filterApproved = filterApproved {
            comments = comments.filter { $0.isApproved == filterApproved }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            comments = comments.filter { comment in
                comment.content.localizedCaseInsensitiveContains(searchText) ||
                comment.author?.fullName.localizedCaseInsensitiveContains(searchText) == true ||
                comment.post?.title.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return comments
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search comments...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                
                Menu {
                    Button("All Comments") { filterApproved = nil }
                    Button("Approved Only") { filterApproved = true }
                    Button("Pending Only") { filterApproved = false }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(filterApproved == nil ? "All" : (filterApproved! ? "Approved" : "Pending"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            // Comments list
            List(filteredComments, id: \.id) { comment in
                CMSCommentRow(comment: comment, dataManager: dataManager)
            }
            .listStyle(.plain)
            .overlay {
                if filteredComments.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Comments" : "No Matching Comments",
                        systemImage: "bubble.left",
                        description: Text(searchText.isEmpty ? "Comments will appear here when created" : "Try a different search term")
                    )
                }
            }
        }
    }
}

#Preview {
    ContentManagementView(
        webServerManager: WebServerManager(dataManager: DataManager(modelContext: ModelContext(try! ModelContainer(for: User.self, Post.self, Comment.self)))),
        dataManager: DataManager(modelContext: ModelContext(try! ModelContainer(for: User.self, Post.self, Comment.self)))
    )
}
