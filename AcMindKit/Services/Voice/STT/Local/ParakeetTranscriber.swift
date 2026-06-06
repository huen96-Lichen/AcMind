import Foundation

// MARK: - Parakeet Transcriber

/// Parakeet 本地语音识别
/// 基于 sherpa-onnx 实现
/// 依赖: sherpa-onnx 运行时
/// 模型大小: ~600 MB (Parakeet-0.6B)
/// 支持语言: 英文（优化）、中文
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
    
    // MARK: - Realtime Session
    
    public func createRealtimeSession() -> RealtimeTranscriptionSession {
        ParakeetRealtimeSession(modelFolder: modelFolder)
    }
}

// MARK: - Parakeet Realtime Session

private final class ParakeetRealtimeSession: RealtimeTranscriptionSession, @unchecked Sendable {
    
    private let modelFolder: String
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var accumulatedText: String = ""
    public var onUpdate: (@Sendable (TranscriptionSnapshot) -> Void)?
    
    init(modelFolder: String) {
        self.modelFolder = modelFolder
    }
    
    func sendAudioData(_ data: Data) async throws {
        if process == nil {
            try startProcess()
        }
        
        guard let stdinPipe = stdinPipe else {
            throw STTError.providerNotAvailable("stdin pipe 未初始化")
        }
        
        stdinPipe.fileHandleForWriting.write(data)
    }
    
    func finish() async throws -> String {
        guard let process = process, let stdinPipe = stdinPipe else {
            return accumulatedText
        }
        
        stdinPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        
        if let stdoutData = stdoutPipe?.fileHandleForReading.readDataToEndOfFile(),
           let stdoutString = String(data: stdoutData, encoding: .utf8) {
            accumulatedText = parseTranscript(stdout: stdoutString)
        }
        
        return accumulatedText
    }
    
    func cancel() async {
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
    }
    
    private func startProcess() throws {
        let storageURL = URL(fileURLWithPath: modelFolder, isDirectory: true)
        let runtimeDir = storageURL.appendingPathComponent("sherpa-onnx-macos", isDirectory: true)
        let executableURL = runtimeDir.appendingPathComponent("bin/sherpa-onnx-offline")
        let libraryURL = runtimeDir.appendingPathComponent("lib")
        let modelDirectory = storageURL.appendingPathComponent("parakeet", isDirectory: true)
        
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw STTError.providerNotAvailable("sherpa-onnx 运行时未找到")
        }
        
        let stdin = Pipe()
        let stdout = Pipe()
        
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "--print-args=false",
            "--tokens=\(modelDirectory.appendingPathComponent("tokens.txt").path)",
            "--paraformer=\(modelDirectory.appendingPathComponent("model.int8.onnx").path)",
            "--provider=cpu",
            "-",
        ]
        process.environment = ["DYLD_LIBRARY_PATH": libraryURL.path]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.currentDirectoryURL = storageURL
        
        try process.run()
        
        self.process = process
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
    }
    
    private func parseTranscript(stdout: String) -> String {
        let candidates = stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard let transcript = candidates.last else {
            return ""
        }
        
        if let jsonText = parseJSONTranscript(stdoutLine: transcript) {
            return jsonText
        }
        
        return transcript
    }
    
    private func parseJSONTranscript(stdoutLine: String) -> String? {
        guard stdoutLine.first == "{",
              let jsonData = stdoutLine.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let text = payload["text"] as? String
        else {
            return nil
        }
        return text
    }
}
