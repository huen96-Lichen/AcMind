import Foundation
import SwiftUI

public enum CompanionSettingsDesign {
    public static let contentMaxWidth: CGFloat = 1280
    public static let pagePadding: CGFloat = 32
    public static let pageTopPadding: CGFloat = 22
    public static let sectionGap: CGFloat = 18
    public static let previewHeight: CGFloat = 316
    public static let previewRadius: CGFloat = 32
    public static let previewPadding: CGFloat = 22
    public static let sectionRadius: CGFloat = 24
    public static let sectionPadding: CGFloat = 20
    public static let widgetPillWidth: CGFloat = 92
    public static let widgetPillHeight: CGFloat = 32
    public static let widgetPillRadius: CGFloat = 16
    public static let widgetItemWidth: CGFloat = 104
    public static let widgetItemHeight: CGFloat = 66
    public static let linkageCardHeight: CGFloat = 84
    public static let linkageCardRadius: CGFloat = 18
    public static let linkageCardPadding: CGFloat = 16
    public static let featureCardPadding: CGFloat = 22
    public static let featureCardWidth: CGFloat = 0
    public static let featureCardHeight: CGFloat = 124
    public static let featureCardRadius: CGFloat = 20
    public static let titleFontSize: CGFloat = 32
    public static let subtitleFontSize: CGFloat = 15
    public static let sectionTitleFontSize: CGFloat = 17
    public static let bodyFontSize: CGFloat = 14
    public static let captionFontSize: CGFloat = 12

    public static let pageBackground = Color(red: 0.965, green: 0.972, blue: 0.98)
    public static let sectionBackground = Color.white.opacity(0.95)
    public static let subtleBackground = Color.white.opacity(0.82)
    public static let previewGradientStart = Color(red: 0.93, green: 0.96, blue: 0.99)
    public static let previewGradientEnd = Color(red: 0.97, green: 0.99, blue: 1.0)
    public static let previewBorder = Color.black.opacity(0.04)
    public static let accentBlue = Color.accentColor
    public static let softText = Color.black.opacity(0.48)
    public static let quietText = Color.black.opacity(0.32)
    public static let badgeBackground = Color.black.opacity(0.74)
    public static let badgeText = Color.white
    public static let widgetSurface = Color.black
}

public enum CompanionControlLayout {
    public static let contentMaxWidth: CGFloat = 1240
    public static let contentHeight: CGFloat = 740
    public static let pagePadding: CGFloat = 20
    public static let sectionGap: CGFloat = 14
    public static let sectionRadius: CGFloat = 22
    public static let sectionPadding: CGFloat = 16
    public static let titleHeight: CGFloat = 64
    public static let previewSectionHeight: CGFloat = 218
    public static let middleSectionHeight: CGFloat = 300
    public static let featureSectionHeight: CGFloat = 124
    public static let debugSectionHeight: CGFloat = 38
    public static let previewCardRadius: CGFloat = 22
    public static let previewCardPadding: CGFloat = 14
    public static let leftPreviewRatio: CGFloat = 0.43
    public static let rightPreviewRatio: CGFloat = 0.57
    public static let linkageWidth: CGFloat = 285
    public static let moduleManagerWidth: CGFloat = 190
    public static let linkageCardHeight: CGFloat = 72
    public static let linkageCardRadius: CGFloat = 16
    public static let linkageCardPadding: CGFloat = 12
    public static let widgetItemWidth: CGFloat = 76
    public static let widgetItemHeight: CGFloat = 52
    public static let widgetPillWidth: CGFloat = 68
    public static let widgetPillHeight: CGFloat = 26
    public static let widgetPillRadius: CGFloat = 13
    public static let widgetColumns: Int = 6
    public static let widgetColumnGap: CGFloat = 10
    public static let widgetRowGap: CGFloat = 10
    public static let widgetGroupGap: CGFloat = 14
    public static let moduleRowHeight: CGFloat = 36
    public static let featureCardHeight: CGFloat = 92
    public static let featureCardRadius: CGFloat = 18
    public static let featureCardPadding: CGFloat = 12
    public static let featureCardGap: CGFloat = 10
    public static let featureCardColumns: Int = 5
}

public enum CompanionPreviewMode: String, CaseIterable, Identifiable, Sendable {
    case capsuleCompact
    case capsuleExpanded
    case continentCompact
    case continentExpanded

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .capsuleCompact: return "胶囊收缩"
        case .capsuleExpanded: return "胶囊展开"
        case .continentCompact: return "大陆收缩"
        case .continentExpanded: return "大陆展开"
        }
    }

    public var displaySubtitle: String {
        switch self {
        case .capsuleCompact: return "桌面状态"
        case .capsuleExpanded: return "桌面状态"
        case .continentCompact: return "顶部状态"
        case .continentExpanded: return "顶部状态"
        }
    }
}

public enum CompanionLaunchSurface: String, CaseIterable, Identifiable, Sendable {
    case capsuleDesktop
    case continentTopDock

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .capsuleDesktop: return "桌面胶囊"
        case .continentTopDock: return "顶部大陆"
        }
    }
}

public enum CompanionFeatureTier: String, CaseIterable, Identifiable, Sendable {
    case pro
    case free
    case beta

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .pro: return "Pro"
        case .free: return "Free"
        case .beta: return "Beta"
        }
    }
}

public struct CompanionWidgetDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let symbolName: String
    public let valueText: String
    public let isEnabled: Bool

    public init(id: String, title: String, symbolName: String, valueText: String, isEnabled: Bool) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.valueText = valueText
        self.isEnabled = isEnabled
    }
}

public enum CompanionWidgetCatalog {
    public static let capsuleWidgets: [CompanionWidgetDefinition] = [
        .init(id: "agent", title: "Agent", symbolName: "sparkles", valueText: "AI", isEnabled: true),
        .init(id: "screenshot", title: "截图", symbolName: "camera.viewfinder", valueText: "Shot", isEnabled: true),
        .init(id: "voice", title: "语音", symbolName: "waveform", valueText: "STT", isEnabled: true),
        .init(id: "clipboard", title: "剪贴板", symbolName: "doc.on.clipboard", valueText: "Clip", isEnabled: false),
        .init(id: "schedule", title: "日程", symbolName: "calendar", valueText: "Plan", isEnabled: true),
        .init(id: "workspace", title: "工作台", symbolName: "square.grid.2x2", valueText: "Desk", isEnabled: false),
        .init(id: "launcher", title: "快捷启动", symbolName: "bolt.circle", valueText: "Go", isEnabled: true),
        .init(id: "tools", title: "工具", symbolName: "wrench.and.screwdriver", valueText: "Kit", isEnabled: false),
        .init(id: "inbox", title: "收集箱", symbolName: "tray.full", valueText: "Queue", isEnabled: true),
        .init(id: "pin", title: "Pin", symbolName: "pin", valueText: "Top", isEnabled: false),
        .init(id: "markdown", title: "Markdown", symbolName: "doc.text", valueText: "MD", isEnabled: false),
        .init(id: "ocr", title: "OCR", symbolName: "viewfinder", valueText: "Text", isEnabled: true)
    ]

    public static let continentWidgets: [CompanionWidgetDefinition] = [
        .init(id: "today", title: "今日", symbolName: "sun.max", valueText: "Now", isEnabled: true),
        .init(id: "music", title: "音乐", symbolName: "music.note", valueText: "Play", isEnabled: true),
        .init(id: "ai", title: "AI", symbolName: "brain", valueText: "Ask", isEnabled: true),
        .init(id: "schedule-continent", title: "日程", symbolName: "calendar.badge.clock", valueText: "Time", isEnabled: true),
        .init(id: "battery", title: "电量", symbolName: "battery.75percent", valueText: "87%", isEnabled: false),
        .init(id: "settings", title: "设置", symbolName: "gearshape", valueText: "Prefs", isEnabled: true),
        .init(id: "collapse", title: "收起", symbolName: "chevron.up", valueText: "Fold", isEnabled: false),
        .init(id: "status", title: "状态点", symbolName: "circle.fill", valueText: "Live", isEnabled: true),
        .init(id: "weather", title: "天气", symbolName: "cloud.sun", valueText: "24°", isEnabled: true),
        .init(id: "tasks", title: "任务", symbolName: "checklist", valueText: "Todo", isEnabled: false),
        .init(id: "entry", title: "快捷入口", symbolName: "rectangle.grid.1x2", valueText: "Jump", isEnabled: true),
        .init(id: "system", title: "系统状态", symbolName: "slider.horizontal.3", valueText: "OK", isEnabled: false)
    ]
}

public struct CompanionFeatureDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let tier: CompanionFeatureTier
    public let isEnabledByDefault: Bool

    public init(id: String, title: String, subtitle: String, tier: CompanionFeatureTier, isEnabledByDefault: Bool) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.tier = tier
        self.isEnabledByDefault = isEnabledByDefault
    }
}

public enum CompanionFeatureCatalog {
    public static let cards: [CompanionFeatureDefinition] = [
        .init(id: "music-link", title: "音乐联动", subtitle: "状态与歌词", tier: .pro, isEnabledByDefault: false),
        .init(id: "schedule-merge", title: "日程聚合", subtitle: "时间线复盘", tier: .free, isEnabledByDefault: true),
        .init(id: "quick-launch", title: "快捷启动", subtitle: "应用与动作", tier: .beta, isEnabledByDefault: false),
        .init(id: "agent-command", title: "Agent 指令", subtitle: "语音与文本", tier: .pro, isEnabledByDefault: false),
        .init(id: "desktop-state", title: "桌面状态", subtitle: "系统与提醒", tier: .free, isEnabledByDefault: false)
    ]
}

public struct CompanionLinkageRule: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let isEnabledByDefault: Bool

    public init(id: String, title: String, isEnabledByDefault: Bool) {
        self.id = id
        self.title = title
        self.isEnabledByDefault = isEnabledByDefault
    }
}

public enum CompanionLinkageCatalog {
    public static let rules: [CompanionLinkageRule] = [
        .init(id: "enable-capsule", title: "启用灵动胶囊", isEnabledByDefault: true),
        .init(id: "enable-continent", title: "启用灵动大陆", isEnabledByDefault: true),
        .init(id: "dock-capsule-to-continent", title: "拖动胶囊到顶部变成大陆", isEnabledByDefault: true),
        .init(id: "return-continent-to-capsule", title: "长按大陆拖回桌面变成胶囊", isEnabledByDefault: true)
    ]
}

public extension DynamicSurfaceVisibilityState {
    var displayName: String {
        switch self {
        case .capsuleCompact: return "灵动胶囊"
        case .continentCompact: return "灵动大陆"
        case .continentExpanded: return "灵动大陆展开"
        }
    }
}

public extension DynamicSurfaceDragPhase {
    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .draggingCapsule: return "胶囊拖拽中"
        case .capsuleHoveringTopDock: return "胶囊吸附预览"
        case .capsuleDockPreview: return "胶囊预览"
        case .draggingContinent: return "大陆拖拽中"
        case .continentLeavingTopDock: return "大陆离开顶部"
        case .committing: return "提交中"
        case .reverting: return "回退中"
        }
    }
}
