import Foundation
import AppKit
import SwiftUI
import UserNotifications

@MainActor
class ApplicationBlockingManager: ObservableObject {
    // MARK: - Singleton
    static let shared = ApplicationBlockingManager()
    
    // MARK: - Published Properties
    
    @Published var isBlockingEnabled: Bool = false
    @Published var blockedApplications: Set<String> = []
    @Published var whitelistedApplications: Set<String> = ["Finder", "System Preferences", "System Settings", "shoulder"]
    @Published var recentlyBlockedApps: [(app: String, timestamp: Date)] = []
    @Published var focusModeActive: Bool = false
    @Published var blockingConfidenceThreshold: Double = 0.7
    @Published var unfocusedNotificationsEnabled: Bool = true
    
    // MARK: - Persisted Settings
    
    @AppStorage("blockingEnabled") private var storedBlockingEnabled: Bool = false
    @AppStorage("unfocusedNotificationsEnabled") private var storedUnfocusedNotificationsEnabled: Bool = true
    @AppStorage("blockedApps") private var storedBlockedApps: String = ""
    @AppStorage("whitelistedApps") private var storedWhitelistedApps: String = "Finder,System Preferences,System Settings,shoulder"
    @AppStorage("blockingConfidenceThreshold") private var storedConfidenceThreshold: Double = 0.7
    @AppStorage("focusModeActive") private var storedFocusModeActive: Bool = false
    
    // MARK: - Private Properties
    
    private var analysisSubscription: Any?
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
        setupAnalysisSubscription()
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        isBlockingEnabled = storedBlockingEnabled
        focusModeActive = storedFocusModeActive
        blockingConfidenceThreshold = storedConfidenceThreshold
        unfocusedNotificationsEnabled = storedUnfocusedNotificationsEnabled
        
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
        storedUnfocusedNotificationsEnabled = unfocusedNotificationsEnabled
        storedBlockedApps = blockedApplications.joined(separator: ",")
        storedWhitelistedApps = whitelistedApplications.joined(separator: ",")
    }
    
    // MARK: - Analysis Handling
    
    private func setupAnalysisSubscription() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnalysisResult),
            name: .mlxAnalysisCompleted,
            object: nil
        )
    }
    
    @objc private func handleAnalysisResult(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let analysis = userInfo["analysis"] as? MLXAnalysisResult,
              let appName = userInfo["appName"] as? String else {
            return
        }
        
        // Only process notifications from actual LLM analysis
        guard analysis.analysis_source == "llm" else {
            // Silently ignore non-LLM analysis results
            return
        }
        
        Task { @MainActor in
            // Send unfocused notification if enabled and activity is off-task
            if unfocusedNotificationsEnabled && !analysis.is_valid && analysis.confidence >= 0.5 {
                showUnfocusedNotification(appName: appName, analysis: analysis)
            }
            
            // Handle blocking if enabled
            if isBlockingEnabled && !analysis.is_valid && analysis.confidence >= blockingConfidenceThreshold {
                await blockApplicationIfNeeded(appName: appName, analysis: analysis)
            }
        }
    }
    
    // MARK: - Blocking Logic
    
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
        } else {
            // Manual blocking: use standard rules
            shouldBlock = shouldBlockApplication(appName)
        }
        
        guard shouldBlock else { 
            return 
        }
        
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) {
            await blockApplication(runningApp, reason: analysis?.explanation)
        } else {
        }
    }
    
    @MainActor
    private func blockApplication(_ app: NSRunningApplication, reason: String? = nil) async {
        guard let appName = app.localizedName else { return }
        
        
        if whitelistedApplications.contains(appName) {
            return
        }
        
        recentlyBlockedApps.append((app: appName, timestamp: Date()))
        if recentlyBlockedApps.count > 10 {
            recentlyBlockedApps.removeFirst()
        }
        
        showBlockingNotification(appName: appName, reason: reason)
        
        _ = app.terminate()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        if app.isTerminated == false {
            _ = app.forceTerminate()
        }
        
        logBlockingEvent(appName: appName, reason: reason)
    }
    
    private func showBlockingNotification(appName: String, reason: String?) {
        let content = UNMutableNotificationContent()
        content.title = "🚫 Blocked"
        // Keep blocking messages brief
        let briefReason = reason != nil ? String(reason!.prefix(30)) : "Stay focused"
        content.body = "\(appName): \(briefReason)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showUnfocusedNotification(appName: String, analysis: MLXAnalysisResult) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Off-Task"
        // Truncate explanation to 30 chars max for brevity
        let briefExplanation = String(analysis.explanation.prefix(30))
        content.body = "\(appName): \(briefExplanation)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func logBlockingEvent(appName: String, reason: String?) {
        let logsURL = FilePaths.todayBlockingLogsPath()
        
        try? FilePaths.createDirectoryIfNeeded(at: logsURL)
        
        let logEntry: [String: Any] = [
            "timestamp": DateFormatters.iso8601.string(from: Date()),
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
    
    // MARK: - List Management
    
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
    
    // MARK: - Mode Controls
    
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
    
    func toggleUnfocusedNotifications() {
        unfocusedNotificationsEnabled.toggle()
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

// MARK: - Statistics

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

