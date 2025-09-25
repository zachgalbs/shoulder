//
//  shoulderApp.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/2/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import Network


@main
struct shoulderApp: App {
    @StateObject private var screenMonitor = ScreenVisibilityMonitor()
    @StateObject private var screenshotManager = ScreenshotManager()
    @StateObject private var mlxLLMManager = MLXLLMManager()
    @StateObject private var focusManager = FocusSessionManager()
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var notificationController = NotificationPresentationController()

    // Initialize ApplicationBlockingManager to set up notification listeners
    private let blockingManager = ApplicationBlockingManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Configure network settings to prevent NECP warnings
        configureNetworking()

        // Initialize ApplicationBlockingManager to ensure notification subscription is set up
        _ = ApplicationBlockingManager.shared
    }
    
    private func configureNetworking() {
        // Configure global network settings to prevent network path warnings
        // This helps suppress NECP (Network Extension Control Policy) warnings
        // that occur when the system tries to check network policies for app requests
        
        // Set default cache policy to reduce unnecessary network calls
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: nil)
    }

    var body: some Scene {
        WindowGroup {
            if focusManager.hasActiveSession {
                ContentView()
                    .environmentObject(screenMonitor)
                    .environmentObject(mlxLLMManager)
                    .environmentObject(screenshotManager)
                    .environmentObject(focusManager)
                    .environmentObject(permissionManager)
                    .environmentObject(notificationController)
                    .frame(minWidth: 600, minHeight: 500)
                    .onAppear {
                        screenMonitor.setModelContext(sharedModelContainer.mainContext)
                        screenshotManager.setMLXLLMManager(mlxLLMManager)
                        screenshotManager.startCapturing()

                        // Request notification permissions for focus session alerts
                        Task {
                            await permissionManager.requestNotificationPermission()
                        }
                    }
            } else {
                FocusSelectionView()
                    .environmentObject(focusManager)
                    .environmentObject(permissionManager)
                    .environmentObject(notificationController)
                    .frame(minWidth: 400, minHeight: 500)
                    .onAppear {
                        // Request notification permissions for focus session alerts
                        Task {
                            await permissionManager.requestNotificationPermission()
                        }
                    }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
