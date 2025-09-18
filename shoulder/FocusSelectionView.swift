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
    @State private var durationMinutes: Int = 30
    
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
                let storedDuration = focusManager.focusDurationMinutes
                durationMinutes = storedDuration > 0 ? storedDuration : 30
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
                
                Text("Your activities will be compared to your focus")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            
            // Duration selection section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                Label("Focus duration", systemImage: "timer")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Slider(value: Binding(
                        get: { Double(durationMinutes) },
                        set: { newValue in
                            let clamped = min(max(newValue, 5), 240)
                            let snapped = (clamped / 5).rounded() * 5
                            durationMinutes = Int(snapped)
                        }
                    ), in: 5...240, step: 5)
                        .tint(DesignSystem.Colors.accentBlue)

                    HStack {
                        Text("\(durationMinutes) minutes")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Stepper("", value: $durationMinutes, in: 5...240, step: 5)
                            .labelsHidden()
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
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
        focusManager.startFocusSession(focus: focusText, durationMinutes: durationMinutes)
    }
}
