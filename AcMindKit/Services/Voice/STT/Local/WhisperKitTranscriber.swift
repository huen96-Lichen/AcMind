import Foundation
#if canImport(WhisperKit)
import WhisperKit

// MARK: - WhisperKit Transcriber

/// WhisperKit 本地语音识别
/// 基于 Apple Silicon CoreML 优化的 Whisper 实现
///
/// 依赖: WhisperKit Swift Package
///   .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.10.0")
///
/// 模型: 从 Hugging Face (argmaxinc/whisperkit-coreml) 自动下载
/// 支持: 99 种语言，自动检测，流式逐窗口输出
///
/// 免费: 完全免费，开源 Apache 2.0
public final class WhisperKitTranscriber: Transcriber, RecordingPrewarmingTranscriber {

    // MARK: - Properties

    private let modelName: String
    private let downloadBase: URL?
    private let modelRepo: String?
    private let modelEndpoint: String?
    private let modelFolder: String?
    private let tokenizerFolder: URL?
    private let pipelineLock = NSLock()
    private var pipeline: WhisperKit?
    private var pipelineLoadTask: Task<WhisperKit, Error>?

    // MARK: - Model Size

    public enum ModelSize: String, Sendable, CaseIterable {
        case tiny
        case base
        case small
        case medium
        case large
        case largeV3  = "large-v3"
        case largeV3Turbo = "large-v3-turbo"

        public var displayName: String {
            switch self {
            case .tiny: return "Tiny (~39MB)"
            case .base: return "Base (~74MB)"
            case .small: return "Small (~244MB)"
            case .medium: return "Medium (~769MB)"
            case .large: return "Large (~1.55GB)"
            case .largeV3: return "Large-v3 (~1.55GB)"
            case .largeV3Turbo: return "Large-v3-turbo (~809MB)"
            }
        }

        public var whisperKitName: String {
            rawValue
        }
    }

    // MARK: - Initialization

    /// 完整初始化
    /// - Parameters:
    ///   - modelName: WhisperKit 模型名，如 "small", "base", "large-v3"
    ///   - downloadBase: 模型下载基础目录
    ///   - modelRepo: Hugging Face 兼容仓库
    ///   - modelEndpoint: Hugging Face 兼容端点
    ///   - modelFolder: 本地已有模型文件夹路径
    ///   - tokenizerFolder: tokenizer 目录
    public init(
        modelName: String,
        downloadBase: URL? = nil,
        modelRepo: String? = nil,
        modelEndpoint: String? = nil,
        modelFolder: String? = nil,
        tokenizerFolder: URL? = nil
    ) {
        self.modelName = modelName
        self.downloadBase = downloadBase
        self.modelRepo = modelRepo
        self.modelEndpoint = modelEndpoint
        self.modelFolder = modelFolder
        self.tokenizerFolder = tokenizerFolder ?? Self.defaultTokenizerFolder(for: modelFolder)
    }

    /// 便捷初始化（按 ModelSize）
    public init(
        modelSize: ModelSize = .medium,
        downloadBase: URL? = nil,
        modelRepo: String? = nil,
        modelEndpoint: String? = nil,
        modelFolder: String? = nil
    ) {
        self.modelName = modelSize.whisperKitName
        self.downloadBase = downloadBase
        self.modelRepo = modelRepo
        self.modelEndpoint = modelEndpoint
        self.modelFolder = modelFolder
        self.tokenizerFolder = nil
    }

    /// 已解析的模型文件夹路径
    public var resolvedModelFolderPath: String? {
        pipelineLock.lock()
        let path = pipeline?.modelFolder?.path ?? modelFolder
        pipelineLock.unlock()
        return path
    }

    // MARK: - Transcriber Protocol

    public func transcribe(audioFile: AudioFile) async throws -> String {
        try await transcribeStream(audioFile: audioFile) { _ in }
    }

    public func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        let pipe = try await ensurePipeline()

        let options = Self.decodingOptions()

        let results: [TranscriptionResult] = try await pipe.transcribe(
            audioPath: audioFile.url.path,
            decodeOptions: options
        ) { progress in
            // progress.text 逐窗口累积 partial transcript
            let partial = progress.text
            if !partial.isEmpty {
                Task { await onUpdate(TranscriptionSnapshot(text: partial, isFinal: false)) }
            }
            return true // 返回 false 可中途取消
        }

        let text = (results.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        await onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
        return text
    }

    // MARK: - RecordingPrewarmingTranscriber

    /// 预热模型（下载 + 初始化 CoreML pipeline）
    /// - Parameter onProgress: 进度回调 (0…1, 状态消息)
    public func prepareForRecording() async {
        do {
            if currentPipeline() != nil { return }
            _ = try await ensurePipeline()
        } catch {
            print("WhisperKit 预热失败: \(error)")
        }
    }

    public func cancelPreparedRecording() async {
        pipelineLock.lock()
        pipelineLoadTask?.cancel()
        pipelineLoadTask = nil
        pipeline = nil
        pipelineLock.unlock()
    }

    /// 带进度回调的预热
    public func prepare(
        onProgress: ((Double, String) -> Void)? = nil
    ) async throws {
        if currentPipeline() != nil { return }
        onProgress?(0.1, "正在初始化 WhisperKit (\(modelName))...")
        _ = try await ensurePipeline()
        onProgress?(1.0, "WhisperKit (\(modelName)) 就绪")
    }

    // MARK: - Decoding Options

    public static func decodingOptions() -> DecodingOptions {
        DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: nil,           // 自动检测
            usePrefillPrompt: true,
            detectLanguage: true,
            withoutTimestamps: true
        )
    }

    // MARK: - Model Availability

    /// 检查模型是否已就绪
    public func isModelAvailable() -> Bool {
        currentPipeline() != nil
    }

    // MARK: - Private

    private func ensurePipeline() async throws -> WhisperKit {
        if let pipe = currentPipeline() { return pipe }

        let loadTask = pipelineInitializationTask()
        do {
            let pipe = try await loadTask.value
            storePipeline(pipe)
            return pipe
        } catch {
            clearPipelineLoadTask()
            throw error
        }
    }

    private func currentPipeline() -> WhisperKit? {
        pipelineLock.lock()
        let pipe = pipeline
        pipelineLock.unlock()
        return pipe
    }

    private func pipelineInitializationTask() -> Task<WhisperKit, Error> {
        pipelineLock.lock()
        if let existingTask = pipelineLoadTask {
            pipelineLock.unlock()
            return existingTask
        }

        let task = Task { [modelName, downloadBase, modelRepo, modelEndpoint, modelFolder, tokenizerFolder] in
            try await WhisperKit(WhisperKitConfig(
                model: modelName,
                downloadBase: downloadBase,
                modelRepo: modelRepo,
                modelEndpoint: modelEndpoint,
                modelFolder: modelFolder,
                tokenizerFolder: tokenizerFolder,
                verbose: false
            ))
        }
        pipelineLoadTask = task
        pipelineLock.unlock()
        return task
    }

    private func storePipeline(_ pipe: WhisperKit) {
        pipelineLock.lock()
        pipeline = pipe
        pipelineLoadTask = nil
        pipelineLock.unlock()
    }

    private func clearPipelineLoadTask() {
        pipelineLock.lock()
        pipelineLoadTask = nil
        pipelineLock.unlock()
    }

    private static func defaultTokenizerFolder(for modelFolder: String?) -> URL? {
        guard let modelFolder else { return nil }
        var currentURL = URL(fileURLWithPath: modelFolder, isDirectory: true)
        while currentURL.path != "/" {
            if currentURL.lastPathComponent == "models" {
                return currentURL.deletingLastPathComponent()
            }
            currentURL.deleteLastPathComponent()
        }
        return nil
    }
}
#endif
