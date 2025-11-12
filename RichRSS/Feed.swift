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

    init(
        id: String,
        title: String,
        feedUrl: String,
        siteUrl: String? = nil,
        feedSummary: String? = nil,
        lastUpdated: Date? = nil,
        faviconUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.feedUrl = feedUrl
        self.siteUrl = siteUrl
        self.feedSummary = feedSummary
        self.lastUpdated = lastUpdated
        self.faviconUrl = faviconUrl
    }
}
