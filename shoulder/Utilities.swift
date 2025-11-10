//
//  Utilities.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/13/25.
//

import Foundation

// MARK: - Date Formatting

struct DateFormatters {
    static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let fileTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH-mm-ss"
        return formatter
    }()
    
    static let iso8601: ISO8601DateFormatter = {
        return ISO8601DateFormatter()
    }()
    
    static let displayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
    
    static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - File Path Management

struct FilePaths {
    static let baseScreenshotPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("src/shoulder/screenshots")
    
    static let baseAnalysisPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("src/shoulder/analyses")
    
    static let baseBlockingLogsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("src/shoulder/blocking_logs")
    
    static func todayScreenshotPath() -> URL {
        let dateString = DateFormatters.fileDate.string(from: Date())
        return baseScreenshotPath.appendingPathComponent(dateString)
    }
    
    static func todayAnalysisPath() -> URL {
        let dateString = DateFormatters.fileDate.string(from: Date())
        return baseAnalysisPath.appendingPathComponent(dateString)
    }
    
    static func todayBlockingLogsPath() -> URL {
        let dateString = DateFormatters.fileDate.string(from: Date())
        return baseBlockingLogsPath.appendingPathComponent(dateString)
    }
    
    static func createDirectoryIfNeeded(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Time Formatting

extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var shortDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(Int(self))s"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let mlxAnalysisCompleted = Notification.Name("MLXAnalysisCompleted")
    static let screenshotCaptured = Notification.Name("ScreenshotCaptured")
    static let applicationBlocked = Notification.Name("ApplicationBlocked")
    static let sessionStarted = Notification.Name("SessionStarted")
    static let sessionEnded = Notification.Name("SessionEnded")
}
