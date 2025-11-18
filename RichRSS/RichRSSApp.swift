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
            AppSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var startupManager: AppStartupManager?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(startupManager ?? AppStartupManager(modelContainer: sharedModelContainer))
                .onAppear {
                    if startupManager == nil {
                        startupManager = AppStartupManager(modelContainer: sharedModelContainer)
                    }
                    checkAndRegisterBackgroundRefresh()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Checks settings and registers background refresh if enabled
    private func checkAndRegisterBackgroundRefresh() {
        Task { @MainActor in
            let context = ModelContext(sharedModelContainer)
            let descriptor = FetchDescriptor<AppSettings>()

            if let settings = try? context.fetch(descriptor).first,
               settings.backgroundRefreshEnabled {
                BackgroundRefreshManager.shared.registerBackgroundTasks()
            }
        }
    }
}
