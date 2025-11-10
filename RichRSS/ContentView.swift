//
//  ContentView.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("selectedThemeStyle") private var selectedThemeStyle: String = "light"
    @State private var selectedArticle: Article?
    @State private var showingArticle = false

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

    var body: some View {
        ZStack {
            // Background color for the entire app
            currentTheme.backgroundColor
                .ignoresSafeArea()

            if showingArticle, let article = selectedArticle {
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
                        showingArticle: $showingArticle
                    )
                    .tabItem {
                        Label("Articles", systemImage: "newspaper.fill")
                    }
                    .tag(0)

                    // Feeds Tab
                    FeedsView()
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
        .preferredColorScheme(currentTheme.style == .dark ? .dark : .light)
        .animation(.easeInOut(duration: 0.2), value: showingArticle)
    }
}

struct ArticlesListViewWithSelection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.pubDate, order: .reverse) private var articles: [Article]
    let theme: Theme
    @Binding var selectedArticle: Article?
    @Binding var showingArticle: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if articles.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                            .opacity(0.3)
                        Text("No Articles Yet")
                            .font(.system(size: 24, weight: .bold, design: .default))
                        Text("Add an RSS feed to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(articles, id: \.uniqueId) { article in
                            Button(action: {
                                selectedArticle = article
                                showingArticle = true
                            }) {
                                ArticleListItemView(article: article)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteArticles)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Articles")
        }
    }

    private func deleteArticles(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(articles[index])
            }
        }
    }
}

struct ArticleListItemView: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Feed badge
            HStack {
                Text(article.feedTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                Spacer()
                Text(relativeDate(article.pubDate))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            // Title
            Text(article.title)
                .font(.system(.headline, design: .default))
                .fontWeight(.semibold)
                .lineLimit(3)
                .tracking(-0.3)

            // Description
            if !article.summary.isEmpty {
                let cleanSummary = HTMLStripper.stripHTML(article.summary)
                if !cleanSummary.isEmpty {
                    Text(cleanSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .lineSpacing(0.5)
                }
            }

            // Meta info
            HStack(spacing: 12) {
                if let author = article.author {
                    Label(author, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if article.isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let daysDifference = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if daysDifference < 7 {
                return "\(daysDifference)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
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
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                }
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
            // Fixed header - does not move with swipe
            ArticleHeaderView(article: article, onBack: { showingArticle = false })
                .id(article.uniqueId)  // Force fade transition when article changes

            Divider()

            // Swipeable content area
            GeometryReader { geometry in
                let screenWidth = geometry.size.width

                ZStack {
                    // LAYER 1: Current Article
                    // ALWAYS at center (x=0), NEVER moves
                    ArticleDetailViewContent(
                        article: article,
                        theme: theme,
                        onPanChanged: { translation in
                            dragState = .dragging
                            currentTranslation = translation

                            // Determine direction from translation
                            if translation < 0 {
                                swipeDirection = -1
                                incomingArticle = hasNext ? allArticles[currentIndex + 1] : nil
                            } else if translation > 0 {
                                swipeDirection = 1
                                incomingArticle = hasPrevious ? allArticles[currentIndex - 1] : nil
                            }

                            // Check threshold (40% of screen)
                            let threshold = screenWidth * 0.4
                            thresholdCrossed = abs(translation) > threshold
                        },
                        onGestureEnded: { finalTranslation in
                            let threshold = screenWidth * 0.4

                            if abs(finalTranslation) > threshold && incomingArticle != nil {
                                // Threshold crossed - complete the swipe
                                dragState = .animating

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

                                    // Reset gesture state after a delay to ensure WebView has loaded the new article
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        print("🎬 [0.45s] Resetting gesture state (clearing incoming layer)")
                                        resetGestureState()
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

                    // LAYER 2: Incoming Article (rendered last = always on top)
                    // Stays visible briefly after animation to cover Layer 1 while WebView loads
                    if let incoming = incomingArticle {
                        ArticleDetailViewContent(
                            article: incoming,
                            theme: theme
                        )
                        .offset(x: swipeDirection == -1 ? (screenWidth + currentTranslation) : (-screenWidth + currentTranslation))
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
    }
}

struct AddFeedView: View {
    @Binding var isPresented: Bool
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onAdd: (String, String) -> Void
    @State private var url = ""
    @State private var title = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    TextField("Feed URL", text: $url)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                    TextField("Feed Title", text: $title)
                        .textContentType(.none)
                }

                if let errorMessage = errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .lineLimit(3)
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
                        Text("Fetching feed...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .padding()
                }
            }
            .navigationTitle("Add Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        errorMessage = nil
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Add") {
                            onAdd(url, title)
                        }
                        .disabled(url.isEmpty || title.isEmpty)
                    }
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Article.self, Feed.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return ContentView()
        .modelContainer(container)
}
