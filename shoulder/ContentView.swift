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
    @EnvironmentObject var focusManager: FocusSessionManager
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: String, CaseIterable {
        case dashboard = "Focus"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard: return "eye.trianglebadge.exclamationmark"
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
                    
                    Text("Focus Companion")
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
            
            MLXStatusView(mlxManager: mlxLLMManager)
            .padding(DesignSystem.Spacing.medium)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}


struct SettingsView: View {
    @EnvironmentObject var mlxLLMManager: MLXLLMManager
    @EnvironmentObject var permissionManager: PermissionManager
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
            
            Section("AI Model") {
                ModelSelectionView(mlxManager: mlxLLMManager)
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

struct ModelSelectionView: View {
    @ObservedObject var mlxManager: MLXLLMManager
    @State private var isChangingModel = false
    @State private var showApiKeyField = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("AI Model", selection: Binding(
                get: { mlxManager.selectedModel },
                set: { newModel in
                    Task {
                        isChangingModel = true
                        await mlxManager.switchModel(to: newModel)
                        isChangingModel = false
                    }
                }
            )) {
                ForEach(AIModelConfiguration.availableModels, id: \.id) { config in
                    Text(config.displayName)
                        .tag(config.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(isChangingModel)
            
            if isChangingModel {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Switching models...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if mlxManager.isRemoteModel {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("OpenAI API Key:")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Button(action: { showApiKeyField.toggle() }) {
                            Image(systemName: showApiKeyField ? "eye.slash" : "eye")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showApiKeyField {
                        SecureField("Enter your OpenAI API key", text: $mlxManager.openaiApiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField("Enter your OpenAI API key", text: $mlxManager.openaiApiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

