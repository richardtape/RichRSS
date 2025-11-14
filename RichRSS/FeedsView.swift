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
    @State private var articleCount = 0
    @State private var discoveredArticles: [Article] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var discoveryStatus: String?
    @State private var addFeedViewReference: AddFeedView?

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
                                .font(.system(size: 24, weight: .semibold))
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
                    discoveryStatus: $discoveryStatus,
                    initialFeedURL: $feedURL,
                    initialFeedTitle: $feedTitle,
                    initialArticleCount: $articleCount,
                    discoveredArticles: $discoveredArticles,
                    onAdd: addFeed
                )
            }
        }
    }

    private func addFeed(url: String, title: String) {
        isLoading = true
        errorMessage = nil
        discoveryStatus = nil

        Task {
            do {
                // If title is empty, we're in discovery mode (user clicked "Search")
                // Otherwise, we're in confirmation mode (user confirmed feed details)
                let isConfirmationMode = !title.isEmpty

                if isConfirmationMode {
                    // User confirmed the feed with title - proceed directly to adding
                    await addConfirmedFeed(url: url, title: title)
                } else {
                    // Discovery mode - find the feed and get its title
                    await discoverAndShowConfirmation(url: url)
                }
            }
        }
    }

    /// Discovers a feed URL and fetches its details for confirmation
    /// This will show the feed details but won't add it to the database yet
    private func discoverAndShowConfirmation(url: String) async {
        do {
            var finalFeedUrl = url

            // Check if this is already an RSS feed
            discoveryStatus = "Checking for RSS feed..."
            let isRSSFeed = await FeedFetcher.shared.isRSSFeed(url)

            if !isRSSFeed {
                // Not a feed, try to discover one
                discoveryStatus = "Searching for feed..."
                let discovered = try await FeedDiscoverer.shared.discoverFeed(from: url) { status in
                    DispatchQueue.main.async {
                        self.discoveryStatus = status
                    }
                }
                finalFeedUrl = discovered.feedUrl
            }

            // Fetch the feed to get its title and article count
            discoveryStatus = "Fetching feed information..."
            let (foundTitle, articles) = try await FeedFetcher.shared.fetchFeedWithTitle(from: finalFeedUrl)

            // Save discovered info and transition to confirmation screen
            await MainActor.run {
                self.feedURL = finalFeedUrl
                self.feedTitle = foundTitle
                self.articleCount = articles.count
                self.discoveredArticles = articles
                self.isLoading = false
                self.discoveryStatus = nil
                // The AddFeedView will detect these updates via bindings and show confirmation screen
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                discoveryStatus = nil
            }
        }
    }

    /// Adds a confirmed feed with URL and title
    private func addConfirmedFeed(url: String, title: String) async {
        do {
            // Discover feed URL if needed
            var finalFeedUrl = url
            discoveryStatus = "Checking for RSS feed..."
            let isRSSFeed = await FeedFetcher.shared.isRSSFeed(url)

            if !isRSSFeed {
                discoveryStatus = "Searching for feed..."
                let discovered = try await FeedDiscoverer.shared.discoverFeed(from: url) { status in
                    DispatchQueue.main.async {
                        self.discoveryStatus = status
                    }
                }
                finalFeedUrl = discovered.feedUrl
            }

            // Fetch the feed with user-confirmed title
            discoveryStatus = "Fetching feed..."
            let articles = try await FeedFetcher.shared.fetchFeed(from: finalFeedUrl, feedTitle: title)

            // Fetch favicon (don't block on this)
            let siteUrl = try? extractSiteUrl(from: finalFeedUrl)
            let faviconUrl = await FaviconFetcher.shared.fetchFaviconUrl(
                feedImageUrl: articles.first?.imageUrl,
                siteUrl: siteUrl
            )

            await MainActor.run {
                // Create and insert the feed
                let feed = Feed(
                    id: UUID().uuidString,
                    title: title,
                    feedUrl: finalFeedUrl,
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
                discoveryStatus = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                discoveryStatus = nil
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

            // Delete all articles associated with this feed
            let articlesToDelete = articles.filter { $0.feedTitle == feed.title }
            for article in articlesToDelete {
                modelContext.delete(article)
            }

            // Delete the feed itself
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
    @Previewable @State var selectedFeedForFilter: Feed? = nil
    @Previewable @State var selectedTab = 1
    return FeedsView(
        selectedFeedForFilter: $selectedFeedForFilter,
        selectedTab: $selectedTab
    )
    .modelContainer(for: Feed.self, inMemory: true)
}
