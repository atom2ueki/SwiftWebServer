//
//  MainView.swift
//  SwiftWebServerExample
//
//  Main view with server management and controls
//

import SwiftUI

struct MainView: View {
    @Bindable var dataManager: DataManager
    @Bindable var webServerManager: WebServerManager
    @State var frontendServerManager: FrontendServerManager
    @State private var selectedTab = 0
    @State private var backendPort: String = "8080"
    @State private var frontendPort: String = "3000"

    var body: some View {
        GeometryReader { geometry in
            
            VStack(spacing: 0) {
                // Dual Server Control Header
                ServersControlHeader(
                    backendServerManager: webServerManager,
                    frontendServerManager: frontendServerManager,
                    dataManager: dataManager,
                    backendPort: $backendPort,
                    frontendPort: $frontendPort
                )

                // Narrow screen: Use TabView for phone layout
                TabView(selection: $selectedTab) {
                    ConsoleView(
                        backendServerManager: webServerManager,
                        frontendServerManager: frontendServerManager
                    )
                    .tabItem {
                        Image(systemName: "terminal")
                        Text("Console")
                    }
                    .tag(0)

                    DataManagementView(
                        webServerManager: webServerManager,
                        dataManager: dataManager
                    )
                    .tabItem {
                        Image(systemName: "cylinder.split.1x2")
                        Text("Data Management")
                    }
                    .tag(1)

                    APITestingView(
                        webServerManager: webServerManager
                    )
                    .tabItem {
                        Image(systemName: "network")
                        Text("API Testing")
                    }
                    .tag(2)
                }
            }
        }
    }
}

// MARK: - Servers Control Header

struct ServersControlHeader: View {
    @Bindable var backendServerManager: WebServerManager
    @Bindable var frontendServerManager: FrontendServerManager
    @Bindable var dataManager: DataManager
    @Binding var backendPort: String
    @Binding var frontendPort: String

    var body: some View {
        VStack(spacing: 16) {
            
            // Use ViewThatFits or conditional layout based on screen size
            ViewThatFits {
                // Horizontal layout (preferred)
                HStack(spacing: 16) {
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
                
                // Vertical layout (fallback)
                VStack(spacing: 16) {
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
        }
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemBackground))
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
                Text(isRunning ? "localhost:\(String(port))" : "Stopped")
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
