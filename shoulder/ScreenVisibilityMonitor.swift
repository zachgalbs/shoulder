//
//  ScreenVisibilityMonitor.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/2/25.
//

import Foundation
import AppKit
import SwiftData
import ApplicationServices

class ScreenVisibilityMonitor: ObservableObject {
    private var workspace: NSWorkspace
    private var modelContext: ModelContext?
    private var currentSession: Item?
    
    init() {
        print("ScreenVisibilityMonitor: Initializing...")
        workspace = NSWorkspace.shared
        startMonitoring()
        
        // Print the current foreground application when the monitor starts
        if let currentApp = getCurrentFrontmostApplication() {
            print("ScreenVisibilityMonitor: Current foreground application: \(currentApp)")
            startSession(for: currentApp)
        } else {
            print("ScreenVisibilityMonitor: Could not determine current foreground application")
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        print("ScreenVisibilityMonitor: Model context set")
    }
    
    deinit {
        print("ScreenVisibilityMonitor: Deinitializing...")
        endCurrentSession()
        stopMonitoring()
    }
    
    private func startMonitoring() {
        print("ScreenVisibilityMonitor: Starting to monitor app changes...")
        // Listen for application activation notifications
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        print("ScreenVisibilityMonitor: Observer added successfully")
    }
    
    private func stopMonitoring() {
        print("ScreenVisibilityMonitor: Stopping monitoring...")
        workspace.notificationCenter.removeObserver(self)
    }
    
    @objc private func applicationDidActivate(_ notification: Notification) {
        print("ScreenVisibilityMonitor: Application activation notification received!")
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let appName = app.localizedName {
            print("ScreenVisibilityMonitor: Foreground application changed to: \(appName)")
            
            // End current session if one exists
            endCurrentSession()
            
            // Start new session
            startSession(for: appName)
        } else {
            print("ScreenVisibilityMonitor: Could not extract app info from notification")
        }
    }
    
    private func getCurrentFrontmostApplication() -> String? {
        if let frontmostApp = workspace.frontmostApplication {
            return frontmostApp.localizedName
        }
        return nil
    }
    
    private func startSession(for appName: String) {
        guard let modelContext = modelContext else {
            print("ScreenVisibilityMonitor: No model context available")
            return
        }
        
        let now = Date()
        let windowTitle = getActiveWindowTitle()
        
        let newSession = Item(
            timestamp: now,
            appName: appName,
            windowTitle: windowTitle,
            startTime: now
        )
        
        modelContext.insert(newSession)
        currentSession = newSession
        
        do {
            try modelContext.save()
            print("ScreenVisibilityMonitor: Started session for \(appName) with window: \(windowTitle ?? "Unknown")")
        } catch {
            print("ScreenVisibilityMonitor: Failed to save session: \(error)")
        }
    }
    
    private func endCurrentSession() {
        guard let session = currentSession else { return }
        
        let now = Date()
        session.updateEndTime(now)
        
        do {
            try modelContext?.save()
            print("ScreenVisibilityMonitor: Ended session for \(session.appName), duration: \(session.duration ?? 0) seconds")
        } catch {
            print("ScreenVisibilityMonitor: Failed to save session end: \(error)")
        }
        
        currentSession = nil
    }
    
    private func getActiveWindowTitle() -> String? {
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        // Create AX application reference
        let app = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        // Get the focused window
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if result == .success, let window = focusedWindow {
            // Get the window title
            var windowTitle: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &windowTitle)
            
            if titleResult == .success, let title = windowTitle as? String {
                return title
            }
        }
        
        return nil
    }
}