//
//  AppStartupManager.swift
//  RichRSS
//
//  Created by Claude on 2025-11-13.
//

import Foundation
import SwiftData

/// Manages app startup state and background feed refreshing
@Observable
final class AppStartupManager {
    var isLoading = true
    var statusMessage: String = "Preparing app..."

    private let modelContainer: ModelContainer

    /// Initializes the startup manager and begins loading sequence
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        Task {
            await startupSequence()
        }
    }

    /// Executes the startup sequence: fetch feeds and refresh them
    private func startupSequence() async {
        do {
            // Step 1: Prepare
            await updateStatus("Loading feeds...")

            // Get the model container from the environment
            let feeds = try await fetchAllFeeds()

            if feeds.isEmpty {
                // No feeds to refresh
                await finishLoading()
                return
            }

            // Step 2: Refresh all feeds
            await updateStatus("Refreshing feeds...")
            let refreshResults = try await FeedFetcher.shared.refreshAllFeeds(feeds: feeds)

            // Step 3: Insert articles in main thread
            await updateStatus("Updating articles...")
            try await insertNewArticles(from: refreshResults)

            await finishLoading()

        } catch {
            print("⚠️ Startup error: \(error.localizedDescription)")
            await finishLoading()
        }
    }

    /// Fetches all feeds from the database
    private func fetchAllFeeds() async throws -> [Feed] {
        return await MainActor.run {
            do {
                let context = ModelContext(self.modelContainer)
                var descriptor = FetchDescriptor<Feed>()
                descriptor.sortBy = [SortDescriptor(\Feed.title)]
                return try context.fetch(descriptor)
            } catch {
                print("⚠️ Failed to fetch feeds: \(error.localizedDescription)")
                return []
            }
        }
    }

    /// Inserts new articles from refresh results
    private func insertNewArticles(from refreshResults: [String: [Article]]) async throws {
        await MainActor.run {
            do {
                let context = ModelContext(self.modelContainer)

                // Fetch existing article GUIDs to avoid duplicates
                let descriptor = FetchDescriptor<Article>()
                let existingArticles = try context.fetch(descriptor)
                let existingGuids = Set(existingArticles.compactMap { $0.guid })
                let existingTitles = Set(existingArticles.map { $0.title })

                // Insert new articles
                for (_, articles) in refreshResults {
                    for newArticle in articles {
                        // Check by guid first, then by title
                        let isDuplicate: Bool
                        if let guid = newArticle.guid {
                            isDuplicate = existingGuids.contains(guid)
                        } else {
                            isDuplicate = existingTitles.contains(newArticle.title)
                        }

                        if !isDuplicate {
                            context.insert(newArticle)
                        }
                    }
                }

                try context.save()
            } catch {
                print("⚠️ Failed to insert articles: \(error.localizedDescription)")
            }
        }
    }

    /// Updates the status message on the main thread
    private func updateStatus(_ message: String) async {
        await MainActor.run {
            self.statusMessage = message
        }
    }

    /// Finishes loading and dismisses the loading screen
    private func finishLoading() async {
        await MainActor.run {
            self.statusMessage = "Ready"
            self.isLoading = false
        }
    }
}
