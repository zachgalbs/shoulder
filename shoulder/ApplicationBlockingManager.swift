import Foundation
import AppKit
import SwiftUI
import UserNotifications

@MainActor
class ApplicationBlockingManager: ObservableObject {
    static let shared = ApplicationBlockingManager()
    
    @Published var isBlockingEnabled: Bool = false
    @Published var blockedApplications: Set<String> = []
    @Published var whitelistedApplications: Set<String> = ["Finder", "System Preferences", "System Settings", "shoulder"]
    @Published var recentlyBlockedApps: [(app: String, timestamp: Date)] = []
    @Published var focusModeActive: Bool = false
    @Published var blockingConfidenceThreshold: Double = 0.7
    
    @AppStorage("blockingEnabled") private var storedBlockingEnabled: Bool = false
    @AppStorage("blockedApps") private var storedBlockedApps: String = ""
    @AppStorage("whitelistedApps") private var storedWhitelistedApps: String = "Finder,System Preferences,System Settings,shoulder"
    @AppStorage("blockingConfidenceThreshold") private var storedConfidenceThreshold: Double = 0.7
    @AppStorage("focusModeActive") private var storedFocusModeActive: Bool = false
    
    private var analysisSubscription: Any?
    
    private init() {
        loadSettings()
        setupAnalysisSubscription()
    }
    
    private func loadSettings() {
        isBlockingEnabled = storedBlockingEnabled
        focusModeActive = storedFocusModeActive
        blockingConfidenceThreshold = storedConfidenceThreshold
        
        if !storedBlockedApps.isEmpty {
            blockedApplications = Set(storedBlockedApps.split(separator: ",").map(String.init))
        }
        
        if !storedWhitelistedApps.isEmpty {
            whitelistedApplications = Set(storedWhitelistedApps.split(separator: ",").map(String.init))
        }
    }
    
    private func saveSettings() {
        storedBlockingEnabled = isBlockingEnabled
        storedFocusModeActive = focusModeActive
        storedConfidenceThreshold = blockingConfidenceThreshold
        storedBlockedApps = blockedApplications.joined(separator: ",")
        storedWhitelistedApps = whitelistedApplications.joined(separator: ",")
    }
    
    private func setupAnalysisSubscription() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnalysisResult),
            name: Notification.Name("MLXAnalysisCompleted"),
            object: nil
        )
    }
    
    @objc private func handleAnalysisResult(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let analysis = userInfo["analysis"] as? MLXAnalysisResult,
              let appName = userInfo["appName"] as? String else {
            print("[Blocking] ❌ Missing analysis data in notification")
            return
        }
        
        print("[Blocking] 📊 Analysis received for \(appName):")
        print("[Blocking]    - Valid: \(analysis.is_valid)")
        print("[Blocking]    - Confidence: \(Int(analysis.confidence * 100))%")
        print("[Blocking]    - Threshold: \(Int(blockingConfidenceThreshold * 100))%")
        print("[Blocking]    - Blocking enabled: \(isBlockingEnabled)")
        
        guard isBlockingEnabled else {
            print("[Blocking] ⚠️ Blocking is disabled")
            return
        }
        
        Task { @MainActor in
            if !analysis.is_valid && analysis.confidence >= blockingConfidenceThreshold {
                print("[Blocking] 🚫 Triggering block for \(appName)")
                await blockApplicationIfNeeded(appName: appName, analysis: analysis)
            } else {
                print("[Blocking] ✅ App allowed - Valid: \(analysis.is_valid), Confidence: \(analysis.confidence)")
            }
        }
    }
    
    func shouldBlockApplication(_ appName: String) -> Bool {
        guard isBlockingEnabled else { return false }
        
        if whitelistedApplications.contains(appName) {
            return false
        }
        
        if focusModeActive {
            return !whitelistedApplications.contains(appName)
        }
        
        return blockedApplications.contains(appName)
    }
    
    @MainActor
    func blockApplicationIfNeeded(appName: String, analysis: MLXAnalysisResult? = nil) async {
        // For AI-driven blocking, we block if analysis says it's off-task
        // For manual blocking, we check the blocklist
        let shouldBlock: Bool
        if let analysis = analysis {
            // AI-driven blocking: block if off-task, unless whitelisted
            let isWhitelisted = whitelistedApplications.contains(appName)
            shouldBlock = !isWhitelisted && !analysis.is_valid
            print("[Blocking] AI Check - App: \(appName), Whitelisted: \(isWhitelisted), Valid: \(analysis.is_valid), Should Block: \(shouldBlock)")
        } else {
            // Manual blocking: use standard rules
            shouldBlock = shouldBlockApplication(appName)
            print("[Blocking] Manual Check - App: \(appName), Should Block: \(shouldBlock)")
        }
        
        guard shouldBlock else { 
            print("[Blocking] ℹ️ Not blocking \(appName)")
            return 
        }
        
        print("[Blocking] 🔍 Looking for running app: \(appName)")
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) {
            print("[Blocking] 🎯 Found running app, proceeding to block")
            await blockApplication(runningApp, reason: analysis?.explanation)
        } else {
            print("[Blocking] ⚠️ App '\(appName)' not found in running applications")
            // Let's see what apps are running
            let runningAppNames = NSWorkspace.shared.runningApplications.compactMap { $0.localizedName }.sorted()
            print("[Blocking] Running apps: \(runningAppNames)")
        }
    }
    
    @MainActor
    private func blockApplication(_ app: NSRunningApplication, reason: String? = nil) async {
        guard let appName = app.localizedName else { return }
        
        print("[Blocking] 🎯 Attempting to block: \(appName)")
        print("[Blocking]    - PID: \(app.processIdentifier)")
        print("[Blocking]    - Bundle ID: \(app.bundleIdentifier ?? "unknown")")
        
        if whitelistedApplications.contains(appName) {
            print("[Blocking] ⚠️ App is whitelisted, not blocking")
            return
        }
        
        recentlyBlockedApps.append((app: appName, timestamp: Date()))
        if recentlyBlockedApps.count > 10 {
            recentlyBlockedApps.removeFirst()
        }
        
        showBlockingNotification(appName: appName, reason: reason)
        
        print("[Blocking] 📤 Sending terminate signal...")
        let terminated = app.terminate()
        print("[Blocking]    - Terminate result: \(terminated)")
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        if app.isTerminated == false {
            print("[Blocking] ⚠️ App still running, force terminating...")
            let forceTerminated = app.forceTerminate()
            print("[Blocking]    - Force terminate result: \(forceTerminated)")
        } else {
            print("[Blocking] ✅ App successfully terminated")
        }
        
        logBlockingEvent(appName: appName, reason: reason)
    }
    
    private func showBlockingNotification(appName: String, reason: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Application Blocked"
        content.body = reason ?? "\(appName) was closed to help you maintain focus."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func logBlockingEvent(appName: String, reason: String?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let logsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("src/shoulder/blocking_logs")
            .appendingPathComponent(dateString)
        
        try? FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true)
        
        let logEntry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "app_name": appName,
            "reason": reason ?? "Manual blocking or focus mode",
            "confidence_threshold": blockingConfidenceThreshold
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: logEntry, options: .prettyPrinted) {
            let timestamp = Date().timeIntervalSince1970
            let logFileURL = logsURL.appendingPathComponent("block-\(timestamp).json")
            try? jsonData.write(to: logFileURL)
        }
    }
    
    func addToBlocklist(_ appName: String) {
        blockedApplications.insert(appName)
        saveSettings()
    }
    
    func removeFromBlocklist(_ appName: String) {
        blockedApplications.remove(appName)
        saveSettings()
    }
    
    func addToWhitelist(_ appName: String) {
        whitelistedApplications.insert(appName)
        blockedApplications.remove(appName)
        saveSettings()
    }
    
    func removeFromWhitelist(_ appName: String) {
        guard appName != "shoulder" && appName != "Finder" else { return }
        whitelistedApplications.remove(appName)
        saveSettings()
    }
    
    func toggleFocusMode() {
        focusModeActive.toggle()
        saveSettings()
        
        if focusModeActive {
            closeAllDistractingApps()
        }
    }
    
    func toggleBlocking() {
        isBlockingEnabled.toggle()
        saveSettings()
    }
    
    @MainActor
    private func closeAllDistractingApps() {
        Task {
            for app in NSWorkspace.shared.runningApplications {
                if let appName = app.localizedName,
                   !whitelistedApplications.contains(appName) {
                    await blockApplication(app, reason: "Focus mode activated")
                }
            }
        }
    }
    
    func updateConfidenceThreshold(_ threshold: Double) {
        blockingConfidenceThreshold = max(0.0, min(1.0, threshold))
        saveSettings()
    }
}

extension ApplicationBlockingManager {
    func getBlockingStatistics() -> (totalBlocked: Int, todayBlocked: Int, mostBlocked: String?) {
        let today = recentlyBlockedApps.filter { 
            Calendar.current.isDateInToday($0.timestamp) 
        }.count
        
        let appCounts = recentlyBlockedApps.reduce(into: [String: Int]()) { counts, entry in
            counts[entry.app, default: 0] += 1
        }
        
        let mostBlocked = appCounts.max(by: { $0.value < $1.value })?.key
        
        return (recentlyBlockedApps.count, today, mostBlocked)
    }
}