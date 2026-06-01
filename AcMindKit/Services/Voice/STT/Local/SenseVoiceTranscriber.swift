import Foundation

// MARK: - SenseVoice Transcriber

/// SenseVoice 本地语音识别
/// 基于 sherpa-onnx 实现
/// 依赖: sherpa-onnx 运行时
/// 模型大小: ~350MB (SenseVoiceSmall)
/// 支持语言: 中文、英文、日语、韩语、粤语
public final class SenseVoiceTranscriber: Transcriber, RecordingPrewarmingTranscriber {
    
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
            model: .senseVoiceSmall,
            modelIdentifier: "csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17",
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
