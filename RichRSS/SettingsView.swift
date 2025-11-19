//
//  SettingsView.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-09.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsObjects: [AppSettings]
    @AppStorage("selectedThemeStyle") private var selectedThemeStyle: String = "system"
    @AppStorage("inAppFontSizeMultiplier") private var inAppFontSizeMultiplier: Double = 1.0
    @State private var showResetConfirmation = false

    // Get or create settings
    private var settings: AppSettings {
        if let existing = settingsObjects.first {
            return existing
        } else {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                TabHeaderView("Settings")

                Form {
                    Section("Appearance") {
                        Picker("Theme", selection: $selectedThemeStyle) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                            Text("Sepia").tag("sepia")
                        }
                    }

                    Section {
                        Picker("App Text Size", selection: $inAppFontSizeMultiplier) {
                            Text("Smaller").tag(0.85)
                            Text("Default").tag(1.0)
                            Text("Larger").tag(1.15)
                            Text("Largest").tag(1.3)
                        }
                    } header: {
                        Text("Text Size")
                    } footer: {
                        Text("Adjusts text size in RichRSS. This combines with your iOS system text size setting (Settings → Display & Brightness → Text Size).")
                            .appFont(.caption)
                    }

                    Section {
                        Toggle(isOn: Binding(
                            get: { settings.backgroundRefreshEnabled },
                            set: { newValue in
                                settings.backgroundRefreshEnabled = newValue
                                handleBackgroundRefreshToggle(enabled: newValue)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Background Refresh")
                                    .appFont(.body)
                                Text("Automatically refresh feeds in the background")
                                    .appFont(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if settings.backgroundRefreshEnabled {
                            Toggle(isOn: Binding(
                                get: { settings.wifiOnlyRefresh },
                                set: { newValue in
                                    settings.wifiOnlyRefresh = newValue
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Wi-Fi Only")
                                        .appFont(.body)
                                    Text("Refresh feeds only when connected to Wi-Fi")
                                        .appFont(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .disabled(!settings.backgroundRefreshEnabled)

                            if let lastRefresh = settings.lastBackgroundRefreshDate {
                                HStack {
                                    Text("Last Background Refresh")
                                        .appFont(.caption)
                                    Spacer()
                                    Text(lastRefresh.relativeTimeString())
                                        .appFont(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Feed Refresh")
                    } footer: {
                        Text("Background refresh requires iOS permission and may not occur if Low Power Mode is enabled or battery is low. iOS determines the optimal refresh schedule based on your usage patterns.")
                            .appFont(.caption)
                    }

                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0")
                                .foregroundColor(.gray)
                        }
                    }

                    Section("Data") {
                        Button(role: .destructive, action: { showResetConfirmation = true }) {
                            Label("Remove Everything", systemImage: "trash.fill")
                        }
                    }
                }
                .alert("Remove Everything?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove All Data", role: .destructive) {
                    resetAllData()
                }
                } message: {
                    Text("This will delete all feeds, articles, and reset your settings. This cannot be undone.")
                }
            }
        }
    }

    private func handleBackgroundRefreshToggle(enabled: Bool) {
        if enabled {
            print("ℹ️ Background refresh enabled")
            BackgroundRefreshManager.shared.scheduleBackgroundRefresh()
        } else {
            print("ℹ️ Background refresh disabled")
            BackgroundRefreshManager.shared.cancelBackgroundTasks()
        }
    }

    private func resetAllData() {
        do {
            // Delete all articles first
            try modelContext.delete(model: Article.self)
            print("✅ Successfully deleted all articles")

            // Delete all feeds
            try modelContext.delete(model: Feed.self)
            print("✅ Successfully deleted all feeds")

            // Delete all settings
            try modelContext.delete(model: AppSettings.self)
            print("✅ Successfully deleted all settings")

            // Save the model context to persist deletions
            try modelContext.save()
            print("✅ Model context saved after deletion")

            // Reset theme to system default
            selectedThemeStyle = "system"

            // Reset text size to default
            inAppFontSizeMultiplier = 1.0

            // Clear HTML cache
            ArticleHTMLCache.shared.clearCache()
            print("✅ HTML cache cleared")

            print("✅ All data removal complete")
        } catch {
            print("❌ Error during data deletion: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SettingsView()
}
