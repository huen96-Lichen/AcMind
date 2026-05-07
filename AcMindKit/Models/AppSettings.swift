import Foundation

// MARK: - AppSettings（应用设置）

/// 全局应用设置
/// 对齐 Electron app_settings 表
public struct AppSettings: Codable, Sendable, Equatable {
    // 外观
    public var theme: AppTheme
    public var language: String

    // AI 默认配置
    public var defaultProviderId: String?
    public var defaultModelId: String?

    // Vault
    public var vaultPath: String

    // 捕获
    public var autoCaptureClipboard: Bool
    public var captureScreenshotHotkey: String?

    // 导出
    public var defaultExportTarget: ExportTarget
    public var autoFrontmatter: Bool

    public init(
        theme: AppTheme = .system,
        language: String = "zh-CN",
        defaultProviderId: String? = nil,
        defaultModelId: String? = nil,
        vaultPath: String = "",
        autoCaptureClipboard: Bool = true,
        captureScreenshotHotkey: String? = nil,
        defaultExportTarget: ExportTarget = .obsidian,
        autoFrontmatter: Bool = true
    ) {
        self.theme = theme
        self.language = language
        self.defaultProviderId = defaultProviderId
        self.defaultModelId = defaultModelId
        self.vaultPath = vaultPath
        self.autoCaptureClipboard = autoCaptureClipboard
        self.captureScreenshotHotkey = captureScreenshotHotkey
        self.defaultExportTarget = defaultExportTarget
        self.autoFrontmatter = autoFrontmatter
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

// MARK: - VoiceSettings（语音设置）

public struct VoiceSettings: Codable, Sendable, Equatable {
    public var defaultProvider: String
    public var defaultLanguage: String
    public var autoPolish: Bool
    public var polishMode: PolishMode

    public init(
        defaultProvider: String = "whisper",
        defaultLanguage: String = "zh",
        autoPolish: Bool = true,
        polishMode: PolishMode = .standard
    ) {
        self.defaultProvider = defaultProvider
        self.defaultLanguage = defaultLanguage
        self.autoPolish = autoPolish
        self.polishMode = polishMode
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

// MARK: - System Types

public enum SystemPermission: String, Codable, Sendable, Hashable, CaseIterable {
    case microphone
    case screenRecording
    case accessibility
    case fullDiskAccess
    case notifications

    public static var allCases: [SystemPermission] {
        [.microphone, .screenRecording, .accessibility, .fullDiskAccess, .notifications]
    }

    public var displayName: String {
        switch self {
        case .microphone: return "麦克风"
        case .screenRecording: return "屏幕录制"
        case .accessibility: return "辅助功能"
        case .fullDiskAccess: return "完全磁盘访问"
        case .notifications: return "通知"
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
