//
//  Feed.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import Foundation
import SwiftData

@Model
final class Feed {
    var id: String
    var title: String
    var feedUrl: String
    var siteUrl: String?
    var feedSummary: String?
    var lastUpdated: Date?
    var faviconUrl: String?
    var isFavorite: Bool = false
    var lastRefreshError: String?  // Persisted error message from last refresh attempt

    // Transient state (not persisted to database)
    @Transient var isRefreshing: Bool = false

    init(
        id: String,
        title: String,
        feedUrl: String,
        siteUrl: String? = nil,
        feedSummary: String? = nil,
        lastUpdated: Date? = nil,
        faviconUrl: String? = nil,
        isFavorite: Bool = false,
        lastRefreshError: String? = nil
    ) {
        self.id = id
        self.title = title
        self.feedUrl = feedUrl
        self.siteUrl = siteUrl
        self.feedSummary = feedSummary
        self.lastUpdated = lastUpdated
        self.faviconUrl = faviconUrl
        self.isFavorite = isFavorite
        self.lastRefreshError = lastRefreshError
    }
}
