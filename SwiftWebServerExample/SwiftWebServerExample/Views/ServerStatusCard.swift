//
//  ServerStatusCard.swift
//  SwiftWebServerExample
//
//  Created by Tony Li on 20/6/25.
//

import SwiftUI

struct ServerStatusCard: View {
    let title: String
    let isRunning: Bool
    let port: UInt
    @Binding var portBinding: String
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 12) {
                // Header with icon and status indicator
                HStack {
                    Image(systemName: isRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isRunning ? .green : .red)
                        .font(.title2)
                    Spacer()
                }

                // Title and status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(isRunning ? .green : .primary)
                        Text(isRunning ? "Running" : "Stopped")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                // Port information
                HStack {
                    if isRunning {
                        Text("localhost:\(String(port))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontDesign(.monospaced)
                    } else {
                        Text("Tap to start")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: 100, maxHeight: .infinity)
            .padding(16)
            .background(isRunning ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRunning ? Color.green : Color.red, lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.3), value: isRunning)
        }
        .buttonStyle(.plain)
    }
}
