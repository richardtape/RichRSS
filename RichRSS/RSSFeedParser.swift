//
//  RSSFeedParser.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import Foundation

class RSSFeedParser: NSObject, XMLParserDelegate {
    private var articles: [Article] = []
    private var currentElement = ""
    private var currentArticle: [String: String] = [:]
    private var feedTitle = ""
    private var feedDescription = ""
    private var parseError: Error?
    private var isAtomFeed = false

    func parseFeed(from data: Data, feedTitle: String) throws -> [Article] {
        self.articles = []
        self.feedTitle = feedTitle

        let parser = XMLParser(data: data)
        parser.delegate = self

        if parser.parse() {
            return articles
        } else if let error = parseError {
            throw error
        } else {
            throw NSError(domain: "RSSParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse RSS feed"])
        }
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        // Detect feed type
        if elementName == "feed" {
            isAtomFeed = true
        }

        // Handle both RSS <item> and Atom <entry>
        if elementName == "item" || elementName == "entry" {
            currentArticle = [:]
        }

        // Handle Atom <link> elements
        if elementName == "link" && isAtomFeed {
            if let href = attributeDict["href"] {
                let rel = attributeDict["rel"] ?? ""
                if rel == "alternate" || rel.isEmpty {
                    currentArticle["link"] = href
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "title":
            currentArticle["title", default: ""] += trimmed
        case "description":
            currentArticle["description", default: ""] += trimmed
        case "content", "content:encoded":
            currentArticle["content", default: ""] += trimmed
        case "link":
            if !isAtomFeed {  // Only parse link text for RSS (Atom uses attributes)
                currentArticle["link", default: ""] += trimmed
            }
        case "author":
            currentArticle["author", default: ""] += trimmed
        case "name":  // Atom <author><name>
            if currentElement == "name" && isAtomFeed {
                currentArticle["author", default: ""] += trimmed
            }
        case "pubDate":
            currentArticle["pubDate", default: ""] += trimmed
        case "published":  // Atom publication date
            currentArticle["pubDate", default: ""] += trimmed
        case "updated":  // Atom updated date (fallback)
            if currentArticle["pubDate"] == nil {
                currentArticle["pubDate", default: ""] += trimmed
            }
        case "guid":
            currentArticle["guid", default: ""] += trimmed
        case "id":  // Atom ID
            if isAtomFeed {
                currentArticle["guid", default: ""] += trimmed
            }
        case "channel":
            if currentElement == "title" {
                feedTitle += trimmed
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // Handle both RSS <item> and Atom <entry>
        if elementName == "item" || elementName == "entry" {
            // Create article from currentArticle dictionary
            let article = createArticle(from: currentArticle)
            articles.append(article)
            currentArticle = [:]
        }
        currentElement = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    // MARK: - Private Methods

    private func createArticle(from dict: [String: String]) -> Article {
        let id = dict["guid"] ?? dict["link"] ?? UUID().uuidString
        let title = dict["title"] ?? "Untitled"
        let summary = dict["description"] ?? ""
        let content = dict["content"]
        let link = dict["link"]
        let author = dict["author"]
        let pubDateString = dict["pubDate"] ?? ""
        let pubDate = parseRSSDate(pubDateString) ?? Date()

        return Article(
            id: id,
            title: title,
            description: summary,
            content: content,
            link: link,
            author: author,
            pubDate: pubDate,
            feedTitle: feedTitle
        )
    }

    private func parseRSSDate(_ dateString: String) -> Date? {
        // Try ISO 8601 format first (Atom uses this)
        if #available(iOS 15.0, *) {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        let formatters = [
            "EEE, dd MMM yyyy HH:mm:ss Z",  // RFC 2822 format (RSS)
            "yyyy-MM-dd'T'HH:mm:ssZ",        // ISO 8601 format
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",   // ISO 8601 with milliseconds
            "yyyy-MM-dd'T'HH:mm:ss"          // ISO 8601 without timezone
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
}
