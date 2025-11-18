//
//  RelativeTimeFormatter.swift
//  RichRSS
//
//  Created by Claude on 2025-11-18.
//

import Foundation

extension Date {
    /// Converts a date to a human-friendly relative time string
    /// - Returns: String like "just now", "5 minutes ago", "2 hours ago", "3 days ago", or formatted date for old dates
    func relativeTimeString() -> String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        // Future dates (shouldn't happen, but handle gracefully)
        guard interval >= 0 else {
            return "just now"
        }

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        let weeks = Int(interval / (86400 * 7))

        switch interval {
        case 0..<60:
            return "just now"
        case 60..<120:
            return "1 minute ago"
        case 120..<3600:
            return "\(minutes) minutes ago"
        case 3600..<7200:
            return "1 hour ago"
        case 7200..<86400:
            return "\(hours) hours ago"
        case 86400..<(86400 * 2):
            return "1 day ago"
        case (86400 * 2)..<(86400 * 7):
            return "\(days) days ago"
        case (86400 * 7)..<(86400 * 14):
            return "1 week ago"
        case (86400 * 14)..<(86400 * 30):
            return "\(weeks) weeks ago"
        default:
            // For anything older than ~1 month, show actual date
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }
}
