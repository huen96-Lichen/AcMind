import SwiftUI
import AppKit
import AcMindKit

// Notch 暗色模式 Token，值与 AcMindDesignTokens.Notch 保持同步
enum NotchV2DesignTokens {
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
    static let expandedWidth: CGFloat = CompanionMenuBarLayout.expandedWidth
    static let collapsedHeight: CGFloat = 30
    static let expandedOverviewHeight: CGFloat = CompanionMenuBarLayout.expandedHeight
    static let expandedMusicHeight: CGFloat = CompanionMenuBarLayout.expandedHeight
    static let expandedAgentHeight: CGFloat = CompanionMenuBarLayout.expandedHeight
    static let expandedScheduleHeight: CGFloat = CompanionMenuBarLayout.expandedHeight
    static let expandedSystemStatusHeight: CGFloat = CompanionMenuBarLayout.expandedHeight
    static let topBarHeight: CGFloat = 34
    static let dashboardFooterHeight: CGFloat = 28
    static let transitionInsertScale: CGFloat = 0.985
    static let transitionRemoveScale: CGFloat = 0.99
    static let springResponse: Double = 0.38
    static let springDampingFraction: Double = 0.88
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
    static let pagePadding: CGFloat = 20
    static let cardSpacing: CGFloat = 10
    static let bottomPadding: CGFloat = 8
    static let pillRadius: CGFloat = 999
    static let smallButtonRadius: CGFloat = 14

    static let collapsedArtworkSize: CGFloat = 18
    static let collapsedArtworkRadius: CGFloat = 4

    enum Typography {
        static let title = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 11, weight: .medium, design: .rounded)
        static let caption = Font.system(size: 9.5, weight: .medium, design: .rounded)
        static let footnote = Font.system(size: 8, weight: .regular, design: .rounded)
    }
}

enum NotchV2Page: String, CaseIterable, Identifiable {
    case overview
    case music
    case agent
    case schedule
    case systemStatus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "本机"
        case .music: return "音乐"
        case .agent: return "AI"
        case .schedule: return "日程"
        case .systemStatus: return "状态"
        }
    }
}
