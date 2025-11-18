//
//  HTMLStripper.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import Foundation

struct HTMLStripper {
    static func stripHTML(_ html: String) -> String {
        var result = html

        // Remove script and style tags with content
        result = result.replacingOccurrences(
            of: "<script[^>]*>.*?</script>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "<style[^>]*>.*?</style>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Replace <br>, <br/>, <br /> with newlines
        result = result.replacingOccurrences(
            of: "<br\\s*/?\\s*>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        // Replace </p>, </div>, </blockquote> with newlines
        result = result.replacingOccurrences(
            of: "</(p|div|blockquote)>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        // Replace opening tags with appropriate spacing
        result = result.replacingOccurrences(
            of: "<(p|div|blockquote)[^>]*>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove all other HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]*>",
            with: "",
            options: .regularExpression
        )

        // Decode HTML entities
        result = decodeHTMLEntities(result)

        // Clean up multiple newlines
        result = result.replacingOccurrences(
            of: "\\n\\n+",
            with: "\n\n",
            options: .regularExpression
        )

        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    /// Generates an excerpt from HTML content
    /// - Takes first ~20 words of plain text
    /// - Strips HTML tags first
    /// - Returns cleaned excerpt suitable for list display
    static func generateExcerpt(from htmlContent: String, wordCount: Int = 20) -> String {
        let plainText = stripHTML(htmlContent)

        // Split into words and take the first N
        let words = plainText.split(separator: " ", omittingEmptySubsequences: true)
        let excerptWords = words.prefix(wordCount)
        let excerpt = excerptWords.joined(separator: " ")

        // Add ellipsis if there are more words
        let hasMore = words.count > wordCount
        return excerpt + (hasMore ? "…" : "")
    }

    static func decodeHTMLEntities(_ html: String) -> String {
        var result = html

        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#39;": "'",
            "&#8217;": "'",
            "&#8216;": "'",
            "&#8220;": "\u{201C}",
            "&#8221;": "\u{201D}"
        ]

        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }

        return result
    }
}
