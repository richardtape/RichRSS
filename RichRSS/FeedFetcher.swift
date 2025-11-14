//
//  FeedFetcher.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import Foundation

actor FeedFetcher {
    static let shared = FeedFetcher()

    private let parser = RSSFeedParser()

    func fetchFeed(from urlString: String, feedTitle: String) async throws -> [Article] {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "FeedFetcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "FeedFetcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "HTTP Error"])
        }

        do {
            let articles = try parser.parseFeed(from: data, feedTitle: feedTitle)
            return articles
        } catch {
            throw error
        }
    }

    /// Fetches all feeds and returns a dictionary of [feedId: articles]
    func refreshAllFeeds(feeds: [Feed]) async throws -> [String: [Article]] {
        var results: [String: [Article]] = [:]

        for feed in feeds {
            do {
                let articles = try await fetchFeed(from: feed.feedUrl, feedTitle: feed.title)
                results[feed.id] = articles
            } catch {
                print("⚠️ Failed to refresh feed '\(feed.title)': \(error.localizedDescription)")
                // Continue refreshing other feeds even if one fails
                results[feed.id] = []
            }
        }

        return results
    }

    /// Checks if a URL points to a valid RSS/Atom feed by examining the Content-Type header
    /// and attempting to parse it as a feed
    /// - Parameter urlString: The URL to validate
    /// - Returns: True if the URL is a valid RSS/Atom feed
    func isRSSFeed(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
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
