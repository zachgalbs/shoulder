//
//  PermissionManager.swift
//  shoulder
//
//  Manages system permission checking and status for the app
//

import Foundation
import AppKit
import UserNotifications
import ApplicationServices
import CoreGraphics

@MainActor
class PermissionManager: ObservableObject {
    @Published var screenRecordingGranted: Bool = false
    @Published var accessibilityGranted: Bool = false
    @Published var notificationsGranted: Bool = false
    @Published var allPermissionsGranted: Bool = false
    @Published var shouldShowGuide: Bool = false
    @Published var hasCompletedInitialSetup: Bool = UserDefaults.standard.bool(forKey: "hasCompletedInitialSetup")
    
    init() {
        checkAllPermissions()
    }
    
    func checkAllPermissions() {
        checkScreenRecordingPermission()
        checkAccessibilityPermission()
        checkNotificationPermission()
        updateOverallStatus()
    }
    
    private func updateOverallStatus() {
        allPermissionsGranted = screenRecordingGranted && accessibilityGranted && notificationsGranted
        
        // Show guide if permissions are missing and user hasn't completed initial setup
        if !allPermissionsGranted && !hasCompletedInitialSetup {
            shouldShowGuide = true
        }
    }
    
    func checkScreenRecordingPermission() {
        // Try to capture a small area of the screen to check permission
        // If it returns nil, we don't have permission
        let displayID = CGMainDisplayID()
        if let image = CGDisplayCreateImage(displayID, rect: CGRect(x: 0, y: 0, width: 1, height: 1)) {
            screenRecordingGranted = true
            // Clean up the test image
            _ = image
        } else {
            screenRecordingGranted = false
        }
    }
    
    func checkAccessibilityPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }
    
    func checkNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            
            await MainActor.run {
                notificationsGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            
            await MainActor.run {
                notificationsGranted = granted
                updateOverallStatus()
            }
            
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func markSetupCompleted() {
        hasCompletedInitialSetup = true
        UserDefaults.standard.set(true, forKey: "hasCompletedInitialSetup")
        shouldShowGuide = false
    }
    
    func resetSetup() {
        hasCompletedInitialSetup = false
        UserDefaults.standard.set(false, forKey: "hasCompletedInitialSetup")
        checkAllPermissions()
    }
}
