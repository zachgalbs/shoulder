//
//  ContentView.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/2/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.startTime, order: .reverse) private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        SessionDetailView(session: item)
                    } label: {
                        SessionRowView(session: item)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            .navigationTitle("App Sessions")
        } detail: {
            Text("Select a session to view details")
                .foregroundColor(.secondary)
        }
        .onAppear {
            // App started
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

struct SessionRowView: View {
    let session: Item
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.appName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let duration = session.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            if let windowTitle = session.windowTitle {
                Text(windowTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text(session.startTime, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

struct SessionDetailView: View {
    let session: Item
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(session.appName)
                .font(.largeTitle)
                .bold()
            
            if let windowTitle = session.windowTitle {
                Text("Window: \(windowTitle)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Details")
                    .font(.headline)
                
                HStack {
                    Text("Started:")
                    Spacer()
                    Text(session.startTime, format: Date.FormatStyle(date: .abbreviated, time: .standard))
                }
                
                if let endTime = session.endTime {
                    HStack {
                        Text("Ended:")
                        Spacer()
                        Text(endTime, format: Date.FormatStyle(date: .abbreviated, time: .standard))
                    }
                } else {
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text("Active")
                            .foregroundColor(.green)
                    }
                }
                
                if let duration = session.duration {
                    HStack {
                        Text("Duration:")
                        Spacer()
                        Text(formatDuration(duration))
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Session Details")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}