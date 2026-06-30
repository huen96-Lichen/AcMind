import Foundation
import SwiftUI
import AcMindKit

// MARK: - Companion Layer Types
// 随身核心类型定义

/// 随身状态
public enum CompanionStatus: String, CaseIterable, Sendable {
    case idle = "idle"
    case listening = "listening"
    case transcribing = "transcribing"
    case ready = "ready"
    case error = "error"

    public var displayName: String {
        switch self {
        case .idle: return "待机"
        case .listening: return "正在听"
        case .transcribing: return "转写中"
        case .ready: return "已完成"
        case .error: return "出错"
        }
    }

    public var icon: String {
        switch self {
        case .idle: return "mic.circle"
        case .listening: return "waveform.circle.fill"
        case .transcribing: return "ellipsis.circle"
        case .ready: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .idle: return .secondary
        case .listening: return .red
        case .transcribing: return .blue
        case .ready: return .green
        case .error: return .orange
        }
    }
}

/// 随身胶囊位置
public enum CompanionCapsulePosition: String, CaseIterable, Sendable, Identifiable {
    case topCenter = "topCenter"
    case topRight = "topRight"
    case hidden = "hidden"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .topCenter: return "顶部居中"
        case .topRight: return "右上角"
        case .hidden: return "隐藏"
        }
    }
}

/// 说入法输出方式
public typealias VoiceOutputMode = SayInputOutputMode

public enum DynamicContinentModuleID: String, CaseIterable, Codable, Sendable, Identifiable {
    case music
    case agent
    case schedule
    case systemStatus

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .music: return "音乐模块"
        case .agent: return "智能体模块"
        case .schedule: return "日程模块"
        case .systemStatus: return "系统状态模块"
        }
    }

    public var description: String { displayName }

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
        case .agent: return "智能体"
        case .systemStatus: return "系统状态"
        }
    }

    public var description: String { displayName }
}

public enum CompanionCollapsedHeightMode: String, CaseIterable, Codable, Sendable, Identifiable, CustomStringConvertible {
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

    public var description: String { displayName }

    public var id: String { rawValue }
}

public enum CompanionNonNotchHeightMode: String, CaseIterable, Codable, Sendable, Identifiable, CustomStringConvertible {
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

    public var description: String { displayName }

    public var id: String { rawValue }
}

/// 灵动大陆显示与行为配置
struct CompanionDisplaySettings: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var autoExpand: Bool
    public var hoverExpandDelay: Double
    public var showOnAllDisplays: Bool
    public var autoSwitchDisplays: Bool
    public var preferredDisplayID: String?
    public var hideInFullscreen: Bool
    public var hideWhenScreenRecording: Bool
    public var enabledDynamicModules: Set<DynamicContinentModuleID>
    public var dynamicModuleOrder: [DynamicContinentModuleID]
    public var overviewVisibleModules: Set<DynamicContinentModuleID>
    public var collapsedVisibleContents: Set<CompanionRuntimeContentID>
    public var collapsedVisibleContentOrder: [CompanionRuntimeContentID]
    public var primarySurfaceContents: Set<CompanionRuntimeContentID>
    public var primarySurfaceContentOrder: [CompanionRuntimeContentID]
    public var nonNotchCollapsedWidth: CGFloat
    public var notchHeightMode: CompanionCollapsedHeightMode
    public var notchCustomHeight: CGFloat
    public var nonNotchHeightMode: CompanionNonNotchHeightMode
    public var nonNotchCustomHeight: CGFloat
    public var showCollapsedSubtitle: Bool
    public var showCollapsedStatusDots: Bool
    public var showSystemEventHUD: Bool
    public var enabledSystemEventKinds: Set<SystemEventKind>

    init(
        isEnabled: Bool = true,
        autoExpand: Bool = false,
        hoverExpandDelay: Double = 1.5,
        showOnAllDisplays: Bool = false,
        autoSwitchDisplays: Bool = true,
        preferredDisplayID: String? = nil,
        hideInFullscreen: Bool = true,
        hideWhenScreenRecording: Bool = true,
        enabledDynamicModules: Set<DynamicContinentModuleID> = Set(DynamicContinentModuleID.allCases),
        dynamicModuleOrder: [DynamicContinentModuleID] = DynamicContinentModuleID.allCases,
        overviewVisibleModules: Set<DynamicContinentModuleID> = Set(DynamicContinentModuleID.allCases),
        collapsedVisibleContents: Set<CompanionRuntimeContentID> = Set(CompanionRuntimeContentID.allCases),
        collapsedVisibleContentOrder: [CompanionRuntimeContentID] = CompanionRuntimeContentID.allCases,
        primarySurfaceContents: Set<CompanionRuntimeContentID> = Set(CompanionRuntimeContentID.allCases),
        primarySurfaceContentOrder: [CompanionRuntimeContentID] = CompanionRuntimeContentID.allCases,
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
        self.dynamicModuleOrder = Self.normalizedOrder(dynamicModuleOrder, fallback: DynamicContinentModuleID.allCases)
        self.overviewVisibleModules = overviewVisibleModules
        self.collapsedVisibleContents = collapsedVisibleContents
        self.collapsedVisibleContentOrder = Self.normalizedOrder(collapsedVisibleContentOrder, fallback: CompanionRuntimeContentID.allCases)
        self.primarySurfaceContents = primarySurfaceContents
        self.primarySurfaceContentOrder = Self.normalizedOrder(primarySurfaceContentOrder, fallback: CompanionRuntimeContentID.allCases)
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
        case dynamicModuleOrder
        case overviewVisibleModules
        case collapsedVisibleContents
        case collapsedVisibleContentOrder
        case primarySurfaceContents
        case primarySurfaceContentOrder
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

    init(from decoder: Decoder) throws {
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
        dynamicModuleOrder = Self.normalizedOrder(
            try container.decodeIfPresent([DynamicContinentModuleID].self, forKey: .dynamicModuleOrder) ?? DynamicContinentModuleID.allCases,
            fallback: DynamicContinentModuleID.allCases
        )
        overviewVisibleModules = try container.decodeIfPresent(Set<DynamicContinentModuleID>.self, forKey: .overviewVisibleModules) ?? enabledDynamicModules
        collapsedVisibleContents = try container.decodeIfPresent(Set<CompanionRuntimeContentID>.self, forKey: .collapsedVisibleContents) ?? Set(CompanionRuntimeContentID.allCases)
        collapsedVisibleContentOrder = Self.normalizedOrder(
            try container.decodeIfPresent([CompanionRuntimeContentID].self, forKey: .collapsedVisibleContentOrder) ?? CompanionRuntimeContentID.allCases,
            fallback: CompanionRuntimeContentID.allCases
        )
        primarySurfaceContents = try container.decodeIfPresent(Set<CompanionRuntimeContentID>.self, forKey: .primarySurfaceContents) ?? Set(CompanionRuntimeContentID.allCases)
        primarySurfaceContentOrder = Self.normalizedOrder(
            try container.decodeIfPresent([CompanionRuntimeContentID].self, forKey: .primarySurfaceContentOrder) ?? CompanionRuntimeContentID.allCases,
            fallback: CompanionRuntimeContentID.allCases
        )
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

    var collectionBehavior: NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [.stationary]
        if showOnAllDisplays {
            behavior.insert(.canJoinAllSpaces)
        }
        if hideInFullscreen == false {
            behavior.insert(.fullScreenAuxiliary)
        }
        return behavior
    }

    private static func normalizedOrder<T: Hashable & Codable>(
        _ values: [T],
        fallback: [T]
    ) -> [T] {
        let filtered = values.filter { fallback.contains($0) }
        let seen = Set(filtered)
        let missing = fallback.filter { seen.contains($0) == false }
        return filtered + missing
    }
}

enum CompanionDisplaySettingsStore {
    private static let key = "companion.displaySettings"

    public static func load() -> CompanionDisplaySettings {
        guard
            let raw = UserDefaults.standard.data(forKey: key),
            let value = try? JSONDecoder().decode(CompanionDisplaySettings.self, from: raw)
        else {
            return CompanionDisplaySettings()
        }
        return value
    }

    public static func save(_ settings: CompanionDisplaySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// 随身快捷键定义
public struct CompanionShortcut: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var action: String
    public var shortcut: String
    public var description: String
    public var isEnabled: Bool
    public var isEditable: Bool

    public init(
        id: String = UUID().uuidString,
        action: String,
        shortcut: String,
        description: String,
        isEnabled: Bool = true,
        isEditable: Bool = true
    ) {
        self.id = id
        self.action = action
        self.shortcut = shortcut
        self.description = description
        self.isEnabled = isEnabled
        self.isEditable = isEditable
    }

    public static var defaultShortcuts: [CompanionShortcut] {
        [
            CompanionShortcut(
                id: "sayinput",
                action: "说入法",
                shortcut: "Fn",
                description: "长按 Fn 在任意应用中唤起并清洗文稿",
                isEnabled: true,
                isEditable: false
            ),
            CompanionShortcut(
                id: "collect",
                action: "快速收集",
                shortcut: "⌥ C",
                description: "快速保存当前内容到收集箱",
                isEnabled: true,
                isEditable: true
            ),
            CompanionShortcut(
                id: "capture",
                action: "截图捕获",
                shortcut: "⌥ S",
                description: "快速截图并保存",
                isEnabled: true,
                isEditable: true
            ),
            CompanionShortcut(
                id: "agent",
                action: "打开智能体",
                shortcut: "⌥ A",
                description: "快速打开主窗口并聚焦智能体",
                isEnabled: true,
                isEditable: true
            ),
            CompanionShortcut(
                id: "schedule",
                action: "今日日程",
                shortcut: "⌥ T",
                description: "查看今日日程",
                isEnabled: true,
                isEditable: true
            )
        ]
    }
}

/// 随身捕获类型
public enum CompanionCaptureType: String, CaseIterable, Sendable, Identifiable {
    case screenshot = "screenshot"
    case scrollScreenshot = "scrollScreenshot"
    case clipboard = "clipboard"
    case selectedText = "selectedText"
    case webpage = "webpage"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .screenshot: return "截图到收集箱"
        case .scrollScreenshot: return "滚动截图到收集箱"
        case .clipboard: return "保存当前剪贴板"
        case .selectedText: return "保存当前选中文字"
        case .webpage: return "保存当前网页"
        }
    }

    public var icon: String {
        switch self {
        case .screenshot: return "camera.viewfinder"
        case .scrollScreenshot: return "scroll"
        case .clipboard: return "doc.on.clipboard"
        case .selectedText: return "text.quote"
        case .webpage: return "globe"
        }
    }
}

extension Notification.Name {
    static let companionConfigurationDidChange = Notification.Name("companion.configuration.didChange")
    static let companionEnabled = Notification.Name("companion.enabled")
    static let companionCapabilities = Notification.Name("companion.capabilities")
    static let companionCapsuleEnabled = Notification.Name("companion.capsule.enabled")
    static let companionCapsuleExpanded = Notification.Name("companion.capsule.expanded")
    static let companionCapsulePosition = Notification.Name("companion.capsule.position")
    static let companionCapsuleShowOnLaunch = Notification.Name("companion.capsule.showOnLaunch")
    static let companionCaptureAutoSaveToInbox = Notification.Name("companion.capture.autoSaveToInbox")
    static let companionCaptureCompleted = Notification.Name("companion.captureCompleted")
    static let companionCaptureEnabled = Notification.Name("companion.capture.enabled")
    static let companionCaptureLinkEnabled = Notification.Name("companion.capture.linkEnabled")
    static let companionCaptureOpenDetailAfterCapture = Notification.Name("companion.capture.openDetailAfterCapture")
    static let companionCaptureSaveDestinationIndex = Notification.Name("companion.capture.saveDestinationIndex")
    static let companionCaptureShortcut = Notification.Name("companion.capture.shortcut")
    static let companionCaptureShowNotification = Notification.Name("companion.capture.showNotification")
    static let companionCaptureSuccess = Notification.Name("companion.captureSuccess")
    static let companionCaptureTextEnabled = Notification.Name("companion.capture.textEnabled")
    static let companionClosePanel = Notification.Name("companion.closePanel")
    static let companionPlaybackStateChanged = Notification.Name("companion.playbackStateChanged")
    static let companionQuickNoteSaved = Notification.Name("companion.quickNoteSaved")
    static let companionScheduleShortcut = Notification.Name("companion.schedule.shortcut")
    static let companionScreenshotShortcut = Notification.Name("companion.screenshot.shortcut")
    static let companionShortcuts = Notification.Name("companion.shortcuts")
    static let companionShortcutsDidChange = Notification.Name("companion.shortcuts.didChange")
    static let companionShortcutsEnabled = Notification.Name("companion.shortcuts.enabled")
    static let companionShowAgent = Notification.Name("companion.showAgent")
    static let companionShowCapturePanel = Notification.Name("companion.showCapturePanel")
    static let companionShowInbox = Notification.Name("companion.showInbox")
    static let companionShowQuickNote = Notification.Name("companion.showQuickNote")
    static let companionShowSchedule = Notification.Name("companion.showSchedule")
    static let companionShowShortcuts = Notification.Name("companion.showShortcuts")
    static let companionShowVoicePanel = Notification.Name("companion.showVoicePanel")
    static let companionVoiceCancelled = Notification.Name("companion.voiceCancelled")
    static let companionVoiceEnabled = Notification.Name("companion.voice.enabled")
    static let companionVoiceFinishRequested = Notification.Name("companion.voice.finishRequested")
    static let companionVoiceOutputMode = Notification.Name("companion.voice.outputMode")
    static let companionVoiceProcessingFinished = Notification.Name("companion.voiceProcessingFinished")
    static let companionVoiceProcessingStarted = Notification.Name("companion.voiceProcessingStarted")
    static let companionVoiceRealtimeTranscript = Notification.Name("companion.voiceRealtimeTranscript")
    static let companionVoiceRecordingStarted = Notification.Name("companion.voiceRecordingStarted")
    static let companionVoiceRecordingStopped = Notification.Name("companion.voiceRecordingStopped")
    static let companionVoiceSaveToInbox = Notification.Name("companion.voice.saveToInbox")
    static let companionVoiceShortcut = Notification.Name("companion.voice.shortcut")
}

/// 权限状态
public enum CompanionPermissionStatus: String, CaseIterable, Sendable, Identifiable {
    case notDetermined = "notDetermined"
    case authorized = "authorized"
    case denied = "denied"
    case restricted = "restricted"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .notDetermined: return "未确定"
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限"
        }
    }

    public var color: Color {
        switch self {
        case .notDetermined: return .orange
        case .authorized: return .green
        case .denied, .restricted: return .red
        }
    }
}

/// 说入法清洗结果
public struct CompanionVoiceTranscription: Identifiable, Sendable {
    public let id = UUID()
    public let text: String
    public let timestamp: Date
    public let duration: TimeInterval

    public init(text: String, timestamp: Date = Date(), duration: TimeInterval = 0) {
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
    }
}
