//
//  RichRSSApp.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import SwiftUI
import SwiftData

@main
struct RichRSSApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Feed.self,
            Article.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
