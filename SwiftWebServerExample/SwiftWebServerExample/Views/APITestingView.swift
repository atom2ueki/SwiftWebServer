//
//  APITestingView.swift
//  SwiftWebServerExample
//
//  API testing interface
//

import SwiftUI
import SwiftData

struct APITestingView: View {
    @Bindable var webServerManager: WebServerManager
    @State private var selectedMethod = "GET"
    @State private var endpoint = "/api/health"
    @State private var requestBody = ""
    @State private var responseStatus = ""
    @State private var responseBody = ""
    @State private var isLoading = false
    @State private var useAuth = false
    @State private var authToken = ""
    
    let httpMethods = ["GET", "POST", "PUT", "DELETE"]
    
    let commonEndpoints = [
        "/api/health",
        "/api/info",
        "/api/users",
        "/api/posts",
        "/api/auth/login",
        "/api/admin/stats"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("API Testing")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    if !webServerManager.isRunning {
                        Text("Server not running")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))

                Divider()

                // Responsive layout based on screen width
                if geometry.size.width > 800 {
                    // Wide screen: side-by-side layout
                    HStack(spacing: 0) {
                        requestPanel
                        Divider()
                        responsePanel
                    }
                } else {
                    // Narrow screen: stacked layout
                    VStack(spacing: 0) {
                        requestPanel
                        Divider()
                        responsePanel
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties for Panels

    private var requestPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                        Text("Request")
                            .font(.headline)
                    
                    // Method and Endpoint
                    HStack {
                        Picker("Method", selection: $selectedMethod) {
                            ForEach(httpMethods, id: \.self) { method in
                                Text(method).tag(method)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                        
                        TextField("Endpoint", text: $endpoint)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Common endpoints
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Endpoints:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), alignment: .leading),
                            GridItem(.flexible(), alignment: .leading)
                        ], alignment: .leading, spacing: 8) {
                            ForEach(commonEndpoints, id: \.self) { endpoint in
                                Button(endpoint) {
                                    self.endpoint = endpoint
                                    // Set appropriate method for endpoint
                                    if endpoint.contains("/auth/login") {
                                        selectedMethod = "POST"
                                        requestBody = """
                                        {
                                            "username": "johndoe",
                                            "password": "password123"
                                        }
                                        """
                                    } else if endpoint.contains("/users") && !endpoint.contains("{") {
                                        if selectedMethod == "POST" {
                                            requestBody = """
                                            {
                                                "username": "newuser",
                                                "email": "newuser@example.com",
                                                "password": "password123",
                                                "firstName": "New",
                                                "lastName": "User"
                                            }
                                            """
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // Authentication
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Use Authentication", isOn: $useAuth)
                        
                        if useAuth {
                            TextField("Bearer Token (login first to get token)", text: $authToken)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    // Request Body
                    if selectedMethod == "POST" || selectedMethod == "PUT" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Request Body (JSON):")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            TextEditor(text: $requestBody)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 120)
                                .border(Color(.separator))
                        }
                    }
                    
                    // Send Button
                    Button(action: sendRequest) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Sending..." : "Send Request")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || !webServerManager.isRunning)

                    Spacer(minLength: 20)
            }
            .padding()
        }
        .frame(minWidth: 300)
    }

    private var responsePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Response")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !responseStatus.isEmpty {
                            Text(responseStatus)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(statusColor(responseStatus))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    ScrollView {
                        Text(responseBody.isEmpty ? "No response yet" : responseBody)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding()
                    }
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
        }
        .padding()
        .frame(minWidth: 300)
    }
    
    private func sendRequest() {
        guard webServerManager.isRunning else { return }
        
        isLoading = true
        responseStatus = ""
        responseBody = ""
        
        Task {
            do {
                let baseURL = "http://localhost:\(String(webServerManager.currentPort))"
                guard let url = URL(string: baseURL + endpoint) else {
                    await MainActor.run {
                        responseStatus = "Invalid URL"
                        responseBody = "The endpoint URL is invalid"
                        isLoading = false
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = selectedMethod
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                if useAuth && !authToken.isEmpty {
                    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                }
                
                if (selectedMethod == "POST" || selectedMethod == "PUT") && !requestBody.isEmpty {
                    request.httpBody = requestBody.data(using: .utf8)
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        responseStatus = "\(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    }
                    
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data),
                       let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                       let prettyString = String(data: prettyData, encoding: .utf8) {
                        responseBody = prettyString
                    } else {
                        responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    }
                    
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    responseStatus = "Error"
                    responseBody = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        if status.hasPrefix("2") {
            return .green
        } else if status.hasPrefix("3") {
            return .blue
        } else if status.hasPrefix("4") {
            return .orange
        } else if status.hasPrefix("5") {
            return .red
        } else {
            return .gray
        }
    }
}

#Preview {
    APITestingView(webServerManager: WebServerManager(dataManager: DataManager(modelContext: ModelContext(try! ModelContainer(for: User.self, Post.self, Comment.self)))))
}
