import Foundation

// MARK: - Transcription Snapshot

/// 转写结果快照
public struct TranscriptionSnapshot: Sendable {
    public let text: String
    public let isFinal: Bool
    
    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

// MARK: - Audio File

/// 音频文件封装
public struct AudioFile: Sendable {
    public let url: URL
    public let sampleRate: Double?
    public let channels: Int?
    
    public init(url: URL, sampleRate: Double? = nil, channels: Int? = nil) {
        self.url = url
        self.sampleRate = sampleRate
        self.channels = channels
    }
}

// MARK: - Transcriber Protocol

/// 转写器协议
/// 支持批量和流式转写
public protocol Transcriber: Sendable {
    /// 批量转写音频文件
    /// - Parameter audioFile: 音频文件
    /// - Returns: 转写文本
    func transcribe(audioFile: AudioFile) async throws -> String
    
    /// 流式转写音频文件
    /// - Parameters:
    ///   - audioFile: 音频文件
    ///   - onUpdate: 实时更新回调
    /// - Returns: 最终转写文本
    func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String
}

// MARK: - Default Implementation

extension Transcriber {
    public func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        let text = try await transcribe(audioFile: audioFile)
        await onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
        return text
    }
}

// MARK: - Recording Prewarming Protocol

/// 支持录音预热的转写器
public protocol RecordingPrewarmingTranscriber: Transcriber {
    /// 准备录音（预热模型）
    func prepareForRecording() async
    
    /// 取消准备
    func cancelPreparedRecording() async
}

// MARK: - Realtime Transcription Session

/// 实时转写会话
public protocol RealtimeTranscriptionSession: Sendable {
    /// 发送音频数据
    func sendAudioData(_ data: Data) async throws
    
    /// 结束会话
    func finish() async throws -> String
    
    /// 取消会话
    func cancel() async
}

// MARK: - STT Provider Type

/// STT Provider 类型
public enum STTProvider: String, Codable, Sendable, CaseIterable {
    // 本地模型
    case senseVoice = "sense_voice"
    case whisperKit = "whisper_kit"
    case qwen3ASR = "qwen3_asr"
    case funASR = "fun_asr"
    case parakeet = "parakeet"
    
    // 云端服务
    case openAI = "openai"
    case aliCloud = "ali_cloud"
    case doubao = "doubao"
    case googleCloud = "google_cloud"
    case groq = "groq"
    
    // 系统
    case appleSpeech = "apple_speech"
    
    // 免费
    case freeModel = "free_model"
    
    public var displayName: String {
        switch self {
        case .senseVoice: return "SenseVoice (本地)"
        case .whisperKit: return "WhisperKit (本地)"
        case .qwen3ASR: return "Qwen3-ASR (本地)"
        case .funASR: return "FunASR (本地)"
        case .parakeet: return "Parakeet (本地)"
        case .openAI: return "OpenAI Whisper"
        case .aliCloud: return "阿里云 ASR"
        case .doubao: return "火山引擎 ASR"
        case .googleCloud: return "Google Cloud Speech"
        case .groq: return "Groq Whisper"
        case .appleSpeech: return "系统听写"
        case .freeModel: return "免费模型"
        }
    }
    
    public var isLocal: Bool {
        switch self {
        case .senseVoice, .whisperKit, .qwen3ASR, .funASR, .parakeet:
            return true
        default:
            return false
        }
    }
    
    public var requiresAPIKey: Bool {
        switch self {
        case .openAI, .aliCloud, .doubao, .googleCloud, .groq:
            return true
        default:
            return false
        }
    }
}
