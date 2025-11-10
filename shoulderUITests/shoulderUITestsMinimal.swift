//
//  shoulderUITestsMinimal.swift
//  shoulderUITests
//
//  Minimal UI smoke test - just verify app launches
//

import XCTest

final class shoulderUITestsMinimal: XCTestCase {
    
    @MainActor
    func testAppLaunchesSuccessfully() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Just verify the app launched and shows something
        XCTAssertTrue(app.windows.firstMatch.exists, "App should have a window")
        
        // Wait a moment to ensure no crash
        Thread.sleep(forTimeInterval: 1)
        
        // Verify some text is visible (any text)
        XCTAssertTrue(app.staticTexts.count > 0, "App should display some text")
    }
}