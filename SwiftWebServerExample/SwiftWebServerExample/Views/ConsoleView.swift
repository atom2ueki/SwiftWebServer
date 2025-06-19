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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Server Console")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Copy logs button
                Button(action: copyAllLogs) {
                    Image(systemName: "doc.on.doc")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))

            Divider()

            // Console Content
            ScrollView {
                LazyVStack(spacing: 0) {
                    let allLogs = getAllLogs()
                    
                    if allLogs.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "terminal")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No logs to display")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Start the servers to see logs appear here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                    } else {
                        ForEach(allLogs, id: \.id) { logMessage in
                            LogMessageRow(logMessage: logMessage)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
        .background(
            Rectangle()
                .fill(backgroundColorForLogType(logMessage.type))
                .opacity(0.1)
        )
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
    
    private func backgroundColorForLogType(_ type: LogType) -> Color {
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
