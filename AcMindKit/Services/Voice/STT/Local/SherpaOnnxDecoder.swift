import Foundation
import AVFoundation

// MARK: - SherpaOnnx Model Type

/// sherpa-onnx 支持的本地模型类型
public enum SherpaOnnxModel: String, Sendable, CaseIterable {
    case senseVoiceSmall = "sense_voice_small"
    case qwen3ASR = "qwen3_asr"
    case funASR = "fun_asr"
    case parakeet = "parakeet"

    public var displayName: String {
        switch self {
        case .senseVoiceSmall: return "SenseVoice Small"
        case .qwen3ASR: return "Qwen3-ASR"
        case .funASR: return "FunASR"
        case .parakeet: return "Parakeet"
        }
    }

    /// 默认模型标识符
    public var defaultModelIdentifier: String {
        switch self {
        case .senseVoiceSmall: return "csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17"
        case .qwen3ASR: return "Qwen/Qwen3-ASR-0.6B"
        case .funASR: return "csukuangfj/sherpa-onnx-paraformer-zh"
        case .parakeet: return "nvidia/parakeet-tdt-0.6b-v2"
        }
    }
}

// MARK: - SherpaOnnx Command Line Decoder

/// sherpa-onnx 命令行解码器
/// 通过 Process 调用 sherpa-onnx-offline 二进制执行本地转写
///
/// 共享运行时: SenseVoice / Qwen3-ASR / FunASR 使用同一个 sherpa-onnx 运行时
/// 运行时包含: sherpa-onnx-offline + libsherpa-onnx-c-api.dylib + libonnxruntime.dylib
///
/// 模型存储: ~/Library/Application Support/AcMind/LocalModels/<model>/
/// 运行时存储: ~/Library/Application Support/AcMind/LocalRuntimes/sherpa-onnx-macos/
public final class SherpaOnnxCommandLineDecoder: Sendable {

    // MARK: - Properties

    private let model: SherpaOnnxModel
    private let modelIdentifier: String
    private let modelFolder: String
    private let processRunner: ProcessCommandRunning

    // MARK: - Directory Names

    private static let runtimeDirectoryName = "sherpa-onnx-macos"
    // MARK: - Initialization

    public init(
        model: SherpaOnnxModel,
        modelIdentifier: String,
        modelFolder: String,
        processRunner: ProcessCommandRunning = ProcessCommandRunner()
    ) {
        self.model = model
        self.modelIdentifier = modelIdentifier
        self.modelFolder = modelFolder
        self.processRunner = processRunner
    }

    // MARK: - Decode

    /// 执行转写
    public func decode(audioFile: AudioFile) async throws -> String {
        let storageURL = URL(fileURLWithPath: modelFolder, isDirectory: true)
        let executableURL = runtimeExecutableURL(storageURL: storageURL)

        // 检查运行时
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw STTError.providerNotAvailable(
                "sherpa-onnx 运行时未找到: \(executableURL.path)\n" +
                "请先下载 sherpa-onnx 运行时"
            )
        }

        // 检查模型文件
        guard isModelInstalled(storageURL: storageURL) else {
            throw STTError.modelNotDownloaded(
                "\(model.displayName) 模型文件不完整"
            )
        }

        // 转码为 WAV（sherpa-onnx 要求 16kHz mono WAV）
        let wavURL = try await transcodeToWav(audioFile: audioFile)

        // 构建命令行参数
        let arguments = try commandLineArguments(
            storageURL: storageURL,
            audioURL: wavURL
        )

        // 执行
        let libraryURL = runtimeLibraryURL(storageURL: storageURL)
        let result = try await processRunner.run(
            executablePath: executableURL.path,
            arguments: arguments,
            environment: ["DYLD_LIBRARY_PATH": libraryURL.path],
            currentDirectoryURL: storageURL
        )

        return try parseTranscript(stdout: result.stdout)
    }

    // MARK: - Command Line Arguments

    private func commandLineArguments(
        storageURL: URL,
        audioURL: URL
    ) throws -> [String] {
        let modelDirectory = modelDirectoryURL(storageURL: storageURL)

        switch model {
        case .senseVoiceSmall:
            return [
                "--print-args=false",
                "--tokens=\(modelDirectory.appendingPathComponent("tokens.txt").path)",
                "--sense-voice-model=\(modelDirectory.appendingPathComponent("model.int8.onnx").path)",
                "--sense-voice-language=auto",
                "--sense-voice-use-itn=true",
                "--provider=cpu",
                audioURL.path,
            ]

        case .qwen3ASR:
            return [
                "--print-args=false",
                "--qwen3-asr-conv-frontend=\(modelDirectory.appendingPathComponent("conv_frontend.onnx").path)",
                "--qwen3-asr-encoder=\(modelDirectory.appendingPathComponent("encoder.int8.onnx").path)",
                "--qwen3-asr-decoder=\(modelDirectory.appendingPathComponent("decoder.int8.onnx").path)",
                "--qwen3-asr-tokenizer=\(modelDirectory.appendingPathComponent("tokenizer").path)",
                "--qwen3-asr-max-total-len=1500",
                "--qwen3-asr-max-new-tokens=512",
                "--qwen3-asr-temperature=0",
                "--provider=cpu",
                audioURL.path,
            ]

        case .funASR:
            return [
                "--print-args=false",
                "--tokens=\(modelDirectory.appendingPathComponent("tokens.txt").path)",
                "--paraformer=\(modelDirectory.appendingPathComponent("model.int8.onnx").path)",
                "--provider=cpu",
                audioURL.path,
            ]

        case .parakeet:
            return [
                "--print-args=false",
                "--tokens=\(modelDirectory.appendingPathComponent("tokens.txt").path)",
                "--encoder=\(modelDirectory.appendingPathComponent("encoder.int8.onnx").path)",
                "--decoder=\(modelDirectory.appendingPathComponent("decoder.int8.onnx").path)",
                "--joiner=\(modelDirectory.appendingPathComponent("joiner.int8.onnx").path)",
                "--model-type=nemo_transducer",
                "--provider=cpu",
                audioURL.path,
            ]
        }
    }

    // MARK: - Transcript Parsing

    private func parseTranscript(stdout: String) throws -> String {
        let candidates = stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let transcript = candidates.last else {
            throw STTError.transcriptionFailed("无语音内容")
        }

        // 尝试 JSON 格式解析
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

    // MARK: - Audio Transcoding

    /// 将音频转码为 16kHz mono WAV（sherpa-onnx 要求）
    private func transcodeToWav(audioFile: AudioFile) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            "-f", "WAVE",
            "-d", "LEI16@16000",
            "-c", "1",
            audioFile.url.path,
            outputURL.path,
        ]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // afconvert 不可用时，直接使用原始文件
            return audioFile.url
        }

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: outputURL.path) else {
            return audioFile.url
        }

        return outputURL
    }

    // MARK: - File Paths

    private func runtimeExecutableURL(storageURL: URL) -> URL {
        storageURL
            .appendingPathComponent(Self.runtimeDirectoryName, isDirectory: true)
            .appendingPathComponent("bin/sherpa-onnx-offline", isDirectory: false)
    }

    private func runtimeLibraryURL(storageURL: URL) -> URL {
        storageURL
            .appendingPathComponent(Self.runtimeDirectoryName, isDirectory: true)
            .appendingPathComponent("lib", isDirectory: true)
    }

    private func modelDirectoryURL(storageURL: URL) -> URL {
        storageURL.appendingPathComponent(model.rawValue, isDirectory: true)
    }

    // MARK: - Model Validation

    /// 检查模型文件是否完整
    public func isModelInstalled(storageURL: URL) -> Bool {
        let fm = FileManager.default
        let modelDir = modelDirectoryURL(storageURL: storageURL)

        switch model {
        case .senseVoiceSmall:
            return fm.fileExists(atPath: modelDir.appendingPathComponent("model.int8.onnx").path) &&
                   fm.fileExists(atPath: modelDir.appendingPathComponent("tokens.txt").path)

        case .qwen3ASR:
            return fm.fileExists(atPath: modelDir.appendingPathComponent("conv_frontend.onnx").path) &&
                   fm.fileExists(atPath: modelDir.appendingPathComponent("encoder.int8.onnx").path) &&
                   fm.fileExists(atPath: modelDir.appendingPathComponent("decoder.int8.onnx").path) &&
                   fm.fileExists(atPath: modelDir.appendingPathComponent("tokenizer").path)

        case .funASR:
            return fm.fileExists(atPath: modelDir.appendingPathComponent("model.int8.onnx").path) &&
                   fm.fileExists(atPath: modelDir.appendingPathComponent("tokens.txt").path)

        case .parakeet:
            return fm.fileExists(atPath: modelDir.appendingPathComponent("encoder.int8.onnx").path) &&
                   fm.fileExists(atPath: modelDir.appendingPathComponent("decoder.int8.onnx").path) &&
                   fm.fileExists(atPath: modelDir.appendingPathComponent("joiner.int8.onnx").path) &&
                   fm.fileExists(atPath: modelDir.appendingPathComponent("tokens.txt").path)
        }
    }

    /// 检查运行时是否已安装
    public func isRuntimeInstalled(storageURL: URL) -> Bool {
        let fm = FileManager.default
        let executableURL = runtimeExecutableURL(storageURL: storageURL)
        let libraryURL = runtimeLibraryURL(storageURL: storageURL)

        let runtimeLibraries = (try? fm.contentsOfDirectory(atPath: libraryURL.path)) ?? []
        return fm.isExecutableFile(atPath: executableURL.path) &&
               fm.fileExists(atPath: libraryURL.appendingPathComponent("libsherpa-onnx-c-api.dylib").path) &&
               runtimeLibraries.contains(where: { $0.hasPrefix("libonnxruntime") && $0.hasSuffix(".dylib") })
    }
}

public final class SherpaOnnxFileTranscriber: Transcriber, RecordingPrewarmingTranscriber {
    private let decoder: SherpaOnnxCommandLineDecoder

    public init(model: SherpaOnnxModel, modelFolder: String, processRunner: ProcessCommandRunning = ProcessCommandRunner()) {
        decoder = SherpaOnnxCommandLineDecoder(
            model: model,
            modelIdentifier: model.defaultModelIdentifier,
            modelFolder: modelFolder,
            processRunner: processRunner
        )
    }

    public func transcribe(audioFile: AudioFile) async throws -> String {
        try await decoder.decode(audioFile: audioFile)
    }

    public func prepareForRecording() async {}
    public func cancelPreparedRecording() async {}
}
