//
//  FocusSessionManager.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/13/25.
//

import SwiftUI
import Combine
import UserNotifications

@MainActor
class FocusSessionManager: ObservableObject {
    @AppStorage("focusText") var focusText: String = ""
    @AppStorage("focusDurationMinutes") var focusDurationMinutes: Int = 60
    @AppStorage("focusStartTime") private var focusStartTimeInterval: Double = 0
    @AppStorage("focusEndTime") private var focusEndTimeInterval: Double = 0
    @AppStorage("hasActiveSession") var hasActiveSession: Bool = false
    
    @Published var focusStartTime: Date? {
        didSet {
            if let startTime = focusStartTime {
                focusStartTimeInterval = startTime.timeIntervalSince1970
            } else {
                focusStartTimeInterval = 0
            }
        }
    }
    
    @Published var focusEndTime: Date? {
        didSet {
            if let endTime = focusEndTime {
                focusEndTimeInterval = endTime.timeIntervalSince1970
            } else {
                focusEndTimeInterval = 0
            }
        }
    }
    
    @Published var timeRemaining: TimeInterval = 0
    private var timer: Timer?
    
    init() {
        // Restore dates from UserDefaults
        if focusStartTimeInterval > 0 {
            focusStartTime = Date(timeIntervalSince1970: focusStartTimeInterval)
        }
        if focusEndTimeInterval > 0 {
            focusEndTime = Date(timeIntervalSince1970: focusEndTimeInterval)
        }
        
        // Check if session is still valid
        if hasActiveSession, let endTime = focusEndTime {
            if Date() > endTime {
                // Session has expired
                endSession()
            } else {
                // Resume timer
                startTimer()
            }
        }
    }
    
    func startFocusSession(focus: String, durationMinutes: Int) {
        focusText = focus
        focusDurationMinutes = durationMinutes
        focusStartTime = Date()
        focusEndTime = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        hasActiveSession = true
        
        // Update MLXLLMManager's focus
        UserDefaults.standard.set(focus, forKey: "userFocus")
        
        startTimer()
    }
    
    func endSession() {
        hasActiveSession = false
        focusStartTime = nil
        focusEndTime = nil
        timeRemaining = 0
        stopTimer()
    }
    
    private func startTimer() {
        stopTimer()
        updateTimeRemaining()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimeRemaining()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimeRemaining() {
        guard let endTime = focusEndTime else {
            timeRemaining = 0
            return
        }
        
        let remaining = endTime.timeIntervalSince(Date())
        if remaining <= 0 {
            timeRemaining = 0
            
            // Send notification that focus session has ended
            let content = UNMutableNotificationContent()
            content.title = "Focus Session Complete"
            content.body = "Your \(focusDurationMinutes) minute focus session on \"\(focusText)\" has ended."
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request)
            
            endSession()
        } else {
            timeRemaining = remaining
        }
    }
    
    var formattedTimeRemaining: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining) % 3600 / 60
        let seconds = Int(timeRemaining) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var progressPercentage: Double {
        guard let startTime = focusStartTime,
              let endTime = focusEndTime else { return 0 }
        
        let totalDuration = endTime.timeIntervalSince(startTime)
        let elapsed = Date().timeIntervalSince(startTime)
        
        return min(max(elapsed / totalDuration, 0), 1)
    }
}
