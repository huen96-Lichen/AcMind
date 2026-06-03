import SwiftUI
import AppKit

enum AcMindDesignTokens {

    // MARK: - Layout
    enum Layout {
        static let sidebarWidth: CGFloat = 240
        static let contentPadding: CGFloat = 28
        static let pageRadius: CGFloat = 24
        static let cardRadius: CGFloat = 16
        static let secondaryCardRadius: CGFloat = 12
        static let inlineBlockRadius: CGFloat = 8
        static let controlHeight: CGFloat = 36
        static let smallSpacing: CGFloat = 8
        static let mediumSpacing: CGFloat = 16
        static let largeSpacing: CGFloat = 24
        static let sectionSpacing: CGFloat = 32
    }

    // MARK: - Colors (通用)
    enum Colors {
        static let appBackground = Color(NSColor.windowBackgroundColor)
        static let surface = Color(NSColor.controlBackgroundColor).opacity(0.82)
        static let surfaceStrong = Color(NSColor.controlBackgroundColor)
        static let border = Color(NSColor.separatorColor)
        static let textPrimary = Color(NSColor.labelColor)
        static let textSecondary = Color(NSColor.secondaryLabelColor)
        static let textTertiary = Color(NSColor.tertiaryLabelColor)
        static let accent = Color.accentColor

        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
    }

    // MARK: - Native (亮色模式，Mac 主窗口)
    enum Native {
        static let background = Color(NSColor.windowBackgroundColor)
        static let sidebarBackground = Color(NSColor.controlBackgroundColor)
        static let secondarySidebarBackground = Color(NSColor.controlBackgroundColor)
        static let contentBackground = Color(NSColor.windowBackgroundColor)
        static let islandBackground = Color(NSColor.windowBackgroundColor)
        static let islandBackgroundSoft = Color(NSColor.controlBackgroundColor)
        static let cardBackground = Color(NSColor.controlBackgroundColor)
        static let cardBackgroundSoft = Color(NSColor.controlBackgroundColor).opacity(0.92)
        static let cardBackgroundStrong = Color(NSColor.controlBackgroundColor)
        static let separator = Color(NSColor.separatorColor)
        static let primaryText = Color(NSColor.labelColor)
        static let secondaryText = Color(NSColor.secondaryLabelColor)
        static let tertiaryText = Color(NSColor.tertiaryLabelColor)
        static let accentBlue = Color(nsColor: .systemBlue)
        static let accentPrimary = Color(nsColor: .systemBlue)
        static let accentGreen = Color(nsColor: .systemGreen)
        static let accentOrange = Color(nsColor: .systemOrange)
        static let accentSecondary = Color(nsColor: .systemGray)
        static let accentCyan = Color(nsColor: .systemTeal)

        static let mainCardRadius: CGFloat = 18
        static let cardRadius: CGFloat = 16
        static let secondaryCardRadius: CGFloat = 14
        static let inlineBlockRadius: CGFloat = 10
        static let sidebarRadius: CGFloat = 24

        enum Typography {
            static let pageTitle: CGFloat = 28
            static let pageSubtitle: CGFloat = 13
            static let sectionTitle: CGFloat = 16
            static let sectionDesc: CGFloat = 12
            static let cardTitle: CGFloat = 14
            static let body: CGFloat = 13
            static let caption: CGFloat = 11
            static let rowTitle: CGFloat = 14.5
            static let rowDesc: CGFloat = 12.5
        }

        enum Layout {
            static let pageMaxWidth: CGFloat = 1360
            static let pagePadding: CGFloat = 24
            static let sectionSpacing: CGFloat = 16
            static let cardSpacing: CGFloat = 12
            static let rowHeight: CGFloat = 46
            static let toggleRowHeight: CGFloat = 46
            static let tabHeight: CGFloat = 40
            static let tabMinWidth: CGFloat = 112
            static let chipHeight: CGFloat = 28
            static let buttonHeight: CGFloat = 32
            static let keycapHeight: CGFloat = 28
            static let summaryWidth: CGFloat = 300
        }
    }

    // MARK: - Notch (暗色模式，Notch/Companion 面板)
    enum Notch {
        static let rootBackground = Color(red: 0.03, green: 0.03, blue: 0.035)
        static let panelBackground = Color(red: 0.055, green: 0.055, blue: 0.07)
        static let innerCardBackground = Color(red: 0.08, green: 0.08, blue: 0.095)
        static let innerCardActive = Color(red: 0.10, green: 0.10, blue: 0.12)
        static let panelBorder = Color.white.opacity(0.06)
        static let innerBorder = Color.white.opacity(0.08)
        static let backdropGradientTop = Color(red: 0.04, green: 0.04, blue: 0.06)
        static let backdropGradientBottom = Color(red: 0.015, green: 0.015, blue: 0.02)
        static let accentPurple = Color(nsColor: .systemBlue)
        static let accentPurpleLight = accentPurple
        static let accentPurpleDark = accentPurple
        static let accentGreen = Color(nsColor: .systemGreen)
        static let accentBlue = Color(nsColor: .systemBlue)
        static let primaryText = Color.white.opacity(0.95)
        static let secondaryText = Color.white.opacity(0.72)
        static let tertiaryText = Color.white.opacity(0.52)
        static let weakText = Color.white.opacity(0.35)
        static let islandBackground = rootBackground
        static let islandBackgroundSoft = Color(red: 0.04, green: 0.04, blue: 0.045)
        static let cardBackground = panelBackground
        static let cardBackgroundStrong = innerCardBackground
        static let cardBackgroundDeep = innerCardActive
        static let separator = panelBorder

        static let collapsedWidth: CGFloat = 228
        static let expandedWidth: CGFloat = 880
        static let collapsedHeight: CGFloat = 30
        static let expandedOverviewHeight: CGFloat = 460
        static let expandedMusicHeight: CGFloat = 460
        static let expandedAgentHeight: CGFloat = 460
        static let expandedScheduleHeight: CGFloat = 460
        static let expandedSystemStatusHeight: CGFloat = 460
        static let topBarHeight: CGFloat = 30
        static let dashboardFooterHeight: CGFloat = 48
        static let transitionInsertScale: CGFloat = 0.995
        static let transitionRemoveScale: CGFloat = 0.997
        static let springResponse: Double = 0.30
        static let springDampingFraction: Double = 0.92
        static let windowExpandDuration: TimeInterval = 0.24
        static let windowCollapseDuration: TimeInterval = 0.20
        static let notchSafeZoneX: CGFloat = 360
        static let notchSafeZoneY: CGFloat = 0
        static let notchSafeZoneWidth: CGFloat = 236
        static let notchSafeZoneHeight: CGFloat = 30
        static let cardRadius: CGFloat = 18
        static let rightCardRadius: CGFloat = 14
        static let largeRadius: CGFloat = 24
        static let islandBottomRadius: CGFloat = 14
        static let pagePadding: CGFloat = 18
        static let cardSpacing: CGFloat = 10
        static let bottomPadding: CGFloat = 8
        static let pillRadius: CGFloat = 999
        static let smallButtonRadius: CGFloat = 14
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

// MARK: - Notch 复用组件

struct NotchCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(
        cornerRadius: CGFloat = AcMindDesignTokens.Notch.cardRadius,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AcMindDesignTokens.Notch.cardBackgroundStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AcMindDesignTokens.Notch.innerBorder, lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    func acmindCardStyle() -> some View {
        self
            .background(AcMindDesignTokens.Native.cardBackground)
            .cornerRadius(AcMindDesignTokens.Native.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AcMindDesignTokens.Native.cardRadius)
                    .stroke(AcMindDesignTokens.Native.separator, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 4)
    }

    func acmindPageStyle() -> some View {
        self
            .background(AcMindDesignTokens.Native.background)
            .ignoresSafeArea()
    }

    func acmindCapsuleStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AcMindDesignTokens.Native.cardBackgroundStrong)
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
            .cornerRadius(AcMindDesignTokens.Layout.inlineBlockRadius)
            .foregroundStyle(isSelected ? .white : .primary)
    }
}

extension View {
    func sidebarItemStyle(isSelected: Bool) -> some View {
        modifier(SidebarItemStyle(isSelected: isSelected))
    }
}
