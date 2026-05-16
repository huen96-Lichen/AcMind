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

/// 随身语音输出方式
public enum VoiceOutputMode: String, CaseIterable, Sendable, Identifiable {
    case copyToClipboard = "copyToClipboard"
    case autoPaste = "autoPaste"
    case ask = "ask"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .copyToClipboard: return "复制到剪贴板"
        case .autoPaste: return "自动粘贴"
        case .ask: return "询问"
        }
    }
}

/// 说入法触发方式
public enum CompanionVoiceTriggerMode: String, CaseIterable, Sendable, Identifiable {
    case fnHold = "fnHold"
    case globalShortcut = "globalShortcut"
    case both = "both"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fnHold: return "Fn 长按"
        case .globalShortcut: return "全局快捷键"
        case .both: return "两者都可"
        }
    }
}

/// 说入法输出目标
public enum CompanionVoiceRouteMode: String, CaseIterable, Sendable, Identifiable {
    case smart = "smart"
    case inputField = "inputField"
    case agent = "agent"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .smart: return "智能判断"
        case .inputField: return "输入框"
        case .agent: return "Agent"
        }
    }
}

/// 随身配置
public struct CompanionConfiguration: Codable, Sendable {
    public var capsuleEnabled: Bool
    public var capsulePosition: String
    public var capsuleExpandedByDefault: Bool

    public var voiceEnabled: Bool
    public var voiceShortcut: String
    public var voiceTriggerMode: String
    public var voiceProvider: String
    public var voiceModel: String
    public var voiceHoldToTalkEnabled: Bool
    public var voiceHoldThreshold: Double
    public var voiceRouteMode: String
    public var voiceOutputMode: String
    public var voiceSaveToInbox: Bool

    public var shortcutsEnabled: Bool

    public var captureEnabled: Bool

    public init(
        capsuleEnabled: Bool = true,
        capsulePosition: String = "topCenter",
        capsuleExpandedByDefault: Bool = false,
        voiceEnabled: Bool = true,
        voiceShortcut: String = "⌥Space",
        voiceTriggerMode: String = CompanionVoiceTriggerMode.both.rawValue,
        voiceProvider: String = STTProvider.appleSpeech.rawValue,
        voiceModel: String = "auto",
        voiceHoldToTalkEnabled: Bool = true,
        voiceHoldThreshold: Double = 0.38,
        voiceRouteMode: String = CompanionVoiceRouteMode.smart.rawValue,
        voiceOutputMode: String = "copyToClipboard",
        voiceSaveToInbox: Bool = true,
        shortcutsEnabled: Bool = true,
        captureEnabled: Bool = true
    ) {
        self.capsuleEnabled = capsuleEnabled
        self.capsulePosition = capsulePosition
        self.capsuleExpandedByDefault = capsuleExpandedByDefault
        self.voiceEnabled = voiceEnabled
        self.voiceShortcut = voiceShortcut
        self.voiceTriggerMode = voiceTriggerMode
        self.voiceProvider = voiceProvider
        self.voiceModel = voiceModel
        self.voiceHoldToTalkEnabled = voiceHoldToTalkEnabled
        self.voiceHoldThreshold = voiceHoldThreshold
        self.voiceRouteMode = voiceRouteMode
        self.voiceOutputMode = voiceOutputMode
        self.voiceSaveToInbox = voiceSaveToInbox
        self.shortcutsEnabled = shortcutsEnabled
        self.captureEnabled = captureEnabled
    }

    public static let `default` = CompanionConfiguration()
}

public extension CompanionConfiguration {
    private enum CodingKeys: String, CodingKey {
        case capsuleEnabled
        case capsulePosition
        case capsuleExpandedByDefault
        case voiceEnabled
        case voiceShortcut
        case voiceTriggerMode
        case voiceProvider
        case voiceModel
        case voiceHoldToTalkEnabled
        case voiceHoldThreshold
        case voiceRouteMode
        case voiceOutputMode
        case voiceSaveToInbox
        case shortcutsEnabled
        case captureEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            capsuleEnabled: (try? container.decodeIfPresent(Bool.self, forKey: .capsuleEnabled)) ?? true,
            capsulePosition: (try? container.decodeIfPresent(String.self, forKey: .capsulePosition)) ?? "topCenter",
            capsuleExpandedByDefault: (try? container.decodeIfPresent(Bool.self, forKey: .capsuleExpandedByDefault)) ?? false,
            voiceEnabled: (try? container.decodeIfPresent(Bool.self, forKey: .voiceEnabled)) ?? true,
            voiceShortcut: (try? container.decodeIfPresent(String.self, forKey: .voiceShortcut)) ?? "⌥Space",
            voiceTriggerMode: (try? container.decodeIfPresent(String.self, forKey: .voiceTriggerMode)) ?? CompanionVoiceTriggerMode.both.rawValue,
            voiceProvider: (try? container.decodeIfPresent(String.self, forKey: .voiceProvider)) ?? STTProvider.appleSpeech.rawValue,
            voiceModel: (try? container.decodeIfPresent(String.self, forKey: .voiceModel)) ?? "auto",
            voiceHoldToTalkEnabled: (try? container.decodeIfPresent(Bool.self, forKey: .voiceHoldToTalkEnabled)) ?? true,
            voiceHoldThreshold: (try? container.decodeIfPresent(Double.self, forKey: .voiceHoldThreshold)) ?? 0.38,
            voiceRouteMode: (try? container.decodeIfPresent(String.self, forKey: .voiceRouteMode)) ?? CompanionVoiceRouteMode.smart.rawValue,
            voiceOutputMode: (try? container.decodeIfPresent(String.self, forKey: .voiceOutputMode)) ?? VoiceOutputMode.copyToClipboard.rawValue,
            voiceSaveToInbox: (try? container.decodeIfPresent(Bool.self, forKey: .voiceSaveToInbox)) ?? true,
            shortcutsEnabled: (try? container.decodeIfPresent(Bool.self, forKey: .shortcutsEnabled)) ?? true,
            captureEnabled: (try? container.decodeIfPresent(Bool.self, forKey: .captureEnabled)) ?? true
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(capsuleEnabled, forKey: .capsuleEnabled)
        try container.encode(capsulePosition, forKey: .capsulePosition)
        try container.encode(capsuleExpandedByDefault, forKey: .capsuleExpandedByDefault)
        try container.encode(voiceEnabled, forKey: .voiceEnabled)
        try container.encode(voiceShortcut, forKey: .voiceShortcut)
        try container.encode(voiceTriggerMode, forKey: .voiceTriggerMode)
        try container.encode(voiceProvider, forKey: .voiceProvider)
        try container.encode(voiceModel, forKey: .voiceModel)
        try container.encode(voiceHoldToTalkEnabled, forKey: .voiceHoldToTalkEnabled)
        try container.encode(voiceHoldThreshold, forKey: .voiceHoldThreshold)
        try container.encode(voiceRouteMode, forKey: .voiceRouteMode)
        try container.encode(voiceOutputMode, forKey: .voiceOutputMode)
        try container.encode(voiceSaveToInbox, forKey: .voiceSaveToInbox)
        try container.encode(shortcutsEnabled, forKey: .shortcutsEnabled)
        try container.encode(captureEnabled, forKey: .captureEnabled)
    }
}

/// 随身快捷键定义
public struct CompanionShortcut: Identifiable, Sendable {
    public let id = UUID()
    public let action: String
    public let shortcut: String
    public let description: String

    public init(action: String, shortcut: String, description: String) {
        self.action = action
        self.shortcut = shortcut
        self.description = description
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
        case .notDetermined: return "未接入"
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

extension Notification.Name {
    static let companionVoiceConfigurationDidChange = Notification.Name("companion.voiceConfigurationDidChange")
    static let companionVoiceAgentDraft = Notification.Name("companion.voiceAgentDraft")
}

/// 随身语音转写结果
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
