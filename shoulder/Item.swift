//
//  Item.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/2/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var appName: String = "Unknown App"
    var windowTitle: String?
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
    
    init(timestamp: Date, appName: String = "Unknown App", windowTitle: String? = nil, startTime: Date? = nil, endTime: Date? = nil) {
        self.timestamp = timestamp
        self.appName = appName
        self.windowTitle = windowTitle
        self.startTime = startTime ?? timestamp
        self.endTime = endTime
        self.duration = endTime != nil ? endTime!.timeIntervalSince(self.startTime) : nil
    }
    
    func updateEndTime(_ endTime: Date) {
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
    }
}
