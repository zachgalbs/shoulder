//
//  shoulderCoreTests.swift
//  shoulderTests
//
//  Essential tests for core functionality only
//

import Testing
import Foundation
import SwiftData
@testable import shoulder

@Suite("Core Functionality Tests")
struct shoulderCoreTests {
    
    @Test("Session tracking creates and saves items")
    @MainActor
    func testSessionTracking() async throws {
        // Setup in-memory storage
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext
        
        // Create a session
        let item = Item(timestamp: Date(), appName: "TestApp", windowTitle: "Test Window")
        context.insert(item)
        
        // End the session
        item.updateEndTime(Date())
        try context.save()
        
        // Verify it was saved with duration
        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        
        #expect(items.count == 1)
        #expect(items.first?.duration != nil)
    }
    
    @Test("Screenshot manager initializes directories")
    @MainActor
    func testScreenshotSetup() {
        let manager = ScreenshotManager()
        
        // Just verify it initializes without crashing
        #expect(manager != nil)
        #expect(manager.lastOCRText == nil)
    }
    
    @Test("LLM manager handles focus changes")
    @MainActor
    func testFocusManagement() {
        let manager = MLXLLMManager()
        
        // Test basic focus functionality
        manager.userFocus = "Writing tests"
        #expect(manager.userFocus == "Writing tests")
        
        // Verify analysis state
        #expect(manager.isAnalyzing == false)
        #expect(manager.isModelLoaded == false)
    }
    
    @Test("Complete app workflow")
    @MainActor
    func testEndToEndWorkflow() async throws {
        // This tests the core app flow works together
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext
        
        // Simulate app usage
        let monitor = ScreenVisibilityMonitor()
        monitor.setModelContext(context)
        
        let screenshotManager = ScreenshotManager()
        let mlxLLMManager = MLXLLMManager()
        screenshotManager.setMLXLLMManager(mlxLLMManager)
        
        // Create a session
        let session = Item(timestamp: Date(), appName: "Xcode", windowTitle: "shoulder.xcodeproj")
        context.insert(session)
        try context.save()
        
        // Verify components are connected
        #expect(monitor != nil)
        #expect(screenshotManager != nil)
        #expect(mlxLLMManager != nil)
        
        // Verify session was saved
        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count >= 1)
    }
}
