import Foundation

public enum NotchV2VoiceCompletionDestination: String, Equatable, Sendable {
    case focusedField
    case clipboard
    case inbox

    public var title: String {
        switch self {
        case .focusedField:
            return "已写入当前光标"
        case .clipboard:
            return "已保存到剪贴板"
        case .inbox:
            return "已保存到收集箱"
        }
    }

    public var subtitle: String {
        switch self {
        case .focusedField:
            return "内容已直接写入"
        case .clipboard:
            return "可直接粘贴使用"
        case .inbox:
            return "已进入收集箱"
        }
    }
}

public enum NotchV2VoiceWaveformMode: Equatable, Sendable {
    case listening
    case processing
}

public enum NotchV2VoiceSurfaceState: Equatable, Sendable {
    case idle
    case listening
    case processing
    case completed(destination: NotchV2VoiceCompletionDestination)
    case cancelled

    public var isActive: Bool {
        switch self {
        case .idle:
            return false
        case .listening, .processing, .completed, .cancelled:
            return true
        }
    }

    public var displayTitle: String? {
        switch self {
        case .idle:
            return nil
        case .listening:
            return "说入法收音中"
        case .processing:
            return "正在清洗文稿"
        case .completed(let destination):
            return destination.title
        case .cancelled:
            return "已取消"
        }
    }

    public var displaySubtitle: String? {
        switch self {
        case .idle:
            return nil
        case .listening:
            return "松开 Fn 完成 · Esc 取消"
        case .processing:
            return "准备写入当前光标"
        case .completed(let destination):
            return destination.subtitle
        case .cancelled:
            return "收音已停止"
        }
    }

    public var displayIcon: String {
        switch self {
        case .idle:
            return "waveform"
        case .listening:
            return "mic.fill"
        case .processing:
            return "waveform"
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    public var waveformMode: NotchV2VoiceWaveformMode {
        switch self {
        case .listening:
            return .listening
        case .processing:
            return .processing
        case .idle, .completed, .cancelled:
            return .listening
        }
    }

    public var showsWaveform: Bool {
        switch self {
        case .listening, .processing:
            return true
        case .idle, .completed, .cancelled:
            return false
        }
    }

    public var surfacePriority: NotchV2SurfacePriority {
        switch self {
        case .listening:
            return .voiceRecording
        case .processing:
            return .voiceProcessing
        case .idle, .completed, .cancelled:
            return .defaultState
        }
    }
}
