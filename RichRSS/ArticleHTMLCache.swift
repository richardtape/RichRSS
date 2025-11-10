//
//  ArticleHTMLCache.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-09.
//

import Foundation

class ArticleHTMLCache {
    static let shared = ArticleHTMLCache()

    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL = {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("ArticleHTMLCache", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)

        return cacheDir
    }()

    func getCachedHTML(for article: Article) -> String? {
        let filename = getCacheFilename(for: article)
        let filePath = cacheDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: filePath.path) {
            do {
                let html = try String(contentsOf: filePath, encoding: .utf8)
                return html
            } catch {
                return nil
            }
        }

        return nil
    }

    func cacheHTML(_ html: String, for article: Article) {
        let filename = getCacheFilename(for: article)
        let filePath = cacheDirectory.appendingPathComponent(filename)

        do {
            try html.write(to: filePath, atomically: true, encoding: .utf8)
        } catch {
            // Silently fail - caching is nice-to-have
        }
    }

    func clearCache() {
        print("🗑️ Clearing article HTML cache...")
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil, options: [])
            for file in files {
                try fileManager.removeItem(at: file)
            }
            print("✅ Cache cleared")
        } catch {
            print("❌ Cache clear error: \(error)")
        }
    }

    private func getCacheFilename(for article: Article) -> String {
        // Use uniqueId as the cache key
        return "\(article.uniqueId).html"
    }
}
