# Xcode Configuration Guide for Background Refresh

This guide walks you through the manual Xcode configuration steps required to enable background refresh in RichRSS.

## Required Steps

### Step 1: Add Background Modes Capability

1. Open `RichRSS.xcodeproj` in Xcode
2. Select the **RichRSS** target in the project navigator
3. Click the **Signing & Capabilities** tab
4. Click the **+ Capability** button (top left)
5. Search for and add **"Background Modes"**
6. In the Background Modes section, check **"Background fetch"**

**Visual Guide:**
```
Signing & Capabilities Tab
└── + Capability
    └── Background Modes
        └── ✓ Background fetch
```

### Step 2: Add Background Task Identifier to Info.plist

1. In Xcode, find and open **Info.plist**
2. Right-click in the file and select **"Add Row"**
3. Add the following key: `BGTaskSchedulerPermittedIdentifiers`
4. Set the type to **Array**
5. Add one item to the array with value: `com.richrss.feedrefresh`

**Alternatively, you can add this XML directly to Info.plist:**

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.richrss.feedrefresh</string>
</array>
```

**Visual Guide:**
```
Info.plist
└── BGTaskSchedulerPermittedIdentifiers (Array)
    └── Item 0 (String): com.richrss.feedrefresh
```

## Verifying Configuration

### Check Background Modes

In the **Signing & Capabilities** tab, you should see:
- ✅ Background Modes capability added
- ✅ "Background fetch" checkbox is checked

### Check Info.plist

Open Info.plist as source code (right-click → Open As → Source Code) and verify:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.richrss.feedrefresh</string>
</array>
```

## Testing Background Refresh

### On Simulator (Development)

1. **Build and run** the app in the simulator
2. **Enable background refresh** in Settings
3. **Close the app** (not just background it)
4. **Trigger background refresh** using Terminal:

```bash
# First, get the app's bundle identifier
xcrun simctl spawn booted log stream --predicate 'subsystem contains "com.richrss"'

# In another terminal, trigger the background task
xcrun simctl spawn booted e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.richrss.feedrefresh"]
```

5. **Watch console logs** for background refresh activity

### On Real Device (Required for Production)

**IMPORTANT**: Background refresh behavior differs significantly between simulator and real device. You MUST test on a real device before releasing.

1. **Build and install** the app on your iPhone/iPad
2. **Enable background refresh** in RichRSS Settings
3. **Enable Background App Refresh** in iOS Settings:
   - Settings → General → Background App Refresh
   - Ensure it's ON globally
   - Ensure it's ON for RichRSS specifically
4. **Use the app normally** for a few days
5. **Check feed timestamps** to see if background refresh occurred

**Tips for Real Device Testing:**
- Background refresh won't happen immediately
- iOS learns your usage patterns (e.g., if you open the app every morning at 8am)
- Low Power Mode completely disables background refresh
- Poor network or low battery may prevent refresh
- Be patient - it may take hours or even a day for iOS to schedule the task

## Debugging

### Enable Console Logging

1. In Xcode, go to **Product → Scheme → Edit Scheme**
2. Select **Run** on the left
3. Go to the **Arguments** tab
4. Under **Environment Variables**, add:
   - Name: `-BGTaskSchedulerSchedulingEnabled`
   - Value: `YES`

This enables background task scheduling in the simulator.

### Check Logs

Look for these log messages:

**Registration:**
```
✅ Background refresh registered and scheduled
```

**Scheduling:**
```
✅ Background refresh scheduled (earliest: 15 minutes from now)
```

**Execution:**
```
🔄 Background refresh started
🔄 Refreshing 10 feeds (max: 10)
✅ Background refresh completed in 4.23s
   Refreshed: 8/10 feeds
   New articles: 15
```

**Expiration:**
```
⏱️ Background refresh expired (30s limit reached)
```

### Common Issues

#### Issue: "Could not schedule background refresh"
**Solution**: Ensure Info.plist has the correct task identifier

#### Issue: Background refresh never runs
**Solution**:
- Verify Background Modes capability is added
- Check iOS Settings → Background App Refresh is enabled
- Disable Low Power Mode
- Use the app regularly to establish a pattern

#### Issue: "Unrecognized selector sent to instance"
**Solution**: Clean build folder (Cmd+Shift+K) and rebuild

#### Issue: 30-second timeout
**Solution**: The app is trying to refresh too many feeds. This is expected - iOS limits background tasks to ~30 seconds. The app prioritizes favorites and limits to 10 feeds maximum.

## Production Checklist

Before releasing to TestFlight or App Store:

- [ ] Background Modes capability added
- [ ] Info.plist contains BGTaskSchedulerPermittedIdentifiers
- [ ] Tested on real device (not just simulator)
- [ ] Background refresh completes within 30 seconds
- [ ] Settings UI works correctly
- [ ] Wi-Fi only setting is respected
- [ ] Tested with Low Power Mode (should gracefully skip)
- [ ] Tested with airplane mode (should gracefully skip)
- [ ] Console logs show no errors or warnings

## Additional Notes

### iOS Limitations

Background refresh is **NOT guaranteed**. iOS decides:
- **When** to run background refresh (based on user patterns)
- **If** to run background refresh (based on battery, network, Low Power Mode)
- **How often** to run background refresh (may be hours or days between runs)

Users should be made aware of these limitations (which is why we have explanatory text in the Settings UI).

### Battery Impact

The background refresh implementation is designed to be battery-efficient:
- Limits to 10 feeds per refresh
- Uses concurrency limit of 5 (vs 8 for foreground)
- Prioritizes favorites
- Respects Wi-Fi only setting
- Skips if Low Power Mode enabled

### Data Usage

To minimize data usage:
- Default to Wi-Fi only
- Limit feeds refreshed per background task
- Future enhancement: Use conditional HTTP requests (If-Modified-Since headers)

## Troubleshooting Workflow

1. **Verify Xcode configuration** (this guide)
2. **Check console logs** for errors
3. **Test on real device** (required!)
4. **Wait patiently** - background refresh may not happen immediately
5. **Use the app regularly** to help iOS learn your pattern
6. **Check iOS Settings** - ensure Background App Refresh is enabled

## Support

If background refresh isn't working after following this guide:
1. Check all configuration steps above
2. Review console logs for errors
3. Test on a real device (not simulator)
4. Ensure the app is used regularly for a few days
5. Remember: iOS controls when background refresh occurs

---

**Once configured, the app will automatically refresh feeds in the background according to iOS's scheduling!**
