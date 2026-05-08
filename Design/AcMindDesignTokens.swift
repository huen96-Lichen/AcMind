import SwiftUI

// MARK: - AcMind Design Tokens
// 统一的设计系统，确保视觉一致性

enum AcMindDesignTokens {

    // MARK: - Layout
    enum Layout {
        static let sidebarWidth: CGFloat = 240
        static let contentPadding: CGFloat = 28
        static let pageRadius: CGFloat = 24
        static let cardRadius: CGFloat = 16
        static let controlHeight: CGFloat = 36
        static let smallSpacing: CGFloat = 8
        static let mediumSpacing: CGFloat = 16
        static let largeSpacing: CGFloat = 24
        static let sectionSpacing: CGFloat = 32
    }

    // MARK: - Colors
    enum Colors {
        static let appBackground = Color(NSColor.windowBackgroundColor)
        static let surface = Color(NSColor.controlBackgroundColor).opacity(0.82)
        static let surfaceStrong = Color(NSColor.controlBackgroundColor)
        static let border = Color.black.opacity(0.08)
        static let textPrimary = Color(NSColor.labelColor)
        static let textSecondary = Color(NSColor.secondaryLabelColor)
        static let textTertiary = Color(NSColor.tertiaryLabelColor)
        static let accent = Color.accentColor

        // Semantic colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.system(size: 28, weight: .bold)
        static let title = Font.system(size: 22, weight: .semibold)
        static let title2 = Font.system(size: 17, weight: .semibold)
        static let title3 = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 13)
        static let bodyLarge = Font.system(size: 15)
        static let caption = Font.system(size: 12)
        static let captionSmall = Font.system(size: 11)
        static let monospace = Font.system(size: 13, design: .monospaced)
    }

    // MARK: - Shadows
    enum Shadows {
        static let small = ShadowStyle(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        static let large = ShadowStyle(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let smooth = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func apply<V: View>(_ view: V) -> some View {
        view.shadow(color: color, radius: radius, x: x, y: y)
    }
}

// MARK: - View Extensions

extension View {
    func acmindCardStyle() -> some View {
        self
            .background(AcMindDesignTokens.Colors.surfaceStrong)
            .cornerRadius(AcMindDesignTokens.Layout.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AcMindDesignTokens.Layout.cardRadius)
                    .stroke(AcMindDesignTokens.Colors.border, lineWidth: 1)
            )
    }

    func acmindPageStyle() -> some View {
        self
            .background(AcMindDesignTokens.Colors.appBackground)
            .ignoresSafeArea()
    }

    func acmindCapsuleStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AcMindDesignTokens.Colors.surfaceStrong)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            )
    }
}

// MARK: - Sidebar Style

struct SidebarItemStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
            .foregroundStyle(isSelected ? .white : .primary)
    }
}

extension View {
    func sidebarItemStyle(isSelected: Bool) -> some View {
        modifier(SidebarItemStyle(isSelected: isSelected))
    }
}
