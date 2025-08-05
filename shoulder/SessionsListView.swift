//
//  SessionsListView.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/3/25.
//

import SwiftUI
import SwiftData

struct SessionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.startTime, order: .reverse) private var items: [Item]
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: Item?
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case active = "Active"
        case completed = "Completed"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .today: return "calendar"
            case .active: return "play.circle"
            case .completed: return "checkmark.circle"
            }
        }
    }
    
    private var filteredItems: [Item] {
        let filtered = items.filter { item in
            if !searchText.isEmpty {
                let matchesSearch = item.appName.localizedCaseInsensitiveContains(searchText) ||
                                  (item.windowTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
                if !matchesSearch { return false }
            }
            
            switch selectedFilter {
            case .all:
                return true
            case .today:
                return Calendar.current.isDateInToday(item.startTime)
            case .active:
                return item.endTime == nil
            case .completed:
                return item.endTime != nil
            }
        }
        
        return filtered
    }
    
    private var groupedItems: [(key: String, value: [Item])] {
        let grouped = Dictionary(grouping: filteredItems) { item in
            formatDateHeader(item.startTime)
        }
        
        return grouped.sorted { first, second in
            guard let firstDate = filteredItems.first(where: { formatDateHeader($0.startTime) == first.key })?.startTime,
                  let secondDate = filteredItems.first(where: { formatDateHeader($0.startTime) == second.key })?.startTime else {
                return false
            }
            return firstDate > secondDate
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large, pinnedViews: .sectionHeaders) {
                        ForEach(groupedItems, id: \.key) { group in
                            Section {
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    ForEach(group.value) { item in
                                        SessionCardView(item: item)
                                            .contextMenu {
                                                Button(action: { deleteItem(item) }) {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            } header: {
                                Text(group.key)
                                    .font(.headline)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .padding(.vertical, DesignSystem.Spacing.xSmall)
                                    .padding(.horizontal, DesignSystem.Spacing.medium)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        Color(NSColor.windowBackgroundColor).opacity(0.95)
                                            .blur(radius: 10)
                                    )
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.large)
                }
            }
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
        .navigationTitle("Sessions")
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    modelContext.delete(item)
                }
            }
        } message: {
            Text("Are you sure you want to delete this session? This action cannot be undone.")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.small) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        FilterChip(
                            title: option.rawValue,
                            icon: option.icon,
                            isSelected: selectedFilter == option
                        ) {
                            selectedFilter = option
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.large)
        .background(
            Color(NSColor.windowBackgroundColor).opacity(0.95)
                .blur(radius: 10)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            Text(searchText.isEmpty ? "No sessions recorded" : "No results found")
                .font(.title3)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text(searchText.isEmpty ? "Sessions will appear here as you use your apps" : "Try adjusting your search or filters")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxLarge)
    }
    
    private func deleteItem(_ item: Item) {
        itemToDelete = item
        showingDeleteAlert = true
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xxSmall) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.xSmall)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(isSelected ? DesignSystem.Colors.accentBlue : Color(NSColor.controlBackgroundColor))
            )
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

struct SessionCardView: View {
    let item: Item
    @State private var isHovered = false
    
    var body: some View {
        NavigationLink(destination: SessionDetailView(session: item)) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                AppIconView(appName: item.appName, size: 44)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxSmall) {
                    HStack {
                        Text(item.appName)
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        if item.endTime == nil {
                            HStack(spacing: 4) {
                                PulsingDot(color: DesignSystem.Colors.activeGreen, size: 6)
                                Text("Active")
                                    .font(.caption2)
                                    .foregroundColor(DesignSystem.Colors.activeGreen)
                            }
                        }
                    }
                    
                    if let windowTitle = item.windowTitle {
                        Text(windowTitle)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: DesignSystem.Spacing.medium) {
                        HStack(spacing: DesignSystem.Spacing.xxSmall) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(item.startTime, format: .dateTime.hour().minute())
                                .font(.caption)
                        }
                        
                        if let endTime = item.endTime {
                            HStack(spacing: DesignSystem.Spacing.xxSmall) {
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                Text(endTime, format: .dateTime.hour().minute())
                                    .font(.caption)
                            }
                        }
                        
                        if let duration = item.duration {
                            HStack(spacing: DesignSystem.Spacing.xxSmall) {
                                Image(systemName: "timer")
                                    .font(.caption2)
                                Text(formatDuration(duration))
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding(DesignSystem.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.8 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(item.endTime == nil ? DesignSystem.Colors.activeGreen.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            let seconds = Int(duration) % 60
            return "\(seconds)s"
        }
    }
}