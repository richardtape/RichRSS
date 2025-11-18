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
    private var isParsingFeedElement = false  // Track if we're in channel/feed element
    private var isParsingArticle = false  // Track if we're inside an article/item
    private var shouldExtractFeedTitle = true  // Whether to extract feed title from XML (false when user provides it)
    private var feedTitleElement: String = ""  // Track which element we're extracting feed title from

    func parseFeed(from data: Data, feedTitle: String) throws -> [Article] {
        self.articles = []
        self.feedTitle = feedTitle
        self.shouldExtractFeedTitle = false  // User provided title, don't extract from XML
        self.isParsingArticle = false
        self.isAtomFeed = false
        self.isParsingFeedElement = false
        self.feedTitleElement = ""

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

    /// Parses a feed and returns both the extracted title and articles
    /// - Parameter data: Raw XML data from the feed URL
    /// - Returns: Tuple of (feedTitle, articles)
    /// - Throws: Parsing errors
    func parseFeedWithTitle(from data: Data) throws -> (title: String, articles: [Article]) {
        self.articles = []
        self.feedTitle = ""  // Reset to extract from feed
        self.shouldExtractFeedTitle = true  // Extract feed title from XML
        self.isParsingFeedElement = false
        self.isAtomFeed = false
        self.isParsingArticle = false
        self.feedTitleElement = ""

        let parser = XMLParser(data: data)
        parser.delegate = self

        if parser.parse() {
            // Use extracted title, fall back to generic name if empty
            let decodedTitle = HTMLStripper.decodeHTMLEntities(feedTitle)
            let finalTitle = decodedTitle.isEmpty ? "Untitled Feed" : decodedTitle
            return (title: finalTitle, articles: articles)
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
            isParsingFeedElement = true
        }

        if elementName == "channel" {
            isParsingFeedElement = true
        }

        // Handle both RSS <item> and Atom <entry>
        if elementName == "item" || elementName == "entry" {
            currentArticle = [:]
            isParsingArticle = true
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
            // Check if we're parsing an article title or feed title
            if isParsingArticle {
                // Article-level title
                currentArticle["title", default: ""] += trimmed
            } else if isParsingFeedElement && shouldExtractFeedTitle && feedTitle.isEmpty {
                // Feed-level title (only capture once, if we should extract it from XML)
                feedTitle = trimmed
            }
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
            isParsingArticle = false
        }

        // End of feed element
        if elementName == "channel" || elementName == "feed" {
            isParsingFeedElement = false
        }

        currentElement = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    // MARK: - Private Methods

    private func createArticle(from dict: [String: String]) -> Article {
        let id = dict["guid"] ?? dict["link"] ?? UUID().uuidString
        let rawTitle = dict["title"] ?? "Untitled"
        let title = HTMLStripper.decodeHTMLEntities(rawTitle)
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
