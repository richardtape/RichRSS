//
//  FeedFetcher.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import Foundation

/// Result of refreshing a single feed
struct FeedRefreshResult {
    let feedId: String
    let articles: [Article]
    let success: Bool
    let error: Error?
    let timestamp: Date
}

actor FeedFetcher {
    static let shared = FeedFetcher()

    private let parser = RSSFeedParser()

    /// Upgrades http:// URLs to https://
    private func upgradeToHttps(_ urlString: String) -> String {
        if urlString.lowercased().starts(with: "http://") {
            return "https://" + urlString.dropFirst(7)
        }
        return urlString
    }

    func fetchFeed(from urlString: String, feedTitle: String) async throws -> (articles: [Article], actualUrl: String) {
        let upgradeUrlString = upgradeToHttps(urlString)
        guard let url = URL(string: upgradeUrlString) else {
            throw NSError(domain: "FeedFetcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "FeedFetcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "HTTP Error"])
        }

        do {
            let articles = try parser.parseFeed(from: data, feedTitle: feedTitle)
            return (articles: articles, actualUrl: upgradeUrlString)
        } catch {
            throw error
        }
    }

    /// Refreshes a single feed and returns the result with success/failure info
    func refreshFeed(_ feed: Feed) async -> FeedRefreshResult {
        do {
            let (articles, _) = try await fetchFeed(from: feed.feedUrl, feedTitle: feed.title)
            return FeedRefreshResult(
                feedId: feed.id,
                articles: articles,
                success: true,
                error: nil,
                timestamp: Date()
            )
        } catch {
            print("⚠️ Failed to refresh feed '\(feed.title)': \(error.localizedDescription)")
            return FeedRefreshResult(
                feedId: feed.id,
                articles: [],
                success: false,
                error: error,
                timestamp: Date()
            )
        }
    }

    /// Refreshes all feeds and returns results with per-feed success/failure info
    /// - Parameter feeds: Array of feeds to refresh
    /// - Returns: Array of FeedRefreshResult with success status and timestamp for each feed
    func refreshAllFeeds(feeds: [Feed]) async -> [FeedRefreshResult] {
        var results: [FeedRefreshResult] = []

        for feed in feeds {
            let result = await refreshFeed(feed)
            results.append(result)
        }

        return results
    }

    /// Legacy method for backwards compatibility - converts new result format to old dictionary format
    /// - Parameter feeds: Array of feeds to refresh
    /// - Returns: Dictionary mapping feed IDs to articles (empty array on failure)
    @available(*, deprecated, message: "Use refreshAllFeeds(feeds:) -> [FeedRefreshResult] instead")
    func refreshAllFeedsLegacy(feeds: [Feed]) async -> [String: [Article]] {
        let results = await refreshAllFeeds(feeds: feeds)
        var dictionary: [String: [Article]] = [:]

        for result in results {
            dictionary[result.feedId] = result.articles
        }

        return dictionary
    }

    /// Fetches a feed and extracts its title from the feed's metadata
    /// - Parameter urlString: URL to the RSS/Atom feed
    /// - Returns: Tuple of (feedTitle, articles) extracted from the feed
    /// - Throws: Network or parsing errors
    func fetchFeedWithTitle(from urlString: String) async throws -> (title: String, articles: [Article], actualUrl: String) {
        let upgradeUrlString = upgradeToHttps(urlString)
        guard let url = URL(string: upgradeUrlString) else {
            throw NSError(domain: "FeedFetcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "FeedFetcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "HTTP Error"])
        }

        do {
            let (title, articles) = try parser.parseFeedWithTitle(from: data)
            return (title: title, articles: articles, actualUrl: upgradeUrlString)
        } catch {
            throw error
        }
    }

    /// Checks if a URL points to a valid RSS/Atom feed by examining the Content-Type header
    /// and attempting to parse it as a feed
    /// - Parameter urlString: The URL to validate
    /// - Returns: True if the URL is a valid RSS/Atom feed
    func isRSSFeed(_ urlString: String) async -> Bool {
        let upgradeUrlString = upgradeToHttps(urlString)
        guard let url = URL(string: upgradeUrlString) else {
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                // Check if it's a successful response
                guard (200...299).contains(httpResponse.statusCode) else {
                    return false
                }

                // Check Content-Type header for feed types
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                    let feedContentTypes = [
                        "application/rss+xml",
                        "application/atom+xml",
                        "application/xml",
                        "text/xml"
                    ]
                    if feedContentTypes.contains(where: { contentType.contains($0) }) {
                        return true
                    }
                }

                // If no explicit feed Content-Type, try parsing to detect feed
                do {
                    _ = try parser.parseFeed(from: data, feedTitle: "")
                    return true
                } catch {
                    return false
                }
            }
        } catch {
            return false
        }

        return false
    }
}
