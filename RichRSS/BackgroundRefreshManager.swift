//
//  BackgroundRefreshManager.swift
//  RichRSS
//
//  Created by Claude on 2025-11-18.
//

import Foundation
import BackgroundTasks
import SwiftData
import Network

@MainActor
class BackgroundRefreshManager: ObservableObject {
    static let shared = BackgroundRefreshManager()

    private let taskIdentifier = "com.richrss.feedrefresh"
    private let modelContainer: ModelContainer

    init() {
        // Initialize model container for background context
        let schema = Schema([Feed.self, Article.self, AppSettings.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Registration

    func registerBackgroundTasks() {
        // Register handler
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
            }
        }

        // Schedule next refresh
        scheduleNextRefresh()

        print("✅ Background refresh registered and scheduled")
    }

    func cancelBackgroundTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        print("✅ Background refresh cancelled")
    }

    // MARK: - Scheduling

    private func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)

        // iOS will decide when to actually run this based on user behavior
        // This is our "earliest" time - could be much later
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background refresh scheduled (earliest: 15 minutes from now)")
        } catch {
            print("⚠️ Could not schedule background refresh: \(error)")
        }
    }

    // MARK: - Background Task Handler

    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        print("🔄 Background refresh started")

        // Schedule the next refresh before starting work
        scheduleNextRefresh()

        // Set expiration handler
        task.expirationHandler = {
            print("⏱️ Background refresh expired (30s limit reached)")
            task.setTaskCompleted(success: false)
        }

        // Perform refresh
        let success = await performBackgroundRefresh()
        task.setTaskCompleted(success: success)
    }

    // MARK: - Refresh Logic

    private func performBackgroundRefresh() async -> Bool {
        let startTime = Date()
        let context = ModelContext(modelContainer)

        do {
            // Fetch settings
            let settingsDescriptor = FetchDescriptor<AppSettings>()
            guard let settings = try context.fetch(settingsDescriptor).first else {
                print("⚠️ No settings found for background refresh")
                return false
            }

            // Check if background refresh is enabled
            guard settings.backgroundRefreshEnabled else {
                print("ℹ️ Background refresh disabled in settings")
                return true // Not an error, just disabled
            }

            // Check Wi-Fi requirement
            if settings.wifiOnlyRefresh && !isConnectedToWiFi() {
                print("ℹ️ Skipping refresh: Wi-Fi required but not connected")
                return true // Not an error, waiting for Wi-Fi
            }

            // Fetch all feeds
            let feedsDescriptor = FetchDescriptor<Feed>()
            let feeds = try context.fetch(feedsDescriptor)

            guard !feeds.isEmpty else {
                print("ℹ️ No feeds to refresh")
                return true
            }

            // Limit feeds to refresh (30-second constraint)
            // Prioritize: favorites first, then by last updated (oldest first)
            let maxFeeds = 10
            let feedsToRefresh = feeds
                .sorted { feed1, feed2 in
                    // Favorites first
                    if feed1.isFavorite != feed2.isFavorite {
                        return feed1.isFavorite
                    }
                    // Then oldest first
                    return (feed1.lastUpdated ?? .distantPast) < (feed2.lastUpdated ?? .distantPast)
                }
                .prefix(maxFeeds)

            print("🔄 Refreshing \(feedsToRefresh.count) feeds (max: \(maxFeeds))")

            // Perform refresh with concurrency limit for background
            let feedFetcher = FeedFetcher.shared
            let results = await feedFetcher.refreshAllFeeds(feeds: Array(feedsToRefresh), maxConcurrent: 5)

            // Fetch existing articles to avoid duplicates
            let articlesDescriptor = FetchDescriptor<Article>()
            let existingArticles = try context.fetch(articlesDescriptor)
            let existingGuids = Set(existingArticles.compactMap { $0.guid })
            let existingTitles = Set(existingArticles.map { $0.title })

            // Update feeds with results
            var successCount = 0
            var newArticleCount = 0

            for result in results {
                if result.success {
                    successCount += 1

                    // Find the feed
                    if let feed = feeds.first(where: { $0.id == result.feedId }) {
                        feed.lastUpdated = result.timestamp
                        feed.lastRefreshError = nil

                        // Save new articles
                        for article in result.articles {
                            let isDuplicate: Bool
                            if let guid = article.guid {
                                isDuplicate = existingGuids.contains(guid)
                            } else {
                                isDuplicate = existingTitles.contains(article.title)
                            }

                            if !isDuplicate {
                                context.insert(article)
                                newArticleCount += 1
                            }
                        }
                    }
                } else {
                    // Store error
                    if let feed = feeds.first(where: { $0.id == result.feedId }),
                       let error = result.error {
                        feed.lastRefreshError = error.localizedDescription
                    }
                }
            }

            // Update last background refresh time
            settings.lastBackgroundRefreshDate = Date()

            // Save context
            try context.save()

            let duration = Date().timeIntervalSince(startTime)
            print("✅ Background refresh completed in \(String(format: "%.2f", duration))s")
            print("   Refreshed: \(successCount)/\(feedsToRefresh.count) feeds")
            print("   New articles: \(newArticleCount)")

            return true

        } catch {
            print("❌ Background refresh failed: \(error)")
            return false
        }
    }

    // MARK: - Network Checking

    private func isConnectedToWiFi() -> Bool {
        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        var isWiFi = false

        monitor.pathUpdateHandler = { path in
            isWiFi = path.usesInterfaceType(.wifi)
            semaphore.signal()
        }

        let queue = DispatchQueue(label: "WiFiCheck")
        monitor.start(queue: queue)

        // Wait up to 1 second for network status
        _ = semaphore.wait(timeout: .now() + 1)
        monitor.cancel()

        return isWiFi
    }
}
