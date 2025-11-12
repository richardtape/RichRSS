//
//  FaviconFetcher.swift
//  RichRSS
//
//  Created by Claude on 2025-11-11.
//

import Foundation

actor FaviconFetcher {
    static let shared = FaviconFetcher()

    private let cache = NSCache<NSString, NSData>()

    /// Fetches favicon for a feed, trying multiple sources
    /// 1. Feed's own image URL (if available from RSS)
    /// 2. Common favicon locations (/favicon.ico)
    func fetchFaviconUrl(feedImageUrl: String?, siteUrl: String?) async -> String? {
        // Try feed's own image first
        if let feedImageUrl = feedImageUrl, !feedImageUrl.isEmpty {
            if isValidUrl(feedImageUrl) {
                return feedImageUrl
            }
        }

        // Try to fetch from site URL
        if let siteUrl = siteUrl, !siteUrl.isEmpty {
            return await tryCommonFaviconLocations(siteUrl: siteUrl)
        }

        return nil
    }

    /// Try common favicon locations
    private func tryCommonFaviconLocations(siteUrl: String) async -> String? {
        guard let url = URL(string: siteUrl) else {
            return nil
        }

        guard let host = url.host else {
            return nil
        }

        let baseUrl = "\(url.scheme ?? "https")://\(host)"

        // Try common favicon paths
        let faviconPaths = [
            "/favicon.ico",
            "/apple-touch-icon.png",
            "/apple-touch-icon-precomposed.png",
        ]

        for path in faviconPaths {
            let faviconUrl = baseUrl + path
            if await isFaviconAccessible(faviconUrl) {
                return faviconUrl
            }
        }

        return nil
    }

    /// Check if a favicon URL is accessible by making a HEAD request
    private func isFaviconAccessible(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
        } catch {
            return false
        }

        return false
    }

    private func isValidUrl(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        return url.scheme != nil && url.host != nil
    }
}
