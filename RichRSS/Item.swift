//
//  Article.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import Foundation
import SwiftData

@Model
final class Article {
    var uniqueId: String = UUID().uuidString  // Unique identifier (UUID) with default value
    var guid: String?  // Original feed guid (may not be unique)
    var title: String
    var summary: String
    var content: String?
    var link: String?
    var author: String?
    var pubDate: Date
    var feedTitle: String
    var imageUrl: String?
    var isRead: Bool = false

    init(
        id: String,
        title: String,
        description: String,
        content: String? = nil,
        link: String? = nil,
        author: String? = nil,
        pubDate: Date,
        feedTitle: String,
        imageUrl: String? = nil
    ) {
        self.uniqueId = UUID().uuidString  // Always generate a unique ID
        self.guid = id  // Store the original guid
        self.title = title
        self.summary = description
        self.content = content
        self.link = link
        self.author = author
        self.pubDate = pubDate
        self.feedTitle = feedTitle
        self.imageUrl = imageUrl
    }
}
