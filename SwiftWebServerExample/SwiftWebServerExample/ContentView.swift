//
//  ContentView.swift
//  SwiftWebServerExample
//
//  Created by Tony Li on 18/6/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dataManager: DataManager?
    @State private var webServerManager: WebServerManager?

    var body: some View {
        if let dataManager = dataManager, let webServerManager = webServerManager {
            MainView(dataManager: dataManager, webServerManager: webServerManager)
        } else {
            VStack {
                ProgressView("Initializing...")
                    .progressViewStyle(CircularProgressViewStyle())
                Text("Setting up data and web server...")
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                setupManagers()
            }
        }
    }

    private func setupManagers() {
        let dataManager = DataManager(modelContext: modelContext)
        let webServerManager = WebServerManager(dataManager: dataManager)

        self.dataManager = dataManager
        self.webServerManager = webServerManager
    }
}
