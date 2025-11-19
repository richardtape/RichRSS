//
//  ContentView.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppStartupManager.self) private var startupManager
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var selectedTab = 0
    @AppStorage("selectedThemeStyle") private var selectedThemeStyle: String = "system"
    @State private var selectedArticle: Article?
    @State private var showingArticle = false
    @State private var selectedFeedForFilter: Feed? = nil

    var currentTheme: Theme {
        let style: ThemeStyle
        switch selectedThemeStyle {
        case "system":
            // Use system color scheme
            style = systemColorScheme == .dark ? .dark : .light
        case "dark":
            style = .dark
        case "sepia":
            style = .sepia
        default:
            style = .light
        }
        return Theme(style: style)
    }

    var body: some View {
        ZStack {
            // Background color for the entire app
            currentTheme.backgroundColor
                .ignoresSafeArea()

            if startupManager.isLoading {
                // Show loading screen during startup
                LoadingView(theme: currentTheme, statusMessage: startupManager.statusMessage)
            } else if showingArticle, let article = selectedArticle {
                // Full-screen article view without tab bar
                ArticleDetailView(
                    article: article,
                    theme: currentTheme,
                    selectedArticle: $selectedArticle,
                    showingArticle: $showingArticle
                )
            } else {
                // Tab view with tab bar
                TabView(selection: $selectedTab) {
                    // Articles Tab
                    ArticlesListViewWithSelection(
                        theme: currentTheme,
                        selectedArticle: $selectedArticle,
                        showingArticle: $showingArticle,
                        selectedFeedForFilter: $selectedFeedForFilter
                    )
                    .tabItem {
                        Label("Articles", systemImage: "newspaper.fill")
                    }
                    .tag(0)

                    // Feeds Tab
                    FeedsView(
                        selectedFeedForFilter: $selectedFeedForFilter,
                        selectedTab: $selectedTab
                    )
                        .tabItem {
                            Label("Feeds", systemImage: "list.bullet")
                        }
                        .tag(1)

                    // Settings Tab
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(2)
                }
            }
        }
        .withTheme(currentTheme)
        .foregroundColor(currentTheme.textColor)
        .accentColor(currentTheme.accentColor)
        .preferredColorScheme(selectedThemeStyle == "system" ? nil : (currentTheme.style == .dark ? .dark : .light))
        .animation(.easeInOut(duration: 0.2), value: showingArticle)
    }
}

struct ArticlesListViewWithSelection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.pubDate, order: .reverse) private var articles: [Article]
    @Query private var feeds: [Feed]
    let theme: Theme
    @Binding var selectedArticle: Article?
    @Binding var showingArticle: Bool
    @Binding var selectedFeedForFilter: Feed?
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date?
    @State private var filterMode: FilterMode = .unreadOnly
    @State private var showingMarkAllConfirmation = false

    enum FilterMode {
        case showAll
        case unreadOnly
        case savedOnly
    }

    var filteredArticles: [Article] {
        var result = articles

        // Apply read/unread/saved filter
        switch filterMode {
        case .showAll:
            break
        case .unreadOnly:
            result = result.filter { !$0.isRead }
        case .savedOnly:
            result = result.filter { $0.isSaved }
        }

        // Apply feed filter
        if let selectedFeed = selectedFeedForFilter {
            result = result.filter { $0.feedTitle == selectedFeed.title }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            if articles.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                        .opacity(0.3)
                    Text("No Articles Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Add an RSS feed to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if filteredArticles.isEmpty && selectedFeedForFilter != nil {
                // Empty state when feed filter is active but no articles match
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "tray.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                        .opacity(0.3)
                    Text("No Articles")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("No articles found for \(selectedFeedForFilter?.title ?? "this feed")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button(action: { selectedFeedForFilter = nil }) {
                        Text("Show All Feeds")
                            .fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .padding(.top, 16)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if filteredArticles.isEmpty && filterMode == .unreadOnly {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                        .opacity(0.3)
                    Text("All Caught Up!")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You've read all your articles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: { filterMode = .showAll }) {
                        Text("Show Read Posts")
                            .fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .padding(.top, 16)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if filteredArticles.isEmpty && filterMode == .savedOnly {
                // Empty state when saved filter is active but no saved articles
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                        .opacity(0.3)
                    Text("No Saved Articles")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Swipe right on any article or tap the bookmark icon to save it for later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button(action: { filterMode = .showAll }) {
                        Text("Show All Articles")
                            .fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .padding(.top, 16)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                VStack(spacing: 0) {
                    // Header with dynamic title
                    TabHeaderView(selectedFeedForFilter?.title ?? "All Feeds") {
                        AnyView(
                            HStack(spacing: 12) {
                                // Clear filter button (only show if feed filter is active)
                                if selectedFeedForFilter != nil {
                                    Button(action: { selectedFeedForFilter = nil }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "xmark.circle.fill")
                                            Text("Clear")
                                        }
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    }
                                }

                                // Filter menu
                                Menu {
                                    Section {
                                        Button(action: { filterMode = .showAll }) {
                                            HStack {
                                                Image(systemName: filterMode == .showAll ? "checkmark.circle.fill" : "circle")
                                                Text("Show All")
                                            }
                                        }

                                        Button(action: { filterMode = .unreadOnly }) {
                                            HStack {
                                                Image(systemName: filterMode == .unreadOnly ? "checkmark.circle.fill" : "circle")
                                                Text("Unread only")
                                            }
                                        }

                                        Button(action: { filterMode = .savedOnly }) {
                                            HStack {
                                                Image(systemName: filterMode == .savedOnly ? "checkmark.circle.fill" : "circle")
                                                Text("Saved only")
                                            }
                                        }
                                    }

                                    Divider()

                                    Button(role: .destructive, action: { showingMarkAllConfirmation = true }) {
                                        HStack {
                                            Image(systemName: "checkmark.square.fill")
                                            Text("Mark all as read")
                                        }
                                    }
                                } label: {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                }
                            }
                        )
                    }
                    .confirmationDialog(
                        "Mark all as read?",
                        isPresented: $showingMarkAllConfirmation,
                        actions: {
                            Button("Mark all as read", role: .destructive) {
                                markAllAsRead()
                            }
                            Button("Cancel", role: .cancel) {}
                        },
                        message: {
                            Text("This will mark all articles as read.")
                        }
                    )

                    // List
                    List {
                        ForEach(filteredArticles, id: \.uniqueId) { article in
                            Button(action: {
                                selectedArticle = article
                                showingArticle = true
                            }) {
                                ArticleListItemView(
                                    article: article,
                                    selectedFeedForFilter: $selectedFeedForFilter,
                                    feeds: feeds
                                )
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    withAnimation {
                                        article.isSaved.toggle()
                                    }
                                } label: {
                                    Label(
                                        article.isSaved ? "Unsave" : "Save",
                                        systemImage: article.isSaved ? "bookmark.slash.fill" : "bookmark.fill"
                                    )
                                }
                                .tint(article.isSaved ? .gray : .blue)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await refreshAllFeeds()
                    }
                }
            }
        }
        .navigationTitle("Articles")
    }

    private func refreshAllFeeds() async {
        print("🔄 Starting feed refresh...")
        let feedsToRefresh = feeds
        if feedsToRefresh.isEmpty {
            print("⚠️ No feeds to refresh")
            return
        }

        let results = await FeedFetcher.shared.refreshAllFeeds(feeds: feedsToRefresh)

        await MainActor.run {
            // Process refresh results for all feeds
            for result in results {
                if result.success {
                    // Successfully refreshed - add articles and update timestamp
                    let feedTitle = feeds.first(where: { $0.id == result.feedId })?.title ?? ""
                    let existingGuids = Set(articles.filter { $0.feedTitle == feedTitle }.compactMap { $0.guid })

                    for article in result.articles {
                        // Only add if not already present (avoid duplicates)
                        if !existingGuids.contains(article.guid ?? "") {
                            modelContext.insert(article)
                        }
                    }

                    // Update lastUpdated timestamp and clear any previous errors
                    if let feed = feeds.first(where: { $0.id == result.feedId }) {
                        feed.lastUpdated = result.timestamp
                        feed.lastRefreshError = nil
                    }
                } else {
                    // Failed to refresh - store error message
                    print("⚠️ Failed to refresh feed: \(result.feedId)")
                    if let feed = feeds.first(where: { $0.id == result.feedId }),
                       let error = result.error {
                        feed.lastRefreshError = error.localizedDescription
                    }
                }
            }

            lastRefreshTime = Date()
            let successCount = results.filter { $0.success }.count
            print("✅ Feed refresh completed: \(successCount)/\(results.count) feeds updated successfully.")
        }
    }

    private func markAllAsRead() {
        // Only mark filtered articles as read (respects both feed filter and read/unread filter)
        for article in filteredArticles {
            article.isRead = true
        }
    }
}

struct ArticleListItemView: View {
    let article: Article
    @Binding var selectedFeedForFilter: Feed?
    let feeds: [Feed]

    var excerpt: String {
        if !article.summary.isEmpty {
            return HTMLStripper.stripHTML(article.summary)
        } else if let content = article.content, !content.isEmpty {
            return HTMLStripper.generateExcerpt(from: content, wordCount: 20)
        } else {
            return ""
        }
    }

    var isFromFavoriteFeed: Bool {
        feeds.first(where: { $0.title == article.feedTitle })?.isFavorite ?? false
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar for favorited feeds
            if isFromFavoriteFeed {
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 4)
            }

            VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(article.title)
                .font(.system(.headline, design: .default))
                .fontWeight(.semibold)
                .lineLimit(3)
                .tracking(-0.3)
                .foregroundColor(.primary)

            // Excerpt/Summary (max 3 lines)
            if !excerpt.isEmpty {
                Text(excerpt)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .lineSpacing(0.5)
            }

            // Meta row: Feed Title • Relative Time
            HStack(spacing: 6) {
                Button(action: {
                    // Find the feed by title and set it as the filter
                    if let feed = feeds.first(where: { $0.title == article.feedTitle }) {
                        selectedFeedForFilter = feed
                    }
                }) {
                    HStack(spacing: 4) {
                        if isFromFavoriteFeed {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }
                        Text(article.feedTitle)
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(article.pubDate.relativeTimeString())
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Divider
            Divider()
                .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        }
        .background(isFromFavoriteFeed ? Color.yellow.opacity(0.05) : Color.clear)
    }

}

struct ArticleDetailViewContent: View {
    let article: Article
    let theme: Theme
    var onPanChanged: ((CGFloat) -> Void)?
    var onGestureEnded: ((CGFloat) -> Void)?

    var body: some View {
        // Just the WebView - no header
        ArticleWebView(
            article: article,
            theme: theme,
            articleLink: article.link,
            onPanChanged: onPanChanged,
            onGestureEnded: onGestureEnded
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("ArticleDetailViewContent appeared: '\(article.title)'")
        }
    }
}

struct ArticleHeaderView: View {
    let article: Article
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(article.feedTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                HStack(spacing: 8) {
                    if let author = article.author {
                        Text(author)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Text(article.pubDate, style: .date)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            // Bookmark button
            Button(action: {
                withAnimation {
                    article.isSaved.toggle()
                }
            }) {
                Image(systemName: article.isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(article.isSaved ? .blue : .gray)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .transition(.opacity)  // Fade transition when article changes
    }
}

enum DragState {
    case idle
    case dragging
    case animating
}

struct ArticleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.pubDate, order: .reverse) private var allArticles: [Article]
    let article: Article
    let theme: Theme
    @Binding var selectedArticle: Article?
    @Binding var showingArticle: Bool
    // Gesture state machine
    @State private var dragState: DragState = .idle
    @State private var currentTranslation: CGFloat = 0
    @State private var thresholdCrossed: Bool = false
    @State private var swipeDirection: Int = 0  // -1 = left (next), +1 = right (prev)
    @State private var incomingArticle: Article?
    @State private var showingEndOfFeed: Bool = false
    @State private var showingBeginningOfFeed: Bool = false
    @State private var boundaryAction: String?  // "endOfFeed" or "beginning"

    var currentIndex: Int {
        allArticles.firstIndex { $0.uniqueId == article.uniqueId } ?? 0
    }

    var hasNext: Bool {
        currentIndex < allArticles.count - 1
    }

    var hasPrevious: Bool {
        currentIndex > 0
    }

    var body: some View {
        print("📱 ArticleDetailView.body: article='\(article.title)', dragState=\(dragState), incomingArticle=\(incomingArticle?.title ?? "nil"), currentTranslation=\(currentTranslation)")

        return VStack(spacing: 0) {
            // Fixed header - always show, but hide content on boundary views
            if showingEndOfFeed || showingBeginningOfFeed {
                // Empty header placeholder for boundary views
                HStack(spacing: 12) {
                    Button(action: { showingArticle = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("")  // Empty
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        HStack(spacing: 8) {
                            Text("")  // Empty
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemBackground))
            } else {
                // Real header with article info
                ArticleHeaderView(article: article, onBack: { showingArticle = false })
                    .id(article.uniqueId)  // Force fade transition when article changes
            }

            Divider()

            // Swipeable content area
            GeometryReader { geometry in
                let screenWidth = geometry.size.width

                ZStack {
                    // LAYER 1: Current Article or Boundary View
                    // ALWAYS at center (x=0), NEVER moves
                    if showingEndOfFeed {
                        EndOfFeedView(
                            theme: theme,
                            currentTranslation: $currentTranslation,
                            screenWidth: screenWidth,
                            onDismiss: { showingArticle = false },
                            onSwipeBack: {
                                // Swiping right on end of feed - show last article
                                let targetTranslation: CGFloat = screenWidth
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentTranslation = targetTranslation
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingEndOfFeed = false
                                    selectedArticle = incomingArticle
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        resetGestureState()
                                    }
                                }
                            }
                        )
                    } else if showingBeginningOfFeed {
                        BeginningOfFeedView(
                            theme: theme,
                            currentTranslation: $currentTranslation,
                            screenWidth: screenWidth,
                            onDismiss: { showingBeginningOfFeed = false },
                            onSwipeBack: {
                                // Swiping left on beginning of feed - show first article
                                let targetTranslation: CGFloat = -screenWidth
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentTranslation = targetTranslation
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingBeginningOfFeed = false
                                    selectedArticle = incomingArticle
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        resetGestureState()
                                    }
                                }
                            }
                        )
                    } else {
                        ArticleDetailViewContent(
                            article: article,
                            theme: theme,
                            onPanChanged: { translation in
                            dragState = .dragging
                            currentTranslation = translation

                            // Determine direction from translation
                            if translation < 0 {
                                swipeDirection = -1
                                // Check if we're at the last article
                                if !hasNext {
                                    boundaryAction = "endOfFeed"
                                    incomingArticle = nil
                                } else {
                                    boundaryAction = nil
                                    let nextArticle = allArticles[currentIndex + 1]
                                    incomingArticle = nextArticle
                                    // Pre-cache the HTML so images load faster
                                    DispatchQueue.global(qos: .userInitiated).async {
                                        _ = ArticleHTMLCache.shared.getCachedHTML(for: nextArticle)
                                    }
                                }
                            } else if translation > 0 {
                                swipeDirection = 1
                                // Check if we're at the first article
                                if !hasPrevious {
                                    print("📱 Dragging right on FIRST article - showing beginning boundary")
                                    boundaryAction = "beginning"
                                    incomingArticle = nil
                                } else {
                                    boundaryAction = nil
                                    let prevArticle = allArticles[currentIndex - 1]
                                    incomingArticle = prevArticle
                                    // Pre-cache the HTML so images load faster
                                    DispatchQueue.global(qos: .userInitiated).async {
                                        _ = ArticleHTMLCache.shared.getCachedHTML(for: prevArticle)
                                    }
                                }
                            }

                            // Check threshold (40% of screen)
                            let threshold = screenWidth * 0.4
                            thresholdCrossed = abs(translation) > threshold
                        },
                        onGestureEnded: { finalTranslation in
                            let threshold = screenWidth * 0.4

                            if abs(finalTranslation) > threshold {
                                dragState = .animating

                                // Handle boundary actions (fake posts)
                                if boundaryAction == "endOfFeed" {
                                    // Last article - show end of feed message as current
                                    print("🎬 Swiped to end of feed")

                                    let targetTranslation: CGFloat = -screenWidth
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentTranslation = targetTranslation
                                    }

                                    // After animation, show the end of feed post as the "current" view
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showingEndOfFeed = true
                                        resetGestureState()
                                        // Set up incoming article for the boundary view to show on swipe back
                                        incomingArticle = allArticles[currentIndex]
                                        swipeDirection = 1
                                    }
                                } else if boundaryAction == "beginning" {
                                    // First article - show beginning of feed message as current
                                    print("🎬 Swiped to beginning of feed")

                                    let targetTranslation: CGFloat = screenWidth
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentTranslation = targetTranslation
                                    }

                                    // After animation, show the beginning of feed post as the "current" view
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showingBeginningOfFeed = true
                                        resetGestureState()
                                        // Set up incoming article for the boundary view to show on swipe back
                                        incomingArticle = allArticles[currentIndex]
                                        swipeDirection = -1
                                    }
                                } else if incomingArticle != nil {
                                    // Normal swipe to next/previous article
                                    // Continue in the direction of the swipe to center (x=0)
                                    let targetTranslation: CGFloat = swipeDirection == -1 ? -screenWidth : screenWidth

                                    // Animate incoming article to center
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentTranslation = targetTranslation
                                    }

                                    // After animation, update the article
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        print("🎬 [0.3s] Animation complete. Changing selectedArticle to: '\(incomingArticle?.title ?? "nil")'")
                                        selectedArticle = incomingArticle
                                        print("🎬 [0.3s] selectedArticle changed, keeping incoming layer visible as cover")

                                        // Reset gesture state after a delay to ensure WebView has loaded the new article and images
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            print("🎬 [0.6s] Resetting gesture state (clearing incoming layer)")
                                            resetGestureState()
                                        }
                                    }
                                }
                            } else {
                                // Threshold not crossed - bounce back
                                dragState = .animating

                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentTranslation = 0
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    resetGestureState()
                                }
                            }
                        }
                    )
                    }

                    // LAYER 2: Incoming Article or Boundary Message (rendered last = always on top)
                    // Stays visible briefly after animation to cover Layer 1 while WebView loads
                    if let incoming = incomingArticle {
                        ArticleDetailViewContent(
                            article: incoming,
                            theme: theme
                        )
                        .offset(x: swipeDirection == -1 ? (screenWidth + currentTranslation) : (-screenWidth + currentTranslation))
                    } else if boundaryAction == "endOfFeed" {
                        // Show end of feed message (draggable like a real post)
                        EndOfFeedView(
                            theme: theme,
                            currentTranslation: .constant(currentTranslation),
                            screenWidth: screenWidth,
                            onDismiss: { showingArticle = false },
                            onSwipeBack: {}
                        )
                        .offset(x: screenWidth + currentTranslation)
                    } else if boundaryAction == "beginning" {
                        // Show beginning of feed message (draggable like a real post)
                        BeginningOfFeedView(
                            theme: theme,
                            currentTranslation: .constant(currentTranslation),
                            screenWidth: screenWidth,
                            onDismiss: { },
                            onSwipeBack: {}
                        )
                        .offset(x: -screenWidth + currentTranslation)
                    }
                }
            }
        }
        .onAppear {
            article.isRead = true
        }
        .onDisappear {
            print("📱 ArticleDetailView.onDisappear: article='\(article.title)'")
        }
    }

    private func resetGestureState() {
        dragState = .idle
        currentTranslation = 0
        thresholdCrossed = false
        swipeDirection = 0
        incomingArticle = nil
        boundaryAction = nil
        // Don't reset showingEndOfFeed/showingBeginningOfFeed here - they stay true to show the boundary views
    }
}

struct EndOfFeedView: View {
    let theme: Theme
    @Binding var currentTranslation: CGFloat
    let screenWidth: CGFloat
    let onDismiss: () -> Void
    let onSwipeBack: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
                .opacity(0.7)

            VStack(spacing: 12) {
                Text("You've Reached the End")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You've read all the articles in this feed.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onDismiss) {
                Text("Back to Article List")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(theme.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor)
        .foregroundColor(theme.textColor)
        .gesture(
            DragGesture()
                .onChanged { value in
                    currentTranslation = value.translation.width
                }
                .onEnded { value in
                    let threshold = screenWidth * 0.4
                    if value.translation.width > threshold {
                        // Swiped right - go back to last article
                        onSwipeBack()
                    } else {
                        // Bounce back
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentTranslation = 0
                        }
                    }
                }
        )
    }
}

struct BeginningOfFeedView: View {
    let theme: Theme
    @Binding var currentTranslation: CGFloat
    let screenWidth: CGFloat
    let onDismiss: () -> Void
    let onSwipeBack: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
                .opacity(0.7)

            VStack(spacing: 12) {
                Text("Beginning of Feed")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You've scrolled to the earliest articles in this feed.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Go Back to First Article")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(theme.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Text("or swipe left to return")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor)
        .foregroundColor(theme.textColor)
        .gesture(
            DragGesture()
                .onChanged { value in
                    currentTranslation = value.translation.width
                }
                .onEnded { value in
                    let threshold = screenWidth * 0.4
                    if value.translation.width < -threshold {
                        // Swiped left - go back to first article
                        onSwipeBack()
                    } else {
                        // Bounce back
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentTranslation = 0
                        }
                    }
                }
        )
    }
}

struct AddFeedView: View {
    @Binding var isPresented: Bool
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    @Binding var discoveryStatus: String?
    @Binding var initialFeedURL: String  // Receives discovered feed URL from parent
    @Binding var initialFeedTitle: String  // Receives discovered feed title from parent
    @Binding var initialArticleCount: Int  // Receives discovered article count from parent
    @Binding var discoveredArticles: [Article]  // Receives discovered articles from parent
    let onAdd: (String, String) -> Void

    @State private var url = ""
    @State private var title = ""
    @State private var isShowingConfirmation = false
    @State private var currentFeedUrl: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isShowingConfirmation {
                    // Confirmation screen with pre-filled title
                    ConfirmFeedView(
                        url: currentFeedUrl,
                        title: $title,
                        articleCount: initialArticleCount,
                        articles: discoveredArticles,
                        isLoading: isLoading,
                        onConfirm: {
                            onAdd(currentFeedUrl, title)
                        },
                        onEditURL: {
                            isShowingConfirmation = false
                        }
                    )
                } else {
                    // URL input screen
                    Form {
                        TextField("Feed URL", text: $url)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .disabled(isLoading)
                    }

                    if let errorMessage = errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(4)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding()
                    }

                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            if let discoveryStatus = discoveryStatus {
                                Text(discoveryStatus)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Searching for feed...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                        .padding()
                    }

                    Spacer()
                }
            }
            .navigationTitle(isShowingConfirmation ? "Confirm Feed" : "Add Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        errorMessage = nil
                        discoveryStatus = nil
                        url = ""
                        title = ""
                        isShowingConfirmation = false
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isShowingConfirmation {
                        // Confirmation screen buttons
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button("Add Feed") {
                                onAdd(currentFeedUrl, title)
                            }
                        }
                    } else {
                        // Initial screen buttons
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button("Search") {
                                currentFeedUrl = url
                                discoveryStatus = nil
                                // Pass empty title to signal discovery mode
                                onAdd(url, "")
                            }
                            .disabled(url.isEmpty)
                        }
                    }
                }
            }
        }
        .onChange(of: initialFeedTitle) { oldValue, newValue in
            // When parent sets a discovered title, transition to confirmation screen
            if !newValue.isEmpty && !initialFeedURL.isEmpty {
                title = newValue
                currentFeedUrl = initialFeedURL
                isShowingConfirmation = true
                // Note: discoveredArticleCount will be fetched by parent when needed
                // For now, we display a placeholder or fetch it ourselves if needed
            }
        }
        .onDisappear {
            // Reset parent state variables when sheet closes
            DispatchQueue.main.async {
                initialFeedURL = ""
                initialFeedTitle = ""
                initialArticleCount = 0
                discoveredArticles = []
            }
        }
    }
}

// MARK: - Confirmation View

struct ConfirmFeedView: View {
    let url: String
    @Binding var title: String
    let articleCount: Int
    let articles: [Article]
    let isLoading: Bool
    let onConfirm: () -> Void
    let onEditURL: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Feed title input
            VStack(alignment: .leading, spacing: 8) {
                Text("Feed Title")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Feed Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
                    .onChange(of: title) { oldValue, newValue in
                        // Limit to 25 characters
                        if newValue.count > 25 {
                            title = String(newValue.prefix(25))
                        }
                    }
            }
            .padding()

            // Feed info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text("URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "link")
                    }
                    Spacer()
                }

                Text(url)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Divider()

                HStack {
                    Label {
                        Text("\(articleCount) articles found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "newspaper.fill")
                    }
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding()

            // Edit URL button
            Button(action: onEditURL) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit URL")
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            .padding(.horizontal)
            .disabled(isLoading)

            // Article preview (most recent) - using same styling as ArticleListItemView
            if !articles.isEmpty, let latestArticle = articles.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest Article")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        Text(latestArticle.title)
                            .font(.system(.headline, design: .default))
                            .fontWeight(.semibold)
                            .lineLimit(3)
                            .tracking(-0.3)
                            .foregroundColor(.primary)

                        // Excerpt/Summary
                        let excerpt = HTMLStripper.stripHTML(latestArticle.summary)
                        if !excerpt.isEmpty {
                            Text(excerpt)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                                .lineSpacing(0.5)
                        }

                        // Meta row: Feed Title • Relative Time
                        HStack(spacing: 6) {
                            Text(latestArticle.feedTitle)
                                .font(.caption2)
                                .foregroundColor(.blue)

                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(latestArticle.pubDate.relativeTimeString())
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()
                        }

                        // Divider
                        Divider()
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
            }

            Spacer()
        }
        .padding(.vertical)
    }
}

#Preview {
    let container = try! ModelContainer(for: Article.self, Feed.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return ContentView()
        .modelContainer(container)
}
