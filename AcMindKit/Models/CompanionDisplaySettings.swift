import Foundation
import AppKit

public enum DynamicContinentModuleID: String, CaseIterable, Codable, Sendable, Identifiable {
    case music
    case agent
    case schedule
    case systemStatus

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .music: return "音乐模块"
        case .agent: return "Agent 模块"
        case .schedule: return "日程模块"
        case .systemStatus: return "系统状态模块"
        }
    }

    public var icon: String {
        switch self {
        case .music: return "music.note"
        case .agent: return "bubble.left"
        case .schedule: return "calendar"
        case .systemStatus: return "cpu"
        }
    }

    public var supportsOverviewSummary: Bool { true }
}

public enum CompanionRuntimeContentID: String, CaseIterable, Codable, Sendable, Identifiable {
    case voice
    case screenshot
    case music
    case schedule
    case agent
    case systemStatus

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .voice: return "说入法"
        case .screenshot: return "截图反馈"
        case .music: return "音乐"
        case .schedule: return "日程"
        case .agent: return "Agent"
        case .systemStatus: return "系统状态"
        }
    }
}

public enum CompanionCollapsedHeightMode: String, CaseIterable, Codable, Sendable {
    case matchHardwareNotch
    case matchMenuBar
    case custom

    public var displayName: String {
        switch self {
        case .matchHardwareNotch: return "匹配真实刘海"
        case .matchMenuBar: return "匹配菜单栏"
        case .custom: return "自定义"
        }
    }
}

public enum CompanionNonNotchHeightMode: String, CaseIterable, Codable, Sendable {
    case matchMenuBar
    case matchNotchReference
    case custom

    public var displayName: String {
        switch self {
        case .matchMenuBar: return "匹配菜单栏"
        case .matchNotchReference: return "匹配刘海参考高度"
        case .custom: return "自定义"
        }
    }
}

public struct CompanionDisplaySettings: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var autoExpand: Bool
    public var hoverExpandDelay: Double
    public var showOnAllDisplays: Bool
    public var autoSwitchDisplays: Bool
    public var preferredDisplayID: String?
    public var hideInFullscreen: Bool
    public var hideWhenScreenRecording: Bool
    public var enabledDynamicModules: Set<DynamicContinentModuleID>
    public var overviewVisibleModules: Set<DynamicContinentModuleID>
    public var collapsedVisibleContents: Set<CompanionRuntimeContentID>
    public var primarySurfaceContents: Set<CompanionRuntimeContentID>
    public var nonNotchCollapsedWidth: CGFloat
    public var notchHeightMode: CompanionCollapsedHeightMode
    public var notchCustomHeight: CGFloat
    public var nonNotchHeightMode: CompanionNonNotchHeightMode
    public var nonNotchCustomHeight: CGFloat
    public var showCollapsedSubtitle: Bool
    public var showCollapsedStatusDots: Bool
    public var showSystemEventHUD: Bool
    public var enabledSystemEventKinds: Set<SystemEventKind>

    public init(
        isEnabled: Bool = true,
        autoExpand: Bool = false,
        hoverExpandDelay: Double = 1.5,
        showOnAllDisplays: Bool = false,
        autoSwitchDisplays: Bool = true,
        preferredDisplayID: String? = nil,
        hideInFullscreen: Bool = true,
        hideWhenScreenRecording: Bool = true,
        enabledDynamicModules: Set<DynamicContinentModuleID> = Set(DynamicContinentModuleID.allCases),
        overviewVisibleModules: Set<DynamicContinentModuleID> = Set(DynamicContinentModuleID.allCases),
        collapsedVisibleContents: Set<CompanionRuntimeContentID> = Set(CompanionRuntimeContentID.allCases),
        primarySurfaceContents: Set<CompanionRuntimeContentID> = Set(CompanionRuntimeContentID.allCases),
        nonNotchCollapsedWidth: CGFloat = 220,
        notchHeightMode: CompanionCollapsedHeightMode = .matchHardwareNotch,
        notchCustomHeight: CGFloat = 30,
        nonNotchHeightMode: CompanionNonNotchHeightMode = .matchMenuBar,
        nonNotchCustomHeight: CGFloat = 30,
        showCollapsedSubtitle: Bool = true,
        showCollapsedStatusDots: Bool = true,
        showSystemEventHUD: Bool = true,
        enabledSystemEventKinds: Set<SystemEventKind> = Set(SystemEventKind.allCases)
    ) {
        self.isEnabled = isEnabled
        self.autoExpand = autoExpand
        self.hoverExpandDelay = hoverExpandDelay
        self.showOnAllDisplays = showOnAllDisplays
        self.autoSwitchDisplays = autoSwitchDisplays
        self.preferredDisplayID = preferredDisplayID
        self.hideInFullscreen = hideInFullscreen
        self.hideWhenScreenRecording = hideWhenScreenRecording
        self.enabledDynamicModules = enabledDynamicModules
        self.overviewVisibleModules = overviewVisibleModules
        self.collapsedVisibleContents = collapsedVisibleContents
        self.primarySurfaceContents = primarySurfaceContents
        self.nonNotchCollapsedWidth = nonNotchCollapsedWidth
        self.notchHeightMode = notchHeightMode
        self.notchCustomHeight = notchCustomHeight
        self.nonNotchHeightMode = nonNotchHeightMode
        self.nonNotchCustomHeight = nonNotchCustomHeight
        self.showCollapsedSubtitle = showCollapsedSubtitle
        self.showCollapsedStatusDots = showCollapsedStatusDots
        self.showSystemEventHUD = showSystemEventHUD
        self.enabledSystemEventKinds = enabledSystemEventKinds
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case autoExpand
        case hoverExpandDelay
        case showOnAllDisplays
        case autoSwitchDisplays
        case preferredDisplayID
        case hideInFullscreen
        case hideWhenScreenRecording
        case enabledDynamicModules
        case overviewVisibleModules
        case collapsedVisibleContents
        case primarySurfaceContents
        case nonNotchCollapsedWidth
        case notchHeightMode
        case notchCustomHeight
        case nonNotchHeightMode
        case nonNotchCustomHeight
        case showCollapsedSubtitle
        case showCollapsedStatusDots
        case showSystemEventHUD
        case enabledSystemEventKinds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        autoExpand = try container.decodeIfPresent(Bool.self, forKey: .autoExpand) ?? false
        hoverExpandDelay = try container.decodeIfPresent(Double.self, forKey: .hoverExpandDelay) ?? 1.5
        showOnAllDisplays = try container.decodeIfPresent(Bool.self, forKey: .showOnAllDisplays) ?? false
        autoSwitchDisplays = try container.decodeIfPresent(Bool.self, forKey: .autoSwitchDisplays) ?? true
        preferredDisplayID = try container.decodeIfPresent(String.self, forKey: .preferredDisplayID)
        hideInFullscreen = try container.decodeIfPresent(Bool.self, forKey: .hideInFullscreen) ?? true
        hideWhenScreenRecording = try container.decodeIfPresent(Bool.self, forKey: .hideWhenScreenRecording) ?? true
        enabledDynamicModules = try container.decodeIfPresent(Set<DynamicContinentModuleID>.self, forKey: .enabledDynamicModules) ?? Set(DynamicContinentModuleID.allCases)
        overviewVisibleModules = try container.decodeIfPresent(Set<DynamicContinentModuleID>.self, forKey: .overviewVisibleModules) ?? enabledDynamicModules
        collapsedVisibleContents = try container.decodeIfPresent(Set<CompanionRuntimeContentID>.self, forKey: .collapsedVisibleContents) ?? Set(CompanionRuntimeContentID.allCases)
        primarySurfaceContents = try container.decodeIfPresent(Set<CompanionRuntimeContentID>.self, forKey: .primarySurfaceContents) ?? Set(CompanionRuntimeContentID.allCases)
        nonNotchCollapsedWidth = try container.decodeIfPresent(CGFloat.self, forKey: .nonNotchCollapsedWidth) ?? 220
        notchHeightMode = try container.decodeIfPresent(CompanionCollapsedHeightMode.self, forKey: .notchHeightMode) ?? .matchHardwareNotch
        notchCustomHeight = try container.decodeIfPresent(CGFloat.self, forKey: .notchCustomHeight) ?? 30
        nonNotchHeightMode = try container.decodeIfPresent(CompanionNonNotchHeightMode.self, forKey: .nonNotchHeightMode) ?? .matchMenuBar
        nonNotchCustomHeight = try container.decodeIfPresent(CGFloat.self, forKey: .nonNotchCustomHeight) ?? 30
        showCollapsedSubtitle = try container.decodeIfPresent(Bool.self, forKey: .showCollapsedSubtitle) ?? true
        showCollapsedStatusDots = try container.decodeIfPresent(Bool.self, forKey: .showCollapsedStatusDots) ?? true
        showSystemEventHUD = try container.decodeIfPresent(Bool.self, forKey: .showSystemEventHUD) ?? true
        enabledSystemEventKinds = try container.decodeIfPresent(Set<SystemEventKind>.self, forKey: .enabledSystemEventKinds) ?? Set(SystemEventKind.allCases)
    }

    public var collectionBehavior: NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [.stationary]
        if showOnAllDisplays {
            behavior.insert(.canJoinAllSpaces)
        }
        if hideInFullscreen == false {
            behavior.insert(.fullScreenAuxiliary)
        }
        return behavior
    }
}

public enum CompanionDisplaySettingsStore {
    private static let key = "companion.displaySettings"

    public static func load(from defaults: UserDefaults = .standard) -> CompanionDisplaySettings {
        guard
            let raw = defaults.data(forKey: key),
            let value = try? JSONDecoder().decode(CompanionDisplaySettings.self, from: raw)
        else {
            return CompanionDisplaySettings()
        }
        return value
    }

    public static func save(_ settings: CompanionDisplaySettings, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
