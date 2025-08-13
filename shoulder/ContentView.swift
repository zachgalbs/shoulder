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
    @EnvironmentObject var screenMonitor: ScreenVisibilityMonitor
    @EnvironmentObject var mlxLLMManager: MLXLLMManager
    @EnvironmentObject var permissionManager: PermissionManager
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case sessions = "Sessions"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .sessions: return "list.bullet.rectangle"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            NavigationStack {
                ZStack {
                    switch selectedTab {
                    case .dashboard:
                        DashboardView()
                    case .sessions:
                        SessionsListView()
                    case .settings:
                        SettingsView()
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $permissionManager.shouldShowGuide) {
            PermissionGuideView(permissionManager: permissionManager)
        }
        .onAppear {
            permissionManager.checkAllPermissions()
        }
    }
    
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            appHeader
            
            List(selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            Text(tab.rawValue)
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: tab.icon)
                                .font(.subheadline)
                                .foregroundColor(selectedTab == tab ? DesignSystem.Colors.accentBlue : DesignSystem.Colors.textSecondary)
                        }
                    }
                    .tag(tab)
                    .accessibilityIdentifier("\(tab.rawValue)NavigationLink")
                }
            }
            .accessibilityIdentifier("SidebarList")
            .listStyle(.sidebar)
            
            Spacer()
            
            statusBar
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private var appHeader: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accentBlue, DesignSystem.Colors.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shoulder")
                        .font(.title2)
                        .fontWeight(.bold)
                        .accessibilityIdentifier("AppTitle")
                    
                    Text("Activity Monitor")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .accessibilityIdentifier("AppSubtitle")
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.medium)
            
            Divider()
        }
    }
    
    private var statusBar: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Divider()
            
            HStack {
                MLXStatusView(mlxManager: mlxLLMManager)
                
                Spacer()
                
                Text("\(items.count) sessions")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.medium)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

struct SessionDetailView: View {
    let session: Item
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                headerSection
                overviewSection
            }
            .padding(DesignSystem.Spacing.large)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    DesignSystem.Colors.accentBlue.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("Session Details")
    }
    
    private var headerSection: some View {
        HStack(spacing: DesignSystem.Spacing.large) {
            AppIconView(appName: session.appName, size: 64)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                Text(session.appName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let windowTitle = session.windowTitle {
                    Text(windowTitle)
                        .font(.title3)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: DesignSystem.Spacing.medium) {
                    if session.endTime == nil {
                        HStack(spacing: DesignSystem.Spacing.xxSmall) {
                            PulsingDot(color: DesignSystem.Colors.activeGreen, size: 8)
                            Text("Active Session")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.activeGreen)
                        }
                    } else {
                        HStack(spacing: DesignSystem.Spacing.xxSmall) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                            Text("Completed")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }
                    
                    if let duration = session.duration {
                        Text("•")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.large)
        .glassCard()
    }
    
    private var overviewSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            DetailRow(label: "Started", value: session.startTime.formatted(date: .abbreviated, time: .standard), icon: "play.circle")
            
            if let endTime = session.endTime {
                DetailRow(label: "Ended", value: endTime.formatted(date: .abbreviated, time: .standard), icon: "stop.circle")
            }
            
            if let duration = session.duration {
                DetailRow(label: "Duration", value: formatDuration(duration), icon: "timer")
            }
        }
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

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: icon)
                    .foregroundColor(DesignSystem.Colors.accentBlue)
                    .frame(width: 20)
                
                Text(label)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Text(value)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.medium)
        }
        .padding(DesignSystem.Spacing.medium)
        .glassCard()
    }
}

struct SettingsView: View {
    @EnvironmentObject var mlxLLMManager: MLXLLMManager
    @EnvironmentObject var permissionManager: PermissionManager
    @State private var showFocusSaved = false
    @State private var showPermissionGuide = false
    
    var body: some View {
        Form {
            Section("Permissions") {
                VStack(alignment: .leading, spacing: 8) {
                    PermissionStatusRow(
                        title: "Screen Recording",
                        isGranted: permissionManager.screenRecordingGranted,
                        icon: "rectangle.dashed.badge.record"
                    )
                    
                    PermissionStatusRow(
                        title: "Accessibility",
                        isGranted: permissionManager.accessibilityGranted,
                        icon: "hand.raised.square"
                    )
                    
                    PermissionStatusRow(
                        title: "Notifications",
                        isGranted: permissionManager.notificationsGranted,
                        icon: "bell.badge"
                    )
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack {
                        Button("Check Permissions") {
                            permissionManager.checkAllPermissions()
                        }
                        
                        Spacer()
                        
                        if !permissionManager.allPermissionsGranted {
                            Button("Run Setup") {
                                showPermissionGuide = true
                            }
                            .foregroundColor(DesignSystem.Colors.accentBlue)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Focus Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Focus:")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        TextField("What are you focusing on?", text: $mlxLLMManager.userFocus)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                // Force save to UserDefaults
                                UserDefaults.standard.set(mlxLLMManager.userFocus, forKey: "userFocus")
                                showFocusSaved = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showFocusSaved = false
                                }
                            }
                    }
                    
                    if showFocusSaved {
                        Text("✓ Focus saved: \"\(mlxLLMManager.userFocus)\"")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.activeGreen)
                            .transition(.opacity)
                    }
                    
                    Text("The AI will check if your activities match this focus")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            
            Section("Application Blocking") {
                NavigationLink(destination: BlockingSettingsView()) {
                    HStack {
                        Image(systemName: "xmark.shield.fill")
                            .foregroundColor(.red)
                        Text("Blocking Settings")
                        Spacer()
                        if ApplicationBlockingManager.shared.isBlockingEnabled {
                            Text("Enabled")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Section("Data Storage") {
                HStack {
                    Button("Open Screenshots Folder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/src/shoulder/screenshots"))
                    }
                    Spacer()
                    Text("~/src/shoulder/screenshots")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                HStack {
                    Button("Open Analysis Folder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/src/shoulder/analyses"))
                    }
                    Spacer()
                    Text("~/src/shoulder/analyses")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Text("Screenshots are captured every 60 seconds")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showPermissionGuide) {
            PermissionGuideView(permissionManager: permissionManager)
        }
        .onAppear {
            permissionManager.checkAllPermissions()
        }
    }
}

struct PermissionStatusRow: View {
    let title: String
    let isGranted: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isGranted ? DesignSystem.Colors.activeGreen : Color.orange)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            if isGranted {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Granted")
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.activeGreen)
            } else {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("Required")
                        .font(.caption)
                }
                .foregroundColor(Color.orange)
            }
        }
    }
}
