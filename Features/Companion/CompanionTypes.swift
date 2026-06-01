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

/// 随身配置
public struct CompanionConfiguration: Codable, Sendable {
    public var capsuleEnabled: Bool
    public var capsuleShowOnLaunch: Bool
    public var capsulePosition: String
    public var capsuleExpandedByDefault: Bool

    public var voiceEnabled: Bool
    public var voiceShortcut: String
    public var voiceOutputMode: String
    public var voiceSaveToInbox: Bool

    public var shortcutsEnabled: Bool

    public var captureEnabled: Bool
    public var captureScreenshotShortcut: String
    public var captureShortcut: String
    public var agentShortcut: String
    public var scheduleShortcut: String
    public var captureAutoSaveToInbox: Bool
    public var captureTextEnabled: Bool
    public var captureLinkEnabled: Bool
    public var captureSaveDestinationIndex: Int

    public init(
        capsuleEnabled: Bool = true,
        capsuleShowOnLaunch: Bool = true,
        capsulePosition: String = "topCenter",
        capsuleExpandedByDefault: Bool = false,
        voiceEnabled: Bool = true,
        voiceShortcut: String = "⌥Space",
        voiceOutputMode: String = "copyToClipboard",
        voiceSaveToInbox: Bool = true,
        shortcutsEnabled: Bool = true,
        captureEnabled: Bool = true,
        captureScreenshotShortcut: String = "⌘⇧4",
        captureShortcut: String = "⌘⇧C",
        agentShortcut: String = "⌘1",
        scheduleShortcut: String = "⌘4",
        captureAutoSaveToInbox: Bool = true,
        captureTextEnabled: Bool = true,
        captureLinkEnabled: Bool = true,
        captureSaveDestinationIndex: Int = 0
    ) {
        self.capsuleEnabled = capsuleEnabled
        self.capsuleShowOnLaunch = capsuleShowOnLaunch
        self.capsulePosition = capsulePosition
        self.capsuleExpandedByDefault = capsuleExpandedByDefault
        self.voiceEnabled = voiceEnabled
        self.voiceShortcut = voiceShortcut
        self.voiceOutputMode = voiceOutputMode
        self.voiceSaveToInbox = voiceSaveToInbox
        self.shortcutsEnabled = shortcutsEnabled
        self.captureEnabled = captureEnabled
        self.captureScreenshotShortcut = captureScreenshotShortcut
        self.captureShortcut = captureShortcut
        self.agentShortcut = agentShortcut
        self.scheduleShortcut = scheduleShortcut
        self.captureAutoSaveToInbox = captureAutoSaveToInbox
        self.captureTextEnabled = captureTextEnabled
        self.captureLinkEnabled = captureLinkEnabled
        self.captureSaveDestinationIndex = captureSaveDestinationIndex
    }

    private enum CodingKeys: String, CodingKey {
        case capsuleEnabled
        case capsuleShowOnLaunch
        case capsulePosition
        case capsuleExpandedByDefault
        case voiceEnabled
        case voiceShortcut
        case voiceOutputMode
        case voiceSaveToInbox
        case shortcutsEnabled
        case captureEnabled
        case captureScreenshotShortcut
        case captureShortcut
        case agentShortcut
        case scheduleShortcut
        case captureAutoSaveToInbox
        case captureTextEnabled
        case captureLinkEnabled
        case captureSaveDestinationIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        capsuleEnabled = try container.decodeIfPresent(Bool.self, forKey: .capsuleEnabled) ?? true
        capsuleShowOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .capsuleShowOnLaunch) ?? true
        capsulePosition = try container.decodeIfPresent(String.self, forKey: .capsulePosition) ?? "topCenter"
        capsuleExpandedByDefault = try container.decodeIfPresent(Bool.self, forKey: .capsuleExpandedByDefault) ?? false
        voiceEnabled = try container.decodeIfPresent(Bool.self, forKey: .voiceEnabled) ?? true
        voiceShortcut = try container.decodeIfPresent(String.self, forKey: .voiceShortcut) ?? "⌥Space"
        voiceOutputMode = try container.decodeIfPresent(String.self, forKey: .voiceOutputMode) ?? "copyToClipboard"
        voiceSaveToInbox = try container.decodeIfPresent(Bool.self, forKey: .voiceSaveToInbox) ?? true
        shortcutsEnabled = try container.decodeIfPresent(Bool.self, forKey: .shortcutsEnabled) ?? true
        captureEnabled = try container.decodeIfPresent(Bool.self, forKey: .captureEnabled) ?? true
        captureScreenshotShortcut = try container.decodeIfPresent(String.self, forKey: .captureScreenshotShortcut) ?? "⌘⇧4"
        captureShortcut = try container.decodeIfPresent(String.self, forKey: .captureShortcut) ?? "⌘⇧C"
        agentShortcut = try container.decodeIfPresent(String.self, forKey: .agentShortcut) ?? "⌘1"
        scheduleShortcut = try container.decodeIfPresent(String.self, forKey: .scheduleShortcut) ?? "⌘4"
        captureAutoSaveToInbox = try container.decodeIfPresent(Bool.self, forKey: .captureAutoSaveToInbox) ?? true
        captureTextEnabled = try container.decodeIfPresent(Bool.self, forKey: .captureTextEnabled) ?? true
        captureLinkEnabled = try container.decodeIfPresent(Bool.self, forKey: .captureLinkEnabled) ?? true
        captureSaveDestinationIndex = try container.decodeIfPresent(Int.self, forKey: .captureSaveDestinationIndex) ?? 0
    }

    public static let `default` = CompanionConfiguration()
}

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
                action: "打开 Agent",
                shortcut: "⌥ A",
                description: "快速打开主窗口并聚焦 Agent",
                isEnabled: true,
                isEditable: true
            ),
            CompanionShortcut(
                id: "schedule",
                action: "今日日程",
                shortcut: "⌥ T",
                description: "快速查看今日日程",
                isEnabled: true,
                isEditable: true
            )
        ]
    }
}

/// 随身捕获类型
public enum CompanionCaptureType: String, CaseIterable, Sendable, Identifiable {
    case screenshot = "screenshot"
    case clipboard = "clipboard"
    case selectedText = "selectedText"
    case webpage = "webpage"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .screenshot: return "截图到收集箱"
        case .clipboard: return "保存当前剪贴板"
        case .selectedText: return "保存当前选中文字"
        case .webpage: return "保存当前网页"
        }
    }

    public var icon: String {
        switch self {
        case .screenshot: return "camera.viewfinder"
        case .clipboard: return "doc.on.clipboard"
        case .selectedText: return "text.quote"
        case .webpage: return "globe"
        }
    }
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
