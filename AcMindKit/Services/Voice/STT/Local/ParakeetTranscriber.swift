import Foundation

// MARK: - Parakeet Transcriber

/// Parakeet 本地语音识别
/// 基于 sherpa-onnx 实现
/// 依赖: sherpa-onnx 运行时
/// 模型大小: ~600 MB (Parakeet-0.6B)
/// 支持语言: 英文（优化）
public final class ParakeetTranscriber: Transcriber, RecordingPrewarmingTranscriber {
    
    // MARK: - Properties
    
    private let modelFolder: String
    private let decoder: SherpaOnnxCommandLineDecoder
    
    // MARK: - Initialization
    
    public init(
        modelFolder: String,
        processRunner: ProcessCommandRunning = ProcessCommandRunner()
    ) {
        self.modelFolder = modelFolder
        self.decoder = SherpaOnnxCommandLineDecoder(
            model: .parakeet,
            modelIdentifier: "nvidia/parakeet-tdt-0.6b-v2",
            modelFolder: modelFolder,
            processRunner: processRunner
        )
    }
    
    // MARK: - Transcriber Protocol

    public func transcribe(audioFile: AudioFile) async throws -> String {
        try await decoder.decode(audioFile: audioFile)
    }
    
    public func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        let text = try await transcribe(audioFile: audioFile)
        await onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
        return text
    }

    // MARK: - RecordingPrewarmingTranscriber

    public func prepareForRecording() async {
        _ = modelFolder
    }

    public func cancelPreparedRecording() async {
        // CLI 模式不需要预热取消
    }
    
}
