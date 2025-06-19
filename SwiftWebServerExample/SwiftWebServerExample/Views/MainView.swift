//
//  MainView.swift
//  SwiftWebServerExample
//
//  Main view with server console and controls
//

import SwiftUI

struct MainView: View {
    @Bindable var dataManager: DataManager
    @Bindable var webServerManager: WebServerManager
    @State private var frontendServerManager: FrontendServerManager?
    @State private var selectedTab = 0
    @State private var backendPort: String = "8080"
    @State private var frontendPort: String = "3000"
    @State private var showingCreateSampleData = false

    var body: some View {
        GeometryReader { geometry in
            // Check if we should show full screen views
            if geometry.size.width > 1000 && (selectedTab == 0 || selectedTab == 1 || selectedTab == 2) {
                // Full screen layout for all views on wide screens
                VStack(spacing: 0) {
                    // Compact header with navigation and server controls
                    VStack(spacing: 12) {
                        // Navigation Bar
                        HStack {
                            Button(action: { selectedTab = 0 }) {
                                HStack {
                                    Image(systemName: "terminal")
                                    Text("Console")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedTab == 0 ? Color.blue : Color.clear)
                                .foregroundColor(selectedTab == 0 ? .white : .primary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button(action: { selectedTab = 1 }) {
                                HStack {
                                    Image(systemName: "cylinder.split.1x2")
                                    Text("Data Management")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedTab == 1 ? Color.blue : Color.clear)
                                .foregroundColor(selectedTab == 1 ? .white : .primary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button(action: { selectedTab = 2 }) {
                                HStack {
                                    Image(systemName: "network")
                                    Text("API Testing")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedTab == 2 ? Color.blue : Color.clear)
                                .foregroundColor(selectedTab == 2 ? .white : .primary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            // Compact server status
                            if let frontendServerManager = frontendServerManager {
                                HStack(spacing: 12) {
                                    // Backend status
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(webServerManager.isRunning ? .green : .red)
                                            .frame(width: 8, height: 8)
                                        Text("API")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    // Frontend status
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(frontendServerManager.isRunning ? .green : .red)
                                            .frame(width: 8, height: 8)
                                        Text("Web")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    // Quick Actions Menu
                                    Menu {
                                        if webServerManager.isRunning {
                                            Button("Open Backend API") {
                                                if let url = URL(string: "http://localhost:\(webServerManager.currentPort)") {
                                                    UIApplication.shared.open(url)
                                                }
                                            }
                                        }

                                        if frontendServerManager.isRunning {
                                            Button("Open Frontend App") {
                                                if let url = URL(string: "http://localhost:\(frontendServerManager.currentPort)") {
                                                    UIApplication.shared.open(url)
                                                }
                                            }
                                        }

                                        if webServerManager.isRunning || frontendServerManager.isRunning {
                                            Divider()
                                        }

                                        Button("Server Settings") {
                                            // This could open a sheet with full server controls
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                    }

                    Divider()

                    // Full screen detail view
                    Group {
                        switch selectedTab {
                        case 0:
                            DualServerConsoleView(
                                backendServerManager: webServerManager,
                                frontendServerManager: frontendServerManager ?? FrontendServerManager(backendServerManager: webServerManager)
                            )
                        case 1:
                            DataManagementView(webServerManager: webServerManager, dataManager: dataManager)
                        case 2:
                            APITestingView(webServerManager: webServerManager)
                        default:
                            DualServerConsoleView(
                                backendServerManager: webServerManager,
                                frontendServerManager: frontendServerManager ?? FrontendServerManager(backendServerManager: webServerManager)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // Traditional layout with full header for narrow screens or when needed
                VStack(spacing: 0) {
                    // Dual Server Control Header
                    if let frontendServerManager = frontendServerManager {
                        DualServerControlHeader(
                            backendServerManager: webServerManager,
                            frontendServerManager: frontendServerManager,
                            dataManager: dataManager,
                            backendPort: $backendPort,
                            frontendPort: $frontendPort,
                            showingCreateSampleData: $showingCreateSampleData
                        )
                    }

                    // Narrow screen: Use TabView for phone layout
                    TabView(selection: $selectedTab) {
                        DualServerConsoleView(
                            backendServerManager: webServerManager,
                            frontendServerManager: frontendServerManager ?? FrontendServerManager(backendServerManager: webServerManager)
                        )
                        .tabItem {
                            Image(systemName: "terminal")
                            Text("Console")
                        }
                        .tag(0)

                        DataManagementView(webServerManager: webServerManager, dataManager: dataManager)
                            .tabItem {
                                Image(systemName: "cylinder.split.1x2")
                                Text("Data Management")
                            }
                            .tag(1)

                        APITestingView(webServerManager: webServerManager)
                            .tabItem {
                                Image(systemName: "network")
                                Text("API Testing")
                            }
                            .tag(2)
                    }
                }
            }
        }
        .onAppear {
            if frontendServerManager == nil {
                frontendServerManager = FrontendServerManager(backendServerManager: webServerManager)
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

// MARK: - Dual Server Control Header

struct DualServerControlHeader: View {
    @Bindable var backendServerManager: WebServerManager
    @Bindable var frontendServerManager: FrontendServerManager
    @Bindable var dataManager: DataManager
    @Binding var backendPort: String
    @Binding var frontendPort: String
    @Binding var showingCreateSampleData: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Title Row
            HStack {
                Text("SwiftWebServer Example")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Quick Actions Menu
                Menu {
                    if backendServerManager.isRunning {
                        Button("Open Backend API") {
                            if let url = URL(string: "http://localhost:\(backendServerManager.currentPort)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    if frontendServerManager.isRunning {
                        Button("Open Frontend App") {
                            if let url = URL(string: "http://localhost:\(frontendServerManager.currentPort)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    if backendServerManager.isRunning || frontendServerManager.isRunning {
                        Divider()
                    }

                    Button("Clear All Logs") {
                        backendServerManager.clearLogs()
                        frontendServerManager.clearLogs()
                    }

                    if dataManager.totalUsers == 0 {
                        Button("Create Sample Data") {
                            showingCreateSampleData = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }

            // Server Status Cards - Responsive layout
            let cardLayout = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
            LazyVGrid(columns: cardLayout, spacing: 16) {
                // Backend Server Card
                ServerStatusCard(
                    title: "Backend API",
                    isRunning: backendServerManager.isRunning,
                    port: backendServerManager.currentPort,
                    portBinding: $backendPort,
                    onToggle: {
                        if backendServerManager.isRunning {
                            backendServerManager.stopServer()
                        } else {
                            if let port = UInt(backendPort), port > 0 && port < 65536 {
                                backendServerManager.startServer(port: port)
                            } else {
                                backendServerManager.startServer()
                            }
                        }
                    }
                )

                // Frontend Server Card
                ServerStatusCard(
                    title: "Frontend App",
                    isRunning: frontendServerManager.isRunning,
                    port: frontendServerManager.currentPort,
                    portBinding: $frontendPort,
                    onToggle: {
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
                )
            }

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
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

// MARK: - Server Status Card

struct ServerStatusCard: View {
    let title: String
    let isRunning: Bool
    let port: UInt
    @Binding var portBinding: String
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Circle()
                    .fill(isRunning ? .green : .red)
                    .frame(width: 12, height: 12)
            }

            // Status
            HStack {
                Text(isRunning ? "localhost:\(port)" : "Stopped")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Controls
            HStack(spacing: 12) {
                // Port Configuration
                if !isRunning {
                    TextField("Port", text: $portBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .keyboardType(.numberPad)
                }

                Spacer()

                // Toggle Button
                Button(action: onToggle) {
                    HStack(spacing: 6) {
                        Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                        Text(isRunning ? "Stop" : "Start")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isRunning ? Color.red : Color.green)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 2, x: 0, y: 1)
    }
}
