# Background Feed Refresh Implementation Plan

## Overview

This document outlines the phased approach to implementing background feed refresh capabilities for RichRSS. The implementation is designed to be incremental, ensuring the app remains functional and testable at each stage.

## Current State Analysis

### What We Have
- ✅ `lastUpdated: Date?` field on Feed model (`Feed.swift:18`)
- ✅ Basic feed refresh logic in `FeedFetcher.swift`
- ✅ Pull-to-refresh on Articles tab
- ✅ SwiftData for local storage

### What Needs Work
- ❌ **Sequential refresh** - feeds fetched one at a time (`FeedFetcher.swift:44-59`)
- ❌ **Bulk timestamp updates** - all feeds marked updated together, even if some fail (`ContentView.swift:383-385`)
- ❌ **Basic date display** - shows full date instead of relative time ("Nov 18, 2025" vs "2 hours ago")
- ❌ **No per-feed refresh** - can't refresh individual feeds
- ❌ **No background refresh** - no BGTaskScheduler implementation
- ❌ **No user settings** - no UI for controlling refresh behavior

---

## Phase 1: Plan & Documentation ✓

**Goal**: Create comprehensive plan document (this file)

**Deliverables**:
- [x] Current state analysis
- [x] Phased implementation plan
- [x] Technical design decisions
- [x] Testing strategy

---

## Phase 2: Preparatory Changes (Foundation)

**Goal**: Refactor refresh infrastructure to support individual feed updates and ensure robust error handling

**Why This First**: These changes improve the existing functionality and create the foundation for background refresh, while keeping the app fully functional and testable.

### 2.1 Refactor Feed Refresh Logic

**File**: `FeedFetcher.swift`

**Changes**:
1. Add new method for single-feed refresh:
   ```swift
   func refreshFeed(_ feed: Feed) async throws -> (articles: [Article], feedMetadata: FeedMetadata)
   ```

2. Update return type to include per-feed success/failure info:
   ```swift
   struct FeedRefreshResult {
       let feedId: String
       let articles: [Article]
       let success: Bool
       let error: Error?
       let timestamp: Date
   }

   func refreshAllFeeds(feeds: [Feed]) async -> [FeedRefreshResult]
   ```

3. Ensure each feed's result includes its own timestamp

**Benefits**:
- Individual feed refresh capability (needed for UI later)
- Better error tracking per feed
- Enables selective timestamp updates (only update successful refreshes)

### 2.2 Update Timestamp Management

**Files**:
- `ContentView.swift` (lines 383-385)
- `AppStartupManager.swift` (lines 28-56)
- `FeedsView.swift` (add feed feature)

**Changes**:
1. Remove bulk `feed.lastUpdated = Date()` logic
2. Update `lastUpdated` **only for successfully refreshed feeds**:
   ```swift
   // Old (updates all):
   for feed in feeds {
       feed.lastUpdated = Date()
   }

   // New (updates only successful):
   for result in refreshResults where result.success {
       if let feed = feeds.first(where: { $0.id == result.feedId }) {
           feed.lastUpdated = result.timestamp
       }
   }
   ```

3. Ensure failed feeds retain their previous `lastUpdated` value

**Benefits**:
- Accurate "last updated" times per feed
- User can see which feeds refreshed successfully
- Failed feeds don't mislead users with false timestamps

### 2.3 Add Refresh State Tracking (Optional but Recommended)

**File**: `Feed.swift`

**Changes**:
Consider adding ephemeral (non-persisted) refresh state:
```swift
@Model
final class Feed {
    // ... existing fields ...
    var lastUpdated: Date?
    var lastRefreshError: String?  // Persisted error message (optional)

    // Transient state (not persisted):
    @Transient var isRefreshing: Bool = false
}
```

**Benefits**:
- UI can show loading spinner on individual feeds
- Better UX during refresh operations
- Useful for per-feed refresh UI in Phase 5

### 2.4 Testing Checklist for Phase 2

- [ ] Pull-to-refresh still works on Articles tab
- [ ] Manual "Add Feed" still works
- [ ] App startup refresh still works
- [ ] Failed feed refreshes don't update timestamp
- [ ] Successful refreshes update timestamp correctly
- [ ] Mixed success/failure scenarios handled gracefully
- [ ] No regressions in existing functionality

**Completion Criteria**: All refresh operations work as before, but with accurate per-feed timestamps

---

## Phase 3: Parallel Feed Fetching

**Goal**: Speed up feed refresh by fetching multiple feeds concurrently

**Why This Now**: With per-feed result tracking from Phase 2, we can safely parallelize while maintaining accurate status per feed.

### 3.1 Implement Concurrent Refresh

**File**: `FeedFetcher.swift`

**Changes**:
Replace sequential loop with TaskGroup:

```swift
func refreshAllFeeds(feeds: [Feed]) async -> [FeedRefreshResult] {
    await withTaskGroup(of: FeedRefreshResult.self) { group in
        var results: [FeedRefreshResult] = []

        // Launch concurrent tasks (one per feed)
        for feed in feeds {
            group.addTask {
                do {
                    let (articles, metadata) = try await self.fetchFeed(
                        from: feed.feedUrl,
                        feedTitle: feed.title
                    )
                    return FeedRefreshResult(
                        feedId: feed.id,
                        articles: articles,
                        success: true,
                        error: nil,
                        timestamp: Date()
                    )
                } catch {
                    return FeedRefreshResult(
                        feedId: feed.id,
                        articles: [],
                        success: false,
                        error: error,
                        timestamp: Date()
                    )
                }
            }
        }

        // Collect results as they complete
        for await result in group {
            results.append(result)
        }

        return results
    }
}
```

### 3.2 Add Concurrency Limits (Optional but Recommended)

**Consideration**: Fetching 50+ feeds simultaneously might:
- Overwhelm the device's network connections
- Trigger rate limiting on servers
- Consume excessive memory

**Solution**: Limit concurrent tasks:
```swift
// Option 1: Simple semaphore approach
let maxConcurrentFeeds = 5

// Option 2: Batched TaskGroup (recommended)
func refreshAllFeeds(feeds: [Feed], maxConcurrent: Int = 5) async -> [FeedRefreshResult]
```

**Recommended limit**: 5-10 concurrent feeds

### 3.3 Performance Monitoring

**Add logging to measure improvement**:
```swift
let startTime = Date()
let results = await feedFetcher.refreshAllFeeds(feeds: feeds)
let duration = Date().timeIntervalSince(startTime)
print("✅ Refreshed \(feeds.count) feeds in \(duration)s")
```

### 3.4 Testing Checklist for Phase 3

- [ ] All feeds refresh successfully with parallel fetching
- [ ] Mixed success/failure scenarios work correctly
- [ ] No crashes or memory issues with many feeds (test with 20+ feeds)
- [ ] Network errors handled gracefully
- [ ] Performance improvement measured (should be significantly faster)
- [ ] Concurrent limit respected (if implemented)
- [ ] UI remains responsive during refresh

**Completion Criteria**: Feed refresh is 3-5x faster with no regressions

---

## Phase 4: Granular "Last Updated" UI

**Goal**: Display relative time instead of absolute dates ("2 hours ago" vs "Nov 18, 2025")

**Why This Now**: With accurate per-feed timestamps from Phase 2, we can show meaningful relative times.

### 4.1 Create Relative Time Formatter

**New File**: `RichRSS/Utilities/RelativeTimeFormatter.swift`

**Implementation**:
```swift
import Foundation

extension Date {
    func relativeTimeString() -> String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        // Future dates (shouldn't happen, but handle gracefully)
        guard interval >= 0 else {
            return "just now"
        }

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        switch interval {
        case 0..<60:
            return "just now"
        case 60..<3600:
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        case 3600..<86400:
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        case 86400..<(86400 * 7):
            return days == 1 ? "1 day ago" : "\(days) days ago"
        case (86400 * 7)..<(86400 * 30):
            let weeks = days / 7
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        default:
            // For anything older than ~1 month, show actual date
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }
}
```

### 4.2 Update FeedsView UI

**File**: `FeedsView.swift` (lines 126-130)

**Changes**:
```swift
// Before:
if let lastUpdated = feed.lastUpdated {
    Text("Last updated: \(lastUpdated, style: .date)")
        .font(.caption2)
        .foregroundColor(.secondary)
}

// After:
if let lastUpdated = feed.lastUpdated {
    Text("Last updated: \(lastUpdated.relativeTimeString())")
        .font(.caption2)
        .foregroundColor(.secondary)
} else {
    Text("Never updated")
        .font(.caption2)
        .foregroundColor(.secondary)
}
```

### 4.3 Consider Dynamic Updates (Optional Enhancement)

**Challenge**: "5 minutes ago" becomes stale if user keeps app open

**Solution Options**:
1. **Simple**: Updates when view appears or refresh happens (recommended for MVP)
2. **Advanced**: Use Timer to update every minute:
   ```swift
   .onReceive(timer) { _ in
       // Trigger view refresh to update relative times
   }
   ```

**Recommendation**: Start with option 1, add option 2 later if users request it

### 4.4 Update Other Views Using Dates

**Check these locations for consistency**:
- Article list (`ContentView.swift`) - already uses relative dates for posts
- Feed detail view (if any)
- Any refresh status messages

### 4.5 Testing Checklist for Phase 4

- [ ] "just now" displays for <1 minute
- [ ] Minutes (1-59) display correctly
- [ ] Hours (1-23) display correctly
- [ ] Days (1-6) display correctly
- [ ] Weeks (1-4) display correctly
- [ ] Old dates (>1 month) show absolute date
- [ ] Nil `lastUpdated` shows "Never updated"
- [ ] Times update when app is reopened
- [ ] Consistent formatting across all views

**Completion Criteria**: All "Last updated" displays show human-friendly relative times

---

## Phase 5: Settings UI for Background Refresh

**Goal**: Add user-facing controls for background refresh preferences

**Why This Now**: Settings UI should exist before implementing the actual background refresh, so users can control it from day one.

### 5.1 Create Settings Data Model

**New File**: `RichRSS/Models/AppSettings.swift`

**Implementation**:
```swift
import Foundation
import SwiftData

@Model
final class AppSettings {
    var backgroundRefreshEnabled: Bool = false
    var wifiOnlyRefresh: Bool = true
    var lastBackgroundRefreshDate: Date?

    // Optional: Advanced settings for future
    var refreshInterval: RefreshInterval = .hourly
    var maxConcurrentRefreshes: Int = 5

    init() {
        self.backgroundRefreshEnabled = false
        self.wifiOnlyRefresh = true
    }
}

enum RefreshInterval: String, Codable, CaseIterable {
    case fifteenMinutes = "Every 15 minutes"
    case thirtyMinutes = "Every 30 minutes"
    case hourly = "Hourly"
    case fourHours = "Every 4 hours"
    case daily = "Daily"

    var seconds: TimeInterval {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .hourly: return 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .daily: return 24 * 60 * 60
        }
    }
}
```

**Note**: iOS Background App Refresh doesn't guarantee these intervals, but they serve as "hints" to the system.

### 5.2 Update SettingsView

**File**: `SettingsView.swift`

**Changes**:
Add new section after "Appearance":

```swift
// Add query for settings
@Query private var settingsObjects: [AppSettings]
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
    Form {
        // ... existing Appearance section ...

        Section {
            Toggle(isOn: $settings.backgroundRefreshEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Background Refresh")
                        .font(.body)
                    Text("Automatically refresh feeds in the background")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Sub-option: only shown when background refresh is enabled
            if settings.backgroundRefreshEnabled {
                Toggle(isOn: $settings.wifiOnlyRefresh) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wi-Fi Only")
                            .font(.body)
                        Text("Refresh feeds only when connected to Wi-Fi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!settings.backgroundRefreshEnabled)

                // Optional: Show last background refresh time
                if let lastRefresh = settings.lastBackgroundRefreshDate {
                    HStack {
                        Text("Last Background Refresh")
                            .font(.caption)
                        Spacer()
                        Text(lastRefresh.relativeTimeString())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Feed Refresh")
        } footer: {
            Text("Background refresh requires iOS permission and may not occur if Low Power Mode is enabled or battery is low.")
                .font(.caption)
        }

        // ... existing About and Data sections ...
    }
}
```

### 5.3 Register AppSettings with SwiftData

**File**: `RichRSSApp.swift`

**Changes**:
Update model container schema:
```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Feed.self,
        Article.self,
        AppSettings.self  // Add this
    ])
    // ... rest of configuration ...
}()
```

### 5.4 Handle Settings Changes

**Add logic to register/unregister background tasks**:
```swift
// In SettingsView or a dedicated manager
.onChange(of: settings.backgroundRefreshEnabled) { oldValue, newValue in
    if newValue {
        BackgroundRefreshManager.shared.registerBackgroundTasks()
    } else {
        BackgroundRefreshManager.shared.cancelBackgroundTasks()
    }
}
```

### 5.5 Testing Checklist for Phase 5

- [ ] Settings section appears correctly
- [ ] Background Refresh toggle works
- [ ] Wi-Fi Only toggle only appears when Background Refresh is enabled
- [ ] Wi-Fi Only defaults to enabled
- [ ] Settings persist across app restarts
- [ ] Multiple app instances don't create duplicate settings
- [ ] Footer text explains iOS limitations clearly
- [ ] Last refresh time displays correctly (if implemented)

**Completion Criteria**: Users can enable/disable background refresh, all settings persist correctly

---

## Phase 6: Background Refresh Implementation

**Goal**: Implement BGTaskScheduler to refresh feeds in the background

**Why This Last**: All infrastructure is in place - we're just adding the iOS-specific background task scheduling.

### 6.1 Add Background Modes Capability

**File**: `RichRSS.xcodeproj` (Xcode project settings)

**Steps**:
1. Select RichRSS target
2. Go to "Signing & Capabilities" tab
3. Click "+ Capability"
4. Add "Background Modes"
5. Enable "Background fetch" checkbox

### 6.2 Register Background Task Identifier

**File**: `Info.plist`

**Changes**:
Add permitted background task scheduler identifiers:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.richrss.feedrefresh</string>
</array>
```

### 6.3 Create Background Refresh Manager

**New File**: `RichRSS/Managers/BackgroundRefreshManager.swift`

**Implementation**:
```swift
import Foundation
import BackgroundTasks
import SwiftData

@MainActor
class BackgroundRefreshManager: ObservableObject {
    static let shared = BackgroundRefreshManager()

    private let taskIdentifier = "com.richrss.feedrefresh"
    private let modelContainer: ModelContainer

    init() {
        // Initialize model container for background context
        let schema = Schema([Feed.self, Article.self, AppSettings.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Registration

    func registerBackgroundTasks() {
        // Register handler
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }

        // Schedule next refresh
        scheduleNextRefresh()
    }

    func cancelBackgroundTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }

    // MARK: - Scheduling

    private func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)

        // iOS will decide when to actually run this based on user behavior
        // This is our "earliest" time - could be much later
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background refresh scheduled")
        } catch {
            print("⚠️ Could not schedule background refresh: \(error)")
        }
    }

    // MARK: - Background Task Handler

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        print("🔄 Background refresh started")

        // Schedule the next refresh before starting work
        scheduleNextRefresh()

        // Set expiration handler
        task.expirationHandler = {
            print("⏱️ Background refresh expired")
            task.setTaskCompleted(success: false)
        }

        // Perform refresh
        Task {
            let success = await performBackgroundRefresh()
            task.setTaskCompleted(success: success)
        }
    }

    // MARK: - Refresh Logic

    private func performBackgroundRefresh() async -> Bool {
        let context = ModelContext(modelContainer)

        do {
            // Fetch settings
            let settingsDescriptor = FetchDescriptor<AppSettings>()
            guard let settings = try context.fetch(settingsDescriptor).first else {
                print("⚠️ No settings found")
                return false
            }

            // Check if background refresh is enabled
            guard settings.backgroundRefreshEnabled else {
                print("ℹ️ Background refresh disabled in settings")
                return true // Not an error, just disabled
            }

            // Check Wi-Fi requirement
            if settings.wifiOnlyRefresh && !isConnectedToWiFi() {
                print("ℹ️ Skipping refresh: Wi-Fi required but not connected")
                return true // Not an error, waiting for Wi-Fi
            }

            // Fetch all feeds
            let feedsDescriptor = FetchDescriptor<Feed>()
            let feeds = try context.fetch(feedsDescriptor)

            guard !feeds.isEmpty else {
                print("ℹ️ No feeds to refresh")
                return true
            }

            // Perform refresh
            let feedFetcher = FeedFetcher()
            let results = await feedFetcher.refreshAllFeeds(feeds: feeds)

            // Update feeds with results
            for result in results where result.success {
                if let feed = feeds.first(where: { $0.id == result.feedId }) {
                    feed.lastUpdated = result.timestamp

                    // Save new articles
                    for article in result.articles {
                        context.insert(article)
                    }
                }
            }

            // Update last background refresh time
            settings.lastBackgroundRefreshDate = Date()

            // Save context
            try context.save()

            let successCount = results.filter { $0.success }.count
            print("✅ Background refresh completed: \(successCount)/\(feeds.count) feeds updated")

            return true

        } catch {
            print("❌ Background refresh failed: \(error)")
            return false
        }
    }

    // MARK: - Network Checking

    private func isConnectedToWiFi() -> Bool {
        // Use Network framework to check connection type
        import Network

        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        var isWiFi = false

        monitor.pathUpdateHandler = { path in
            isWiFi = path.usesInterfaceType(.wifi)
            semaphore.signal()
        }

        let queue = DispatchQueue(label: "WiFiCheck")
        monitor.start(queue: queue)
        semaphore.wait()
        monitor.cancel()

        return isWiFi
    }
}
```

### 6.4 Update App Delegate / App Lifecycle

**File**: `RichRSSApp.swift`

**Changes**:
```swift
import BackgroundTasks

@main
struct RichRSSApp: App {
    // ... existing code ...

    init() {
        // Register background tasks early
        BackgroundRefreshManager.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .onAppear {
                    // Check settings and register if needed
                    Task {
                        await checkBackgroundRefreshSettings()
                    }
                }
        }
    }

    @MainActor
    private func checkBackgroundRefreshSettings() async {
        let context = ModelContext(sharedModelContainer)
        let descriptor = FetchDescriptor<AppSettings>()

        if let settings = try? context.fetch(descriptor).first,
           settings.backgroundRefreshEnabled {
            BackgroundRefreshManager.shared.registerBackgroundTasks()
        }
    }
}
```

### 6.5 Update Settings to Trigger Registration

**File**: `SettingsView.swift`

**Changes**:
Add onChange handler (from Phase 5.4):
```swift
.onChange(of: settings.backgroundRefreshEnabled) { oldValue, newValue in
    if newValue {
        BackgroundRefreshManager.shared.registerBackgroundTasks()
    } else {
        BackgroundRefreshManager.shared.cancelBackgroundTasks()
    }
}
```

### 6.6 Add Debugging Support

**For development/testing**, add simulator debugging arguments:

**File**: Edit scheme → Run → Arguments

Add environment variable:
```
-BGTaskSchedulerSchedulingEnabled YES
```

**Testing background refresh in simulator**:
```bash
# In Terminal, while app is running:
xcrun simctl spawn booted log stream --predicate 'subsystem contains "com.richrss"'

# Trigger background refresh:
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.richrss.feedrefresh"]
```

### 6.7 Handle Background Refresh Permission

**Add user education**:
- Show alert when user enables background refresh explaining iOS settings
- Provide link to Settings app if permission denied
- Check `BGTaskScheduler` status and inform user

**Optional enhancement in SettingsView**:
```swift
Button("Open Background App Refresh Settings") {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}
```

### 6.8 Performance Optimizations

**Implement smart refresh strategies for 30-second limit**:

1. **Prioritize feeds**:
   - Favorite feeds first
   - Recently viewed feeds
   - Feeds with most frequent updates

2. **Conditional requests**:
   - Use HTTP `If-Modified-Since` headers
   - Skip feeds updated in last N minutes

3. **Batch limits**:
   ```swift
   // Refresh max 10 feeds per background task
   let feedsToRefresh = feeds
       .sorted { ($0.isFavorite ? 0 : 1, $0.lastUpdated ?? .distantPast) < ($1.isFavorite ? 0 : 1, $1.lastUpdated ?? .distantPast) }
       .prefix(10)
   ```

4. **Track refresh duration**:
   ```swift
   let startTime = Date()
   // ... perform refresh ...
   let duration = Date().timeIntervalSince(startTime)

   if duration > 25 {
       print("⚠️ Background refresh took \(duration)s - approaching limit!")
   }
   ```

### 6.9 Testing Checklist for Phase 6

**Functionality**:
- [ ] Background task registers successfully
- [ ] Background task can be triggered in simulator
- [ ] Feeds refresh correctly in background
- [ ] lastUpdated timestamps update correctly
- [ ] New articles appear after background refresh
- [ ] Wi-Fi only setting respected
- [ ] Settings toggle properly enables/disables background refresh
- [ ] Background refresh completes within 30 seconds

**Edge Cases**:
- [ ] No crashes if no feeds exist
- [ ] Handles network errors gracefully
- [ ] Handles task expiration correctly
- [ ] Multiple background refreshes don't conflict
- [ ] Settings changes while background task running
- [ ] App deletion/reinstall clears scheduled tasks

**Real Device Testing** (required before shipping):
- [ ] Test on real device (simulator behavior differs)
- [ ] Verify Background App Refresh permission in Settings
- [ ] Test with Low Power Mode enabled (should not run)
- [ ] Test on cellular vs Wi-Fi
- [ ] Leave app in background for hours and verify refresh occurs
- [ ] Check battery impact over several days

**Completion Criteria**: Background refresh works reliably on real devices with user's permission

---

## Additional Considerations

### Battery Impact Mitigation

**Strategies to minimize battery drain**:
1. Use conditional HTTP requests (If-Modified-Since)
2. Implement exponential backoff for failed feeds
3. Skip feeds that rarely update
4. Respect system's scheduling decisions (don't fight the OS)
5. Minimize parsing/processing work

### Error Handling & Logging

**Implement robust logging**:
- Use `OSLog` for debugging background tasks
- Track success/failure rates per feed
- Surface errors to user if persistent

### User Education

**Consider adding**:
- First-time setup wizard explaining background refresh
- Help/FAQ section in settings
- Troubleshooting guide if background refresh not working

### Future Enhancements (Out of Scope for MVP)

1. **Silent Push Notifications** (requires server):
   - More reliable than Background App Refresh
   - Near real-time updates
   - Better battery life (server monitors feeds, not device)

2. **Selective Feed Refresh**:
   - User-configurable per-feed refresh settings
   - "Don't refresh this feed in background" option

3. **Smart Refresh Scheduling**:
   - ML-based prediction of when user will open app
   - Adapt refresh timing to user's reading habits

4. **Refresh Analytics**:
   - Show user statistics on refresh success rates
   - Data usage tracking
   - Battery usage attribution

---

## Timeline Estimate

| Phase | Estimated Effort | Dependencies |
|-------|-----------------|--------------|
| Phase 1: Planning | ✅ Complete | None |
| Phase 2: Preparatory Changes | 2-3 hours | None |
| Phase 3: Parallel Fetching | 1-2 hours | Phase 2 |
| Phase 4: Granular UI | 1 hour | Phase 2 |
| Phase 5: Settings UI | 1-2 hours | Phase 4 |
| Phase 6: Background Refresh | 3-4 hours | Phases 2, 3, 5 |
| **Testing & Polish** | 2-3 hours | All phases |
| **Total** | **10-15 hours** | - |

**Note**: Timeline assumes familiarity with iOS development and Swift. Real-device testing may reveal issues requiring additional time.

---

## Success Criteria

**Phase 2-3 Complete**:
- ✅ Feeds refresh in parallel
- ✅ Per-feed timestamps accurate
- ✅ Failed refreshes don't corrupt timestamps
- ✅ Existing functionality intact

**Phase 4-5 Complete**:
- ✅ Human-friendly relative times displayed
- ✅ Settings UI functional and intuitive
- ✅ All settings persist correctly

**Phase 6 Complete**:
- ✅ Background refresh works on real devices
- ✅ Respects user preferences (Wi-Fi only, enabled/disabled)
- ✅ Completes within iOS time limits (30s)
- ✅ No excessive battery drain
- ✅ User understands how to enable/use feature

---

## Risk Mitigation

| Risk | Mitigation Strategy |
|------|---------------------|
| Background refresh unreliable on iOS | Document limitations clearly, consider silent push for future |
| 30-second timeout exceeded | Implement feed prioritization, batch limits, performance monitoring |
| Battery drain complaints | Smart refresh strategies, conditional requests, respect system decisions |
| User confusion about iOS permissions | Clear UI messaging, setup wizard, link to Settings |
| Regression in existing functionality | Comprehensive testing at each phase, maintain working app throughout |
| Network errors during background refresh | Robust error handling, retry logic, graceful degradation |

---

## Questions for Consideration

1. **Refresh Interval UI**: Should we expose refresh interval settings to users, or rely entirely on iOS's intelligent scheduling?
   - **Recommendation**: Start without exposing interval (rely on iOS), add later if users request it

2. **Notification on New Articles**: Should background refresh show a notification when new articles are found?
   - **Recommendation**: Not for MVP, but good future enhancement (would require notification permissions)

3. **Data Usage Tracking**: Should we track and display data usage from refreshes?
   - **Recommendation**: Not for MVP, add later if battery/data concerns arise

4. **Per-Feed Refresh Settings**: Should users be able to disable background refresh for specific feeds?
   - **Recommendation**: Not for MVP, but architectural changes in Phase 2 make this easy to add later

---

## Conclusion

This phased approach ensures:
- ✅ App remains functional and testable at every stage
- ✅ Each phase builds logically on previous work
- ✅ User experience improvements delivered incrementally
- ✅ Background refresh is well-integrated and respects iOS best practices

The plan prioritizes stability, testability, and user control while delivering a feature that significantly improves the app's value proposition for RSS power users.

**Next Step**: Begin Phase 2 implementation with preparatory changes to refresh infrastructure.
