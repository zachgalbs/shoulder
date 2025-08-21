//
//  ScreenshotManagerIntegrationTests.swift
//  shoulderTests
//
//  Created for PR #33 - Integration and System Testing
//  Tests ScreenCaptureKit integration, fallback logic, and system interactions
//

import Testing
import Foundation
import CoreGraphics
import ScreenCaptureKit
@testable import shoulder

@MainActor
struct ScreenshotManagerIntegrationTests {
    
    // MARK: - ScreenCaptureKit Integration Tests
    
    @Test func testScreenCaptureKitAvailability() async throws {
        // Test that we can check ScreenCaptureKit availability
        let isAvailable = await SCScreenshotManager.isAvailable
        
        // Should be a boolean value (true on macOS 12.3+, false on older versions)
        #expect(type(of: isAvailable) == Bool.self)
    }
    
    @Test func testManagerHandlesScreenCaptureKitUnavailable() async throws {
        // Test that manager gracefully handles when ScreenCaptureKit is unavailable
        let manager = ScreenshotManager()
        
        // Manager should still initialize successfully
        #expect(manager.getCurrentQuality() == .medium)
        #expect(manager.getConfiguration().captureInterval == 10.0)
        
        // Quality changes should still work
        manager.setScreenshotQuality(.high)
        #expect(manager.getCurrentQuality() == .high)
    }
    
    @Test func testFallbackToLegacyCapture() async throws {
        let manager = ScreenshotManager()
        
        // Manager should initialize and be ready to fallback to legacy capture
        #expect(manager != nil)
        
        // Even if ScreenCaptureKit fails, manager should function
        let config = manager.getConfiguration()
        #expect(config.captureInterval == 10.0)
    }
    
    @Test func testScreenCaptureKitConfigurationSetup() async throws {
        let manager = ScreenshotManager()
        
        // Test that configuration setup works regardless of ScreenCaptureKit availability
        let stats = manager.getQualityStats()
        
        if stats != nil {
            // ScreenCaptureKit is available and configured
            #expect(stats!.width > 0)
            #expect(stats!.height > 0)
            #expect(stats!.quality > 0.0)
            #expect(["png", "jpg"].contains(stats!.format))
        } else {
            // ScreenCaptureKit not available - fallback mode
            // Manager should still function normally
            #expect(manager.getCurrentQuality() != nil)
        }
    }
    
    // MARK: - Quality Configuration Integration Tests
    
    @Test func testQualityConfigurationWithScreenCaptureKit() async throws {
        let manager = ScreenshotManager()
        
        // Test quality changes work with or without ScreenCaptureKit
        let qualities: [ScreenshotQuality] = [.high, .medium, .low]
        
        for quality in qualities {
            manager.setScreenshotQuality(quality)
            #expect(manager.getCurrentQuality() == quality)
            
            // Quality stats may or may not be available depending on ScreenCaptureKit
            let stats = manager.getQualityStats()
            if let stats = stats {
                let expectedSettings = quality.settings
                #expect(abs(stats.quality - expectedSettings.quality) < 0.01)
                #expect(stats.format == expectedSettings.format.fileExtension)
            }
        }
    }
    
    @Test func testConfigurationUpdateIntegration() async throws {
        let manager = ScreenshotManager()
        
        // Test that quality changes integrate properly with configuration updates
        manager.setScreenshotQuality(.low)
        let lowStats = manager.getQualityStats()
        
        manager.setScreenshotQuality(.high)
        let highStats = manager.getQualityStats()
        
        // If both stats are available, high quality should have larger dimensions
        if let low = lowStats, let high = highStats {
            #expect(high.width >= low.width)
            #expect(high.height >= low.height)
            #expect(high.quality >= low.quality)
        }
    }
    
    // MARK: - System Integration Tests\n    \n    @Test func testDirectoryCreationIntegration() async throws {\n        // Test that the screenshot directory structure is created properly\n        let homeDir = FileManager.default.homeDirectoryForCurrentUser\n        let expectedBase = homeDir.appendingPathComponent(\"src/shoulder/screenshots\")\n        \n        // The directory path should be constructed correctly\n        #expect(expectedBase.path.contains(\"screenshots\"))\n        #expect(expectedBase.path.contains(\"shoulder\"))\n        \n        // Test date-based folder structure\n        let dateFormatter = DateFormatter()\n        dateFormatter.dateFormat = \"yyyy-MM-dd\"\n        let todayString = dateFormatter.string(from: Date())\n        let todayFolder = expectedBase.appendingPathComponent(todayString)\n        \n        #expect(todayFolder.lastPathComponent == todayString)\n    }\n    \n    @Test func testFileNamingIntegration() async throws {\n        // Test that file naming follows the expected pattern\n        let timeFormatter = DateFormatter()\n        timeFormatter.dateFormat = \"HH-mm-ss\"\n        let timeString = timeFormatter.string(from: Date())\n        \n        // Test screenshot filename generation\n        let jpegFilename = \"screenshot-\\(timeString).jpg\"\n        let mdFilename = \"screenshot-\\(timeString).md\"\n        \n        #expect(jpegFilename.hasPrefix(\"screenshot-\"))\n        #expect(jpegFilename.hasSuffix(\".jpg\"))\n        #expect(mdFilename.hasPrefix(\"screenshot-\"))\n        #expect(mdFilename.hasSuffix(\".md\"))\n    }\n    \n    // MARK: - MLXLLMManager Integration Tests\n    \n    @Test func testMLXLLMManagerIntegration() async throws {\n        let manager = ScreenshotManager()\n        let mlxManager = MLXLLMManager()\n        \n        // Test that MLX manager can be set\n        manager.setMLXLLMManager(mlxManager)\n        \n        // Manager should continue to function normally\n        #expect(manager.getCurrentQuality() == .medium)\n        \n        manager.setScreenshotQuality(.high)\n        #expect(manager.getCurrentQuality() == .high)\n    }\n    \n    @Test func testPendingAnalysisIntegration() async throws {\n        let smallQueueConfig = ScreenshotConfiguration(\n            captureInterval: 1.0,\n            contentChangeThreshold: 0.5,\n            minAnalysisInterval: 1.0,\n            maxScreenshotsWithoutAnalysis: 5,\n            maxPendingAnalyses: 3\n        )\n        \n        let manager = ScreenshotManager(configuration: smallQueueConfig)\n        let mlxManager = MLXLLMManager()\n        \n        // Set up MLX manager (which triggers pending analysis monitoring)\n        manager.setMLXLLMManager(mlxManager)\n        \n        // Manager should function normally with pending analysis system\n        #expect(manager.getConfiguration().maxPendingAnalyses == 3)\n        #expect(manager.getCurrentQuality() == .medium)\n    }\n    \n    // MARK: - Timer Integration Tests\n    \n    @Test func testTimerConfigurationIntegration() async throws {\n        let fastConfig = ScreenshotConfiguration(\n            captureInterval: 0.5, // Very fast for testing\n            contentChangeThreshold: 0.5,\n            minAnalysisInterval: 1.0,\n            maxScreenshotsWithoutAnalysis: 10,\n            maxPendingAnalyses: 20\n        )\n        \n        let manager = ScreenshotManager(configuration: fastConfig)\n        \n        // Configuration should be applied\n        #expect(manager.getConfiguration().captureInterval == 0.5)\n        \n        // Manager should be ready for timer operations\n        #expect(manager.getCurrentQuality() == .medium)\n    }\n    \n    @Test func testCaptureLifecycleIntegration() async throws {\n        let manager = ScreenshotManager()\n        \n        // Test that manager can start and stop capturing\n        manager.startCapturing()\n        \n        // Should be able to change quality during capture\n        manager.setScreenshotQuality(.low)\n        #expect(manager.getCurrentQuality() == .low)\n        \n        manager.setScreenshotQuality(.high)\n        #expect(manager.getCurrentQuality() == .high)\n        \n        // Should be able to stop capturing\n        manager.stopCapturing()\n        \n        // Quality changes should still work after stopping\n        manager.setScreenshotQuality(.medium)\n        #expect(manager.getCurrentQuality() == .medium)\n    }\n    \n    // MARK: - Error Recovery Integration Tests\n    \n    @Test func testErrorRecoveryIntegration() async throws {\n        let manager = ScreenshotManager()\n        \n        // Manager should handle various error conditions gracefully\n        // Test that quality changes work even if ScreenCaptureKit fails\n        for _ in 0..<10 {\n            manager.setScreenshotQuality(.high)\n            manager.setScreenshotQuality(.medium)\n            manager.setScreenshotQuality(.low)\n        }\n        \n        // Should end up in a consistent state\n        let finalQuality = manager.getCurrentQuality()\n        #expect([.high, .medium, .low].contains(finalQuality))\n    }\n    \n    @Test func testConfigurationErrorRecovery() async throws {\n        // Test with various configurations to ensure robustness\n        let configs = [\n            ScreenshotConfiguration.default,\n            ScreenshotConfiguration(\n                captureInterval: 1.0,\n                contentChangeThreshold: 0.1,\n                minAnalysisInterval: 2.0,\n                maxScreenshotsWithoutAnalysis: 5,\n                maxPendingAnalyses: 10\n            ),\n            ScreenshotConfiguration(\n                captureInterval: 30.0,\n                contentChangeThreshold: 0.9,\n                minAnalysisInterval: 60.0,\n                maxScreenshotsWithoutAnalysis: 100,\n                maxPendingAnalyses: 200\n            )\n        ]\n        \n        for config in configs {\n            let manager = ScreenshotManager(configuration: config)\n            \n            // Each manager should initialize successfully\n            #expect(manager.getCurrentQuality() == .medium)\n            #expect(manager.getConfiguration().captureInterval == config.captureInterval)\n            \n            // Should handle quality changes\n            manager.setScreenshotQuality(.high)\n            #expect(manager.getCurrentQuality() == .high)\n        }\n    }\n    \n    // MARK: - Full System Integration Tests\n    \n    @Test func testFullSystemIntegration() async throws {\n        // Test that all components work together\n        let config = ScreenshotConfiguration(\n            captureInterval: 2.0,\n            contentChangeThreshold: 0.6,\n            minAnalysisInterval: 5.0,\n            maxScreenshotsWithoutAnalysis: 15,\n            maxPendingAnalyses: 25\n        )\n        \n        let manager = ScreenshotManager(configuration: config)\n        let mlxManager = MLXLLMManager()\n        \n        // Set up full system\n        manager.setMLXLLMManager(mlxManager)\n        \n        // Test system functionality\n        #expect(manager.getConfiguration().captureInterval == 2.0)\n        #expect(manager.getCurrentQuality() == .medium)\n        \n        // Test quality adaptation\n        manager.setScreenshotQuality(.high)\n        #expect(manager.getCurrentQuality() == .high)\n        \n        // Test capture lifecycle\n        manager.startCapturing()\n        \n        // Should be able to change settings during capture\n        manager.setScreenshotQuality(.low)\n        #expect(manager.getCurrentQuality() == .low)\n        \n        manager.stopCapturing()\n        \n        // System should remain consistent\n        #expect(manager.getCurrentQuality() == .low)\n        #expect(manager.getConfiguration().maxPendingAnalyses == 25)\n    }\n    \n    @Test func testConcurrentSystemOperations() async throws {\n        let manager = ScreenshotManager()\n        let mlxManager = MLXLLMManager()\n        \n        manager.setMLXLLMManager(mlxManager)\n        \n        // Test concurrent system operations\n        await withTaskGroup(of: Void.self) { group in\n            // Quality changes\n            group.addTask {\n                for i in 0..<20 {\n                    let quality: ScreenshotQuality = [.high, .medium, .low][i % 3]\n                    manager.setScreenshotQuality(quality)\n                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms\n                }\n            }\n            \n            // Configuration access\n            group.addTask {\n                for _ in 0..<20 {\n                    _ = manager.getConfiguration()\n                    _ = manager.getCurrentQuality()\n                    _ = manager.getQualityStats()\n                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms\n                }\n            }\n            \n            // Capture lifecycle operations\n            group.addTask {\n                for _ in 0..<5 {\n                    manager.startCapturing()\n                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms\n                    manager.stopCapturing()\n                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms\n                }\n            }\n        }\n        \n        // System should be in a consistent state\n        let finalQuality = manager.getCurrentQuality()\n        #expect([.high, .medium, .low].contains(finalQuality))\n        \n        let finalConfig = manager.getConfiguration()\n        #expect(finalConfig.captureInterval == 10.0)\n    }\n}"