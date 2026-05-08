import Foundation

// MARK: - SenseVoice Transcriber

/// SenseVoice 本地语音识别
/// 基于 sherpa-onnx 实现
/// 
/// ⚠️ TODO: 需要集成 sherpa-onnx 依赖
/// 依赖: https://github.com/k2-fsa/sherpa-onnx
/// 模型大小: ~350MB (SenseVoiceSmall)
/// 支持语言: 中文、英文、日语、韩语、粤语
public final class SenseVoiceTranscriber: Transcriber {
    
    // MARK: - Properties
    
    private let modelPath: String
    private let processRunner: ProcessCommandRunning
    
    // MARK: - Initialization
    
    public init(
        modelPath: String,
        processRunner: ProcessCommandRunning = ProcessCommandRunner()
    ) {
        self.modelPath = modelPath
        self.processRunner = processRunner
    }
    
    // MARK: - Transcriber Protocol
    
    public func transcribe(audioFile: AudioFile) async throws -> String {
        // ⚠️ TODO: 实现 SenseVoice 转写
        // 1. 检查模型文件是否存在
        // 2. 调用 sherpa-onnx 命令行工具
        // 3. 解析输出结果
        
        throw STTError.providerNotAvailable(
            "SenseVoice 尚未实现。需要:\n" +
            "1. 集成 sherpa-onnx 依赖\n" +
            "2. 下载 SenseVoice 模型 (~350MB)\n" +
            "3. 实现命令行调用"
        )
    }
    
    public func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        // ⚠️ TODO: 实现流式转写
        // SenseVoice 本身不支持流式，需要模拟
        
        let text = try await transcribe(audioFile: audioFile)
        await onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
        return text
    }
}
