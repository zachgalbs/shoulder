# Application Blocking Implementation

## Overview
This implementation adds intelligent application blocking to the Shoulder app, automatically closing distracting applications when the AI detects the user is off-task.

## Key Features

### 1. **Intelligent Blocking**
- Integrates with existing MLX AI analysis to detect when users are off-task
- Configurable confidence threshold (default 70%)
- Automatic blocking when confidence exceeds threshold

### 2. **Focus Mode**
- One-click activation to block all non-whitelisted apps
- Helps maintain deep focus during important work sessions
- Instantly closes all distracting applications

### 3. **Whitelist/Blocklist Management**
- Maintain lists of always-allowed and always-blocked applications
- System apps (Finder, shoulder) are protected from blocking
- Easy UI for adding/removing applications

### 4. **Blocking Statistics**
- Track total apps blocked
- Daily blocking count
- Most frequently blocked application
- Recent blocking history with timestamps

### 5. **User Notifications**
- macOS notifications when apps are blocked
- Shows reason for blocking (AI analysis or focus mode)
- Non-intrusive alerts

## Architecture

### Core Components

1. **ApplicationBlockingManager.swift**
   - Singleton manager for all blocking logic
   - Handles app termination using NSRunningApplication
   - Manages whitelist/blocklist persistence
   - Tracks blocking statistics

2. **BlockingSettingsView.swift**
   - Comprehensive settings UI
   - Toggle blocking on/off
   - Manage whitelists and blocklists
   - Adjust confidence threshold
   - View blocking statistics

3. **Integration Points**
   - `ScreenVisibilityMonitor`: Checks apps before allowing switch
   - `MLXLLMManager`: Sends notifications when off-task detected
   - `DashboardView`: Shows blocking status and statistics
   - `ContentView`: Settings navigation link

## How It Works

1. **Detection Flow**:
   ```
   User switches app → ScreenVisibilityMonitor → Check blocklist → Allow/Block
                    ↓
   Screenshot taken → OCR → MLX Analysis → Off-task detected → Block if confidence > threshold
   ```

2. **Blocking Process**:
   - App identified as distracting (manual list or AI detection)
   - `NSRunningApplication.terminate()` called
   - If app doesn't terminate, `forceTerminate()` used
   - User notified via macOS notification
   - Event logged to `~/src/shoulder/blocking_logs/`

3. **Configuration Storage**:
   - Uses `@AppStorage` for persistence
   - Settings survive app restarts
   - Separate storage for:
     - Blocking enabled state
     - Focus mode state
     - Confidence threshold
     - Blocked apps list
     - Whitelisted apps list

## User Interface

### Settings Page
- Located in Settings → Application Blocking
- Shows current blocking status
- One-click access to detailed settings

### Blocking Settings View
- **Enable/Disable Toggle**: Master on/off switch
- **Focus Mode**: Nuclear option for maximum focus
- **Confidence Slider**: 50-100% threshold adjustment
- **App Lists**: Visual management of blocked/allowed apps
- **Statistics**: Real-time blocking metrics

### Dashboard Integration
- Blocking status indicator (shield icon)
- Shows "Focus Mode Active" or "Blocking Enabled"
- Daily blocked count display

## Safety Features

1. **Protected Applications**:
   - System apps cannot be blocked (Finder, System Preferences)
   - Shoulder app itself is protected
   - Cannot be removed from whitelist

2. **Graceful Termination**:
   - Attempts normal termination first
   - Only force-terminates if necessary
   - 100ms delay between attempts

3. **User Control**:
   - Master toggle to disable all blocking
   - Per-app whitelist overrides
   - Adjustable sensitivity

## Testing

Comprehensive test suite in `ApplicationBlockingTests.swift`:
- Initialization tests
- Blocking logic validation
- Focus mode behavior
- Whitelist/blocklist management
- Confidence threshold clamping

All tests passing ✅

## Configuration Files

- **Blocking logs**: `~/src/shoulder/blocking_logs/YYYY-MM-DD/block-{timestamp}.json`
- **Settings**: Stored in UserDefaults with keys:
  - `blockingEnabled`
  - `focusModeActive`
  - `blockingConfidenceThreshold`
  - `blockedApps`
  - `whitelistedApps`

## Future Enhancements

1. **Time-based Rules**: Block certain apps during work hours
2. **Temporary Unblocking**: Allow 5-minute breaks
3. **Productivity Scoring**: Track focus improvement over time
4. **App Categories**: Block entire categories (social media, games)
5. **Smart Learning**: AI learns which apps help/hurt productivity
6. **Pomodoro Integration**: Auto-enable during focus periods

## Usage Instructions

1. **Enable Blocking**:
   - Go to Settings → Application Blocking
   - Toggle "Enable Application Blocking"

2. **Configure Apps**:
   - Add distracting apps to blocklist
   - Add essential apps to whitelist

3. **Set Sensitivity**:
   - Adjust confidence threshold slider
   - Higher = fewer false positives
   - Lower = more aggressive blocking

4. **Focus Mode**:
   - Toggle when you need maximum focus
   - Blocks everything except whitelisted apps
   - Use sparingly - it's powerful!

## Technical Notes

- Uses `NSWorkspace` and `NSRunningApplication` APIs
- Requires no additional entitlements
- Works within existing app sandbox
- Blocking happens on main thread for UI safety
- Async/await used for non-blocking operations

## Build & Run

```bash
# Build
xcodebuild -project shoulder.xcodeproj -scheme shoulder -configuration Debug build

# Run tests
xcodebuild test -project shoulder.xcodeproj -scheme shoulder -destination 'platform=macOS'
```

Build status: ✅ **SUCCESSFUL**
Test status: ✅ **ALL PASSING**