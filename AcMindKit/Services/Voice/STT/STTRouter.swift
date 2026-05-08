import Foundation

// MARK: - STT Router

/// STT 路由器
/// 根据配置选择合适的 Transcriber
public final class STTRouter: @unchecked Sendable {
    
    // MARK: - Properties
    
    private var currentProvider: STTProvider
    private let settingsService: SettingsServiceProtocol?
    
    // Transcribers
    private var senseVoiceTranscriber: Transcriber?
    private var whisperKitTranscriber: Transcriber?
    private var qwen3ASRTranscriber: Transcriber?
    private var appleSpeechTranscriber: Transcriber?
    private var openAITranscriber: Transcriber?
    private var aliCloudTranscriber: Transcriber?
    private var doubaoTranscriber: Transcriber?

    // Configuration
    private var whisperKitModelName: String = "large-v3-turbo"
    private var sherpaOnnxModelFolder: String?
    
    // MARK: - Initialization
    
    public init(
        provider: STTProvider = .appleSpeech,
        settingsService: SettingsServiceProtocol? = nil,
        whisperKitModelName: String = "large-v3-turbo",
        sherpaOnnxModelFolder: String? = nil
    ) {
        self.currentProvider = provider
        self.settingsService = settingsService
        self.whisperKitModelName = whisperKitModelName
        self.sherpaOnnxModelFolder = sherpaOnnxModelFolder
            ?? (NSHomeDirectory() + "/Library/Application Support/AcMind/LocalModels")
    }
    
    // MARK: - Provider Management
    
    public func setProvider(_ provider: STTProvider) {
        self.currentProvider = provider
    }
    
    public func getProvider() -> STTProvider {
        currentProvider
    }
    
    // MARK: - Transcription
    
    public func transcribe(
        audioFile: AudioFile
    ) async throws -> String {
        try await transcribeStream(audioFile: audioFile) { _ in }
    }
    
    public func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        let transcriber = try await getTranscriber(for: currentProvider)
        
        do {
            return try await transcriber.transcribeStream(
                audioFile: audioFile,
                onUpdate: onUpdate
            )
        } catch {
            // 尝试 fallback 到系统听写
            if currentProvider != .appleSpeech {
                print("STT failed with \(currentProvider), falling back to Apple Speech: \(error)")
                if let fallback = appleSpeechTranscriber {
                    return try await fallback.transcribeStream(
                        audioFile: audioFile,
                        onUpdate: onUpdate
                    )
                }
            }
            throw error
        }
    }
    
    // MARK: - Prewarming
    
    public func prepareForRecording() async {
        switch currentProvider {
        case .senseVoice:
            await (senseVoiceTranscriber as? RecordingPrewarmingTranscriber)?.prepareForRecording()
        case .whisperKit:
            await (whisperKitTranscriber as? RecordingPrewarmingTranscriber)?.prepareForRecording()
        case .qwen3ASR:
            await (qwen3ASRTranscriber as? RecordingPrewarmingTranscriber)?.prepareForRecording()
        default:
            break
        }
    }
    
    public func cancelPreparedRecording() async {
        switch currentProvider {
        case .senseVoice:
            await (senseVoiceTranscriber as? RecordingPrewarmingTranscriber)?.cancelPreparedRecording()
        case .whisperKit:
            await (whisperKitTranscriber as? RecordingPrewarmingTranscriber)?.cancelPreparedRecording()
        case .qwen3ASR:
            await (qwen3ASRTranscriber as? RecordingPrewarmingTranscriber)?.cancelPreparedRecording()
        default:
            break
        }
    }
    
    // MARK: - Private
    
    private func getTranscriber(for provider: STTProvider) async throws -> Transcriber {
        switch provider {
        case .senseVoice:
            if let transcriber = senseVoiceTranscriber {
                return transcriber
            }
            // 延迟初始化
            let transcriber = try await createSenseVoiceTranscriber()
            senseVoiceTranscriber = transcriber
            return transcriber
            
        case .whisperKit:
            if let transcriber = whisperKitTranscriber {
                return transcriber
            }
            let transcriber = try await createWhisperKitTranscriber()
            whisperKitTranscriber = transcriber
            return transcriber

        case .qwen3ASR:
            if let transcriber = qwen3ASRTranscriber {
                return transcriber
            }
            let transcriber = try await createQwen3ASRTranscriber()
            qwen3ASRTranscriber = transcriber
            return transcriber
            
        case .appleSpeech:
            if let transcriber = appleSpeechTranscriber {
                return transcriber
            }
            let transcriber = AppleSpeechTranscriber()
            appleSpeechTranscriber = transcriber
            return transcriber
            
        case .openAI:
            if let transcriber = openAITranscriber {
                return transcriber
            }
            let transcriber = try await createOpenAITranscriber()
            openAITranscriber = transcriber
            return transcriber
            
        case .aliCloud:
            if let transcriber = aliCloudTranscriber {
                return transcriber
            }
            let transcriber = try await createAliCloudTranscriber()
            aliCloudTranscriber = transcriber
            return transcriber
            
        case .doubao:
            if let transcriber = doubaoTranscriber {
                return transcriber
            }
            let transcriber = try await createDoubaoTranscriber()
            doubaoTranscriber = transcriber
            return transcriber
            
        default:
            // Fallback to Apple Speech
            if let transcriber = appleSpeechTranscriber {
                return transcriber
            }
            let transcriber = AppleSpeechTranscriber()
            appleSpeechTranscriber = transcriber
            return transcriber
        }
    }
    
    // MARK: - Transcriber Creation
    
    private func createSenseVoiceTranscriber() async throws -> Transcriber {
        // SenseVoice 基于 sherpa-onnx，需要先下载模型
        // 模型下载: https://github.com/k2-fsa/sherpa-onnx/releases
        // 默认模型路径: ~/Library/Application Support/AcMind/models/sensevoice
        let modelPath = NSHomeDirectory() + "/Library/Application Support/AcMind/models/sensevoice"
        let modelDir = URL(fileURLWithPath: modelPath)
        let modelExists = FileManager.default.fileExists(atPath: modelDir.path)

        guard modelExists else {
            throw STTError.modelNotDownloaded(
                "SenseVoice 模型未找到。请在设置中下载模型，" +
                "或手动放置到: \(modelPath)"
            )
        }

        return SenseVoiceTranscriber(modelPath: modelPath)
    }

    private func createWhisperKitTranscriber() async throws -> Transcriber {
        #if canImport(WhisperKit)
        return WhisperKitTranscriber(modelName: whisperKitModelName)
        #else
        throw STTError.providerNotAvailable(
            "WhisperKit 依赖未集成。需要在 Package.swift 中添加:\n" +
            ".package(url: \"https://github.com/argmaxinc/WhisperKit\", from: \"0.10.0\")"
        )
        #endif
    }

    private func createQwen3ASRTranscriber() async throws -> Transcriber {
        guard let modelFolder = sherpaOnnxModelFolder else {
            throw STTError.providerNotAvailable("sherpa-onnx 模型目录未配置")
        }

        let storageURL = URL(fileURLWithPath: modelFolder, isDirectory: true)

        // 检查运行时和模型
        let decoder = SherpaOnnxCommandLineDecoder(
            model: .qwen3ASR,
            modelIdentifier: "Qwen/Qwen3-ASR-0.6B",
            modelFolder: modelFolder
        )

        guard decoder.isRuntimeInstalled(storageURL: storageURL) else {
            throw STTError.modelNotDownloaded(
                "sherpa-onnx 运行时未找到。\n" +
                "请下载 sherpa-onnx-macos tar.bz2 并解压到:\n" +
                "\(modelFolder)/sherpa-onnx-macos/\n" +
                "下载地址: https://github.com/k2-fsa/sherpa-onnx/releases"
            )
        }

        guard decoder.isModelInstalled(storageURL: storageURL) else {
            throw STTError.modelNotDownloaded(
                "Qwen3-ASR 模型文件不完整。\n" +
                "需要以下文件:\n" +
                "  - qwen3_asr/conv_frontend.onnx\n" +
                "  - qwen3_asr/encoder.int8.onnx\n" +
                "  - qwen3_asr/decoder.int8.onnx\n" +
                "  - qwen3_asr/tokenizer/\n" +
                "下载地址: https://github.com/k2-fsa/sherpa-onnx/releases"
            )
        }

        return Qwen3ASRTranscriber(
            modelIdentifier: "Qwen/Qwen3-ASR-0.6B",
            modelFolder: modelFolder
        )
    }
    
    private func createOpenAITranscriber() async throws -> Transcriber {
        guard let apiKey = await SecretStore.shared.getAPIKey(for: "openai") else {
            throw STTError.apiKeyMissing("OpenAI API Key 未配置")
        }
        return OpenAIWhisperTranscriber(apiKey: apiKey)
    }
    
    private func createAliCloudTranscriber() async throws -> Transcriber {
        guard let appId = await SecretStore.shared.getAPIKey(for: "alicloud_app_id"),
              let token = await SecretStore.shared.getAPIKey(for: "alicloud_token") else {
            throw STTError.apiKeyMissing("阿里云 ASR 凭证未配置")
        }
        return AliCloudTranscriber(appId: appId, token: token)
    }
    
    private func createDoubaoTranscriber() async throws -> Transcriber {
        guard let appId = await SecretStore.shared.getAPIKey(for: "doubao_app_id"),
              let token = await SecretStore.shared.getAPIKey(for: "doubao_token") else {
            throw STTError.apiKeyMissing("火山引擎 ASR 凭证未配置")
        }
        return DoubaoTranscriber(appId: appId, token: token)
    }
}

// MARK: - STT Error

public enum STTError: Error, LocalizedError {
    case providerNotAvailable(String)
    case apiKeyMissing(String)
    case transcriptionFailed(String)
    case modelNotDownloaded(String)
    
    public var errorDescription: String? {
        switch self {
        case .providerNotAvailable(let message):
            return "Provider 不可用: \(message)"
        case .apiKeyMissing(let message):
            return "API Key 缺失: \(message)"
        case .transcriptionFailed(let message):
            return "转写失败: \(message)"
        case .modelNotDownloaded(let message):
            return "模型未下载: \(message)"
        }
    }
}
