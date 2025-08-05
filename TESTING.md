# Minimal Testing Guide for Shoulder App

## Testing Philosophy

We follow a **minimal testing approach** - only test what can actually break and provides real value. No testing framework features or simple getters/setters.

## Test Structure

### Unit Tests (`shoulderTests/shoulderCoreTests.swift`)
Only 4 essential tests using Swift Testing framework:
1. **Session Tracking** - Verifies sessions are created and saved with duration
2. **Screenshot Setup** - Ensures screenshot manager initializes without crashing  
3. **Focus Management** - Tests LLM focus can be changed
4. **End-to-End Workflow** - Verifies all components work together

### UI Tests (`shoulderUITests/shoulderUITestsMinimal.swift`)
Just 1 smoke test using XCTest:
- **App Launch** - Verifies the app starts without crashing

## Running Tests

```bash
# Run all tests (takes ~5 seconds)
xcodebuild test -project shoulder.xcodeproj -scheme shoulder -destination 'platform=macOS'

# Or in Xcode
Press ⌘U
```

## What We Test

✅ **Core business logic** - Session tracking and duration calculation
✅ **Critical integrations** - SwiftData persistence 
✅ **Basic smoke test** - App launches successfully

## What We DON'T Test

❌ Property initializers and getters/setters
❌ UI layout details and navigation
❌ Framework functionality (Swift/SwiftUI features)
❌ Simple data structures

## Why So Few Tests?

- **Less maintenance** - Fewer tests to update when code changes
- **Faster feedback** - All tests run in seconds
- **Higher value** - Each test catches real bugs
- **Clear purpose** - Easy to understand what each test does

## Adding New Tests

Before adding a test, ask:
1. Has this actually broken before?
2. Is the logic complex enough to warrant testing?
3. Would a bug here be caught quickly in manual testing?

If you answered "no" to any of these, you probably don't need the test.

## Test Results

Current test suite:
- **5 total tests** (4 unit, 1 UI)
- **~5 second runtime**
- **Tests core functionality only**