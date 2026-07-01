import Foundation

// MARK: - STT Router

/// STT 路由器
/// 根据配置选择合适的 Transcriber
public final class STTRouter: @unchecked Sendable {
    private static let logger = AcMindLogger(category: .ai)
    
    // MARK: - Properties
    
    private var currentProvider: STTProvider
    private let settingsService: SettingsServiceProtocol?
    
    // Transcribers
    private var senseVoiceTranscriber: Transcriber?
    private var whisperKitTranscriber: Transcriber?
    private var qwen3ASRTranscriber: Transcriber?
    private var funASRTranscriber: Transcriber?
    private var parakeetTranscriber: Transcriber?
    private var appleSpeechTranscriber: Transcriber?
    private var openAITranscriber: Transcriber?
    private var aliCloudTranscriber: Transcriber?
    private var doubaoTranscriber: Transcriber?
    private var mimoTranscriber: Transcriber?

    // Configuration
    private var whisperKitModelName: String = "medium"
    private var sherpaOnnxModelFolder: String?
    private let transcriberFactory: (@Sendable (STTProvider) async throws -> Transcriber)?
    
    // MARK: - Initialization
    
    public init(
        provider: STTProvider = .appleSpeech,
        settingsService: SettingsServiceProtocol? = nil,
        whisperKitModelName: String = "medium",
        sherpaOnnxModelFolder: String? = nil,
        transcriberFactory: (@Sendable (STTProvider) async throws -> Transcriber)? = nil
    ) {
        self.currentProvider = provider
        self.settingsService = settingsService
        self.whisperKitModelName = whisperKitModelName
        self.sherpaOnnxModelFolder = sherpaOnnxModelFolder
            ?? (NSHomeDirectory() + "/Library/Application Support/AcMind/LocalModels")
        self.transcriberFactory = transcriberFactory
    }
    
    // MARK: - Provider Management
    
    public func setProvider(_ provider: STTProvider) {
        self.currentProvider = STTProvider.selectableProvider(from: provider)
    }
    
    private func getProvider() -> STTProvider {
        currentProvider
    }
    
    /// 获取当前 provider 的 Transcriber 实例
    public func getTranscriber() async throws -> Transcriber {
        try await getTranscriber(for: currentProvider)
    }
    
    // MARK: - Transcription
    
    public func transcribe(
        audioFile: AudioFile
    ) async throws -> String {
        try await transcribeStream(audioFile: audioFile) { _ in }
    }
    
    public func transcribe(
        audioFile: AudioFile,
        language: String
    ) async throws -> String {
        if language != "auto" {
            let langProvider = selectProviderForLanguage(language)
            if langProvider != currentProvider {
                do {
                    let transcriber = try await getTranscriber(for: langProvider)
                    return try await transcriber.transcribe(audioFile: audioFile)
                } catch {
                    Self.logger.warning("STT language route failed with \(langProvider), falling back to \(currentProvider): \(error)")
                    return try await transcribe(audioFile: audioFile)
                }
            }
        }
        return try await transcribe(audioFile: audioFile)
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
            // 尝试兼容路径：系统听写
            if currentProvider != .appleSpeech {
                Self.logger.warning("STT failed with \(currentProvider), using Apple Speech compatibility path: \(error)")
                let compatibilityTranscriber = try await getTranscriber(for: .appleSpeech)
                return try await compatibilityTranscriber.transcribeStream(
                    audioFile: audioFile,
                    onUpdate: onUpdate
                )
            }
            throw error
        }
    }
    
    // MARK: - Language Routing
    
    private func selectProviderForLanguage(_ language: String) -> STTProvider {
        switch language {
        case "zh": return .senseVoice
        case "en": return .parakeet
        case "ja": return .whisperKit
        default: return currentProvider
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
        case .funASR:
            await (funASRTranscriber as? RecordingPrewarmingTranscriber)?.prepareForRecording()
        case .parakeet:
            await (parakeetTranscriber as? RecordingPrewarmingTranscriber)?.prepareForRecording()
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
        case .funASR:
            await (funASRTranscriber as? RecordingPrewarmingTranscriber)?.cancelPreparedRecording()
        case .parakeet:
            await (parakeetTranscriber as? RecordingPrewarmingTranscriber)?.cancelPreparedRecording()
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
            let transcriber = try await makeTranscriber(for: provider)
            senseVoiceTranscriber = transcriber
            return transcriber
            
        case .whisperKit:
            if let transcriber = whisperKitTranscriber {
                return transcriber
            }
            let transcriber = try await makeTranscriber(for: provider)
            whisperKitTranscriber = transcriber
            return transcriber

        case .qwen3ASR:
            if let transcriber = qwen3ASRTranscriber {
                return transcriber
            }
            let transcriber = try await makeTranscriber(for: provider)
            qwen3ASRTranscriber = transcriber
            return transcriber

        case .funASR:
            if let transcriber = funASRTranscriber { return transcriber }
            let transcriber = try await makeTranscriber(for: provider)
            funASRTranscriber = transcriber
            return transcriber
            
        case .parakeet:
            if let transcriber = parakeetTranscriber {
                return transcriber
            }
            let transcriber = try await makeTranscriber(for: provider)
            parakeetTranscriber = transcriber
            return transcriber
            
        case .appleSpeech:
            if let transcriber = appleSpeechTranscriber {
                return transcriber
            }
            let transcriber = try await makeTranscriber(for: provider)
            appleSpeechTranscriber = transcriber
            return transcriber
            
        case .openAI:
            if let transcriber = openAITranscriber {
                return transcriber
            }
            let transcriber = try await makeTranscriber(for: provider)
            openAITranscriber = transcriber
            return transcriber
            
        case .aliCloud:
            if let transcriber = aliCloudTranscriber {
                return transcriber
            }
            let transcriber = try await makeTranscriber(for: provider)
            aliCloudTranscriber = transcriber
            return transcriber
            
        case .doubao:
            if let transcriber = doubaoTranscriber {
                return transcriber
            }
            let transcriber = try await makeTranscriber(for: provider)
            doubaoTranscriber = transcriber
            return transcriber

        case .mimoASR:
            if let transcriber = mimoTranscriber {
                return transcriber
            }
            let transcriber = try await makeTranscriber(for: provider)
            mimoTranscriber = transcriber
            return transcriber
            
        case .googleCloud, .groq, .freeModel:
            throw STTError.providerNotAvailable("\(provider.displayName) 尚未接入可执行转写适配器")
        }
    }

    private func makeTranscriber(for provider: STTProvider) async throws -> Transcriber {
        if let transcriberFactory {
            return try await transcriberFactory(provider)
        }

        switch provider {
        case .senseVoice:
            return try await createSenseVoiceTranscriber()
        case .whisperKit:
            return try await createWhisperKitTranscriber()
        case .qwen3ASR:
            return try await createQwen3ASRTranscriber()
        case .funASR:
            return try await createFunASRTranscriber()
        case .parakeet:
            return try await createParakeetTranscriber()
        case .appleSpeech:
            return AppleSpeechTranscriber()
        case .openAI:
            return try await createOpenAITranscriber()
        case .aliCloud:
            return try await createAliCloudTranscriber()
        case .doubao:
            return try await createDoubaoTranscriber()
        case .mimoASR:
            return try await createMiMoTranscriber()
        case .googleCloud, .groq, .freeModel:
            throw STTError.providerNotAvailable("\(provider.displayName) 尚未接入可执行转写适配器")
        }
    }
    
    // MARK: - Transcriber Creation
    
    private func createSenseVoiceTranscriber() async throws -> Transcriber {
        // SenseVoice 基于 sherpa-onnx，需要先下载模型
        // 模型下载: https://github.com/k2-fsa/sherpa-onnx/releases
        // 默认模型路径: ~/Library/Application Support/AcMind/LocalModels
        let modelFolder: String
        if let sherpaOnnxModelFolder {
            modelFolder = sherpaOnnxModelFolder
        } else {
            let modelsDirectory = await LocalASRManager.shared.getModelsDirectory()
            modelFolder = modelsDirectory.path
        }
        let storageURL = URL(fileURLWithPath: modelFolder, isDirectory: true)
        let decoder = SherpaOnnxCommandLineDecoder(
            model: .senseVoiceSmall,
            modelIdentifier: "csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17",
            modelFolder: modelFolder
        )

        guard decoder.isRuntimeInstalled(storageURL: storageURL) else {
            throw STTError.providerNotAvailable(
                "sherpa-onnx 运行时未找到。请先在模型管理中下载运行时。"
            )
        }

        guard decoder.isModelInstalled(storageURL: storageURL) else {
            throw STTError.modelNotDownloaded(
                "SenseVoice 模型尚未下载。请先在模型管理中下载后重试。"
            )
        }

        return SenseVoiceTranscriber(modelFolder: modelFolder)
    }

    private func createWhisperKitTranscriber() async throws -> Transcriber {
        #if canImport(WhisperKit)
        let root = URL(fileURLWithPath: sherpaOnnxModelFolder ?? "", isDirectory: true)
        let downloadBase = root.appendingPathComponent("whisperkit-medium", isDirectory: true)
        return WhisperKitTranscriber(modelName: whisperKitModelName, downloadBase: downloadBase)
        #else
        throw STTError.providerNotAvailable(
            "WhisperKit 依赖尚未集成。需要在 Package.swift 中添加:\n" +
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

    private func createFunASRTranscriber() async throws -> Transcriber {
        guard let modelFolder = sherpaOnnxModelFolder else {
            throw STTError.providerNotAvailable("sherpa-onnx 模型目录未配置")
        }
        let storageURL = URL(fileURLWithPath: modelFolder, isDirectory: true)
        let decoder = SherpaOnnxCommandLineDecoder(
            model: .funASR,
            modelIdentifier: SherpaOnnxModel.funASR.defaultModelIdentifier,
            modelFolder: modelFolder
        )
        guard decoder.isRuntimeInstalled(storageURL: storageURL) else {
            throw STTError.modelNotDownloaded("sherpa-onnx 运行时尚未下载。请先在模型管理中下载 FunASR。")
        }
        guard decoder.isModelInstalled(storageURL: storageURL) else {
            throw STTError.modelNotDownloaded("FunASR Paraformer 模型尚未下载。")
        }
        return SherpaOnnxFileTranscriber(model: .funASR, modelFolder: modelFolder)
    }

    private func createParakeetTranscriber() async throws -> Transcriber {
        guard let modelFolder = sherpaOnnxModelFolder else {
            throw STTError.providerNotAvailable("sherpa-onnx 模型目录未配置")
        }

        let storageURL = URL(fileURLWithPath: modelFolder, isDirectory: true)

        let decoder = SherpaOnnxCommandLineDecoder(
            model: .parakeet,
            modelIdentifier: "nvidia/parakeet-tdt-0.6b-v2",
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
                "Parakeet 模型文件不完整。\n" +
                "需要以下文件:\n" +
                "  - parakeet/encoder.int8.onnx\n" +
                "  - parakeet/decoder.int8.onnx\n" +
                "  - parakeet/joiner.int8.onnx\n" +
                "  - parakeet/tokens.txt\n" +
                "下载地址: https://github.com/k2-fsa/sherpa-onnx/releases"
            )
        }

        return ParakeetTranscriber(modelFolder: modelFolder)
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
    
    private func createMiMoTranscriber() async throws -> Transcriber {
        guard let apiKey = await SecretStore.shared.getAPIKey(for: "mimo") else {
            throw STTError.apiKeyMissing("MiMo API Key 未配置")
        }
        return MiMoTranscriber(apiKey: apiKey)
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
