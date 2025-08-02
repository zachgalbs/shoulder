//
//  shoulderApp.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/2/25.
//

import SwiftUI
import SwiftData

@main
struct shoulderApp: App {
    @StateObject private var screenMonitor = ScreenVisibilityMonitor()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Migration failed, delete the old store and create a new one
            print("Migration failed, deleting old database: \(error)")
            
            // Get the application support directory
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeURL = appSupportURL.appendingPathComponent("default.store")
                try? FileManager.default.removeItem(at: storeURL)
                print("Deleted old database at: \(storeURL)")
            }
            
            // Try creating the container again
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after deleting old database: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(screenMonitor)
                .onAppear {
                    print("shoulderApp: Main app view appeared, screenMonitor should be initialized")
                    screenMonitor.setModelContext(sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}