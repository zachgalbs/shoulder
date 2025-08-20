//
//  FocusSelectionView.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/13/25.
//

import SwiftUI

struct FocusSelectionView: View {
    @EnvironmentObject var focusManager: FocusSessionManager
    @State private var focusText: String = ""
    @State private var selectedDuration: Int = 60
    @State private var customDuration: String = ""
    @State private var useCustomDuration: Bool = false
    @State private var customDurationError: String?
    
    let predefinedDurations = [15, 30, 45, 60, 90, 120]
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    // Header
                    headerSection(width: min(geometry.size.width, 800))
                    
                    // Main content
                    mainContent(width: min(geometry.size.width, 800))
                    
                    // Start button
                    startButton(width: min(geometry.size.width, 800))
                }
                .padding(.horizontal, dynamicPadding(for: geometry.size.width))
                .padding(.vertical, DesignSystem.Spacing.medium)
                .frame(maxWidth: 800)
                .frame(minHeight: geometry.size.height)
                .frame(maxWidth: .infinity)
            }
            .background(backgroundGradient)
            .onAppear {
                // Pre-fill with last focus if available
                if !focusManager.focusText.isEmpty {
                    focusText = focusManager.focusText
                }
                selectedDuration = focusManager.focusDurationMinutes
            }
        }
    }
    
    private func dynamicPadding(for width: CGFloat) -> CGFloat {
        if width < 400 {
            return DesignSystem.Spacing.small
        } else if width < 600 {
            return DesignSystem.Spacing.medium
        } else {
            return DesignSystem.Spacing.large
        }
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
    
    private func headerSection(width: CGFloat) -> some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "eye.trianglebadge.exclamationmark")
                .font(.system(size: dynamicIconSize(for: width)))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.accentBlue, DesignSystem.Colors.accentPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Welcome to Shoulder")
                .font(dynamicTitleFont(for: width))
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            Text("Set your focus for this session")
                .font(dynamicSubtitleFont(for: width))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(.top, DesignSystem.Spacing.medium)
    }
    
    private func dynamicIconSize(for width: CGFloat) -> CGFloat {
        if width < 400 {
            return 32
        } else if width < 600 {
            return 40
        } else {
            return 48
        }
    }
    
    private func dynamicTitleFont(for width: CGFloat) -> Font {
        if width < 400 {
            return .title2
        } else if width < 600 {
            return .title
        } else {
            return .largeTitle
        }
    }
    
    private func dynamicSubtitleFont(for width: CGFloat) -> Font {
        if width < 400 {
            return .caption
        } else if width < 600 {
            return .body
        } else {
            return .title3
        }
    }
    
    private func mainContent(width: CGFloat) -> some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Focus input section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Label("What are you focusing on?", systemImage: "target")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("e.g., Writing code, Studying, Creative work...", text: $focusText)
                    .textFieldStyle(.roundedBorder)
                    .font(dynamicTextFieldFont(for: width))
                    .frame(maxWidth: .infinity)
                
                Text("Your activities will be monitored to help you stay on track")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            
            // Duration selection section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                Label("How long do you want to focus?", systemImage: "timer")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Predefined duration buttons with adaptive grid
                LazyVGrid(
                    columns: adaptiveColumns(for: width),
                    spacing: DesignSystem.Spacing.small
                ) {
                    ForEach(predefinedDurations, id: \.self) { duration in
                        DurationButton(
                            duration: duration,
                            isSelected: !useCustomDuration && selectedDuration == duration,
                            width: width,
                            action: {
                                selectedDuration = duration
                                useCustomDuration = false
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Custom duration input
                HStack {
                    Button(action: {
                        useCustomDuration = true
                    }) {
                        HStack(spacing: DesignSystem.Spacing.xSmall) {
                            Image(systemName: useCustomDuration ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(useCustomDuration ? DesignSystem.Colors.accentBlue : DesignSystem.Colors.textSecondary)
                            Text("Custom:")
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    TextField("Minutes", text: $customDuration)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .disabled(!useCustomDuration)
                        .onChange(of: customDuration) {
                            if useCustomDuration {
                                if let minutes = Int(customDuration) {
                                    if minutes <= 0 {
                                        customDurationError = "Duration must be greater than 0"
                                    } else if minutes > 480 {
                                        customDurationError = "Duration cannot exceed 8 hours (480 minutes)"
                                    } else {
                                        customDurationError = nil
                                        selectedDuration = minutes
                                    }
                                } else if !customDuration.isEmpty {
                                    customDurationError = "Please enter a valid number"
                                } else {
                                    customDurationError = nil
                                }
                            }
                        }
                    
                    Text("minutes")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                }
                
                if let error = customDurationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func adaptiveColumns(for width: CGFloat) -> [GridItem] {
        let effectiveWidth = min(width, 800)
        let minItemWidth: CGFloat = 100
        let spacing: CGFloat = DesignSystem.Spacing.small
        let horizontalPadding = dynamicPadding(for: effectiveWidth) * 2
        let availableWidth = effectiveWidth - horizontalPadding
        let numberOfColumns = max(2, Int(availableWidth / (minItemWidth + spacing)))
        
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: min(numberOfColumns, 3))
    }
    
    
    private func dynamicTextFieldFont(for width: CGFloat) -> Font {
        if width < 400 {
            return .body
        } else if width < 600 {
            return .title3
        } else {
            return .title3
        }
    }
    
    private func startButton(width: CGFloat) -> some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Button(action: startFocusSession) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Focus Session")
                        .fontWeight(.semibold)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                .font(dynamicButtonFont(for: width))
                .foregroundColor(.white)
                .frame(maxWidth: dynamicButtonWidth(for: width))
                .padding(.vertical, dynamicButtonPadding(for: width))
                .background(
                    LinearGradient(
                        colors: focusText.isEmpty ? 
                            [Color.gray, Color.gray.opacity(0.8)] :
                            [DesignSystem.Colors.accentBlue, DesignSystem.Colors.accentPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .shadow(
                    color: DesignSystem.Shadow.medium.color,
                    radius: DesignSystem.Shadow.medium.radius,
                    x: DesignSystem.Shadow.medium.x,
                    y: DesignSystem.Shadow.medium.y
                )
            }
            .disabled(focusText.isEmpty)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            
            if !focusText.isEmpty {
                Text("Session will last \(selectedDuration) minutes")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.top, DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity)
    }
    
    private func dynamicButtonFont(for width: CGFloat) -> Font {
        if width < 400 {
            return .body
        } else if width < 600 {
            return .title3
        } else {
            return .title3
        }
    }
    
    private func dynamicButtonWidth(for width: CGFloat) -> CGFloat {
        if width < 400 {
            return width * 0.8
        } else if width < 600 {
            return min(width * 0.6, 280)
        } else {
            return 300
        }
    }
    
    private func dynamicButtonPadding(for width: CGFloat) -> CGFloat {
        if width < 400 {
            return DesignSystem.Spacing.small
        } else {
            return DesignSystem.Spacing.medium
        }
    }
    
    private func startFocusSession() {
        guard !focusText.isEmpty else { return }
        guard customDurationError == nil else { return }
        
        let duration = useCustomDuration ? (Int(customDuration) ?? 60) : selectedDuration
        focusManager.startFocusSession(focus: focusText, durationMinutes: duration)
    }
}

struct DurationButton: View {
    let duration: Int
    let isSelected: Bool
    let width: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xxSmall) {
                Text("\(duration)")
                    .font(dynamicDurationFont(for: width))
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.7)
                Text("min")
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, dynamicDurationPadding(for: width))
            .padding(.horizontal, DesignSystem.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(isSelected ? 
                        LinearGradient(
                            colors: [DesignSystem.Colors.accentBlue, DesignSystem.Colors.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) : 
                        LinearGradient(
                            colors: [Color(NSColor.controlBackgroundColor)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .stroke(isSelected ? Color.clear : DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func dynamicDurationFont(for width: CGFloat) -> Font {
        if width < 400 {
            return .body
        } else if width < 600 {
            return .title3
        } else {
            return .title3
        }
    }
    
    private func dynamicDurationPadding(for width: CGFloat) -> CGFloat {
        if width < 400 {
            return DesignSystem.Spacing.xSmall
        } else {
            return DesignSystem.Spacing.small
        }
    }
}

