# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shoulder is a macOS SwiftUI app that monitors application usage and captures periodic screenshots. It tracks when users switch between applications, recording session metadata (app name, window title, start/end times, duration) and automatically takes screenshots every 60 seconds for activity monitoring.

## Architecture

### Core Components

- **shoulderApp.swift**: Main app entry point with SwiftData model container configured for in-memory storage only
- **ScreenVisibilityMonitor**: Tracks application switching using NSWorkspace notifications and Accessibility APIs to capture window titles
- **ScreenshotManager**: Handles automated screenshot capture using CGDisplayCreateImage and OCR text extraction using Vision framework, saving to `~/src/shoulder/screenshots/YYYY-MM-DD/`
- **MLXLLMManager**: Native MLX-based LLM manager for AI-powered productivity analysis, saving insights to `~/src/shoulder/analyses/YYYY-MM-DD/`
- **Item.swift**: SwiftData model representing app usage sessions with start/end times and calculated duration
- **ContentView.swift**: Main UI with navigation split view showing session list and detail views
- **DashboardView.swift**: Primary dashboard with activity overview, AI insights, and real-time session monitoring

### Data Flow

1. App launches with in-memory SwiftData storage
2. ScreenVisibilityMonitor starts tracking frontmost application changes
3. ScreenshotManager begins periodic capture on 60-second timer
4. Each screenshot triggers OCR processing using Vision framework
5. OCR results saved as markdown files alongside screenshots
6. LLM analyzes OCR text for productivity insights (when enabled)
7. Analysis results saved to `~/src/shoulder/analyses/YYYY-MM-DD/`
8. Each app switch creates new Item session, ending the previous one
9. UI displays sessions sorted by start time (most recent first)

### Key Technologies

- SwiftUI for UI
- SwiftData for data persistence (in-memory only)
- NSWorkspace for application monitoring
- Accessibility APIs (AXUIElement) for window title capture
- ScreenCaptureKit/Core Graphics for screenshot functionality
- Vision framework for OCR text extraction
- AppKit for macOS integration

## Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -project shoulder.xcodeproj -scheme shoulder -configuration Debug build

# Run tests  
xcodebuild test -project shoulder.xcodeproj -scheme shoulder -destination 'platform=macOS'

# Clean build folder
xcodebuild clean -project shoulder.xcodeproj -scheme shoulder
```

### Testing
The project uses Swift Testing framework. Test files are in `shoulderTests/` and `shoulderUITests/`.

## Development Workflow

**IMPORTANT**: Always test that the app builds and runs correctly before committing and pushing changes. The user wants to review functionality before any commits are made.

- Always allow the user to test the functionality before pushing to git

## Security Considerations

The app requires specific entitlements in `shoulder.entitlements`:
- `com.apple.security.app-sandbox`: App sandboxing
- `com.apple.security.files.user-selected.read-write`: File access
- `com.apple.security.files.downloads.read-write`: Downloads access  
- `com.apple.security.device.camera`: Camera access (for screen capture)

The app accesses sensitive system APIs for screen capture and application monitoring. Ensure proper privacy permissions are handled when making changes to monitoring functionality.

## File Structure Notes

- Screenshots are organized by date: `~/src/shoulder/screenshots/YYYY-MM-DD/screenshot-HH-MM-SS.png`
- Markdown files with OCR text: `~/src/shoulder/screenshots/YYYY-MM-DD/screenshot-HH-MM-SS.md`
- LLM analysis results: `~/src/shoulder/analyses/YYYY-MM-DD/analysis-HH-MM-SS.json`
- OCR processing runs asynchronously using Vision framework for optimal performance
- LLM analysis via native MLX framework for on-device inference
- SwiftData storage is intentionally in-memory only to avoid persistence issues
- All monitoring components are ObservableObject classes for SwiftUI integration