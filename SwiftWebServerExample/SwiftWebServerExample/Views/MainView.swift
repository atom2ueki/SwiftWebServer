//
//  MainView.swift
//  SwiftWebServerExample
//
//  Dashboard-style main view with cards for all functionality
//

import SwiftUI

struct MainView: View {
    @Bindable var dataManager: DataManager
    @Bindable var webServerManager: WebServerManager
    @State var frontendServerManager: FrontendServerManager
    @State private var backendPort: String = "8080"
    @State private var frontendPort: String = "3000"

    // Sheet presentation states
    @State private var showingUsersManagement = false
    @State private var showingPostsManagement = false
    @State private var showingCommentsManagement = false
    @State private var showingSessionsManagement = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Dashboard Grid with Server Cards
                DashboardGrid(
                    dataManager: dataManager,
                    webServerManager: webServerManager,
                    frontendServerManager: frontendServerManager,
                    showingUsersManagement: $showingUsersManagement,
                    showingPostsManagement: $showingPostsManagement,
                    showingCommentsManagement: $showingCommentsManagement,
                    showingSessionsManagement: $showingSessionsManagement,
                    backendPort: $backendPort,
                    frontendPort: $frontendPort
                )
                .padding(.top, 8)

                // Console View integrated directly
                ConsoleView(
                    backendServerManager: webServerManager,
                    frontendServerManager: frontendServerManager
                )
                .padding(.top, 16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingUsersManagement) {
            UsersManagementSheet(dataManager: dataManager)
        }
        .sheet(isPresented: $showingPostsManagement) {
            PostsManagementSheet(dataManager: dataManager)
        }
        .sheet(isPresented: $showingCommentsManagement) {
            CommentsManagementSheet(dataManager: dataManager)
        }
        .sheet(isPresented: $showingSessionsManagement) {
            SessionsManagementSheet(dataManager: dataManager)
        }
    }
}

// MARK: - Dashboard Grid

struct DashboardGrid: View {
    @Bindable var dataManager: DataManager
    @Bindable var webServerManager: WebServerManager
    @Bindable var frontendServerManager: FrontendServerManager

    @Binding var showingUsersManagement: Bool
    @Binding var showingPostsManagement: Bool
    @Binding var showingCommentsManagement: Bool
    @Binding var showingSessionsManagement: Bool
    @Binding var backendPort: String
    @Binding var frontendPort: String

    var body: some View {
        VStack(spacing: 16) {
            // All Cards in Unified Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                // Server Status Cards
                ServerStatusCard(
                    title: "Backend",
                    isRunning: webServerManager.isRunning,
                    port: webServerManager.currentPort,
                    portBinding: $backendPort,
                    onToggle: {
                        toggleBackendServer()
                    }
                )

                ServerStatusCard(
                    title: "Frontend",
                    isRunning: frontendServerManager.isRunning,
                    port: frontendServerManager.currentPort,
                    portBinding: $frontendPort,
                    onToggle: {
                        toggleFrontendServer()
                    }
                )

                // Data Management Cards
                DashboardCard(
                    title: "Users",
                    count: dataManager.totalUsers,
                    icon: "person.3.fill",
                    color: .blue,
                    action: { showingUsersManagement = true }
                )

                DashboardCard(
                    title: "Posts",
                    count: dataManager.totalPosts,
                    icon: "doc.text.fill",
                    color: .green,
                    action: { showingPostsManagement = true }
                )

                DashboardCard(
                    title: "Comments",
                    count: dataManager.totalComments,
                    icon: "bubble.left.fill",
                    color: .orange,
                    action: { showingCommentsManagement = true }
                )

                DashboardCard(
                    title: "Sessions",
                    count: dataManager.activeAuthTokens,
                    icon: "key.fill",
                    color: .purple,
                    action: { showingSessionsManagement = true }
                )
            }
        }
    }

    // MARK: - Server Control Methods

    private func toggleBackendServer() {
        if webServerManager.isRunning {
            webServerManager.stopServer()
        } else {
            if let port = UInt(backendPort), port > 0 && port < 65536 {
                webServerManager.startServer(port: port)
            } else {
                webServerManager.startServer()
            }
        }
    }

    private func toggleFrontendServer() {
        if frontendServerManager.isRunning {
            frontendServerManager.stopServer()
        } else {
            if let port = UInt(frontendPort), port > 0 && port < 65536 {
                frontendServerManager.startServer(port: port)
            } else {
                frontendServerManager.startServer()
            }
        }
    }
}

// MARK: - Dashboard Card

struct DashboardCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
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
                            .foregroundColor(.primary)
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: 100, maxHeight: .infinity)
            .padding(16)
            .background(.card)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
