//
//  PermissionGuideView.swift
//  shoulder
//
//  Inline permission guide to help users enable required permissions
//

import SwiftUI

struct PermissionGuideView: View {
    @ObservedObject var permissionManager: PermissionManager
    @State private var isCheckingPermissions = false
    @State private var checkTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accentBlue, DesignSystem.Colors.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Permission Setup")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Shoulder needs a few permissions to monitor your activity")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DesignSystem.Spacing.xLarge)
            .padding(.bottom, DesignSystem.Spacing.large)
            
            // Permission Cards
            VStack(spacing: DesignSystem.Spacing.medium) {
                PermissionCard(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Capture screenshots for activity analysis",
                    isGranted: permissionManager.screenRecordingGranted,
                    action: {
                        permissionManager.openScreenRecordingSettings()
                        schedulePermissionRecheck()
                    }
                )
                
                PermissionCard(
                    icon: "hand.raised.square",
                    title: "Accessibility",
                    description: "Read window titles to track app usage",
                    isGranted: permissionManager.accessibilityGranted,
                    action: {
                        permissionManager.openAccessibilitySettings()
                        schedulePermissionRecheck()
                    }
                )
                
                PermissionCard(
                    icon: "bell.badge",
                    title: "Notifications",
                    description: "Alert you when blocking distracting apps",
                    isGranted: permissionManager.notificationsGranted,
                    action: {
                        Task {
                            let granted = await permissionManager.requestNotificationPermission()
                            if !granted {
                                permissionManager.openNotificationSettings()
                            }
                            schedulePermissionRecheck()
                        }
                    }
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            
            Spacer()
            
            // Bottom Actions
            VStack(spacing: DesignSystem.Spacing.medium) {
                if permissionManager.allPermissionsGranted {
                    Button(action: {
                        permissionManager.markSetupCompleted()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Continue")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Spacing.medium)
                        .background(DesignSystem.Colors.activeGreen)
                        .foregroundColor(.white)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DesignSystem.Spacing.large)
                }
                
                Button(action: {
                    permissionManager.markSetupCompleted()
                    dismiss()
                }) {
                    Text(permissionManager.allPermissionsGranted ? "Setup Complete" : "Skip Setup")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                
                if isCheckingPermissions {
                    HStack(spacing: DesignSystem.Spacing.small) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Checking permissions...")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .padding(.bottom, DesignSystem.Spacing.large)
        }
        .frame(width: 500, height: 600)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor)
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.accentBlue.opacity(0.05),
                        DesignSystem.Colors.accentPurple.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .onAppear {
            permissionManager.checkAllPermissions()
            startPeriodicPermissionCheck()
        }
        .onDisappear {
            stopPeriodicPermissionCheck()
        }
    }
    
    private func startPeriodicPermissionCheck() {
        // Check permissions every second while the view is visible
        checkTask = Task { @MainActor in
            while !Task.isCancelled {
                permissionManager.checkAllPermissions()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    private func stopPeriodicPermissionCheck() {
        checkTask?.cancel()
        checkTask = nil
    }
    
    private func schedulePermissionRecheck() {
        isCheckingPermissions = true
        
        // Check permissions every second for the next 10 seconds
        // This gives time for the user to grant permissions and return
        Task { @MainActor in
            for _ in 0..<10 {
                permissionManager.checkAllPermissions()
                
                if permissionManager.allPermissionsGranted {
                    isCheckingPermissions = false
                    break
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            isCheckingPermissions = false
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted ? DesignSystem.Colors.activeGreen.opacity(0.1) : Color.orange.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isGranted ? DesignSystem.Colors.activeGreen : Color.orange)
            }
            
            // Text
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxSmall) {
                HStack(spacing: DesignSystem.Spacing.xSmall) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.activeGreen)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Action Button
            if !isGranted {
                Button(action: action) {
                    Text("Enable")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, DesignSystem.Spacing.small)
                        .padding(.vertical, DesignSystem.Spacing.xSmall)
                        .background(DesignSystem.Colors.accentBlue)
                        .foregroundColor(.white)
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(isGranted ? DesignSystem.Colors.activeGreen.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}