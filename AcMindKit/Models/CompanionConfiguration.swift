import Foundation

/// 随身配置
///
/// 这份配置保存的是随身入口与捕获行为的真实持久化状态，
/// 供设置页、随身面板和运行时注册逻辑共享。
public struct CompanionConfiguration: Codable, Sendable, Equatable {
    public var companionEnabled: Bool
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
        companionEnabled: Bool = true,
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
        self.companionEnabled = companionEnabled
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
        case companionEnabled
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
        companionEnabled = try container.decodeIfPresent(Bool.self, forKey: .companionEnabled) ?? true
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

/// 随身捕获结果去向
public enum CompanionCaptureSaveDestination: Int, CaseIterable, Codable, Sendable, Identifiable {
    case inbox = 0
    case clipboard = 1
    case ask = 2

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .inbox:
            return "收集箱"
        case .clipboard:
            return "剪贴板"
        case .ask:
            return "询问"
        }
    }

    public var description: String {
        switch self {
        case .inbox:
            return "捕获后默认进入收集箱"
        case .clipboard:
            return "捕获后复制结果到剪贴板"
        case .ask:
            return "每次捕获后询问下一步"
        }
    }
}
