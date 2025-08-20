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
    private var recentSessions: [(app: String, session: Item, endTime: Date)] = []
    private let mergeWindowSeconds: TimeInterval = 30.0
    
    init() {
        workspace = NSWorkspace.shared
        startMonitoring()
        
        if let currentApp = getCurrentFrontmostApplication() {
            startSession(for: currentApp)
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    deinit {
        endCurrentSession()
        stopMonitoring()
    }
    
    private func startMonitoring() {
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    private func stopMonitoring() {
        workspace.notificationCenter.removeObserver(self)
    }
    
    @objc private func applicationDidActivate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let appName = app.localizedName {
            
            // Check if this application should be blocked
            Task { @MainActor in
                if ApplicationBlockingManager.shared.shouldBlockApplication(appName) {
                    await ApplicationBlockingManager.shared.blockApplicationIfNeeded(appName: appName)
                    return
                }
            }
            
            // Check if we're returning to a recent app within the merge window
            let now = Date()
            if let recentIndex = recentSessions.firstIndex(where: { recent in
                recent.app == appName && 
                now.timeIntervalSince(recent.endTime) <= mergeWindowSeconds
            }) {
                // Merge: Resume the previous session instead of starting new
                let recent = recentSessions[recentIndex]
                
                // End and potentially delete the current short session
                if let currentSession = currentSession {
                    currentSession.updateEndTime(now)
                    // If current session was very short, delete it
                    if let duration = currentSession.duration, duration < mergeWindowSeconds {
                        modelContext?.delete(currentSession)
                    }
                }
                
                // Resume the previous session
                recent.session.endTime = nil
                recent.session.duration = nil
                currentSession = recent.session
                
                // Remove from recent sessions since it's active again
                recentSessions.remove(at: recentIndex)
                
                // Save the changes
                try? modelContext?.save()
            } else {
                // Normal app switch - end current and start new
                endCurrentSession()
                startSession(for: appName)
            }
        }
    }
    
    private func getCurrentFrontmostApplication() -> String? {
        if let frontmostApp = workspace.frontmostApplication {
            return frontmostApp.localizedName
        }
        return nil
    }
    
    private func startSession(for appName: String) {
        guard let modelContext = modelContext else { return }
        
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
        } catch {
        }
    }
    
    private func endCurrentSession() {
        guard let session = currentSession else { return }
        
        let now = Date()
        session.updateEndTime(now)
        
        // Add to recent sessions for potential merging
        if let appName = session.appName as String? {
            recentSessions.append((app: appName, session: session, endTime: now))
            
            // Keep only last 3 recent sessions to prevent memory growth
            if recentSessions.count > 3 {
                recentSessions.removeFirst()
            }
            
            // Clean up old recent sessions beyond merge window
            recentSessions.removeAll { recent in
                now.timeIntervalSince(recent.endTime) > mergeWindowSeconds * 2
            }
        }
        
        do {
            try modelContext?.save()
        } catch {
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
