//
//  DesignSystem.swift
//  shoulder
//
//  Created by Zachary Galbraith on 8/3/25.
//

import SwiftUI

struct DesignSystem {
    struct Colors {
        static let primaryGradient = LinearGradient(
            colors: [Color(hex: "007AFF"), Color(hex: "5856D6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let cardBackground = Color(NSColor.controlBackgroundColor).opacity(0.9)
        static let cardBackgroundDark = Color(hex: "1C1C1E")
        
        static let activeGreen = Color(hex: "34C759")
        static let warningOrange = Color(hex: "FF9500")
        static let errorRed = Color(hex: "FF3B30")
        
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color(NSColor.tertiaryLabelColor)
        
        static let accentBlue = Color(hex: "007AFF")
        static let accentPurple = Color(hex: "5856D6")
        static let accentTeal = Color(hex: "5AC8FA")
        static let accentPink = Color(hex: "FF2D55")
        
        // Additional colors for evaluation suite
        static let backgroundTertiary = Color(NSColor.quaternaryLabelColor).opacity(0.1)
        static let warningYellow = Color(hex: "FF9500")
        static let destructiveRed = Color(hex: "FF3B30")
    }
    
    struct Spacing {
        static let xxxSmall: CGFloat = 2
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let xxLarge: CGFloat = 48
    }
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }
    
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let smooth = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }
    
    struct Shadow {
        static let light = (color: Color.black.opacity(0.05), radius: 8.0, x: 0.0, y: 2.0)
        static let medium = (color: Color.black.opacity(0.1), radius: 12.0, x: 0.0, y: 4.0)
        static let heavy = (color: Color.black.opacity(0.15), radius: 20.0, x: 0.0, y: 8.0)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(colorScheme == .dark ? 
                          Color(NSColor.controlBackgroundColor).opacity(0.3) :
                          Color.white.opacity(0.8))
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(
                color: DesignSystem.Shadow.light.color,
                radius: DesignSystem.Shadow.light.radius,
                x: DesignSystem.Shadow.light.x,
                y: DesignSystem.Shadow.light.y
            )
    }
}

extension View {
    func glassCard() -> some View {
        self.modifier(GlassCardModifier())
    }
}

struct AppIconView: View {
    let appName: String
    let size: CGFloat
    
    private var iconColor: Color {
        switch appName.lowercased() {
        case let name where name.contains("safari"):
            return DesignSystem.Colors.accentBlue
        case let name where name.contains("chrome"):
            return Color(hex: "4285F4")
        case let name where name.contains("firefox"):
            return Color(hex: "FF9500")
        case let name where name.contains("xcode"):
            return DesignSystem.Colors.accentBlue
        case let name where name.contains("terminal"):
            return Color.black
        case let name where name.contains("finder"):
            return Color(hex: "1E8BFF")
        case let name where name.contains("slack"):
            return DesignSystem.Colors.accentPurple
        case let name where name.contains("mail"):
            return DesignSystem.Colors.accentBlue
        case let name where name.contains("messages"):
            return DesignSystem.Colors.activeGreen
        case let name where name.contains("notes"):
            return Color(hex: "FFD60A")
        case let name where name.contains("vscode") || name.contains("code"):
            return Color(hex: "007ACC")
        default:
            return DesignSystem.Colors.accentTeal
        }
    }
    
    private var iconSymbol: String {
        switch appName.lowercased() {
        case let name where name.contains("safari"):
            return "safari"
        case let name where name.contains("chrome") || name.contains("firefox"):
            return "globe"
        case let name where name.contains("xcode"):
            return "hammer"
        case let name where name.contains("terminal"):
            return "terminal"
        case let name where name.contains("finder"):
            return "folder"
        case let name where name.contains("slack"):
            return "message.badge"
        case let name where name.contains("mail"):
            return "envelope"
        case let name where name.contains("messages"):
            return "message"
        case let name where name.contains("notes"):
            return "note.text"
        case let name where name.contains("code"):
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "app"
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(
                    LinearGradient(
                        colors: [iconColor, iconColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image(systemName: iconSymbol)
                .font(.system(size: size * 0.5))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct PulsingDot: View {
    let color: Color
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}
