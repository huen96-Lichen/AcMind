import Foundation
import SwiftUI

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

/// 随身配置
public struct CompanionConfiguration: Codable, Sendable {
    public var capsuleEnabled: Bool
    public var capsulePosition: String
    public var capsuleExpandedByDefault: Bool

    public var voiceEnabled: Bool
    public var voiceShortcut: String
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
        self.voiceOutputMode = voiceOutputMode
        self.voiceSaveToInbox = voiceSaveToInbox
        self.shortcutsEnabled = shortcutsEnabled
        self.captureEnabled = captureEnabled
    }

    public static let `default` = CompanionConfiguration()
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
