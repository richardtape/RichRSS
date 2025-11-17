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
    @AppStorage("selectedThemeStyle") private var selectedThemeStyle: String = "system"
    @State private var showResetConfirmation = false

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
        do {
            // Delete all articles first
            try modelContext.delete(model: Article.self)
            print("✅ Successfully deleted all articles")

            // Delete all feeds
            try modelContext.delete(model: Feed.self)
            print("✅ Successfully deleted all feeds")

            // Save the model context to persist deletions
            try modelContext.save()
            print("✅ Model context saved after deletion")

            // Reset theme to system default
            selectedThemeStyle = "system"

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
