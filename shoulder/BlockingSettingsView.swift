import SwiftUI

struct BlockingSettingsView: View {
    @ObservedObject var blockingManager = ApplicationBlockingManager.shared
    @State private var newAppToBlock = ""
    @State private var newAppToWhitelist = ""
    @State private var showingAddBlockedApp = false
    @State private var showingAddWhitelistedApp = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                blockingToggleSection
                
                if blockingManager.isBlockingEnabled {
                    focusModeSection
                    confidenceThresholdSection
                    blockedAppsSection
                    whitelistedAppsSection
                    blockingStatisticsSection
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var blockingToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Application Blocking")
                .font(.headline)
            
            Toggle("Enable Application Blocking", isOn: Binding(
                get: { blockingManager.isBlockingEnabled },
                set: { newValue in
                    if blockingManager.isBlockingEnabled != newValue {
                        blockingManager.toggleBlocking()
                    }
                }
            ))
            
            Text("When enabled, distracting applications will be automatically closed based on AI analysis.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var focusModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Mode")
                .font(.headline)
            
            HStack {
                Toggle("Focus Mode", isOn: $blockingManager.focusModeActive)
                    .onChange(of: blockingManager.focusModeActive) { _, _ in
                        blockingManager.toggleFocusMode()
                    }
                
                if blockingManager.focusModeActive {
                    Label("Active", systemImage: "circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            Text("Focus mode blocks all apps except whitelisted ones.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var confidenceThresholdSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Blocking Sensitivity")
                .font(.headline)
            
            HStack {
                Text("Confidence Threshold:")
                Text("\(Int(blockingManager.blockingConfidenceThreshold * 100))%")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
            }
            
            Slider(value: Binding(
                get: { blockingManager.blockingConfidenceThreshold },
                set: { blockingManager.updateConfidenceThreshold($0) }
            ), in: 0.5...1.0)
            
            Text("Higher values mean apps are blocked only when AI is very confident they're distracting.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var blockedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Blocked Applications")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddBlockedApp.toggle() }) {
                    Image(systemName: "plus.circle")
                }
                .popover(isPresented: $showingAddBlockedApp) {
                    addBlockedAppPopover
                }
            }
            
            if blockingManager.blockedApplications.isEmpty {
                Text("No applications in blocklist")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(blockingManager.blockedApplications).sorted(), id: \.self) { app in
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                
                                Text(app)
                                    .font(.system(.body, design: .monospaced))
                                
                                Spacer()
                                
                                Button(action: {
                                    blockingManager.removeFromBlocklist(app)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var whitelistedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Whitelisted Applications")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddWhitelistedApp.toggle() }) {
                    Image(systemName: "plus.circle")
                }
                .popover(isPresented: $showingAddWhitelistedApp) {
                    addWhitelistedAppPopover
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(blockingManager.whitelistedApplications).sorted(), id: \.self) { app in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text(app)
                                .font(.system(.body, design: .monospaced))
                            
                            Spacer()
                            
                            if app != "shoulder" && app != "Finder" {
                                Button(action: {
                                    blockingManager.removeFromWhitelist(app)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 150)
            
            Text("Whitelisted apps are never blocked, even in Focus Mode.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var blockingStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Blocking Statistics")
                .font(.headline)
            
            let stats = blockingManager.getBlockingStatistics()
            
            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text("Total Blocked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.totalBlocked)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.todayBlocked)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                if let mostBlocked = stats.mostBlocked {
                    VStack(alignment: .leading) {
                        Text("Most Blocked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(mostBlocked)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                }
            }
            
            if !blockingManager.recentlyBlockedApps.isEmpty {
                Divider()
                
                Text("Recently Blocked")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(blockingManager.recentlyBlockedApps.reversed(), id: \.timestamp) { entry in
                            HStack {
                                Text(entry.app)
                                    .font(.system(.caption, design: .monospaced))
                                
                                Spacer()
                                
                                Text(entry.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var addBlockedAppPopover: some View {
        VStack(spacing: 12) {
            Text("Add Application to Blocklist")
                .font(.headline)
            
            TextField("Application Name", text: $newAppToBlock)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    newAppToBlock = ""
                    showingAddBlockedApp = false
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Add") {
                    if !newAppToBlock.isEmpty {
                        blockingManager.addToBlocklist(newAppToBlock)
                        newAppToBlock = ""
                        showingAddBlockedApp = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newAppToBlock.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private var addWhitelistedAppPopover: some View {
        VStack(spacing: 12) {
            Text("Add Application to Whitelist")
                .font(.headline)
            
            TextField("Application Name", text: $newAppToWhitelist)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    newAppToWhitelist = ""
                    showingAddWhitelistedApp = false
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Add") {
                    if !newAppToWhitelist.isEmpty {
                        blockingManager.addToWhitelist(newAppToWhitelist)
                        newAppToWhitelist = ""
                        showingAddWhitelistedApp = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newAppToWhitelist.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}