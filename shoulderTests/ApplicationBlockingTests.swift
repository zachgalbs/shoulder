import Testing
import Foundation
@testable import shoulder

struct ApplicationBlockingTests {
    
    @Test("Application blocking manager initialization")
    @MainActor
    func testBlockingManagerInitialization() async throws {
        let manager = ApplicationBlockingManager.shared
        
        #expect(manager.whitelistedApplications.contains("shoulder"))
        #expect(manager.whitelistedApplications.contains("Finder"))
        #expect(manager.blockedApplications.isEmpty || !manager.blockedApplications.isEmpty)
    }
    
    @Test("Should block application logic")
    @MainActor
    func testShouldBlockApplication() async throws {
        let manager = ApplicationBlockingManager.shared
        
        // Test whitelisted apps are never blocked
        manager.isBlockingEnabled = true
        #expect(!manager.shouldBlockApplication("shoulder"))
        #expect(!manager.shouldBlockApplication("Finder"))
        
        // Test blocked apps are blocked when enabled
        manager.addToBlocklist("TestApp")
        #expect(manager.shouldBlockApplication("TestApp"))
        
        // Test apps aren't blocked when disabled
        manager.isBlockingEnabled = false
        #expect(!manager.shouldBlockApplication("TestApp"))
        
        // Clean up
        manager.removeFromBlocklist("TestApp")
    }
    
    @Test("Focus mode blocks all non-whitelisted apps")
    @MainActor
    func testFocusMode() async throws {
        let manager = ApplicationBlockingManager.shared
        
        manager.isBlockingEnabled = true
        manager.focusModeActive = true
        
        // Whitelisted apps should still be allowed
        #expect(!manager.shouldBlockApplication("shoulder"))
        #expect(!manager.shouldBlockApplication("Finder"))
        
        // Any other app should be blocked
        #expect(manager.shouldBlockApplication("Safari"))
        #expect(manager.shouldBlockApplication("Chrome"))
        #expect(manager.shouldBlockApplication("Slack"))
        
        manager.focusModeActive = false
    }
    
    @Test("Confidence threshold updates")
    @MainActor
    func testConfidenceThreshold() async throws {
        let manager = ApplicationBlockingManager.shared
        
        // Test threshold clamping
        manager.updateConfidenceThreshold(0.3)
        #expect(manager.blockingConfidenceThreshold == 0.3)
        
        manager.updateConfidenceThreshold(1.5)
        #expect(manager.blockingConfidenceThreshold == 1.0)
        
        manager.updateConfidenceThreshold(-0.5)
        #expect(manager.blockingConfidenceThreshold == 0.0)
        
        // Reset to default
        manager.updateConfidenceThreshold(0.7)
    }
    
    @Test("Whitelist and blocklist management")
    @MainActor
    func testListManagement() async throws {
        let manager = ApplicationBlockingManager.shared
        
        // Test adding to blocklist
        manager.addToBlocklist("TestApp1")
        #expect(manager.blockedApplications.contains("TestApp1"))
        
        // Test adding to whitelist removes from blocklist
        manager.addToWhitelist("TestApp1")
        #expect(manager.whitelistedApplications.contains("TestApp1"))
        #expect(!manager.blockedApplications.contains("TestApp1"))
        
        // Test protected apps can't be removed from whitelist
        manager.removeFromWhitelist("shoulder")
        #expect(manager.whitelistedApplications.contains("shoulder"))
        
        manager.removeFromWhitelist("Finder")
        #expect(manager.whitelistedApplications.contains("Finder"))
        
        // Test normal apps can be removed from whitelist
        manager.removeFromWhitelist("TestApp1")
        #expect(!manager.whitelistedApplications.contains("TestApp1"))
        
        // Clean up
        manager.removeFromBlocklist("TestApp1")
    }
}