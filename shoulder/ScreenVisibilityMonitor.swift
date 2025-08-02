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
            endCurrentSession()
            startSession(for: appName)
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
            print("Failed to save session: \(error)")
        }
    }
    
    private func endCurrentSession() {
        guard let session = currentSession else { return }
        
        let now = Date()
        session.updateEndTime(now)
        
        do {
            try modelContext?.save()
        } catch {
            print("Failed to save session end: \(error)")
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