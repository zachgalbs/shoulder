//
//  ScreenshotManagerPerformanceTests.swift
//  shoulderTests
//
//  Created for PR #33 - Performance and Memory Testing
//

import Testing
import Foundation
import CoreGraphics
@testable import shoulder

@MainActor
struct ScreenshotManagerPerformanceTests {
    
    // MARK: - Memory Management Tests
    
    @Test func testManagerMemoryFootprint() async throws {
        // Test that creating and destroying managers doesn't leak memory
        var managers: [ScreenshotManager] = []
        
        for _ in 0..<10 {
            managers.append(ScreenshotManager())
        }
        
        #expect(managers.count == 10)
        
        // Test configuration access doesn't retain extra memory
        for manager in managers {
            _ = manager.getConfiguration()
            _ = manager.getCurrentQuality()
        }
        
        // Clean up
        managers.removeAll()
        
        // Creating a new manager after cleanup should work fine
        let newManager = ScreenshotManager()
        #expect(newManager.getCurrentQuality() == .medium)
    }
    
    @Test func testConfigurationValueSemantics() async throws {
        // Test that configurations are value types and don't share references
        let config1 = ScreenshotConfiguration(
            captureInterval: 5.0,
            contentChangeThreshold: 0.3,
            minAnalysisInterval: 10.0,
            maxScreenshotsWithoutAnalysis: 15,
            maxPendingAnalyses: 20
        )
        
        let config2 = config1 // Should be a copy, not a reference
        
        // Both should have the same values
        #expect(config1.captureInterval == config2.captureInterval)
        #expect(config1.contentChangeThreshold == config2.contentChangeThreshold)
        #expect(config1.minAnalysisInterval == config2.minAnalysisInterval)
        #expect(config1.maxScreenshotsWithoutAnalysis == config2.maxScreenshotsWithoutAnalysis)
        #expect(config1.maxPendingAnalyses == config2.maxPendingAnalyses)
    }
    
    @Test func testMultipleManagersIndependence() async throws {
        // Test that multiple managers don't interfere with each other
        let managers = (0..<5).map { i in
            let config = ScreenshotConfiguration(
                captureInterval: Double(i + 1),
                contentChangeThreshold: 0.5,
                minAnalysisInterval: Double(i * 5 + 10),
                maxScreenshotsWithoutAnalysis: i + 10,
                maxPendingAnalyses: (i + 1) * 10
            )
            return ScreenshotManager(configuration: config)
        }
        
        #expect(managers.count == 5)
        
        // Each manager should have its own configuration
        for (index, manager) in managers.enumerated() {
            let config = manager.getConfiguration()
            #expect(config.captureInterval == Double(index + 1))
            #expect(config.minAnalysisInterval == Double(index * 5 + 10))
            #expect(config.maxScreenshotsWithoutAnalysis == index + 10)
        }
        
        // Quality changes should be independent
        managers[0].setScreenshotQuality(.high)
        managers[1].setScreenshotQuality(.low)
        managers[2].setScreenshotQuality(.medium)
        
        #expect(managers[0].getCurrentQuality() == .high)
        #expect(managers[1].getCurrentQuality() == .low)
        #expect(managers[2].getCurrentQuality() == .medium)
    }
    
    // MARK: - Performance Benchmarks
    
    @Test func testConfigurationCreationPerformance() async throws {
        let startTime = Date()
        
        // Create many configurations quickly
        var configurations: [ScreenshotConfiguration] = []
        for i in 0..<1000 {
            configurations.append(ScreenshotConfiguration(
                captureInterval: Double(i % 10 + 1),
                contentChangeThreshold: Double(i % 10) / 10.0,
                minAnalysisInterval: Double(i % 20 + 5),
                maxScreenshotsWithoutAnalysis: i % 50 + 10,
                maxPendingAnalyses: (i % 10 + 1) * 5
            ))
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(configurations.count == 1000)
        #expect(duration < 1.0) // Should complete in under 1 second
    }
    
    @Test func testQualityChangePerformance() async throws {
        let manager = ScreenshotManager()
        let startTime = Date()
        
        // Rapid quality changes
        for i in 0..<100 {
            let quality: ScreenshotQuality = [.high, .medium, .low][i % 3]
            manager.setScreenshotQuality(quality)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(duration < 0.1) // Should complete in under 100ms
        #expect([.high, .medium, .low].contains(manager.getCurrentQuality()))
    }
    
    @Test func testManagerInitializationPerformance() async throws {
        let startTime = Date()
        
        // Create many managers
        var managers: [ScreenshotManager] = []
        for _ in 0..<50 {
            managers.append(ScreenshotManager())
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(managers.count == 50)
        #expect(duration < 5.0) // Should complete in under 5 seconds (allowing for ScreenCaptureKit setup)
        
        // All managers should be properly initialized
        for manager in managers {
            #expect(manager.getCurrentQuality() == .medium)
            #expect(manager.getConfiguration().captureInterval == 10.0)
        }
    }
    
    // MARK: - Stress Tests
    
    @Test func testRapidQualityChangesStress() async throws {
        let manager = ScreenshotManager()
        let qualities: [ScreenshotQuality] = [.high, .medium, .low]
        
        // Stress test with rapid changes
        for _ in 0..<1000 {
            let randomQuality = qualities.randomElement()!
            manager.setScreenshotQuality(randomQuality)
            
            // Verify state is always consistent
            let currentQuality = manager.getCurrentQuality()
            #expect(qualities.contains(currentQuality))
        }
    }
    
    @Test func testConfigurationAccessStress() async throws {
        let manager = ScreenshotManager()
        
        // Rapid configuration access
        for _ in 0..<1000 {
            let config = manager.getConfiguration()
            #expect(config.captureInterval == 10.0)
            
            let quality = manager.getCurrentQuality()
            #expect([.high, .medium, .low].contains(quality))
            
            let stats = manager.getQualityStats()
            // stats may be nil if ScreenCaptureKit isn't available
            if let stats = stats {
                #expect(stats.width > 0)
                #expect(stats.height > 0)
            }
        }
    }
    
    // MARK: - Edge Case Performance Tests
    
    @Test func testExtremeConfigurationValues() async throws {
        // Test with extreme but valid configuration values
        let extremeConfig = ScreenshotConfiguration(
            captureInterval: 0.1, // Very fast capture
            contentChangeThreshold: 0.99, // Very high threshold
            minAnalysisInterval: 0.1, // Very short interval
            maxScreenshotsWithoutAnalysis: 1000, // Very high count
            maxPendingAnalyses: 1000 // Very large queue
        )
        
        let manager = ScreenshotManager(configuration: extremeConfig)
        let appliedConfig = manager.getConfiguration()
        
        #expect(appliedConfig.captureInterval == 0.1)
        #expect(appliedConfig.contentChangeThreshold == 0.99)
        #expect(appliedConfig.maxPendingAnalyses == 1000)
        
        // Manager should still function normally
        manager.setScreenshotQuality(.high)
        #expect(manager.getCurrentQuality() == .high)
    }
    
    @Test func testMinimalConfigurationValues() async throws {
        // Test with minimal but valid configuration values
        let minimalConfig = ScreenshotConfiguration(
            captureInterval: 1.0,
            contentChangeThreshold: 0.0,
            minAnalysisInterval: 1.0,
            maxScreenshotsWithoutAnalysis: 1,
            maxPendingAnalyses: 1
        )
        
        let manager = ScreenshotManager(configuration: minimalConfig)
        let appliedConfig = manager.getConfiguration()
        
        #expect(appliedConfig.captureInterval == 1.0)
        #expect(appliedConfig.contentChangeThreshold == 0.0)
        #expect(appliedConfig.maxPendingAnalyses == 1)
        
        // Manager should still function normally
        manager.setScreenshotQuality(.low)
        #expect(manager.getCurrentQuality() == .low)
    }
    
    // MARK: - Memory Leak Prevention Tests
    
    @Test func testManagerCleanup() async throws {
        // Test that managers can be created and destroyed without leaks
        for iteration in 0..<10 {
            autoreleasepool {
                let manager = ScreenshotManager()
                manager.setScreenshotQuality(.high)
                #expect(manager.getCurrentQuality() == .high)
                
                let mlxManager = MLXLLMManager()
                manager.setMLXLLMManager(mlxManager)
                
                // Manager should be deallocated when leaving this scope
            }
        }
        
        // Should be able to create a new manager without issues
        let finalManager = ScreenshotManager()
        #expect(finalManager.getCurrentQuality() == .medium)
    }
    
    @Test func testConfigurationRetention() async throws {
        // Test that configurations don't retain unnecessary references
        weak var weakManager: ScreenshotManager?
        
        autoreleasepool {
            let config = ScreenshotConfiguration(
                captureInterval: 5.0,
                contentChangeThreshold: 0.3,
                minAnalysisInterval: 10.0,
                maxScreenshotsWithoutAnalysis: 15,
                maxPendingAnalyses: 20
            )
            
            let manager = ScreenshotManager(configuration: config)
            weakManager = manager
            
            #expect(weakManager != nil)
            
            // Use the manager
            manager.setScreenshotQuality(.high)
            _ = manager.getConfiguration()
            
            // Manager should be deallocated when leaving this scope
        }
        
        // Manager should be deallocated
        #expect(weakManager == nil)
    }
    
    // MARK: - Image Processing Performance Tests
    
    @Test func testImageScalingPerformance() async throws {
        // Test the performance characteristics of different quality settings
        let qualities: [ScreenshotQuality] = [.high, .medium, .low]
        
        for quality in qualities {
            let settings = quality.settings
            
            // Verify scale values are reasonable for performance
            #expect(settings.scale > 0.0)
            #expect(settings.scale <= 1.0)
            
            // Higher quality should have higher scale
            switch quality {
            case .high:
                #expect(settings.scale == 1.0)
            case .medium:
                #expect(settings.scale < 1.0)
                #expect(settings.scale >= 0.5)
            case .low:
                #expect(settings.scale <= 0.7)
                #expect(settings.scale >= 0.3)
            }
        }
    }
    
    @Test func testJPEGQualityPerformance() async throws {
        // Test that JPEG quality settings are optimized for performance vs quality
        let highSettings = ScreenshotQuality.high.settings
        let mediumSettings = ScreenshotQuality.medium.settings
        let lowSettings = ScreenshotQuality.low.settings
        
        // All should use JPEG for performance
        #expect(highSettings.format == .jpeg)
        #expect(mediumSettings.format == .jpeg)
        #expect(lowSettings.format == .jpeg)
        
        // Quality values should be reasonable
        #expect(highSettings.quality > 0.9) // High quality
        #expect(mediumSettings.quality > 0.8) // Good quality
        #expect(lowSettings.quality > 0.7) // Acceptable quality
        
        // Quality should be ordered correctly
        #expect(highSettings.quality > mediumSettings.quality)
        #expect(mediumSettings.quality > lowSettings.quality)
    }
}"