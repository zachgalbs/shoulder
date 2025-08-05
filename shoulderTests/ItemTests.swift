//
//  ItemTests.swift
//  shoulderTests
//
//  Created by Zachary Galbraith on 8/4/25.
//

import Testing
import Foundation
@testable import shoulder

struct ItemTests {
    
    @Test func testItemInitialization() async throws {
        let timestamp = Date()
        let item = Item(timestamp: timestamp, appName: "Safari", windowTitle: "Apple - Home")
        
        #expect(item.timestamp == timestamp)
        #expect(item.appName == "Safari")
        #expect(item.windowTitle == "Apple - Home")
        #expect(item.endTime == nil)
    }
    
    @Test func testDurationCalculation() async throws {
        let startTime = Date()
        let item = Item(timestamp: startTime, appName: "Xcode", windowTitle: "MyProject")
        
        let endTime = startTime.addingTimeInterval(300)
        item.updateEndTime(endTime)
        
        #expect(item.duration == 300)
    }
    
    @Test func testDurationWithNoEndTime() async throws {
        let item = Item(timestamp: Date(), appName: "Terminal", windowTitle: "~")
        
        #expect(item.duration == nil)
    }
    
    @Test func testUpdateEndTime() async throws {
        let startTime = Date()
        let item = Item(timestamp: startTime, appName: "Slack", windowTitle: "General")
        
        let endTime = startTime.addingTimeInterval(3665)
        item.updateEndTime(endTime)
        
        #expect(item.endTime == endTime)
        #expect(item.duration == 3665)
    }
    
    @Test func testDefaultAppName() async throws {
        let timestamp = Date()
        let item = Item(timestamp: timestamp)
        
        #expect(item.appName == "Unknown App")
        #expect(item.windowTitle == nil)
    }
    
    @Test func testStartTimeDefaultsToTimestamp() async throws {
        let timestamp = Date()
        let item = Item(timestamp: timestamp, appName: "Chrome", windowTitle: "GitHub")
        
        #expect(item.startTime == timestamp)
    }
}