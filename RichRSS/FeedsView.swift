//
//  FeedsView.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-09.
//

import SwiftUI
import SwiftData

struct FeedsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Feed.title) private var feeds: [Feed]
    @State private var showAddFeed = false
    @State private var feedURL = ""
    @State private var feedTitle = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if feeds.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                            .opacity(0.3)
                        Text("No Feeds Yet")
                            .font(.system(size: 24, weight: .bold, design: .default))
                        Text("Add an RSS feed to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(feeds) { feed in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(feed.title)
                                    .font(.headline)
                                Text(feed.feedUrl)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                if let lastUpdated = feed.lastUpdated {
                                    Text("Last updated: \(lastUpdated, style: .date)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: deleteFeeds)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Feeds")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddFeed = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showAddFeed) {
                AddFeedView(
                    isPresented: $showAddFeed,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage,
                    onAdd: addFeed
                )
            }
        }
    }

    private func addFeed(url: String, title: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let articles = try await FeedFetcher.shared.fetchFeed(from: url, feedTitle: title)

                await MainActor.run {
                    // Create and insert the feed
                    let feed = Feed(
                        id: UUID().uuidString,
                        title: title,
                        feedUrl: url,
                        lastUpdated: Date()
                    )
                    modelContext.insert(feed)

                    // Insert articles
                    for article in articles {
                        modelContext.insert(article)
                    }

                    isLoading = false
                    showAddFeed = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func deleteFeeds(offsets: IndexSet) {
        for index in offsets {
            let feed = feeds[index]
            modelContext.delete(feed)
        }
    }
}

#Preview {
    FeedsView()
        .modelContainer(for: Feed.self, inMemory: true)
}
