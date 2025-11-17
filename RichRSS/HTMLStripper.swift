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

    /// Decodes HTML entities in a string using native iOS capabilities
    /// Handles all standard HTML entities including numeric character references
    /// Can be called independently to decode entities in any text
    static func decodeHTMLEntities(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        // Use NSAttributedString's HTML parsing for comprehensive entity decoding
        // This handles all named entities and numeric character references (&#8217;, &#x2019;, etc.)
        let html = "<span>\(text)</span>"

        guard let data = html.data(using: .utf8) else { return text }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }

        // Fallback to manual decoding if NSAttributedString fails
        return manualDecodeEntities(text)
    }

    /// Fallback method for decoding common HTML entities manually
    private static func manualDecodeEntities(_ text: String) -> String {
        var result = text

        // Expanded set of common HTML entities
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#39;": "'",
            "&#8217;": "'",  // Right single quotation mark (curly apostrophe)
            "&#8216;": "'",  // Left single quotation mark
            "&#8220;": """,  // Left double quotation mark
            "&#8221;": """,  // Right double quotation mark
            "&#8211;": "–",  // En dash
            "&#8212;": "—",  // Em dash
            "&#8230;": "…",  // Horizontal ellipsis
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&bull;": "•",
            "&middot;": "·",
            "&ldquo;": """,
            "&rdquo;": """,
            "&lsquo;": "'",
            "&rsquo;": "'"
        ]

        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }

        return result
    }
}
