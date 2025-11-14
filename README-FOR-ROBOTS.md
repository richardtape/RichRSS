# RichRSS - iOS RSS Reader

A beautiful, feature-rich native iOS RSS reader built with SwiftUI. Designed for a delightful reading experience with smooth gestures, multiple themes, persistent storage, and automatic feed discovery.

## Project Overview

RichRSS is a native iOS application that allows users to:

-   Subscribe to RSS feeds with intelligent feed discovery (RSS 2.0 and Atom 1.0 formats)
-   Read articles with a beautiful, distraction-free interface
-   Navigate between articles with intuitive swipe gestures
-   Switch between three themes: Light, Dark, and Sepia
-   Manage feeds and articles with persistent storage
-   Cache article HTML for faster loading
-   Pull-to-refresh feeds from within articles view
-   Watch embedded videos (YouTube, Vimeo, and other iframe-based embeds)
-   Filter articles (Show All, Unread Only, Saved/Bookmarked)
-   View feed favicons and unread counts
-   Automatic feed refresh on app startup

## Architecture

The app uses a modern SwiftUI-based architecture with the following key technologies:

-   **SwiftUI**: Declarative UI framework for iOS
-   **SwiftData**: Modern persistent storage framework
-   **WKWebView**: For rendering article HTML content
-   **XMLParser**: For parsing RSS and Atom feeds
-   **Combine**: For async operations and state management

## Project File Structure

### Core App Files

#### `RichRSSApp.swift`

The app entry point. Configures the SwiftData container for persistent storage and initializes the root view.

-   Creates SwiftData ModelContainer with Feed and Article schemas
-   Initializes AppStartupManager for background feed refresh on launch
-   Passes startup manager to ContentView via environment
-   Configures modelContainer modifier for SwiftData access throughout app

#### `ContentView.swift` - **Main Navigation & Article Reading**

The core of the app. Contains:

-   **ContentView**: Main app container with tab navigation (Articles, Feeds, Settings)
    -   Shows LoadingView during app startup
    -   Renders articles/feeds/settings based on selected tab
    -   Passes theme through environment to all child views
-   **ArticlesListViewWithSelection**: Displays the list of articles with filtering
    `FilterMode` enum: `.showAll`, `.unreadOnly`, `.savedOnly`
    Filter menu with radio-button style selection
    "Mark all as read" button with confirmation dialog
    Pull-to-refresh functionality (`.refreshable` modifier)
    -   Swipe actions to bookmark/save articles
    -   Shows "Saved Articles" and "Unread" empty states
    -   Uses `TabHeaderView` for header consistency
-   **ArticleListItemView**: Individual article list item
    -   Displays feed title, article title, summary
    -   Shows author and publication date
    -   Displays unread/read indicator
    -   Bookmark icon for saved articles
-   **ArticleDetailView**: Full-screen article reader with swipe navigation between articles
    -   Implements the swipe gesture system for navigating between articles
    -   Manages boundary detection (beginning/end of feed)
    -   Handles the smooth animation when swiping between articles
    -   Integrates with AppStartupManager for fresh content
-   **ArticleDetailViewContent**: Wrapper that combines the article header and WebView
-   **ArticleHeaderView**: Displays feed title, author, publication date, and back button
-   **EndOfFeedView**: Boundary view shown when reaching the last article
-   **BeginningOfFeedView**: Boundary view shown when reaching the first article
-   **DragState** enum: Tracks gesture state (idle, dragging, animating)

### Theme System

The theme system uses CSS variables for a single source of truth, with Swift extracting values at runtime.

#### `Theme.swift`

Defines the theme structure and available theme styles:

-   **ThemeStyle** enum: `.light`, `.dark`, `.sepia`
-   **Theme** struct: Contains the current style and provides CSS filename
-   Maps theme styles to CSS variable files

#### `ThemeColors.swift`

Swift extension on Theme that extracts colors from CSS files at runtime:

-   `backgroundColor`: Main background color
-   `textColor`: Primary text color
-   `accentColor`: Accent/link color
-   `secondaryTextColor`: Secondary text color
-   `borderColor`: Border color
-   `codeBackgroundColor`: Code block background
-   `blockquoteBackgroundColor`: Blockquote background

Includes `Color(hex:)` initializer for parsing hex colors from CSS.

#### `ThemeEnvironment.swift`

Provides SwiftUI environment integration:

-   **ThemeKey**: EnvironmentKey for theme access
-   `appTheme` environment value
-   `.withTheme()` modifier for propagating theme through view hierarchy

#### CSS Files (`variables-light.css`, `variables-dark.css`, `variables-sepia.css`)

Define CSS custom properties (variables) for each theme:

-   `--bg-color`: Background color
-   `--text-color`: Text color
-   `--accent-color`: Accent color
-   And other theme-specific variables

#### `components.css`

Consolidated base styles for all UI components and article rendering:

-   Typography settings with CSS variables (font sizes, weights, line heights)
-   Spacing system (xs, sm, md, lg, xl, xxl)
-   Link styling
-   Code block styling
-   Blockquote styling
-   Image responsiveness
-   Responsive iframe styling for embedded videos (YouTube, Vimeo, etc.)
-   Color variables with semantic naming (bg-color, text-color, accent-color, etc.)
-   Pill styling for badges and metadata

**Note**: This file consolidates what was previously split between `article.css` and theme files. It serves as the single source of truth for all component styling, with theme files (`variables-*.css`) containing only color/typography/spacing overrides.

### Data Models

#### `Item.swift`

**Note**: This file is deprecated. Articles are now stored using the Article model in Feed.swift.

#### `Feed.swift`

SwiftData models for persistent storage:

**Feed model**:

-   `id`: UUID string identifier
-   `title`: User-provided feed name
-   `feedUrl`: RSS feed URL
-   `siteUrl`: Website URL (optional)
-   `feedSummary`: Feed description
-   `lastUpdated`: Last sync timestamp
-   **NEW** `faviconUrl`: Website favicon URL (optional, auto-fetched on feed add)

**Article model**:

-   `uniqueId`: UUID string (unique across all feeds)
-   `guid`: Original feed GUID (may be duplicated across feeds)
-   `title`: Article headline
-   `summary`: Article description/excerpt
-   `content`: Full HTML article content
-   `link`: URL to original article
-   `author`: Author name (optional)
-   `pubDate`: Publication date
-   `feedTitle`: Feed name (denormalized for easy display)
-   `imageUrl`: Featured image URL (optional)
-   `isRead`: Read/unread status
-   **NEW** `isSaved`: Bookmarked/saved status (boolean, defaults to false)

### Feed Management

#### `FeedsView.swift`

UI for managing user's feed subscriptions:

-   Displays list of subscribed feeds with last updated timestamp
-   Shows feed favicon (36x36) with first-letter fallback
-   Shows unread count for each feed in a pill badge
-   Swipe-to-delete for removing feeds
-   "Add Feed" button opens AddFeedView
-   Empty state message when no feeds
-   Uses `TabHeaderView` for consistent header styling

#### `FeedFetcher.swift`

Handles async feed fetching and parsing:

-   Fetches feed from URL
-   Delegates parsing to RSSFeedParser
-   Returns array of Article objects
-   Error handling for network and parsing failures
-   **NEW** `isRSSFeed()`: Validates if a URL is a valid RSS/Atom feed
-   **NEW** `refreshAllFeeds()`: Fetches all subscribed feeds and returns dictionary of [feedId: articles]

#### `RSSFeedParser.swift`

XML parsing logic supporting both RSS 2.0 and Atom 1.0:

-   Uses XMLParser delegate pattern
-   Handles element navigation (`<item>` vs `<entry>`)
-   Extracts article metadata
-   Maps feed-specific field names to Article properties
-   Cleans HTML content

#### `FeedDiscoverer.swift`

Intelligent feed discovery when user provides website URL instead of feed URL:

-   Detects if provided URL is already an RSS/Atom feed
-   If not, searches for feeds at common paths:
    -   `/feed`, `/feed/`, `/rss`, `/rss.xml`, `/feed.xml`
    -   `/?feed=rss2`, `/index.php?feed=rss2`, `/atom.xml`
-   Uses HEAD requests for fast validation
-   Provides real-time status updates to UI during discovery
-   User-friendly error messages if no feed found
-   Returns discovered feed URL ready for fetching

#### `FaviconFetcher.swift`

Asynchronous favicon fetching for feed subscriptions:

-   Attempts multiple favicon sources for a website
-   Checks feed's own image URL first
-   Tries common favicon paths (/favicon.ico, /apple-touch-icon.png)
-   HEAD request validation to avoid dead links
-   Returns favicon URL or nil (triggering first-letter fallback in UI)
-   Non-blocking: doesn't delay feed addition

#### `FaviconView.swift`

Displays feed favicon or generates first-letter avatar:

-   Shows favicon image if available (36x36pt)
-   Fallback: First letter of feed title in colored circle
-   Async loading of favicon images
-   Themed to match app colors

### Article Display & Caching

#### `ArticleWebView.swift`

UIViewRepresentable wrapper for WKWebView:

**ArticleWebView struct**:

-   Wraps WKWebView for SwiftUI
-   Generates HTML with embedded CSS themes
-   Caches HTML to disk for reuse
-   Handles pan gestures for swipe navigation
-   **NEW** WKWebView configured for video embed support:
    -   `allowsInlineMediaPlayback = true`
    -   `mediaTypesRequiringUserActionForPlayback = []` (enable autoplay)
    -   `allowsContentJavaScript = true` (for interactive embeds)
-   **NEW** Enhanced iframe handling:
    -   Preserves iframes from article content (critical!)
    -   Adds `allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"` to all iframes
    -   Adds `allowfullscreen` attribute for full-screen capability
    -   Works with YouTube, Vimeo, and other iframe-based embeds
-   **NEW** HTML improvements:
    -   Sets `baseURL` to valid origin (helps YouTube embed validation)
    -   Adds `<meta name="referrer" content="no-referrer-when-downgrade">` for security headers

**WebViewContainer class** (UIView subclass):

-   Manages WKWebView instance
-   Detects horizontal vs vertical pan gestures
-   Disables vertical scrolling when horizontal pan detected (swipe lock)
-   Continuous translation reporting during drag
-   Reports gesture end with final translation
-   Minimum 10px movement detection before determining gesture direction

#### `ArticleHTMLCache.swift`

Disk-based HTML caching for articles:

-   Singleton instance (`ArticleHTMLCache.shared`)
-   Stores HTML files in app's caches directory
-   Uses article `uniqueId` as cache key
-   `getCachedHTML()`: Retrieve cached HTML
-   `cacheHTML()`: Save HTML to disk
-   `clearCache()`: Wipe all cached articles (called from Settings)

#### `HTMLStripper.swift`

HTML sanitization utility:

-   Removes dangerous `<script>` and `<style>` tags
-   Uses regex pattern matching
-   Called before rendering article content
-   Prevents malicious content execution

### Settings & Data Management

#### `SettingsView.swift`

User preferences and data management:

-   Theme selector (Light/Dark/Sepia)
-   App version display
-   "Remove Everything" button to:
    -   Delete all articles from database
    -   Delete all feeds from database
    -   Reset theme to Light
    -   Clear article HTML cache
-   Uses `TabHeaderView` for consistent header styling

#### `TabHeaderView.swift`

Unified header component for tab views:

-   Provides consistent styling across Articles, Feeds, and Settings tabs
-   Accepts title and optional trailing content (buttons, menus)
-   33px bold title, left-aligned
-   Consistent 12px padding on all sides
-   Eliminates duplicated header code across tabs

#### `LoadingView.swift`

Splash screen shown during app startup:

-   Displays app icon and name ("RichRSS")
-   Shows loading spinner during initialization
-   Displays dynamic status message (e.g., "Refreshing feeds...")
-   Fully themed to match current theme selection
-   Prevents user interaction until startup complete

#### `AppStartupManager.swift`

Manages app startup state and background feed refresh:

-   Executes multi-step startup sequence:
    1. Loads all subscribed feeds from database
    2. Refreshes all feeds in background
    3. Updates database with new articles
    4. Deduplicates articles by GUID to prevent duplicates
-   Observable state for UI binding:
    -   `isLoading`: Boolean controlling LoadingView visibility
    -   `statusMessage`: Current status (e.g., "Refreshing feeds...")
-   Graceful error handling if refresh fails
-   Updates happen asynchronously, doesn't block UI startup

#### `PullToRefreshView.swift`

Pull-to-refresh functionality in articles list:

-   Integrated with SwiftUI's native `.refreshable` modifier
-   User drags down from top of articles list
-   Icon rotates as drag distance increases
-   Haptic feedback when threshold crossed
-   Auto-triggers feed refresh when threshold exceeded (60pt)
-   Displays loading indicator and status during refresh

## Key Systems Explained

### Theming System

1. **CSS as Source of Truth**: Each theme (light/dark/sepia) has a CSS file with custom properties defining all colors
2. **Swift Extraction**: `ThemeColors.swift` parses CSS at runtime using regex to extract hex color values
3. **Environment Propagation**: Theme is passed through SwiftUI environment using `.withTheme()` modifier
4. **HTML Integration**: CSS variables are embedded in article HTML, so articles automatically style to the current theme
5. **Persistence**: Selected theme is saved to `@AppStorage("selectedThemeStyle")`

**Workflow**:

```
User changes theme in Settings
→ AppStorage updates "selectedThemeStyle"
→ ContentView reads new value
→ currentTheme is recalculated
→ Theme passed to all views via environment
→ ArticleWebView regenerates HTML with new CSS
```

### App Startup with Background Feed Refresh

**NEW SYSTEM**: Automatic feed refresh on app launch

1. **App launches** → RichRSSApp initializes
2. **AppStartupManager created** → Starts async startup sequence
3. **LoadingView displayed** → Shows "Preparing app..." status
4. **Database fetch** → Loads all subscribed feeds
5. **Background refresh** → FeedFetcher.refreshAllFeeds() runs asynchronously
6. **Status updates** → LoadingView shows "Refreshing feeds..." → "Updating articles..."
7. **Deduplication** → New articles checked against existing articles by GUID
8. **Database insert** → Only new articles added to avoid duplicates
9. **LoadingView dismissed** → isLoading = false, shows fresh content

**Benefits**:

-   User always sees fresh feed content when opening app
-   No manual refresh needed (though pull-to-refresh still available)
-   Background process doesn't block UI initialization
-   Graceful error handling if refresh fails

### Feed Discovery System

**NEW SYSTEM**: Intelligent feed URL detection

1. **User provides URL** (e.g., "theverge.com")
2. **FeedDiscoverer.discoverFeed()** called with status callback
3. **First check**: Is it already an RSS feed?
    - Uses `FeedFetcher.isRSSFeed()` to validate
    - If yes, proceeds directly to fetch
4. **Search phase**: If not a feed, tries common paths:
    - `/feed`, `/feed/`, `/rss`, `/rss.xml`, `/feed.xml`
    - `/?feed=rss2`, `/index.php?feed=rss2`, `/atom.xml`
5. **Validation**: Each path tested with HEAD request
6. **Real-time feedback**: UI updates with "Searching at `/feed`..."
7. **Success**: Returns discovered feed URL
8. **Failure**: Returns user-friendly error message

**Why This Works**:

-   Most content platforms follow predictable feed URL patterns
-   HEAD requests are fast (no body download)
-   User-friendly error messages guide them if discovery fails
-   Real-time status prevents "stuck" feeling

### Feed Adding & Parsing

1. **User enters feed URL or website URL**: FeedsView shows AddFeedView sheet
2. **FeedDiscoverer.discoverFeed()**: If not already RSS feed, finds it (NEW)
3. **FeedFetcher.fetchFeed()**: Downloads and parses XML from remote server
4. **RSSFeedParser parses XML**: Determines if RSS 2.0 or Atom 1.0, extracts articles
5. **Favicon fetch**: FaviconFetcher tries to get website favicon (async, non-blocking)
6. **Articles inserted to database**: Each article gets unique UUID
7. **Feed created in database**: Linked to articles via feedTitle, stores faviconUrl
8. **UI updates**: New articles appear in ArticlesListViewWithSelection, favicon displays in FeedsView

**Key Design Decisions**:

-   Each article has a `uniqueId` (UUID) to handle duplicate feed GUIDs across feeds
-   `feedTitle` is denormalized into Article for easy display without joins
-   HTML is cached immediately after fetching to speed up subsequent views
-   Favicon fetched asynchronously, feed adds immediately (doesn't wait for favicon)

### Video Embed Support

**NEW SYSTEM**: YouTube, Vimeo, and other embedded videos now work

**Critical Configuration** (in ArticleWebView.swift):

-   WKWebView setup:
    -   `allowsInlineMediaPlayback = true` → Videos play without fullscreen popup
    -   `mediaTypesRequiringUserActionForPlayback = []` → Autoplay enabled
    -   `allowsContentJavaScript = true` → Interactive embeds supported
-   HTML generation:
    -   `baseURL = URL(string: "https://example.com")` → YouTube needs valid origin
    -   Adds `<meta name="referrer" content="no-referrer-when-downgrade">` → Security headers
-   Iframe handling:
    -   Preserves all `<iframe>` tags from article content
    -   Adds `allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"` → YouTube permissions
    -   Adds `allowfullscreen` attribute → Full-screen capability

**CSS Support** (components.css):

-   Responsive iframe styling: `max-width: 100%; height: auto`
-   YouTube/Vimeo aspect ratio: `aspect-ratio: 16 / 9`

**Why This Works**:

-   YouTube's "Error 153" occurs when it can't validate the embedding context
-   The `baseURL` parameter gives WKWebView a valid origin
-   The `allow` attribute grants necessary permissions
-   Responsive CSS ensures videos fit mobile screens

### Article Filtering System

**NEW SYSTEM**: Filter articles by read status and saved status

**Three-mode filter** (FilterMode enum):

-   `.showAll`: Display all articles (read and unread)
-   `.unreadOnly`: Show only unread articles (default on startup)
-   `.savedOnly`: Show only bookmarked articles

**UI Implementation**:

-   Filter menu in Articles tab header
-   Radio-button style selection (checkmark.circle.fill vs circle)
-   "Mark all as read" option with confirmation dialog
-   Dynamic empty states:
    -   "No Unread Articles" when unreadOnly filter active but none exist
    -   "No Saved Articles" when savedOnly filter active but none exist
-   Filter persists across navigation

**Swipe Actions**:

-   Swipe right on article → Bookmark/save toggle
-   Visual feedback: bookmark icon changes color
-   Saved articles appear in .savedOnly filter

### Article Swiping Navigation

The swipe gesture system provides buttery-smooth navigation between articles.

#### Gesture Detection (in WebViewContainer):

1. User touches screen → gesture begins
2. First 10px movement determines direction (horizontal or vertical)
3. If horizontal → disable WebView vertical scrolling, report pan changes
4. If vertical → let WebView handle scrolling normally
5. When finger lifts → report final translation

#### Animation Flow (in ArticleDetailView):

1. **User drags horizontally**:

    - `onPanChanged` updates `currentTranslation`
    - Layer 2 (incoming article) position calculated: `offset = screenWidth + currentTranslation`
    - User sees next/previous article sliding in from off-screen

2. **User releases finger past 40% threshold**:

    - `dragState` changes to `.animating`
    - Animation plays: incoming article slides to center (0.3s)
    - After animation: `selectedArticle` updated to incoming article
    - Layer 2 (incoming) hidden after 0.3s delay to let Layer 1 settle

3. **Article changes**:
    - New article renders in Layer 1 (centered)
    - All gesture state resets
    - Ready for next swipe

#### Boundary Handling:

-   **At last article**: Swiping left shows "End of Feed" boundary view

    -   Can swipe right on boundary view to go back to last article
    -   Or tap button to dismiss to article list

-   **At first article**: Swiping right shows "Beginning of Feed" boundary view
    -   Can swipe left on boundary view to go back to first article
    -   Or tap button to dismiss

#### Why This Works:

-   **Two-layer ZStack**: Current article (Layer 1) stays at x=0, incoming article (Layer 2) animates in
-   **Direct translation mapping**: User's finger directly controls incoming article position → feels responsive
-   **Delayed state reset**: After article changes, state resets after 0.3s delay → incoming layer stays visible during transition → no flicker
-   **Horizontal lock**: Once horizontal pan detected, vertical scrolling disabled → prevents accidental scroll-while-swiping

### Data Persistence

**SwiftData** handles all persistence:

-   Models decorated with `@Model` macro
-   Automatic CRUD operations
-   Queries use `@Query` with sort descriptors
-   Model changes automatically saved

**Important Notes**:

-   `uniqueId` field has default value (`UUID().uuidString`) for safe migration
-   Relationship: Feed 1:Many Article (via feedTitle)
-   No explicit foreign keys; relationships denormalized for simplicity

## Development Guidelines

### Adding a New Feature

1. **UI**: Add view in ContentView.swift or create new view file
2. **State Management**: Use `@State` for local state, `@Query` for database queries
3. **Theming**: Use `theme.backgroundColor`, `theme.textColor` etc.
4. **Navigation**: Use bindings ($) to pass state between views
5. **Testing**: Test on real device if involving gestures or animations

### Modifying Theming

1. Add/update CSS custom property in `variables-*.css` files
2. Add computed property in `ThemeColors.swift` extension
3. Use new property in views via `theme.propertyName`

### Adding a New Feed Source

1. Verify feed URL is valid RSS 2.0 or Atom 1.0
2. RSSFeedParser will auto-detect format
3. Add feed via app UI → FeedFetcher → RSSFeedParser → Database

### Debugging

**Useful print statements already in code**:

-   `print("📱 ArticleDetailView.body...")`: View hierarchy debugging
-   `print("🎬 ...")`: Swipe gesture flow
-   `print("⏱️ ...")`: Timer events

## Known Limitations

1. **No offline access**: Articles require internet to fetch initially, cached HTML viewable offline
2. **Limited Atom support**: Only fully tested with common Atom implementations
3. **No full-text search**: Only filter by read status, saved status, or feed
4. **No sync across devices**: All data stored locally only
5. **HTML rendering**: Limited to basic HTML; complex layouts may render poorly
6. **Feed discovery limitations**: Doesn't search subdomains (e.g., won't find feeds.example.com if you enter example.com)
7. **No video download**: Embedded videos stream only, not downloadable

## Future Enhancement Opportunities

-   Full-text search across articles
-   Read/unread sync across devices via iCloud
-   Custom fonts and font sizing
-   Article tagging and collections
-   Keyboard shortcuts for navigation
-   Share articles to other apps
-   Dark mode automatic scheduling
-   Feed update notifications
-   Watch history and reading time tracking
-   Private/encrypted article notes
-   Multi-device feed sync via cloud
-   Feed source categorization
-   Smart feed grouping and folders
