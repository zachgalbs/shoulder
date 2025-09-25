//
//  NotificationPresentationController.swift
//  shoulder
//
//  Ensures user notifications display while the app is in the foreground
//

import Foundation
import UserNotifications

@MainActor
final class NotificationPresentationController: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
