# RichRSS - iOS RSS Reader

A beautiful, feature-rich native iOS RSS reader built with SwiftUI. Designed for a delightful reading experience with smooth gestures, multiple themes, and persistent storage.

## Project Overview

RichRSS is a native iOS application that allows users to:
- Subscribe to RSS feeds (RSS 2.0 and Atom 1.0 formats)
- Read articles with a beautiful, distraction-free interface
- Navigate between articles with intuitive swipe gestures
- Switch between three themes: Light, Dark, and Sepia
- Manage feeds and articles with persistent storage
- Cache article HTML for faster loading

## Architecture

The app uses a modern SwiftUI-based architecture with the following key technologies:

- **SwiftUI**: Declarative UI framework for iOS
- **SwiftData**: Modern persistent storage framework
- **WKWebView**: For rendering article HTML content
- **XMLParser**: For parsing RSS and Atom feeds
- **Combine**: For async operations and state management

## Project File Structure

### Core App Files

#### `RichRSSApp.swift`
The app entry point. Configures the SwiftData container for persistent storage and initializes the root view.

#### `ContentView.swift` - **Main Navigation & Article Reading**
The core of the app. Contains:
- **ContentView**: Main app container with tab navigation (Articles, Feeds, Settings)
- **ArticlesListViewWithSelection**: Displays the list of articles with swipe-to-delete functionality
- **ArticleListItemView**: Individual article list item with feed badge, title, summary, author, and publication date
- **ArticleDetailView**: Full-screen article reader with swipe navigation between articles
  - Implements the swipe gesture system for navigating between articles
  - Manages boundary detection (beginning/end of feed)
  - Handles the smooth animation when swiping between articles
- **ArticleDetailViewContent**: Wrapper that combines the article header and WebView
- **ArticleHeaderView**: Displays feed title, author, publication date, and back button
- **EndOfFeedView**: Boundary view shown when reaching the last article
- **BeginningOfFeedView**: Boundary view shown when reaching the first article
- **DragState** enum: Tracks gesture state (idle, dragging, animating)

### Theme System

The theme system uses CSS variables for a single source of truth, with Swift extracting values at runtime.

#### `Theme.swift`
Defines the theme structure and available theme styles:
- **ThemeStyle** enum: `.light`, `.dark`, `.sepia`
- **Theme** struct: Contains the current style and provides CSS filename
- Maps theme styles to CSS variable files

#### `ThemeColors.swift`
Swift extension on Theme that extracts colors from CSS files at runtime:
- `backgroundColor`: Main background color
- `textColor`: Primary text color
- `accentColor`: Accent/link color
- `secondaryTextColor`: Secondary text color
- `borderColor`: Border color
- `codeBackgroundColor`: Code block background
- `blockquoteBackgroundColor`: Blockquote background

Includes `Color(hex:)` initializer for parsing hex colors from CSS.

#### `ThemeEnvironment.swift`
Provides SwiftUI environment integration:
- **ThemeKey**: EnvironmentKey for theme access
- `appTheme` environment value
- `.withTheme()` modifier for propagating theme through view hierarchy

#### CSS Files (`variables-light.css`, `variables-dark.css`, `variables-sepia.css`)
Define CSS custom properties (variables) for each theme:
- `--bg-color`: Background color
- `--text-color`: Text color
- `--accent-color`: Accent color
- And other theme-specific variables

#### `article.css`
Base styles for article content rendering:
- Typography settings
- Padding and spacing
- Link styling
- Code block styling
- Blockquote styling
- Image responsiveness

### Data Models

#### `Item.swift`
**Note**: This file is deprecated. Articles are now stored using the Article model in Feed.swift.

#### `Feed.swift`
SwiftData models for persistent storage:

**Feed model**:
- `id`: UUID string identifier
- `title`: User-provided feed name
- `feedUrl`: RSS feed URL
- `siteUrl`: Website URL (optional)
- `feedSummary`: Feed description
- `lastUpdated`: Last sync timestamp

**Article model**:
- `uniqueId`: UUID string (unique across all feeds)
- `guid`: Original feed GUID (may be duplicated across feeds)
- `title`: Article headline
- `summary`: Article description/excerpt
- `content`: Full HTML article content
- `link`: URL to original article
- `author`: Author name (optional)
- `pubDate`: Publication date
- `feedTitle`: Feed name (denormalized for easy display)
- `imageUrl`: Featured image URL (optional)
- `isRead`: Read/unread status

### Feed Management

#### `FeedsView.swift`
UI for managing user's feed subscriptions:
- Displays list of subscribed feeds with last updated timestamp
- Swipe-to-delete for removing feeds
- "Add Feed" button opens AddFeedView
- Empty state message when no feeds

#### `FeedFetcher.swift`
Handles async feed fetching and parsing:
- Fetches feed from URL
- Delegates parsing to RSSFeedParser
- Returns array of Article objects
- Error handling for network and parsing failures

#### `RSSFeedParser.swift`
XML parsing logic supporting both RSS 2.0 and Atom 1.0:
- Uses XMLParser delegate pattern
- Handles element navigation (`<item>` vs `<entry>`)
- Extracts article metadata
- Maps feed-specific field names to Article properties
- Cleans HTML content

### Article Display & Caching

#### `ArticleWebView.swift`
UIViewRepresentable wrapper for WKWebView:

**ArticleWebView struct**:
- Wraps WKWebView for SwiftUI
- Generates HTML with embedded CSS themes
- Caches HTML to disk for reuse
- Handles pan gestures for swipe navigation

**WebViewContainer class** (UIView subclass):
- Manages WKWebView instance
- Detects horizontal vs vertical pan gestures
- Disables vertical scrolling when horizontal pan detected (swipe lock)
- Continuous translation reporting during drag
- Reports gesture end with final translation
- Minimum 10px movement detection before determining gesture direction

#### `ArticleHTMLCache.swift`
Disk-based HTML caching for articles:
- Singleton instance (`ArticleHTMLCache.shared`)
- Stores HTML files in app's caches directory
- Uses article `uniqueId` as cache key
- `getCachedHTML()`: Retrieve cached HTML
- `cacheHTML()`: Save HTML to disk
- `clearCache()`: Wipe all cached articles (called from Settings)

#### `HTMLStripper.swift`
HTML sanitization utility:
- Removes dangerous `<script>` and `<style>` tags
- Uses regex pattern matching
- Called before rendering article content
- Prevents malicious content execution

### Settings & Data Management

#### `SettingsView.swift`
User preferences and data management:
- Theme selector (Light/Dark/Sepia)
- App version display
- "Remove Everything" button to:
  - Delete all articles from database
  - Delete all feeds from database
  - Reset theme to Light
  - Clear article HTML cache

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

### Feed Adding & Parsing

1. **User enters feed URL**: FeedsView shows AddFeedView sheet
2. **FeedFetcher fetches URL**: Downloads XML from remote server
3. **RSSFeedParser parses XML**: Determines if RSS 2.0 or Atom 1.0, extracts articles
4. **Articles inserted to database**: Each article gets unique UUID
5. **Feed created in database**: Linked to articles via feedTitle
6. **UI updates**: New articles appear in ArticlesListViewWithSelection

**Key Design Decisions**:
- Each article has a `uniqueId` (UUID) to handle duplicate feed GUIDs across feeds
- `feedTitle` is denormalized into Article for easy display without joins
- HTML is cached immediately after fetching to speed up subsequent views

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
- **At last article**: Swiping left shows "End of Feed" boundary view
  - Can swipe right on boundary view to go back to last article
  - Or tap button to dismiss to article list

- **At first article**: Swiping right shows "Beginning of Feed" boundary view
  - Can swipe left on boundary view to go back to first article
  - Or tap button to dismiss

#### Why This Works:
- **Two-layer ZStack**: Current article (Layer 1) stays at x=0, incoming article (Layer 2) animates in
- **Direct translation mapping**: User's finger directly controls incoming article position → feels responsive
- **Delayed state reset**: After article changes, state resets after 0.3s delay → incoming layer stays visible during transition → no flicker
- **Horizontal lock**: Once horizontal pan detected, vertical scrolling disabled → prevents accidental scroll-while-swiping

### Data Persistence

**SwiftData** handles all persistence:
- Models decorated with `@Model` macro
- Automatic CRUD operations
- Queries use `@Query` with sort descriptors
- Model changes automatically saved

**Important Notes**:
- `uniqueId` field has default value (`UUID().uuidString`) for safe migration
- Relationship: Feed 1:Many Article (via feedTitle)
- No explicit foreign keys; relationships denormalized for simplicity

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
- `print("📱 ArticleDetailView.body...")`: View hierarchy debugging
- `print("🎬 ...")`: Swipe gesture flow
- `print("⏱️ ...")`: Timer events

## Known Limitations

1. **No offline sync**: Feeds only fetch when user explicitly adds them
2. **Limited Atom support**: Only fully tested with common Atom implementations
3. **No search/filter**: Articles displayed in reverse chronological order only
4. **No sync across devices**: All data stored locally only
5. **HTML rendering**: Limited to basic HTML; complex layouts may render poorly

## Future Enhancement Opportunities

- Background fetch for automatic feed updates
- Full-text search across articles
- Read/unread sync across devices via iCloud
- Custom fonts and font sizing
- Article tagging and collections
- Keyboard shortcuts for navigation
- Share articles to other apps
- Dark mode automatic scheduling
