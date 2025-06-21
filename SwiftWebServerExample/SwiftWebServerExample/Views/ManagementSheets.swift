//
//  ManagementSheets.swift
//  SwiftWebServerExample
//
//  Management sheet views for dashboard cards
//

import SwiftUI
import SwiftData

// MARK: - Users Management Sheet

struct UsersManagementSheet: View {
    @Bindable var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateUser = false

    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.users, id: \.id) { user in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.username)
                            .font(.headline)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("Posts: \(user.posts.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Active: \(user.isActive ? "Yes" : "No")")
                                .font(.caption)
                                .foregroundColor(user.isActive ? .green : .red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteUsers)
            }
            .navigationTitle("Users Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Add User") {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showingCreateUser = true
                    }
                    .foregroundColor(.blue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCreateUser) {
                CreateUserSheet(dataManager: dataManager)
            }
        }
    }
    
    private func deleteUsers(offsets: IndexSet) {
        for index in offsets {
            let user = dataManager.users[index]
            try? dataManager.deleteUser(user)
        }
    }
}

// MARK: - Posts Management Sheet

struct PostsManagementSheet: View {
    @Bindable var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.posts, id: \.id) { post in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.title)
                            .font(.headline)
                        Text(post.content)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        HStack {
                            Text("Views: \(post.viewCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(post.isPublished ? "Published" : "Draft")
                                .font(.caption)
                                .foregroundColor(post.isPublished ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deletePosts)
            }
            .navigationTitle("Posts Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func deletePosts(offsets: IndexSet) {
        for index in offsets {
            let post = dataManager.posts[index]
            try? dataManager.deletePost(post)
        }
    }
}

// MARK: - Comments Management Sheet

struct CommentsManagementSheet: View {
    @Bindable var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
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
                            HStack {
                                if let author = comment.author {
                                    Text("By: \(author.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(comment.isApproved ? "Approved" : "Pending")
                                    .font(.caption)
                                    .foregroundColor(comment.isApproved ? .green : .orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteComments)
                }
            }
            .navigationTitle("Comments Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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

// MARK: - Sessions Management Sheet

struct SessionsManagementSheet: View {
    @Bindable var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingCleanupAlert = false

    var body: some View {
        NavigationView {
            SessionsListView(dataManager: dataManager)
                .navigationTitle("Sessions Management")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        CleanupButton(
                            dataManager: dataManager,
                            showingCleanupAlert: $showingCleanupAlert
                        )
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .alert("Cleanup Expired Sessions", isPresented: $showingCleanupAlert) {
                    Button("Cleanup") {
                        try? dataManager.cleanupExpiredTokens()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will permanently remove all expired and revoked sessions.")
                }
        }
    }
}

// MARK: - Sessions List View

struct SessionsListView: View {
    @Bindable var dataManager: DataManager

    var body: some View {
        List {
            if dataManager.authTokens.isEmpty {
                EmptySessionsView()
            } else {
                ForEach(dataManager.authTokens, id: \.id) { token in
                    SessionRowView(token: token, dataManager: dataManager)
                }
            }
        }
    }
}

// MARK: - Empty Sessions View

struct EmptySessionsView: View {
    var body: some View {
        Text("No sessions available")
            .foregroundColor(.secondary)
            .italic()
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let token: AuthToken
    @Bindable var dataManager: DataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SessionHeaderView(token: token)
            SessionTokenView(token: token)
            SessionDatesView(token: token)
            SessionDeviceView(token: token)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if token.isValid {
                Button("Revoke") {
                    try? dataManager.revokeAuthToken(token.token)
                }
                .tint(.red)
            }
        }
    }
}

// MARK: - Session Header View

struct SessionHeaderView: View {
    let token: AuthToken

    var body: some View {
        HStack {
            Text(token.user?.username ?? "Unknown User")
                .font(.headline)
            Spacer()
            StatusBadge(isActive: token.isValid)
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


// MARK: - Session Token View

struct SessionTokenView: View {
    let token: AuthToken

    var body: some View {
        Text("Token: \(String(token.token.prefix(20)))...")
            .font(.caption)
            .fontDesign(.monospaced)
            .foregroundColor(.secondary)
    }
}

// MARK: - Session Dates View

struct SessionDatesView: View {
    let token: AuthToken

    var body: some View {
        HStack {
            SessionDateLabelsView(token: token)
            Spacer()
            SessionLastUsedView(token: token)
        }
    }
}

// MARK: - Session Date Labels View

struct SessionDateLabelsView: View {
    let token: AuthToken

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Created: \(token.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Expires: \(token.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Session Last Used View

struct SessionLastUsedView: View {
    let token: AuthToken

    var body: some View {
        if let lastUsed = token.lastUsedAt {
            Text("Last used: \(lastUsed.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Session Device View

struct SessionDeviceView: View {
    let token: AuthToken

    var body: some View {
        if let deviceInfo = token.deviceInfo {
            Text("Device: \(deviceInfo)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Cleanup Button

struct CleanupButton: View {
    @Bindable var dataManager: DataManager
    @Binding var showingCleanupAlert: Bool

    private var hasExpiredTokens: Bool {
        !dataManager.authTokens.filter { $0.isExpired || $0.isRevoked }.isEmpty
    }

    var body: some View {
        Button("Cleanup") {
            showingCleanupAlert = true
        }
        .disabled(!hasExpiredTokens)
    }
}

// MARK: - Create User Sheet

struct CreateUserSheet: View {
    @Bindable var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isCreating = false
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Information")) {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                }

                Section(header: Text("Personal Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
            }
            .navigationTitle("Add User")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createUser()
                    }
                    .disabled(isCreating || !isFormValid)
                }
            }
            .disabled(isCreating)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func createUser() {
        isCreating = true

        let createRequest = CreateUserRequest(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            _ = try dataManager.createUser(request: createRequest)

            // Haptic feedback for successful creation
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            dismiss()
        } catch {
            // Haptic feedback for error
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)

            errorMessage = error.localizedDescription
            showingError = true
        }

        isCreating = false
    }
}




