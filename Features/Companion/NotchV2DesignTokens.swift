import SwiftUI
import AppKit
import AcMindKit

enum NotchV2DesignTokens {
    static let rootBackground = Color(red: 0.02, green: 0.024, blue: 0.027) // #050607
    static let panelBackground = Color(red: 0.043, green: 0.047, blue: 0.055) // #0B0C0E
    static let innerCardBackground = Color(red: 0.078, green: 0.082, blue: 0.094) // #141518
    static let innerCardActive = Color(red: 0.102, green: 0.106, blue: 0.122) // #1A1B1F
    static let panelBorder = Color.white.opacity(0.085)
    static let innerBorder = Color.white.opacity(0.10)
    static let accentPurple = Color(red: 0.70, green: 0.19, blue: 1.0)
    static let accentPurpleLight = accentPurple
    static let accentPurpleDark = accentPurple
    static let accentGreen = Color(red: 0.22, green: 0.95, blue: 0.42)
    static let primaryText = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let secondaryText = Color.white.opacity(0.68)
    static let tertiaryText = Color.white.opacity(0.46)
    static let weakText = Color.white.opacity(0.28)
    static let islandBackground = rootBackground
    static let islandBackgroundSoft = rootBackground
    static let cardBackground = panelBackground
    static let cardBackgroundStrong = innerCardBackground
    static let cardBackgroundDeep = innerCardActive
    static let separator = panelBorder
    static let collapsedWidth: CGFloat = 228
    static let expandedWidth: CGFloat = 880
    static let collapsedHeight: CGFloat = 30
    static let expandedOverviewHeight: CGFloat = 440
    static let expandedMusicHeight: CGFloat = 390
    static let expandedAgentHeight: CGFloat = 430
    static let expandedScheduleHeight: CGFloat = 440
    static let notchSafeZoneX: CGFloat = 360
    static let notchSafeZoneY: CGFloat = 0
    static let notchSafeZoneWidth: CGFloat = 160
    static let notchSafeZoneHeight: CGFloat = 30
    static let cardRadius: CGFloat = 24
    static let largeRadius: CGFloat = 32
    static let islandBottomRadius: CGFloat = 12
    static let pagePadding: CGFloat = 32
    static let contentTopGap: CGFloat = 12
    static let contentBottomGap: CGFloat = 12
    static let bottomPadding: CGFloat = contentBottomGap
    static let cardSpacing: CGFloat = 20
    static let sectionGap: CGFloat = 24
    static let rowGap: CGFloat = 16
    static let leftColumnWidth: CGFloat = 160
    static let centerColumnWidth: CGFloat = 396
    static let rightColumnWidth: CGFloat = 180
    static let columnGap: CGFloat = 16
    static let topBarHeight: CGFloat = 36
    static let expandedContentHeight: CGFloat = 440
    static let mainTitleSize: CGFloat = 20
    static let pageTitleSize: CGFloat = 14
    static let cardTitleSize: CGFloat = 14
    static let bodySize: CGFloat = 14
    static let captionSize: CGFloat = 10
    static let microSize: CGFloat = 8
    static let pillRadius: CGFloat = 999
    static let smallButtonRadius: CGFloat = 16
}

enum NotchV2Page: String, CaseIterable, Identifiable {
    case overview
    case music
    case agent
    case schedule

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "今日"
        case .music: return "音乐"
        case .agent: return "AI"
        case .schedule: return "日程"
        }
    }
}
