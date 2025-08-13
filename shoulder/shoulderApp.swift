//
//  shoulderApp.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/2/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct shoulderApp: App {
    @StateObject private var screenMonitor = ScreenVisibilityMonitor()
    @StateObject private var screenshotManager = ScreenshotManager()
    @StateObject private var mlxLLMManager = MLXLLMManager()
    
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(screenMonitor)
                .environmentObject(mlxLLMManager)
                .environmentObject(screenshotManager)
                .onAppear {
                    screenMonitor.setModelContext(sharedModelContainer.mainContext)
                    screenshotManager.setMLXLLMManager(mlxLLMManager)
                    screenshotManager.startCapturing()
                    
                    // Request notification permissions for blocking alerts
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                        if granted {
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}