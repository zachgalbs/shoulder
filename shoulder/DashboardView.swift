//
//  DashboardView.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/3/25.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var screenMonitor: ScreenVisibilityMonitor
    @EnvironmentObject var mlxLLMManager: MLXLLMManager
    @EnvironmentObject var screenshotManager: ScreenshotManager
    @EnvironmentObject var focusManager: FocusSessionManager
    @State private var analysisError: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
                
                VStack(spacing: DesignSystem.Spacing.xxLarge) {
                    Spacer()
                    
                    // Main Focus Display
                    focusDisplay
                    
                    // Focus Status Indicator
                    if mlxLLMManager.isModelLoaded {
                        focusStatusIndicator
                    }
                    
                    // Error message
                    if let error = analysisError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(DesignSystem.Spacing.small)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    
                    // End Session Button
                    endSessionButton
                    
                    Spacer()
                }
                .padding(DesignSystem.Spacing.xxLarge)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
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
    
    private var focusDisplay: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Focus Text
            Text(focusManager.focusText.isEmpty ? "No Focus Set" : focusManager.focusText)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.accentBlue, DesignSystem.Colors.accentPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding(.horizontal)
            
            // Circular Progress with Time
            ZStack {
                // Background circle
                Circle()
                    .stroke(
                        Color(NSColor.separatorColor).opacity(0.2),
                        lineWidth: 20
                    )
                    .frame(width: 280, height: 280)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: focusManager.progressPercentage)
                    .stroke(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accentBlue, DesignSystem.Colors.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: focusManager.progressPercentage)
                
                // Time display
                VStack(spacing: DesignSystem.Spacing.xSmall) {
                    Text(focusManager.formattedTimeRemaining)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("remaining")
                        .font(.title3)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.large)
        }
    }
    
    private var focusStatusIndicator: some View {
        Group {
            if let analysis = mlxLLMManager.lastAnalysis {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    // Focus indicator
                    HStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: analysis.is_valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(analysis.is_valid ? DesignSystem.Colors.activeGreen : Color.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(analysis.is_valid ? "On Focus" : "Off Focus")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text(analysis.explanation)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Blocking indicator if active
                    if ApplicationBlockingManager.shared.focusModeActive {
                        HStack(spacing: DesignSystem.Spacing.xSmall) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.orange)
                            Text("Blocking Active")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(
                                    analysis.is_valid ? DesignSystem.Colors.activeGreen.opacity(0.2) : Color.red.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                )
            } else if mlxLLMManager.isAnalyzing {
                HStack {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(DesignSystem.Colors.accentBlue)
                                .frame(width: 6, height: 6)
                                .opacity(1.0)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: mlxLLMManager.isAnalyzing
                                )
                        }
                    }
                    Text("Analyzing focus...")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
            }
        }
    }
    
    private var endSessionButton: some View {
        Button(action: {
            focusManager.endSession()
        }) {
            HStack {
                Image(systemName: "stop.fill")
                Text("End Focus Session")
                    .fontWeight(.semibold)
            }
            .font(.title3)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.vertical, DesignSystem.Spacing.medium)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.8), Color.red],
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
        .buttonStyle(.plain)
    }
    
    private func analyzeCurrentSession() {
        guard let ocrText = screenshotManager.lastOCRText else { return }
        
        Task {
            do {
                _ = try await mlxLLMManager.analyzeScreenshot(
                    ocrText: ocrText,
                    appName: "",
                    windowTitle: nil
                )
            } catch {
                analysisError = "Analysis failed: \(error.localizedDescription)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    analysisError = nil
                }
            }
        }
    }
}