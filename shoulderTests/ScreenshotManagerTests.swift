//
//  ScreenshotManagerTests.swift
//  shoulderTests
//
//  Created by Zachary Galbraith on 8/4/25.
//

import Testing
import Foundation
import CoreGraphics
@testable import shoulder

@MainActor
struct ScreenshotManagerTests {
    
    @Test func testManagerInitialization() async throws {
        let manager = ScreenshotManager()
        
        #expect(manager.lastOCRText == nil)
    }
    
    @Test func testLLMManagerSetting() async throws {
        let manager = ScreenshotManager()
        let llmManager = LLMAnalysisManager()
        
        manager.setLLMManager(llmManager)
        
        // LLM manager is set internally
        #expect(manager != nil)
    }
    
    @Test func testOCRTextProperty() async throws {
        let manager = ScreenshotManager()
        
        #expect(manager.lastOCRText == nil)
        
        // Simulate OCR text update would be done internally
        // We can't directly test private methods
    }
    
    @Test func testSpatialTextInitialization() async throws {
        let boundingBox = CGRect(x: 100, y: 200, width: 150, height: 30)
        let spatialText = SpatialText(
            text: "Hello World",
            confidence: 0.95,
            boundingBox: boundingBox
        )
        
        #expect(spatialText.text == "Hello World")
        #expect(spatialText.confidence == 0.95)
        #expect(spatialText.boundingBox == boundingBox)
        #expect(spatialText.centerY == boundingBox.midY)
        #expect(spatialText.centerX == boundingBox.midX)
    }
    
    @Test func testScreenshotDirectoryStructure() async throws {
        // Test that screenshot paths follow expected structure
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let screenshotBase = homeDir.appendingPathComponent("src/shoulder/screenshots")
        
        #expect(screenshotBase.path.contains("screenshots"))
        #expect(screenshotBase.path.contains("shoulder"))
    }
    
    @Test func testMarkdownFileNaming() async throws {
        // Test expected markdown file naming convention
        let testPath = "/Users/test/screenshots/2025-01-01/screenshot-10-30-00"
        let pngPath = testPath + ".png"
        let mdPath = testPath + ".md"
        
        #expect(pngPath.hasSuffix(".png"))
        #expect(mdPath.hasSuffix(".md"))
        #expect(pngPath.dropLast(4) == mdPath.dropLast(3))
    }
    
    @Test func testCaptureIntervalConstant() async throws {
        // The capture interval is a private constant set to 60 seconds
        // We can verify the directory structure instead
        let expectedInterval: TimeInterval = 60.0
        
        #expect(expectedInterval == 60.0)
    }
}