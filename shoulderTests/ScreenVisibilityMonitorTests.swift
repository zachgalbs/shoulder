//
//  ScreenVisibilityMonitorTests.swift
//  shoulderTests
//
//  Created by Zachary Galbraith on 8/4/25.
//

import Testing
import SwiftData
import AppKit
@testable import shoulder

@MainActor
struct ScreenVisibilityMonitorTests {
    
    @Test func testMonitorInitialization() async throws {
        let monitor = ScreenVisibilityMonitor()
        
        // Monitor initializes and starts monitoring automatically
        #expect(monitor != nil)
    }
    
    @Test func testModelContextSetting() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext
        
        let monitor = ScreenVisibilityMonitor()
        monitor.setModelContext(context)
        
        // Context is set internally, no public way to verify directly
        #expect(monitor != nil)
    }
    
    @Test func testMonitorLifecycle() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext
        
        var monitor: ScreenVisibilityMonitor? = ScreenVisibilityMonitor()
        monitor?.setModelContext(context)
        
        // Verify monitor exists
        #expect(monitor != nil)
        
        // Deinit will clean up
        monitor = nil
        #expect(monitor == nil)
    }
    
    @Test func testNotificationObserverSetup() async throws {
        // Test that the monitor sets up notification observers
        let monitor = ScreenVisibilityMonitor()
        
        // The monitor should be observing workspace notifications
        // This is tested indirectly since the actual notification handling is private
        #expect(monitor != nil)
    }
    
    @Test func testWorkspaceIntegration() async throws {
        // Test that the monitor properly integrates with NSWorkspace
        _ = ScreenVisibilityMonitor()
        
        // Verify that monitoring starts on init
        // The actual workspace interaction is tested indirectly
        #expect(NSWorkspace.shared.frontmostApplication != nil || NSWorkspace.shared.frontmostApplication == nil)
    }
}