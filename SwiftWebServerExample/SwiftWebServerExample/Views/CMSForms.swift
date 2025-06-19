//
//  CMSForms.swift
//  SwiftWebServerExample
//
//  CMS forms for creating and editing content
//

import SwiftUI

// MARK: - User Forms

struct CreateUserSheet: View {
    @Bindable var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("User Information") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createUser()
                    }
                    .disabled(isLoading || username.isEmpty || email.isEmpty || password.isEmpty || firstName.isEmpty || lastName.isEmpty)
                }
            }
        }
    }
    
    private func createUser() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let request = CreateUserRequest(
                    username: username,
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName
                )
                
                _ = try dataManager.createUser(request: request)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct EditUserSheet: View {
    let user: User
    @Bindable var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var email: String
    @State private var firstName: String
    @State private var lastName: String
    @State private var isActive: Bool
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    init(user: User, dataManager: DataManager) {
        self.user = user
        self.dataManager = dataManager
        self._email = State(initialValue: user.email)
        self._firstName = State(initialValue: user.firstName)
        self._lastName = State(initialValue: user.lastName)
        self._isActive = State(initialValue: user.isActive)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("User Information") {
                    HStack {
                        Text("Username")
                        Spacer()
                        Text(user.username)
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                    
                    Toggle("Active", isOn: $isActive)
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Posts")
                        Spacer()
                        Text("\(user.posts.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Comments")
                        Spacer()
                        Text("\(user.comments.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(user.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.secondary)
                    }
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateUser()
                    }
                    .disabled(isLoading || email.isEmpty || firstName.isEmpty || lastName.isEmpty)
                }
            }
        }
    }
    
    private func updateUser() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let request = UpdateUserRequest(
                    email: email != user.email ? email : nil,
                    firstName: firstName != user.firstName ? firstName : nil,
                    lastName: lastName != user.lastName ? lastName : nil,
                    isActive: isActive != user.isActive ? isActive : nil
                )
                
                try dataManager.updateUser(user, request: request)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Post Forms

struct CreatePostSheet: View {
    @Bindable var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var isPublished = false
    @State private var selectedAuthor: User?
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Post Information") {
                    TextField("Title", text: $title)
                    
                    Picker("Author", selection: $selectedAuthor) {
                        Text("Select Author").tag(nil as User?)
                        ForEach(dataManager.users, id: \.id) { user in
                            Text(user.fullName).tag(user as User?)
                        }
                    }
                    
                    Toggle("Publish immediately", isOn: $isPublished)
                }
                
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createPost()
                    }
                    .disabled(isLoading || title.isEmpty || content.isEmpty || selectedAuthor == nil)
                }
            }
        }
        .onAppear {
            // Select first user as default author
            if selectedAuthor == nil && !dataManager.users.isEmpty {
                selectedAuthor = dataManager.users.first
            }
        }
    }
    
    private func createPost() {
        guard let author = selectedAuthor else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let request = CreatePostRequest(
                    title: title,
                    content: content,
                    isPublished: isPublished
                )
                
                _ = try dataManager.createPost(request: request, author: author)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct EditPostSheet: View {
    let post: Post
    @Bindable var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var content: String
    @State private var isPublished: Bool
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    init(post: Post, dataManager: DataManager) {
        self.post = post
        self.dataManager = dataManager
        self._title = State(initialValue: post.title)
        self._content = State(initialValue: post.content)
        self._isPublished = State(initialValue: post.isPublished)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Post Information") {
                    TextField("Title", text: $title)
                    
                    HStack {
                        Text("Author")
                        Spacer()
                        Text(post.author?.fullName ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Published", isOn: $isPublished)
                }
                
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Views")
                        Spacer()
                        Text("\(post.viewCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Comments")
                        Spacer()
                        Text("\(post.comments.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Reading Time")
                        Spacer()
                        Text("\(post.readingTime) min")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.secondary)
                    }
                    
                    if let publishedAt = post.publishedAt {
                        HStack {
                            Text("Published")
                            Spacer()
                            Text(publishedAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updatePost()
                    }
                    .disabled(isLoading || title.isEmpty || content.isEmpty)
                }
            }
        }
    }
    
    private func updatePost() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let request = UpdatePostRequest(
                    title: title != post.title ? title : nil,
                    content: content != post.content ? content : nil,
                    isPublished: isPublished != post.isPublished ? isPublished : nil
                )
                
                try dataManager.updatePost(post, request: request)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
