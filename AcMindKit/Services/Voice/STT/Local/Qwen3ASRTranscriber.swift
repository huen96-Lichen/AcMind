import Foundation

// MARK: - Qwen3-ASR Transcriber

/// Qwen3-ASR 本地语音识别
/// 基于 Qwen3 的音频理解能力，通过 sherpa-onnx 运行
///
/// 依赖: sherpa-onnx 运行时（与 SenseVoice 共享）
/// 模型: Qwen3-ASR-0.6B, INT8 量化
/// 语言: 中文为主
/// 模型文件:
///   - conv_frontend.onnx (音频前端)
///   - encoder.int8.onnx (编码器)
///   - decoder.int8.onnx (解码器)
///   - tokenizer/ (BPE tokenizer)
///
/// 免费: 完全免费，Qwen3-ASR 开源模型
/// 来源: ModelScope (zengshuishui/Qwen3-ASR-onnx)
///
/// 注意: Qwen3-ASR 本身不支持流式，此处通过分段转写模拟流式效果
public final class Qwen3ASRTranscriber: Transcriber, RecordingPrewarmingTranscriber {

    // MARK: - Properties

    private let decoder: SherpaOnnxCommandLineDecoder
    private let modelFolder: String

    // MARK: - Initialization

    /// - Parameters:
    ///   - modelIdentifier: 模型标识符，默认 "Qwen/Qwen3-ASR-0.6B"
    ///   - modelFolder: 模型存储根目录（包含 sherpa-onnx 运行时 + 模型文件）
    ///   - processRunner: 命令行运行器（可注入测试替身）
    public init(
        modelIdentifier: String = "Qwen/Qwen3-ASR-0.6B",
        modelFolder: String,
        processRunner: ProcessCommandRunning = ProcessCommandRunner()
    ) {
        self.modelFolder = modelFolder
        self.decoder = SherpaOnnxCommandLineDecoder(
            model: .qwen3ASR,
            modelIdentifier: modelIdentifier,
            modelFolder: modelFolder,
            processRunner: processRunner
        )
    }

    // MARK: - Transcriber Protocol

    public func transcribe(audioFile: AudioFile) async throws -> String {
        try await decoder.decode(audioFile: audioFile)
    }

    /// 模拟流式转写
    /// Qwen3-ASR 不支持真正的流式，此处先发送 "正在识别..." 状态，
    /// 转写完成后一次性返回结果。
    /// 如需真正的流式体验，建议使用 WhisperKit 或云端 ASR。
    public func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        // 发送开始状态
        await onUpdate(TranscriptionSnapshot(text: "⏳ 正在识别...", isFinal: false))

        // 执行转写
        let text = try await decoder.decode(audioFile: audioFile)

        // 发送最终结果
        await onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
        return text
    }

    // MARK: - RecordingPrewarmingTranscriber

    public func prepareForRecording() async {
        // sherpa-onnx CLI 无需预热，模型在首次调用时加载
    }

    public func cancelPreparedRecording() async {
        // CLI 模式无需取消
    }

    // MARK: - Model Availability

    /// 检查模型和运行时是否已安装
    public func isAvailable() -> Bool {
        let storageURL = URL(fileURLWithPath: modelFolder, isDirectory: true)
        return decoder.isRuntimeInstalled(storageURL: storageURL) &&
               decoder.isModelInstalled(storageURL: storageURL)
    }
}
