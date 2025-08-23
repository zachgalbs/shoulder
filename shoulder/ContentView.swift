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
    @State private var isValidatingKey = false
    
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
                    VStack(alignment: .leading) {
                        Text(config.displayName)
                            .font(.subheadline)
                        if !config.description.isEmpty {
                            Text(config.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
                APIKeyInputView(
                    apiKey: $mlxManager.openaiApiKey,
                    isModelReady: mlxManager.isModelReady,
                    isModelLoaded: mlxManager.isModelLoaded,
                    modelLoadingMessage: mlxManager.modelLoadingMessage,
                    isValidating: isValidatingKey,
                    onKeyChanged: { newKey in
                        if !newKey.isEmpty && newKey != mlxManager.openaiApiKey {
                            Task {
                                isValidatingKey = true
                                await mlxManager.switchModel(to: mlxManager.selectedModel)
                                isValidatingKey = false
                            }
                        }
                    }
                )
            }
        }
        .padding(.vertical, 4)
    }
}

/// Input field for OpenAI API key with validation, security, and accessibility features
/// Supports real-time validation with debouncing, secure display, and tap-to-reveal functionality
struct APIKeyInputView: View {
    @Binding var apiKey: String
    let isModelReady: Bool
    let isModelLoaded: Bool
    let modelLoadingMessage: String
    let isValidating: Bool
    let onKeyChanged: (String) -> Void
    
    @State private var showApiKey = false
    @State private var isEditing = false
    @State private var validationTimer: Timer?
    @State private var pendingValidationKey: String = ""
    
    private var keyValidationState: KeyValidationState {
        if isValidating {
            return .validating
        } else if apiKey.isEmpty {
            return .empty
        } else if !isModelLoaded && modelLoadingMessage.contains("API key") {
            return .invalid
        } else if isModelReady {
            return .valid
        } else {
            return .unknown
        }
    }
    
    /// Computed property for displaying truncated API key safely
    private var truncatedDisplayKey: String {
        guard !apiKey.isEmpty else { return APIKeyConstants.placeholderText }
        if apiKey.count <= 12 {
            return String(repeating: "•", count: apiKey.count)
        }
        return "sk-..." + String(apiKey.suffix(APIKeyConstants.keyPreviewLength))
    }
    
    /// Computed binding for TextField to prevent memory leaks
    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { apiKey },
            set: { newValue in
                apiKey = newValue
                scheduleValidation(for: newValue)
            }
        )
    }
    
    /// Schedule validation with debouncing to prevent race conditions
    private func scheduleValidation(for key: String) {
        // Cancel any existing timer
        validationTimer?.invalidate()
        pendingValidationKey = key
        
        // Only schedule validation for non-empty keys that have changed
        guard !key.isEmpty && key != apiKey else { return }
        
        validationTimer = Timer.scheduledTimer(withTimeInterval: APIKeyConstants.validationDebounceDelay, repeats: false) { _ in
            // Only trigger validation if the key hasn't changed since scheduling
            if pendingValidationKey == key {
                onKeyChanged(key)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Text("OpenAI API Key:")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
                
                // Validation status indicator
                HStack(spacing: 4) {
                    switch keyValidationState {
                    case .validating:
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Validating...")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    case .valid:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.activeGreen)
                            .font(.caption)
                        Text("Valid")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.activeGreen)
                    case .invalid:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.errorRed)
                            .font(.caption)
                        Text("Invalid")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.errorRed)
                    case .empty, .unknown:
                        EmptyView()
                    }
                }
                
                // Toggle visibility button with accessibility
                Button(action: { 
                    withAnimation(DesignSystem.Animation.quick) {
                        showApiKey.toggle()
                    }
                }) {
                    Image(systemName: showApiKey ? "eye.slash.fill" : "eye.fill")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.accentBlue)
                }
                .buttonStyle(.plain)
                .disabled(isValidating)
                .accessibilityLabel(showApiKey ? "Hide API key" : "Show API key")
                .accessibilityHint("Toggle API key visibility for secure entry")
            }
            
            // Fixed-height input field with proper accessibility
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(Color(NSColor.textBackgroundColor))
                    .stroke(strokeColor, lineWidth: 1)
                    .frame(height: APIKeyConstants.fieldHeight)
                
                HStack {
                    if showApiKey || isEditing {
                        TextField(APIKeyConstants.skPlaceholder, text: apiKeyBinding)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .onEditingChanged { editing in
                            isEditing = editing
                        }
                        .accessibilityLabel("OpenAI API Key Input")
                        .accessibilityHint("Enter your OpenAI API key for remote model access")
                    } else {
                        Text(truncatedDisplayKey)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(apiKey.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                            .onTapGesture {
                                withAnimation(DesignSystem.Animation.quick) {
                                    showApiKey = true
                                }
                            }
                            .accessibilityLabel(apiKey.isEmpty ? "API key not set" : "API key is set")
                            .accessibilityHint(APIKeyConstants.tapToEditHint)
                            .accessibilityAddTraits(.isButton)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.small)
            }
            
            // Error message
            if case .invalid = keyValidationState {
                Text(modelLoadingMessage)
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.errorRed)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(DesignSystem.Animation.standard, value: keyValidationState)
        .onDisappear {
            // Clean up timer when view disappears to prevent memory leaks
            validationTimer?.invalidate()
            validationTimer = nil
        }
    }
    
    private var strokeColor: Color {
        switch keyValidationState {
        case .valid:
            return DesignSystem.Colors.activeGreen.opacity(0.5)
        case .invalid:
            return DesignSystem.Colors.errorRed.opacity(0.5)
        case .validating:
            return DesignSystem.Colors.accentBlue.opacity(0.5)
        default:
            return Color.gray.opacity(0.3)
        }
    }
}

/// Validation states for the API key input field
private enum KeyValidationState {
    case empty
    case validating
    case valid
    case invalid
    case unknown
}

/// Constants for the API key input field
private enum APIKeyConstants {
    static let fieldHeight: CGFloat = 28
    static let keyPreviewLength = 4
    static let validationDebounceDelay: TimeInterval = 0.5
    static let placeholderText = "Enter your OpenAI API key"
    static let skPlaceholder = "sk-..."
    static let tapToEditHint = "Tap to edit API key"
}

