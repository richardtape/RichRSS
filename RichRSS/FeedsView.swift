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
    @Query(sort: \Article.pubDate, order: .reverse) private var articles: [Article]
    @AppStorage("selectedThemeStyle") private var selectedThemeStyle: String = "light"
    @Binding var selectedFeedForFilter: Feed?
    @Binding var selectedTab: Int
    @State private var showAddFeed = false
    @State private var feedURL = ""
    @State private var feedTitle = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var currentTheme: Theme {
        let style: ThemeStyle
        switch selectedThemeStyle {
        case "dark":
            style = .dark
        case "sepia":
            style = .sepia
        default:
            style = .light
        }
        return Theme(style: style)
    }

    func unreadCount(for feed: Feed) -> Int {
        articles.filter { $0.feedTitle == feed.title && !$0.isRead }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with add feed button
                TabHeaderView("Feeds") {
                    AnyView(
                        Button(action: { showAddFeed = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    )
                }

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
                            Button(action: {
                                // Set the feed filter and switch to Articles tab
                                selectedFeedForFilter = feed
                                selectedTab = 0
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    // Icon column (36x36)
                                    FaviconView(faviconUrl: feed.faviconUrl, feedTitle: feed.title)
                                        .frame(width: 36, height: 36)

                                    // Feed Info
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(feed.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(feed.feedUrl)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)

                                        // Last updated + unread count
                                        let count = unreadCount(for: feed)
                                        HStack(spacing: 6) {
                                            if let lastUpdated = feed.lastUpdated {
                                                Text("Last updated: \(lastUpdated, style: .date)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }

                                            if count > 0 {
                                                Text("•")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)

                                                HStack(spacing: 2) {
                                                    Text("\(count) unread")
                                                }
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(currentTheme.pillTextColor)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(currentTheme.pillBackgroundColor)
                                                .cornerRadius(4)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete(perform: deleteFeeds)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
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

                // Fetch favicon (don't block on this)
                let siteUrl = try? extractSiteUrl(from: url)
                let faviconUrl = await FaviconFetcher.shared.fetchFaviconUrl(
                    feedImageUrl: articles.first?.imageUrl,
                    siteUrl: siteUrl
                )

                await MainActor.run {
                    // Create and insert the feed
                    let feed = Feed(
                        id: UUID().uuidString,
                        title: title,
                        feedUrl: url,
                        siteUrl: siteUrl,
                        lastUpdated: Date(),
                        faviconUrl: faviconUrl
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

    private func extractSiteUrl(from feedUrl: String) throws -> String {
        guard let url = URL(string: feedUrl) else {
            throw NSError(domain: "FeedsView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        if let scheme = url.scheme, let host = url.host {
            return "\(scheme)://\(host)"
        }

        throw NSError(domain: "FeedsView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not extract site URL"])
    }

    private func deleteFeeds(offsets: IndexSet) {
        for index in offsets {
            let feed = feeds[index]
            modelContext.delete(feed)
        }
    }
}

// MARK: - FaviconView

struct FaviconView: View {
    let faviconUrl: String?
    let feedTitle: String
    @State private var faviconImage: UIImage?
    @State private var isLoading = false

    var firstLetter: String {
        feedTitle.prefix(1).uppercased()
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.blue.opacity(0.2))

            if let faviconImage = faviconImage {
                // Display favicon image
                Image(uiImage: faviconImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                // Fallback: First letter in circle
                Text(firstLetter)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
        .task {
            await loadFavicon()
        }
    }

    private func loadFavicon() async {
        guard let faviconUrl = faviconUrl, !faviconUrl.isEmpty else {
            return
        }

        guard let url = URL(string: faviconUrl) else {
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.faviconImage = image
                }
            }
        } catch {
            print("Failed to load favicon from \(faviconUrl): \(error)")
        }
    }
}

#Preview {
    FaviconView(faviconUrl: nil, feedTitle: "BBC News")
}

#Preview {
    FeedsView()
        .modelContainer(for: Feed.self, inMemory: true)
}
