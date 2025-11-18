# Phase 5: Settings UI for Background Refresh - Implementation Summary

## Overview
Phase 5 adds the user-facing settings controls for background refresh. Users can now enable/disable background refresh and control whether it only works on Wi-Fi. The actual background refresh functionality will be implemented in Phase 6.

## Changes Made

### 1. AppSettings.swift (New File)

**Created**: `RichRSS/AppSettings.swift`

A SwiftData model to persist background refresh settings:

```swift
@Model
final class AppSettings {
    var backgroundRefreshEnabled: Bool = false
    var wifiOnlyRefresh: Bool = true
    var lastBackgroundRefreshDate: Date?
}
```

**Fields:**
- `backgroundRefreshEnabled`: Master toggle (default: `false` - opt-in)
- `wifiOnlyRefresh`: Restrict refresh to Wi-Fi only (default: `true`)
- `lastBackgroundRefreshDate`: Timestamp of last successful background refresh

**Design Decisions:**
- Background refresh is **disabled by default** (opt-in for battery/data concerns)
- Wi-Fi only is **enabled by default** (respectful of cellular data)
- Settings persist across app sessions via SwiftData

### 2. RichRSSApp.swift

**Updated**: Schema registration

Added `AppSettings.self` to the SwiftData schema:

```swift
let schema = Schema([
    Feed.self,
    Article.self,
    AppSettings.self,  // NEW
])
```

**Effect:**
- AppSettings can now be stored and queried
- SwiftData handles database migration automatically
- Settings persist across app launches

### 3. SettingsView.swift

**Major Update**: Added "Feed Refresh" section with toggles

**New UI Elements:**

1. **Background Refresh Toggle**
   - Label: "Background Refresh"
   - Description: "Automatically refresh feeds in the background"
   - Default: OFF
   - Behavior: Shows/hides Wi-Fi toggle when enabled

2. **Wi-Fi Only Toggle**
   - Label: "Wi-Fi Only"
   - Description: "Refresh feeds only when connected to Wi-Fi"
   - Default: ON
   - Visibility: Only shown when Background Refresh is enabled
   - State: Disabled when Background Refresh is off

3. **Last Background Refresh Display**
   - Shows: "Last Background Refresh: X hours ago"
   - Visibility: Only shown when Background Refresh is enabled AND a refresh has occurred
   - Format: Uses our unified `relativeTimeString()` format

4. **Section Footer**
   - Explains iOS limitations and behavior
   - Sets proper expectations about refresh reliability

**Settings Management:**

Added smart settings getter that:
- Returns existing settings if found
- Creates new settings object if none exists
- Ensures settings are always available

```swift
private var settings: AppSettings {
    if let existing = settingsObjects.first {
        return existing
    } else {
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        return newSettings
    }
}
```

**Handler Methods:**

Added `handleBackgroundRefreshToggle()`:
- Called when user toggles background refresh
- Contains TODO placeholders for Phase 6 implementation
- Will register/unregister background tasks in Phase 6

Updated `resetAllData()`:
- Now also deletes AppSettings when removing everything
- Ensures clean slate when user resets app

## User Interface

### Settings Screen Layout

```
┌─────────────────────────────────┐
│ Settings                        │
├─────────────────────────────────┤
│                                 │
│ ▼ Appearance                    │
│   Theme: [System ▼]             │
│                                 │
│ ▼ Feed Refresh                  │
│   ⚪ Background Refresh          │
│      Automatically refresh      │
│      feeds in the background    │
│                                 │
│   (When enabled:)               │
│   ✓ Wi-Fi Only                  │
│      Refresh feeds only when    │
│      connected to Wi-Fi         │
│                                 │
│   Last Background Refresh:      │
│   2 hours ago                   │
│                                 │
│   Background refresh requires   │
│   iOS permission and may not    │
│   occur if Low Power Mode is    │
│   enabled or battery is low...  │
│                                 │
│ ▼ About                         │
│   Version: 1.0                  │
│                                 │
│ ▼ Data                          │
│   🗑️ Remove Everything          │
│                                 │
└─────────────────────────────────┘
```

### UI States

**State 1: Background Refresh Disabled (Default)**
- Shows: Background Refresh toggle (OFF)
- Hides: Wi-Fi Only toggle
- Hides: Last refresh timestamp
- Footer: Visible

**State 2: Background Refresh Enabled, Never Run**
- Shows: Background Refresh toggle (ON)
- Shows: Wi-Fi Only toggle (defaults ON)
- Hides: Last refresh timestamp (none yet)
- Footer: Visible

**State 3: Background Refresh Enabled, Has Run**
- Shows: Background Refresh toggle (ON)
- Shows: Wi-Fi Only toggle
- Shows: Last refresh timestamp
- Footer: Visible

## User Experience Flow

### Enabling Background Refresh

1. User opens Settings tab
2. Taps "Background Refresh" toggle
3. Toggle switches ON
4. Wi-Fi Only toggle appears (already ON)
5. Footer explains iOS behavior
6. (Phase 6: Background tasks are registered)

### Changing Wi-Fi Preference

1. User has Background Refresh enabled
2. Taps "Wi-Fi Only" toggle
3. Toggle switches ON/OFF
4. Preference saved immediately
5. (Phase 6: Will affect when refresh occurs)

### Disabling Background Refresh

1. User taps "Background Refresh" toggle OFF
2. Wi-Fi toggle disappears
3. Last refresh timestamp disappears
4. (Phase 6: Background tasks are cancelled)

## Data Persistence

### How Settings Are Stored

**First Launch:**
1. User opens Settings
2. No AppSettings object exists
3. Getter creates new AppSettings with defaults
4. Inserted into SwiftData
5. Settings persist

**Subsequent Launches:**
1. User opens Settings
2. Query finds existing AppSettings
3. Getter returns existing object
4. Current preferences shown

**After Toggling:**
1. User changes toggle
2. Binding updates AppSettings property
3. SwiftData auto-saves changes
4. Preference persists immediately

### Database Migration

SwiftData handles migration automatically because:
- AppSettings is a new model (no existing data to migrate)
- All fields have default values
- No complex relationships to existing models

If you're upgrading from an earlier version:
- App launches normally
- No data loss
- Settings start with defaults
- No manual migration needed

## Phase 6 Integration Points

### Placeholders Added

The following TODO placeholders were added for Phase 6:

```swift
private func handleBackgroundRefreshToggle(enabled: Bool) {
    if enabled {
        print("ℹ️ Background refresh enabled - will be implemented in Phase 6")
        // TODO: Phase 6 - Register background tasks
        // BackgroundRefreshManager.shared.registerBackgroundTasks()
    } else {
        print("ℹ️ Background refresh disabled - will be implemented in Phase 6")
        // TODO: Phase 6 - Cancel background tasks
        // BackgroundRefreshManager.shared.cancelBackgroundTasks()
    }
}
```

### What Phase 6 Will Add

When implementing Phase 6, we'll:
1. Create `BackgroundRefreshManager` class
2. Implement `registerBackgroundTasks()` method
3. Implement `cancelBackgroundTasks()` method
4. Uncomment the TODO lines in `handleBackgroundRefreshToggle()`
5. Add actual BGTaskScheduler integration

## Testing Checklist

### Basic Functionality
- [ ] Open Settings tab
- [ ] "Feed Refresh" section appears
- [ ] Background Refresh toggle shows (OFF by default)
- [ ] Wi-Fi Only toggle is hidden initially

### Enabling Background Refresh
- [ ] Tap Background Refresh toggle
- [ ] Toggle switches to ON
- [ ] Wi-Fi Only toggle appears (ON by default)
- [ ] Footer text explains iOS behavior
- [ ] Console shows: "ℹ️ Background refresh enabled - will be implemented in Phase 6"

### Wi-Fi Only Toggle
- [ ] With Background Refresh ON, Wi-Fi toggle is enabled
- [ ] Can toggle Wi-Fi ON/OFF
- [ ] Changes persist when leaving and returning to Settings

### Disabling Background Refresh
- [ ] Tap Background Refresh toggle OFF
- [ ] Wi-Fi Only toggle disappears
- [ ] Console shows: "ℹ️ Background refresh disabled - will be implemented in Phase 6"

### Settings Persistence
- [ ] Enable Background Refresh
- [ ] Toggle Wi-Fi Only OFF
- [ ] Close app completely
- [ ] Reopen app and go to Settings
- [ ] Background Refresh still ON
- [ ] Wi-Fi Only still OFF

### Reset Data
- [ ] Enable Background Refresh with custom settings
- [ ] Tap "Remove Everything"
- [ ] Confirm deletion
- [ ] Return to Settings
- [ ] Background Refresh back to OFF (default)
- [ ] Wi-Fi Only back to ON when enabled

### Last Refresh Timestamp (Phase 6)
- [ ] Currently hidden (no background refresh has run yet)
- [ ] Will appear after Phase 6 implementation
- [ ] Will use relativeTimeString() format

## Design Decisions Explained

### Why Background Refresh Is Disabled by Default

**Reasons:**
1. **Battery Respect**: Users should opt-in to background activity
2. **Data Respect**: Some users have limited data plans
3. **User Control**: Makes the feature discoverable but non-intrusive
4. **iOS Guidelines**: Apple recommends opt-in for background tasks

**Alternative Considered**: Default to ON
- Rejected: Too aggressive for first-time users

### Why Wi-Fi Only Is Enabled by Default

**Reasons:**
1. **Data Respect**: Most users prefer not to use cellular data
2. **Common Pattern**: Most apps default to Wi-Fi only
3. **Battery Efficiency**: Wi-Fi uses less battery than cellular
4. **User Expectation**: Standard iOS behavior

**Alternative Considered**: Default to OFF (allow cellular)
- Rejected: Could surprise users with data usage

### Why Last Refresh Timestamp Is Optional

**Reasons:**
1. **Clean UI**: Don't show meaningless "Never" state
2. **Progressive Disclosure**: Only show when relevant
3. **Context**: Timestamp is only useful after refresh has occurred

**Alternative Considered**: Always show timestamp
- Rejected: "Never refreshed" or empty state looks unpolished

### Why Footer Explains iOS Limitations

**Reasons:**
1. **Set Expectations**: Background refresh isn't guaranteed
2. **Reduce Support**: Users understand why it might not work
3. **Transparency**: Be honest about iOS limitations
4. **Education**: Help users understand Low Power Mode impact

## Accessibility

### VoiceOver Support

All controls are accessible:
- ✅ Background Refresh toggle is labeled
- ✅ Wi-Fi Only toggle is labeled
- ✅ Descriptions are readable by VoiceOver
- ✅ Footer provides context
- ✅ Last refresh timestamp is announced

### Dynamic Type

All text scales with system font size:
- Body text: .body font
- Descriptions: .caption font
- Relative sizing maintained

## Known Limitations

### Phase 5 Limitations

1. **No Actual Background Refresh**: Toggles work, but don't trigger background tasks yet
2. **No Timestamp**: Last refresh timestamp never appears (no refreshes occur yet)
3. **No Validation**: Can't check if iOS permission is granted
4. **No Deep Link**: Can't open iOS Settings to grant permission

These will be addressed in Phase 6.

### iOS Limitations (General)

1. **Not Guaranteed**: iOS decides when (and if) to run background tasks
2. **Low Power Mode**: Disables all background refresh
3. **User Control**: Users can disable in iOS Settings → General → Background App Refresh
4. **Battery/Network**: iOS may skip refresh if battery low or no network

These are iOS platform limitations, not app bugs.

## Future Enhancements (Beyond Phase 6)

### Possible Additions

1. **Refresh Interval Picker**
   - Let users choose: 15min, 30min, 1hr, 4hr, daily
   - Note: iOS treats these as hints, not guarantees

2. **Per-Feed Settings**
   - Enable/disable background refresh per feed
   - Useful for high-volume feeds

3. **Notification on New Articles**
   - Optional notification when background refresh finds new articles
   - Would require notification permissions

4. **Background Refresh Statistics**
   - Show success rate
   - Show data usage
   - Show battery impact

5. **Manual Refresh Interval**
   - Separate setting for pull-to-refresh caching

None of these are planned for the initial implementation.

## Files Modified

1. **RichRSS/AppSettings.swift** - New model for storing settings
2. **RichRSS/RichRSSApp.swift** - Registered AppSettings in schema
3. **RichRSS/SettingsView.swift** - Added UI controls and logic

**Total**: 1 new file, 2 modified files

## What's Next

After testing Phase 5:
- **Phase 6**: Implement actual background refresh with BGTaskScheduler
  - Add Background Modes capability
  - Create BackgroundRefreshManager
  - Register background task identifiers
  - Implement task handlers
  - Test on real device (required for background tasks)

Phase 5 provides the UI foundation. Phase 6 provides the functionality.

## Conclusion

Phase 5 creates a clean, intuitive settings interface for background refresh. The UI follows iOS conventions, sets proper user expectations, and provides all necessary controls. The actual background refresh implementation in Phase 6 will hook into these existing settings seamlessly.

**Key Achievement**: Users can now control background refresh preferences, and the app is ready for Phase 6 implementation.
