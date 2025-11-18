//
//  AppSettings.swift
//  RichRSS
//
//  Created by Claude on 2025-11-18.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    var backgroundRefreshEnabled: Bool = false
    var wifiOnlyRefresh: Bool = true
    var lastBackgroundRefreshDate: Date?

    init(
        backgroundRefreshEnabled: Bool = false,
        wifiOnlyRefresh: Bool = true,
        lastBackgroundRefreshDate: Date? = nil
    ) {
        self.backgroundRefreshEnabled = backgroundRefreshEnabled
        self.wifiOnlyRefresh = wifiOnlyRefresh
        self.lastBackgroundRefreshDate = lastBackgroundRefreshDate
    }
}
