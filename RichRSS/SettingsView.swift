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
    @AppStorage("selectedThemeStyle") private var selectedThemeStyle: String = "light"
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                TabHeaderView("Settings")

                Form {
                    Section("Appearance") {
                        Picker("Theme", selection: $selectedThemeStyle) {
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                            Text("Sepia").tag("sepia")
                        }
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

    private func resetAllData() {
        // Delete all articles
        try? modelContext.delete(model: Article.self)

        // Delete all feeds
        try? modelContext.delete(model: Feed.self)

        // Reset theme to light
        selectedThemeStyle = "light"

        // Clear HTML cache
        ArticleHTMLCache.shared.clearCache()
    }
}

#Preview {
    SettingsView()
}
