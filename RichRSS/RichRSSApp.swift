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

    init() {
        // Register background task handlers BEFORE app finishes launching
        // This must happen in init(), not in onAppear or later
        BackgroundRefreshManager.shared.registerBackgroundTaskHandlers()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(startupManager ?? AppStartupManager(modelContainer: sharedModelContainer))
                .trackDynamicTypeScale()  // Enable Dynamic Type tracking throughout the app
                .onAppear {
                    if startupManager == nil {
                        startupManager = AppStartupManager(modelContainer: sharedModelContainer)
                    }
                    checkAndScheduleBackgroundRefresh()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Checks settings and schedules background refresh if enabled
    private func checkAndScheduleBackgroundRefresh() {
        Task { @MainActor in
            let context = ModelContext(sharedModelContainer)
            let descriptor = FetchDescriptor<AppSettings>()

            if let settings = try? context.fetch(descriptor).first,
               settings.backgroundRefreshEnabled {
                BackgroundRefreshManager.shared.scheduleBackgroundRefresh()
            }
        }
    }
}
