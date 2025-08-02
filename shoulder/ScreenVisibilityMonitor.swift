//
//  ScreenVisibilityMonitor.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/2/25.
//

import Foundation
import AppKit

class ScreenVisibilityMonitor: ObservableObject {
    private var workspace: NSWorkspace
    
    init() {
        print("ScreenVisibilityMonitor: Initializing...")
        workspace = NSWorkspace.shared
        startMonitoring()
        
        // Print the current foreground application when the monitor starts
        if let currentApp = getCurrentFrontmostApplication() {
            print("ScreenVisibilityMonitor: Current foreground application: \(currentApp)")
        } else {
            print("ScreenVisibilityMonitor: Could not determine current foreground application")
        }
    }
    
    deinit {
        print("ScreenVisibilityMonitor: Deinitializing...")
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
}