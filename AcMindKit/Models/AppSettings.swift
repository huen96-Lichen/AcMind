import Foundation

// MARK: - AppSettings（应用设置）

/// 全局应用设置
/// 对齐旧版 app_settings 表
public struct AppSettings: Codable, Sendable, Equatable {
    // 外观
    public var theme: AppTheme
    public var language: String

    // AI 默认配置
    public var defaultProviderId: String?
    public var defaultModelId: String?
    public var modelRoutingStrategy: ModelRoutingStrategy

    // Vault
    public var vaultPath: String

    // 捕获
    public var autoCaptureClipboard: Bool
    public var captureScreenshotHotkey: String?

    // 导出
    public var defaultExportTarget: ExportTarget
    public var autoFrontmatter: Bool

    // 桌面胶囊
    public var desktopCapsule: DesktopCapsuleSettings

    // 热区触发角
    public var hotCornerSettings: HotCornerSettings

    public init(
        theme: AppTheme = .system,
        language: String = "zh-CN",
        defaultProviderId: String? = nil,
        defaultModelId: String? = nil,
        modelRoutingStrategy: ModelRoutingStrategy = .automatic,
        vaultPath: String = "",
        autoCaptureClipboard: Bool = true,
        captureScreenshotHotkey: String? = nil,
        defaultExportTarget: ExportTarget = .obsidian,
        autoFrontmatter: Bool = true,
        desktopCapsule: DesktopCapsuleSettings = .default,
        hotCornerSettings: HotCornerSettings = .defaultSettings
    ) {
        self.theme = theme
        self.language = language
        self.defaultProviderId = defaultProviderId
        self.defaultModelId = defaultModelId
        self.modelRoutingStrategy = modelRoutingStrategy
        self.vaultPath = vaultPath
        self.autoCaptureClipboard = autoCaptureClipboard
        self.captureScreenshotHotkey = captureScreenshotHotkey
        self.defaultExportTarget = defaultExportTarget
        self.autoFrontmatter = autoFrontmatter
        self.desktopCapsule = desktopCapsule
        self.hotCornerSettings = hotCornerSettings
    }
}

public enum AppTheme: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case light
    case dark
    case system

    public static var allCases: [AppTheme] { [.system, .light, .dark] }

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

// MARK: - CorrectionRule（纠错规则）

public struct CorrectionRule: Codable, Sendable, Identifiable, Equatable {
    public var id = UUID()
    public var pattern: String
    public var replacement: String
    public var isRegex: Bool

    public init(pattern: String, replacement: String, isRegex: Bool = false) {
        self.pattern = pattern
        self.replacement = replacement
        self.isRegex = isRegex
    }
}

// MARK: - VoiceSettings（语音设置）

public struct VoiceSettings: Codable, Sendable, Equatable {
    public var defaultProvider: String
    public var defaultLanguage: String
    public var autoPolish: Bool
    public var voicePolishMode: VoicePolishMode
    public var triggerMode: SayInputTriggerMode
    public var silenceTimeout: TimeInterval
    public var enableSilenceDetection: Bool
    public var outputMode: SayInputOutputMode
    public var saveToInbox: Bool
    public var allowContinuation: Bool
    public var continuationWindow: TimeInterval
    public var enablePunctuationAppend: Bool
    public var injectionStrategy: String
    public var enableCloudSync: Bool
    public var preferredLanguage: String
    public var translationLanguage: String
    public var correctionRules: [CorrectionRule]
    public var muteSystemAudioDuringRecording: Bool

    public init(
        defaultProvider: String = "whisper",
        defaultLanguage: String = "zh",
        autoPolish: Bool = true,
        voicePolishMode: VoicePolishMode = .light,
        triggerMode: SayInputTriggerMode = .hold,
        silenceTimeout: TimeInterval = 3.0,
        enableSilenceDetection: Bool = false,
        outputMode: SayInputOutputMode = .copyToClipboard,
        saveToInbox: Bool = true,
        allowContinuation: Bool = true,
        continuationWindow: TimeInterval = 12.0,
        enablePunctuationAppend: Bool = false,
        injectionStrategy: String = "postToPid",
        enableCloudSync: Bool = false,
        preferredLanguage: String = "auto",
        translationLanguage: String = "zh",
        correctionRules: [CorrectionRule] = [],
        muteSystemAudioDuringRecording: Bool = false
    ) {
        self.defaultProvider = defaultProvider
        self.defaultLanguage = defaultLanguage
        self.autoPolish = autoPolish
        self.voicePolishMode = voicePolishMode
        self.triggerMode = triggerMode
        self.silenceTimeout = silenceTimeout
        self.enableSilenceDetection = enableSilenceDetection
        self.outputMode = outputMode
        self.saveToInbox = saveToInbox
        self.allowContinuation = allowContinuation
        self.continuationWindow = continuationWindow
        self.enablePunctuationAppend = enablePunctuationAppend
        self.injectionStrategy = injectionStrategy
        self.enableCloudSync = enableCloudSync
        self.preferredLanguage = preferredLanguage
        self.translationLanguage = translationLanguage
        self.correctionRules = correctionRules
        self.muteSystemAudioDuringRecording = muteSystemAudioDuringRecording
    }
}

public enum PolishMode: String, Codable, Sendable, Hashable, CaseIterable {
    case none
    case standard
    case aggressive

    public static var allCases: [PolishMode] { [.none, .standard, .aggressive] }

    public var displayName: String {
        switch self {
        case .none: return "无"
        case .standard: return "标准"
        case .aggressive: return "强力"
        }
    }
}

public extension PolishMode {
    /// 映射到语音润色侧的四档模式
    var asVoicePolishMode: VoicePolishMode {
        switch self {
        case .none:
            return .none
        case .standard:
            return .light
        case .aggressive:
            return .formal
        }
    }
}

public extension VoiceSettings {
    /// 将语音设置转换为说入法配置
    var asSayInputConfiguration: SayInputConfiguration {
        SayInputConfiguration(
            autoPolish: autoPolish,
            polishMode: voicePolishMode,
            outputMode: outputMode,
            saveToInbox: saveToInbox,
            allowContinuation: allowContinuation,
            continuationWindow: continuationWindow,
            transcriptTimeout: 30.0,
            transcriptPollInterval: 1.0,
            triggerMode: triggerMode,
            silenceTimeout: silenceTimeout,
            enableSilenceDetection: enableSilenceDetection,
            preferredLanguage: preferredLanguage,
            translationLanguage: translationLanguage,
            correctionRules: correctionRules,
            muteSystemAudioDuringRecording: muteSystemAudioDuringRecording,
            enablePunctuationAppend: enablePunctuationAppend,
            injectionStrategy: injectionStrategy
        )
    }
}

// MARK: - System Types

public enum SystemPermission: String, Codable, Sendable, Hashable, CaseIterable {
    case microphone
    case screenRecording
    case accessibility
    case fullDiskAccess
    case notifications
    case speechRecognition

    public static var allCases: [SystemPermission] {
        [.microphone, .screenRecording, .accessibility, .fullDiskAccess, .notifications, .speechRecognition]
    }

    public var displayName: String {
        switch self {
        case .microphone: return "麦克风"
        case .screenRecording: return "屏幕录制"
        case .accessibility: return "辅助功能"
        case .fullDiskAccess: return "完全磁盘访问"
        case .notifications: return "通知"
        case .speechRecognition: return "语音识别"
        }
    }
}

public enum PermissionStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case notDetermined
    case denied
    case authorized
    case restricted

    public static var allCases: [PermissionStatus] {
        [.notDetermined, .denied, .authorized, .restricted]
    }

    public var displayName: String {
        switch self {
        case .notDetermined: return "未确定"
        case .denied: return "已拒绝"
        case .authorized: return "已授权"
        case .restricted: return "受限"
        }
    }
}

public struct KeyboardShortcut: Codable, Sendable, Hashable, Equatable {
    public let key: String
    public let modifiers: [ModifierKey]

    public init(key: String, modifiers: [ModifierKey] = []) {
        self.key = key
        self.modifiers = modifiers
    }

    public var displayString: String {
        let modString = modifiers.map(\.displayName).joined(separator: "+")
        return modString.isEmpty ? key : "\(modString)+\(key)"
    }
}

public extension KeyboardShortcut {
    /// Parse a user-facing shortcut string such as `⌥ C` or `⌘⇧4`.
    /// Returns nil for unsupported inputs like `Fn`.
    init?(displayString rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let collapsed = trimmed.replacingOccurrences(of: " ", with: "")
        guard collapsed.caseInsensitiveCompare("fn") != .orderedSame else { return nil }

        var remainder = collapsed
        var modifiers: [ModifierKey] = []
        let modifierSymbols: [String: ModifierKey] = [
            "⌘": .command,
            "⌥": .option,
            "⌃": .control,
            "⇧": .shift
        ]

        while let first = remainder.first, let modifier = modifierSymbols[String(first)] {
            if modifiers.contains(modifier) == false {
                modifiers.append(modifier)
            }
            remainder.removeFirst()
        }

        guard remainder.isEmpty == false else { return nil }
        self.init(key: remainder, modifiers: modifiers)
    }
}

public enum ModifierKey: String, Codable, Sendable, Hashable, CaseIterable {
    case command
    case option
    case control
    case shift

    public static var allCases: [ModifierKey] { [.command, .option, .control, .shift] }

    public var displayName: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }
}

// MARK: - SystemPermission → AppPermissionKind

public extension SystemPermission {
    var toAppPermissionKind: AppPermissionKind {
        switch self {
        case .microphone: return .microphone
        case .screenRecording: return .screenRecording
        case .accessibility: return .accessibility
        case .fullDiskAccess: return .fullDiskAccess
        case .notifications: return .notifications
        case .speechRecognition: return .speechRecognition
        }
    }
}

public extension Notification.Name {
    static let settingsDidChange = Notification.Name("AcMind.settingsDidChange")
}
