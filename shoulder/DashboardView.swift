//
//  DashboardView.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/3/25.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Item.startTime, order: .reverse) private var items: [Item]
    @EnvironmentObject var screenMonitor: ScreenVisibilityMonitor
    
    private var activeSession: Item? {
        items.first { $0.endTime == nil }
    }
    
    private var todaySessions: [Item] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return items.filter { calendar.startOfDay(for: $0.startTime) == today }
    }
    
    private var totalTimeToday: TimeInterval {
        todaySessions.compactMap { $0.duration }.reduce(0, +)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                headerSection
                todaysSummary
                activeSessionCard
                recentActivitySection
            }
            .padding(DesignSystem.Spacing.large)
        }
        .background(backgroundGradient)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(NSColor.windowBackgroundColor),
                DesignSystem.Colors.accentBlue.opacity(0.05),
                DesignSystem.Colors.accentPurple.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                Text("Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: DesignSystem.Spacing.xSmall) {
                PulsingDot(color: DesignSystem.Colors.activeGreen, size: 8)
                Text("Recording")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.xSmall)
            .background(Capsule().fill(DesignSystem.Colors.activeGreen.opacity(0.1)))
        }
    }
    
    private var todaysSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                Text("Today's Activity")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xSmall) {
                    Text(formatDuration(totalTimeToday))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("• \(todaySessions.count) sessions")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.medium)
        .glassCard()
    }
    
    private var activeSessionCard: some View {
        Group {
            if let active = activeSession {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    HStack {
                        Text("Current Activity")
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        PulsingDot(color: DesignSystem.Colors.activeGreen, size: 6)
                    }
                    
                    HStack(spacing: DesignSystem.Spacing.medium) {
                        AppIconView(appName: active.appName, size: 48)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxSmall) {
                            Text(active.appName)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            if let windowTitle = active.windowTitle {
                                Text(windowTitle)
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                            
                            HStack {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text("Started \(active.startTime, format: .dateTime.hour().minute())")
                                    .font(.caption)
                            }
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text(formatElapsedTime(since: active.startTime))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.accentBlue)
                            Text("elapsed")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.large)
                .glassCard()
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Colors.activeGreen.opacity(0.3), lineWidth: 2)
                )
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: SessionsListView()) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.accentBlue)
                }
            }
            
            VStack(spacing: DesignSystem.Spacing.small) {
                ForEach(items.prefix(5)) { item in
                    RecentActivityRow(item: item)
                }
            }
        }
    }
    
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatElapsedTime(since startTime: Date) -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RecentActivityRow: View {
    let item: Item
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            AppIconView(appName: item.appName, size: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let windowTitle = item.windowTitle {
                    Text(windowTitle)
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let duration = item.duration {
                    Text(formatShortDuration(duration))
                        .font(.caption)
                        .fontWeight(.medium)
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(DesignSystem.Colors.activeGreen)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.caption2)
                    }
                }
                
                Text(item.startTime, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
    
    private func formatShortDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

