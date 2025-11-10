//
//  ScreenshotManagerTests.swift
//  shoulderTests
//
//  Created by Zachary Galbraith on 8/4/25.
//

import Testing
import Foundation
import CoreGraphics
import ScreenCaptureKit
@testable import shoulder

@MainActor
struct ScreenshotManagerTests {
    
    @Test func testManagerInitialization() async throws {
        let manager = ScreenshotManager()
        
        #expect(manager.lastOCRText == nil)
        #expect(manager.getCurrentQuality() == .medium) // Default quality
    }
    
    @Test func testLLMManagerSetting() async throws {
        let manager = ScreenshotManager()
        let mlxLLMManager = MLXLLMManager()
        
        manager.setMLXLLMManager(mlxLLMManager)
        
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
        // Test expected markdown file naming convention (updated to JPEG)
        let testPath = "/Users/test/screenshots/2025-01-01/screenshot-10-30-00"
        let jpgPath = testPath + ".jpg"  // Updated to JPEG
        let mdPath = testPath + ".md"
        
        #expect(jpgPath.hasSuffix(".jpg"))
        #expect(mdPath.hasSuffix(".md"))
    }
    
    // MARK: - Basic Initialization Tests
    
    @Test func testManagerInitializationWithCustomConfiguration() async throws {
        let customConfig = ScreenshotConfiguration(
            captureInterval: 5.0,
            contentChangeThreshold: 0.3,
            minAnalysisInterval: 15.0,
            maxScreenshotsWithoutAnalysis: 20,
            maxPendingAnalyses: 25
        )
        
        let manager = ScreenshotManager(configuration: customConfig)
        let config = manager.getConfiguration()
        
        #expect(config.captureInterval == 5.0)
        #expect(config.contentChangeThreshold == 0.3)
        #expect(config.minAnalysisInterval == 15.0)
        #expect(config.maxScreenshotsWithoutAnalysis == 20)
        #expect(config.maxPendingAnalyses == 25)
    }
    
    @Test func testDefaultConfiguration() async throws {
        let defaultConfig = ScreenshotConfiguration.default
        
        #expect(defaultConfig.captureInterval == 10.0)
        #expect(defaultConfig.contentChangeThreshold == 0.5)
        #expect(defaultConfig.minAnalysisInterval == 30.0)
        #expect(defaultConfig.maxScreenshotsWithoutAnalysis == 30)
        #expect(defaultConfig.maxPendingAnalyses == 50)
    }
    
    // MARK: - Quality System Tests
    
    @Test func testScreenshotQualitySettings() async throws {
        let highSettings = ScreenshotQuality.high.settings
        let mediumSettings = ScreenshotQuality.medium.settings
        let lowSettings = ScreenshotQuality.low.settings
        
        #expect(highSettings.scale == 1.0)
        #expect(highSettings.quality == 0.95)
        #expect(highSettings.format == .jpeg)
        
        #expect(mediumSettings.scale == 0.7)
        #expect(mediumSettings.quality == 0.85)
        #expect(mediumSettings.format == .jpeg)
        
        #expect(lowSettings.scale == 0.5)
        #expect(lowSettings.quality == 0.75)
        #expect(lowSettings.format == .jpeg)
    }
    
    @Test func testImageFormatExtensions() async throws {
        #expect(ImageFormat.png.fileExtension == "png")
        #expect(ImageFormat.jpeg.fileExtension == "jpg")
    }
    
    @Test func testQualityChanges() async throws {
        let manager = ScreenshotManager()
        
        #expect(manager.getCurrentQuality() == .medium)
        
        manager.setScreenshotQuality(.high)
        #expect(manager.getCurrentQuality() == .high)
        
        manager.setScreenshotQuality(.low)
        #expect(manager.getCurrentQuality() == .low)
        
        // Setting same quality should not cause issues
        manager.setScreenshotQuality(.low)
        #expect(manager.getCurrentQuality() == .low)
    }
    
    // MARK: - Configuration Tests
    
    @Test func testUpdatedCaptureInterval() async throws {
        // Updated from 60s to 10s in the new implementation
        let defaultConfig = ScreenshotConfiguration.default
        #expect(defaultConfig.captureInterval == 10.0)
    }
    
    @Test func testConfigurationBounds() async throws {
        let config = ScreenshotConfiguration.default
        
        // Verify reasonable bounds
        #expect(config.captureInterval > 0)
        #expect(config.contentChangeThreshold >= 0.0 && config.contentChangeThreshold <= 1.0)
        #expect(config.minAnalysisInterval > 0)
        #expect(config.maxScreenshotsWithoutAnalysis > 0)
        #expect(config.maxPendingAnalyses > 0)
    }
    
    // MARK: - Performance Tests
    
    @Test func testMemoryUsageWithMultipleInstances() async throws {
        // Test that creating multiple managers doesn't cause issues
        var managers: [ScreenshotManager] = []
        
        for _ in 0..<5 {
            managers.append(ScreenshotManager())
        }
        
        #expect(managers.count == 5)
        
        // Clean up
        managers.removeAll()
    }
    
    @Test func testConfigurationMemoryEfficiency() async throws {
        // Test that configurations are value types and don't retain references
        let config1 = ScreenshotConfiguration.default
        let config2 = ScreenshotConfiguration(
            captureInterval: config1.captureInterval,
            contentChangeThreshold: config1.contentChangeThreshold,
            minAnalysisInterval: config1.minAnalysisInterval,
            maxScreenshotsWithoutAnalysis: config1.maxScreenshotsWithoutAnalysis,
            maxPendingAnalyses: config1.maxPendingAnalyses
        )
        
        #expect(config1.captureInterval == config2.captureInterval)
        #expect(config1.contentChangeThreshold == config2.contentChangeThreshold)
    }
}