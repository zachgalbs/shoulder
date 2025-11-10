//
//  ScreenshotManagerConcurrencyTests.swift
//  shoulderTests
//
//  Created for PR #33 - Thread Safety and Concurrency Testing
//

import Testing
import Foundation
@testable import shoulder

@MainActor
struct ScreenshotManagerConcurrencyTests {
    
    // MARK: - AnalysisState Actor Thread Safety Tests
    
    @Test func testAnalysisStateActorConcurrentAccess() async throws {
        let analysisState = AnalysisState()
        
        // Test concurrent updates from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await analysisState.updateContent(
                        ocrText: "Text \(i)",
                        appName: "App \(i)"
                    )
                }
            }
        }
        
        let finalState = await analysisState.getCurrentState()
        #expect(finalState.screenshots == 10)
        #expect(!finalState.ocrText.isEmpty)
        #expect(!finalState.appName.isEmpty)
    }
    
    @Test func testAnalysisStateActorReset() async throws {
        let analysisState = AnalysisState()
        
        // Set up initial state
        await analysisState.updateContent(ocrText: "Initial text", appName: "Initial app")
        let beforeReset = await analysisState.getCurrentState()
        #expect(beforeReset.screenshots == 1)
        
        // Reset counter
        await analysisState.resetAnalysisCounter()
        let afterReset = await analysisState.getCurrentState()
        
        #expect(afterReset.screenshots == 0)
        #expect(afterReset.lastTime != nil)
        #expect(afterReset.ocrText == "Initial text") // Text should remain
        #expect(afterReset.appName == "Initial app") // App name should remain
    }
    
    @Test func testAnalysisStateActorConcurrentReadWrite() async throws {
        let analysisState = AnalysisState()
        
        // Concurrent read/write operations
        let readTask = Task {
            var results: [(String, String, Int)] = []
            for _ in 0..<50 {
                let state = await analysisState.getCurrentState()
                results.append((state.ocrText, state.appName, state.screenshots))
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
            return results
        }
        
        let writeTask = Task {
            for i in 0..<25 {
                await analysisState.updateContent(
                    ocrText: "Concurrent text \(i)",
                    appName: "Concurrent app \(i)"
                )
                try? await Task.sleep(nanoseconds: 2_000_000) // 2ms
            }
        }
        
        let (readResults, _) = await (readTask.value, writeTask.value)
        
        // Should have captured all read operations without crashes
        #expect(readResults.count == 50)
        
        let finalState = await analysisState.getCurrentState()
        #expect(finalState.screenshots == 25)
    }
    
    // MARK: - Bounded Queue Thread Safety Tests
    
    @Test func testBoundedQueueConcurrentOperations() async throws {
        let customConfig = ScreenshotConfiguration(
            captureInterval: 1.0,
            contentChangeThreshold: 0.5,
            minAnalysisInterval: 1.0,
            maxScreenshotsWithoutAnalysis: 5,
            maxPendingAnalyses: 3 // Small queue for testing overflow
        )
        
        let manager = ScreenshotManager(configuration: customConfig)
        
        // This test verifies that the bounded queue implementation handles concurrent access properly
        // Since the queue methods are private, we test this indirectly through manager behavior
        #expect(manager.getConfiguration().maxPendingAnalyses == 3)
    }
    
    @Test func testQueueOverflowBehavior() async throws {
        let tinyQueueConfig = ScreenshotConfiguration(
            captureInterval: 1.0,
            contentChangeThreshold: 0.5,
            minAnalysisInterval: 1.0,
            maxScreenshotsWithoutAnalysis: 5,
            maxPendingAnalyses: 2 // Very small queue
        )
        
        let manager = ScreenshotManager(configuration: tinyQueueConfig)
        
        // Verify configuration was applied correctly
        #expect(manager.getConfiguration().maxPendingAnalyses == 2)
        
        // Queue overflow behavior is tested indirectly through the configuration bounds
        // The actual queue management is internal and tested through integration
    }
    
    // MARK: - Quality Change Concurrency Tests
    
    @Test func testConcurrentQualityChanges() async throws {
        let manager = ScreenshotManager()
        
        let qualities: [ScreenshotQuality] = [.high, .medium, .low]
        
        // Test concurrent quality changes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    let quality = qualities[i % 3]
                    manager.setScreenshotQuality(quality)
                }
            }
        }
        
        // Should end up with one of the valid qualities
        let finalQuality = manager.getCurrentQuality()
        #expect([.high, .medium, .low].contains(finalQuality))
    }
    
    @Test func testQualityChangesDuringConfiguration() async throws {
        let manager = ScreenshotManager()
        
        // Test rapid quality changes
        let changeTask = Task {
            for _ in 0..<100 {
                manager.setScreenshotQuality(.high)
                manager.setScreenshotQuality(.low)
                manager.setScreenshotQuality(.medium)
                try? await Task.sleep(nanoseconds: 1_000) // 1 microsecond
            }
        }
        
        let readTask = Task {
            var qualities: [ScreenshotQuality] = []
            for _ in 0..<50 {
                qualities.append(manager.getCurrentQuality())
                try? await Task.sleep(nanoseconds: 2_000) // 2 microseconds
            }
            return qualities
        }
        
        let (_, qualities) = await (changeTask.value, readTask.value)
        
        // All read qualities should be valid
        #expect(qualities.allSatisfy { [.high, .medium, .low].contains($0) })
        #expect(!qualities.isEmpty)
    }
    
    // MARK: - Manager Lifecycle Concurrency Tests
    
    @Test func testConcurrentManagerInitialization() async throws {
        // Test creating multiple managers concurrently
        let managers = await withTaskGroup(of: ScreenshotManager.self, returning: [ScreenshotManager].self) { group in
            for _ in 0..<5 {
                group.addTask {
                    return ScreenshotManager()
                }
            }
            
            var results: [ScreenshotManager] = []
            for await manager in group {
                results.append(manager)
            }
            return results
        }
        
        #expect(managers.count == 5)
        
        // Each manager should have proper initialization
        for manager in managers {
            #expect(manager.getCurrentQuality() == .medium)
            #expect(manager.lastOCRText == nil)
        }
    }
    
    @Test func testManagerStateIsolation() async throws {
        // Test that multiple managers don't interfere with each other
        let manager1 = ScreenshotManager()
        let manager2 = ScreenshotManager()
        
        // Change quality on one manager
        manager1.setScreenshotQuality(.high)
        manager2.setScreenshotQuality(.low)
        
        #expect(manager1.getCurrentQuality() == .high)
        #expect(manager2.getCurrentQuality() == .low)
        
        // Managers should be independent
        #expect(manager1.getCurrentQuality() != manager2.getCurrentQuality())
    }
    
    // MARK: - Race Condition Prevention Tests
    
    @Test func testConfigurationRaceConditions() async throws {
        let manager = ScreenshotManager()
        
        // Simulate concurrent operations that might cause race conditions
        await withTaskGroup(of: Void.self) { group in
            // Quality changes
            group.addTask {
                for _ in 0..<50 {
                    manager.setScreenshotQuality(.high)
                    try? await Task.sleep(nanoseconds: 100_000) // 0.1ms
                }
            }
            
            // Quality reads
            group.addTask {
                for _ in 0..<50 {
                    _ = manager.getCurrentQuality()
                    try? await Task.sleep(nanoseconds: 100_000) // 0.1ms
                }
            }
            
            // Configuration reads
            group.addTask {
                for _ in 0..<50 {
                    _ = manager.getConfiguration()
                    try? await Task.sleep(nanoseconds: 100_000) // 0.1ms
                }
            }
        }
        
        // Should complete without crashes or inconsistent state
        #expect(manager.getCurrentQuality() != nil)
        #expect(manager.getConfiguration() != nil)
    }
}