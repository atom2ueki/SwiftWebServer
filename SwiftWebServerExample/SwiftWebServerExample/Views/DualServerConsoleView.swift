//
//  DualServerConsoleView.swift
//  SwiftWebServerExample
//
//  Console view for both frontend and backend servers
//

import SwiftUI
import SwiftData

struct DualServerConsoleView: View {
    @Bindable var backendServerManager: WebServerManager
    @Bindable var frontendServerManager: FrontendServerManager
    
    @State private var selectedServer = 0 // 0 = Backend, 1 = Frontend, 2 = Combined
    @State private var searchText = ""
    @State private var selectedLogType: LogType? = nil
    @State private var autoScroll = true
    
    var filteredBackendLogs: [LogMessage] {
        filterLogs(backendServerManager.logMessages)
    }
    
    var filteredFrontendLogs: [LogMessage] {
        filterLogs(frontendServerManager.logMessages)
    }
    
    var combinedLogs: [LogMessage] {
        let combined = (backendServerManager.logMessages + frontendServerManager.logMessages)
            .sorted { $0.timestamp > $1.timestamp }
        return filterLogs(combined)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Server Console")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Clear logs menu
                Menu {
                    Button("Clear Backend Logs") {
                        backendServerManager.clearLogs()
                    }
                    Button("Clear Frontend Logs") {
                        frontendServerManager.clearLogs()
                    }
                    Button("Clear All Logs") {
                        backendServerManager.clearLogs()
                        frontendServerManager.clearLogs()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))

            Divider()

            VStack(spacing: 0) {
                // Server Selection and Controls
                VStack(spacing: 12) {
                    // Server Selection Picker
                    Picker("Server", selection: $selectedServer) {
                        Text("Backend").tag(0)
                        Text("Frontend").tag(1)
                        Text("Combined").tag(2)
                    }
                    .pickerStyle(.segmented)
                    
                    // Search and Filter Controls
                    HStack(spacing: 12) {
                        // Search Field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search logs...", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        
                        // Log Type Filter
                        Menu {
                            Button("All Types") {
                                selectedLogType = nil
                            }
                            Divider()
                            Button("Info") {
                                selectedLogType = .info
                            }
                            Button("Success") {
                                selectedLogType = .success
                            }
                            Button("Warning") {
                                selectedLogType = .warning
                            }
                            Button("Error") {
                                selectedLogType = .error
                            }
                        } label: {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text(selectedLogType?.rawValue.capitalized ?? "All")
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        
                        // Auto-scroll Toggle
                        Button(action: { autoScroll.toggle() }) {
                            Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .foregroundColor(autoScroll ? .blue : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Log Display
                ScrollViewReader { proxy in
                    List {
                        ForEach(currentLogs, id: \.id) { log in
                            LogRowView(log: log, serverType: serverTypeForLog(log))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        
                        if currentLogs.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                
                                Text("No logs to display")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Start the server to see logs appear here")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: currentLogs.count) { _, _ in
                        if autoScroll && !currentLogs.isEmpty {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(currentLogs.first?.id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    private var currentLogs: [LogMessage] {
        switch selectedServer {
        case 0: return filteredBackendLogs
        case 1: return filteredFrontendLogs
        case 2: return combinedLogs
        default: return []
        }
    }
    
    private func filterLogs(_ logs: [LogMessage]) -> [LogMessage] {
        logs.filter { log in
            let matchesSearch = searchText.isEmpty || 
                log.message.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedLogType == nil || log.type == selectedLogType
            return matchesSearch && matchesType
        }
    }
    
    private func serverTypeForLog(_ log: LogMessage) -> String {
        if selectedServer == 2 { // Combined view
            if backendServerManager.logMessages.contains(where: { $0.id == log.id }) {
                return "Backend"
            } else {
                return "Frontend"
            }
        }
        return ""
    }
}

// MARK: - Log Row View

struct LogRowView: View {
    let log: LogMessage
    let serverType: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(log.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // Log Type Indicator
            Circle()
                .fill(log.type.swiftUIColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            // Server Type (for combined view)
            if !serverType.isEmpty {
                Text(serverType)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(serverType == "Backend" ? Color.blue : Color.orange)
                    .cornerRadius(4)
            }
            
            // Log Message
            Text(log.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
    }
}

// MARK: - LogType Extension

extension LogType {
    var swiftUIColor: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, Post.self, Comment.self, configurations: config)
    let context = ModelContext(container)

    let dataManager = DataManager(modelContext: context)
    let webServerManager = WebServerManager(dataManager: dataManager)
    let frontendServerManager = FrontendServerManager(backendServerManager: webServerManager)

    DualServerConsoleView(
        backendServerManager: webServerManager,
        frontendServerManager: frontendServerManager
    )
}
