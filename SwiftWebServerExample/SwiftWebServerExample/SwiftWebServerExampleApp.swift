//
//  SwiftWebServerExampleApp.swift
//  SwiftWebServerExample
//
//  Created by Tony Li on 18/6/25.
//

import SwiftUI
import SwiftData

@main
struct SwiftWebServerExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [User.self, Post.self, Comment.self, AuthToken.self])
    }
}
