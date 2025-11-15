//
//  FeedDiscoverer.swift
//  RichRSS
//
//  Created by Claude on 2025-11-11.
//

import Foundation

actor FeedDiscoverer {
    static let shared = FeedDiscoverer()

    /// Common paths to check for RSS feeds, in order of preference
    private let commonFeedPaths = [
        "/feed",           // WordPress default
        "/feed/",          // WordPress with trailing slash
        "/feeds/main",     // Daring Fireball and similar
        "/rss",            // Common alternative
        "/rss.xml",        // Drupal standard
        "/feed.xml",       // Generic feed location
        "/?feed=rss2",     // WordPress query parameter
        "/index.php?feed=rss2",  // WordPress with index
        "/atom.xml"        // Atom format alternative
    ]

    /// Attempts to discover an RSS feed for the given URL
    /// - Parameters:
    ///   - urlString: The website URL to search for feeds
    ///   - statusCallback: Optional callback to report discovery progress
    /// - Returns: A tuple of (feedUrl, statusMessage) if successful
    /// - Throws: An error if the URL is invalid or no feed is found
    func discoverFeed(
        from urlString: String,
        statusCallback: ((String) -> Void)? = nil
    ) async throws -> (feedUrl: String, statusMessage: String) {
        // Validate and normalize the URL
        let normalizedUrl = try normalizeURL(urlString)
        statusCallback?("Checking for RSS feed...")

        // First, check if the provided URL is already an RSS feed
        if await isRSSFeed(normalizedUrl) {
            return (feedUrl: normalizedUrl, statusMessage: "Feed found at provided URL")
        }

        // Try common feed paths
        for path in commonFeedPaths {
            let candidateUrl = normalizedUrl + path
            statusCallback?("Searching at `\(path)`...")

            if await isValidFeedUrl(candidateUrl) {
                return (feedUrl: candidateUrl, statusMessage: "Feed discovered at `\(path)`")
            }
        }

        // No feed found
        throw NSError(
            domain: "FeedDiscoverer",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "No RSS feed found. We checked common feed paths but didn't find one. Please enter the direct feed URL or verify the website has an RSS feed available."
            ]
        )
    }

    /// Normalizes a URL string to ensure it's valid and has a proper scheme
    /// - Parameter urlString: The URL string to normalize
    /// - Returns: A normalized URL string
    /// - Throws: An error if the URL is invalid
    private func normalizeURL(_ urlString: String) throws -> String {
        let trimmedUrl = urlString.trimmingCharacters(in: .whitespaces)

        // Check if URL is empty
        guard !trimmedUrl.isEmpty else {
            throw NSError(
                domain: "FeedDiscoverer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Please enter a valid URL"]
            )
        }

        // Add scheme if missing
        var urlToValidate = trimmedUrl
        if !trimmedUrl.contains("://") {
            urlToValidate = "https://" + trimmedUrl
        }

        // Validate URL structure
        guard let url = URL(string: urlToValidate), url.host != nil else {
            throw NSError(
                domain: "FeedDiscoverer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL format"]
            )
        }

        // Return base URL without trailing slash
        if let scheme = url.scheme, let host = url.host {
            return "\(scheme)://\(host)"
        }

        throw NSError(
            domain: "FeedDiscoverer",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not parse URL"]
        )
    }

    /// Checks if a URL points to a valid RSS feed by examining Content-Type
    /// - Parameter urlString: The URL to check
    /// - Returns: True if the URL is a valid RSS/Atom feed
    private func isRSSFeed(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                // Check if it's a successful response
                guard (200...299).contains(httpResponse.statusCode) else {
                    return false
                }

                // Check Content-Type header
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                    let feedContentTypes = [
                        "application/rss+xml",
                        "application/atom+xml",
                        "application/xml",
                        "text/xml"
                    ]
                    return feedContentTypes.contains { contentType.contains($0) }
                }

                // If no Content-Type, try to parse as XML to detect feed
                return true  // We'll let the parser determine if it's valid
            }
        } catch {
            return false
        }

        return false
    }

    /// Validates if a URL exists and returns a successful HTTP status
    /// Uses HEAD request for speed (no body download)
    /// - Parameter urlString: The URL to validate
    /// - Returns: True if the URL exists and is accessible
    private func isValidFeedUrl(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5  // 5-second timeout

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
        } catch {
            // If HEAD request fails, try GET with timeout
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 5

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    return (200...299).contains(httpResponse.statusCode)
                }
            } catch {
                return false
            }
        }

        return false
    }
}
