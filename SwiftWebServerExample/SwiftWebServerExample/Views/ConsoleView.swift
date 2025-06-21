//
//  ConsoleView.swift
//  SwiftWebServerExample
//
//  Console view for displaying server logs
//

import SwiftUI
import UIKit

struct ConsoleView: View {
    @Bindable var backendServerManager: WebServerManager
    @Bindable var frontendServerManager: FrontendServerManager
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🪵 Server Console")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                HStack(spacing: 12) {
                    // Clear logs button
                    Button(action: { showingDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }

                    // Copy logs button
                    Button(action: copyAllLogsWithHaptic) {
                        Image(systemName: "doc.on.doc")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.card)

            Divider()

            // Console Content
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    let allLogs = getAllLogs()

                    if allLogs.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "terminal")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)

                            Text("No logs to display")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("Start the servers to see logs appear here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    } else {
                        ForEach(allLogs.prefix(100), id: \.id) { logMessage in
                            LogMessageRow(logMessage: logMessage)
                        }

                        if allLogs.count > 100 {
                            Text("... and \(allLogs.count - 100) more entries")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .frame(maxHeight: 500) // Increased height for better visibility
            .background(.console)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .alert("Clear All Logs", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllLogsWithHaptic()
            }
        } message: {
            Text("Are you sure you want to clear all console logs? This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAllLogs() -> [LogMessage] {
        let backendLogs = backendServerManager.logMessages.map { log in
            LogMessage(
                timestamp: log.timestamp,
                message: "[API] \(log.message)",
                type: log.type
            )
        }

        let frontendLogs = frontendServerManager.logMessages.map { log in
            LogMessage(
                timestamp: log.timestamp,
                message: "[Web] \(log.message)",
                type: log.type
            )
        }

        return (backendLogs + frontendLogs).sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    private func copyAllLogs() {
        let allLogsText = getAllLogs()
            .map { "[\($0.timestamp.formatted(date: .omitted, time: .standard))] \($0.message)" }
            .joined(separator: "\n")

        UIPasteboard.general.string = allLogsText
    }

    private func copyAllLogsWithHaptic() {
        // Light haptic feedback for copy action
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        copyAllLogs()
    }

    private func clearAllLogs() {
        backendServerManager.clearLogs()
        frontendServerManager.clearLogs()
    }

    private func clearAllLogsWithHaptic() {
        // Strong haptic feedback for delete action
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        clearAllLogs()
    }
}

// MARK: - Log Message Row Component

struct LogMessageRow: View {
    let logMessage: LogMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(logMessage.timestamp.formatted(date: .omitted, time: .standard))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // Type indicator
            Circle()
                .fill(colorForLogType(logMessage.type))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            // Message
            Text(logMessage.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(.clear)
    }
    
    private func colorForLogType(_ type: LogType) -> Color {
        switch type {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
