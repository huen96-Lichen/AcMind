import Foundation

public enum LocalASRModelType: String, Codable, CaseIterable, Sendable {
    case senseVoice
    case whisperKit
    case funASR
    case qwen3ASR
    case parakeet
    
    public var displayName: String {
        switch self {
        case .senseVoice: return "SenseVoice"
        case .whisperKit: return "WhisperKit"
        case .funASR: return "FunASR"
        case .qwen3ASR: return "Qwen3-ASR"
        case .parakeet: return "Parakeet"
        }
    }
    
    public var modelSize: String {
        switch self {
        case .senseVoice: return "~350 MB"
        case .whisperKit: return "~1.5 GB"
        case .funASR: return "~180 MB"
        case .qwen3ASR: return "~1.3 GB"
        case .parakeet: return "~600 MB"
        }
    }
    
    public var supportedLanguages: String {
        switch self {
        case .senseVoice: return "中文、英文、日语、韩语、粤语"
        case .whisperKit: return "多语言（英语优化）"
        case .funASR: return "中文（优化）"
        case .qwen3ASR: return "中文（上下文理解）"
        case .parakeet: return "英文（优化）"
        }
    }
}

public struct LocalASRModelInfo: Codable, Sendable {
    public let id: String
    public let type: LocalASRModelType
    public let name: String
    public let storagePath: String
    public let version: String
    public var isDownloaded: Bool
    public var size: Int64
    
    public init(id: String, type: LocalASRModelType, name: String, storagePath: String, version: String, isDownloaded: Bool = false, size: Int64 = 0) {
        self.id = id
        self.type = type
        self.name = name
        self.storagePath = storagePath
        self.version = version
        self.isDownloaded = isDownloaded
        self.size = size
    }

    public var modelSize: String {
        guard size > 0 else { return type.modelSize }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    public var supportedLanguages: String {
        type.supportedLanguages
    }
}

public struct DownloadProgress: Sendable {
    public let modelId: String
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let progress: Double
    
    public init(modelId: String, bytesDownloaded: Int64, totalBytes: Int64) {
        self.modelId = modelId
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.progress = totalBytes > 0 ? Double(bytesDownloaded) / Double(totalBytes) : 0
    }
}

public actor LocalASRManager: @unchecked Sendable {
    
    public static let shared = LocalASRManager()
    
    private let modelsDirectory: URL
    private var downloadTasks: [String: Task<Void, Error>] = [:]
    
    public var onDownloadProgress: ((DownloadProgress) -> Void)?
    public var onDownloadComplete: ((String) -> Void)?
    public var onDownloadError: ((String, Error) -> Void)?
    
    public init(modelsDirectory: URL? = nil) {
        if let modelsDirectory {
            self.modelsDirectory = modelsDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let acmindDir = appSupport.appendingPathComponent("AcMind", isDirectory: true)
            self.modelsDirectory = acmindDir.appendingPathComponent("LocalModels", isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: self.modelsDirectory, withIntermediateDirectories: true)
    }
    
    public func getModelsDirectory() -> URL {
        return modelsDirectory
    }

    public func setDownloadObservers(
        progress: ((DownloadProgress) -> Void)? = nil,
        complete: ((String) -> Void)? = nil,
        error: ((String, Error) -> Void)? = nil
    ) {
        onDownloadProgress = progress
        onDownloadComplete = complete
        onDownloadError = error
    }
    
    public func listAvailableModels() -> [LocalASRModelInfo] {
        var models: [LocalASRModelInfo] = []
        
        let senseVoicePath = modelsDirectory.appendingPathComponent(SherpaOnnxModel.senseVoiceSmall.rawValue)
        models.append(LocalASRModelInfo(
            id: "sensevoice-small",
            type: .senseVoice,
            name: "SenseVoice Small",
            storagePath: senseVoicePath.path,
            version: "1.0",
            isDownloaded: isSherpaModelInstalled(.senseVoiceSmall)
        ))
        
        let whisperKitPath = modelsDirectory.appendingPathComponent("whisperkit-medium")
        models.append(LocalASRModelInfo(
            id: "whisperkit-medium",
            type: .whisperKit,
            name: "WhisperKit Medium",
            storagePath: whisperKitPath.path,
            version: "0.10.0",
            isDownloaded: isWhisperKitModelInstalled(at: whisperKitPath)
        ))
        
        let funASRPath = modelsDirectory.appendingPathComponent(SherpaOnnxModel.funASR.rawValue)
        models.append(LocalASRModelInfo(
            id: "funasr-paraformer",
            type: .funASR,
            name: "FunASR Paraformer",
            storagePath: funASRPath.path,
            version: "1.0",
            isDownloaded: isSherpaModelInstalled(.funASR)
        ))
        
        let qwen3Path = modelsDirectory.appendingPathComponent(SherpaOnnxModel.qwen3ASR.rawValue)
        models.append(LocalASRModelInfo(
            id: "qwen3-asr-0.6b",
            type: .qwen3ASR,
            name: "Qwen3-ASR 0.6B",
            storagePath: qwen3Path.path,
            version: "1.0",
            isDownloaded: isSherpaModelInstalled(.qwen3ASR)
        ))

        let parakeetPath = modelsDirectory.appendingPathComponent(SherpaOnnxModel.parakeet.rawValue)
        models.append(LocalASRModelInfo(
            id: "parakeet-tdt-0.6b-v2",
            type: .parakeet,
            name: "Parakeet TDT 0.6B v2",
            storagePath: parakeetPath.path,
            version: "1.0",
            isDownloaded: isSherpaModelInstalled(.parakeet)
        ))
        
        return models
    }
    
    public func isModelDownloaded(_ modelId: String) -> Bool {
        let models = listAvailableModels()
        return models.first { $0.id == modelId }?.isDownloaded ?? false
    }
    
    public func getModelPath(for modelId: String) -> URL? {
        let models = listAvailableModels()
        guard let model = models.first(where: { $0.id == modelId }) else { return nil }
        return URL(fileURLWithPath: model.storagePath)
    }
    
    public func downloadModel(_ modelId: String) async throws {
        if let existingTask = downloadTasks[modelId] {
            try await existingTask.value
            return
        }

        let task = Task<Void, Error> { [weak self] in
            guard let self = self else { return }
            try await self.performDownload(modelId: modelId)
        }
        
        downloadTasks[modelId] = task
        do {
            try await task.value
            await completeDownload(modelId: modelId)
        } catch {
            await failDownload(modelId: modelId, error: error)
            throw error
        }
    }
    
    public func cancelDownload(_ modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
    }
    
    public func deleteModel(_ modelId: String) throws {
        guard let modelPath = getModelPath(for: modelId) else {
            throw LocalASRError.modelNotFound
        }
        
        try FileManager.default.removeItem(at: modelPath)
    }
    
    private func performDownload(modelId: String) async throws {
        let downloadURL: URL
        let destinationPath: URL
        
        switch modelId {
        case "sensevoice-small":
            downloadURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2")!
            destinationPath = modelsDirectory.appendingPathComponent(SherpaOnnxModel.senseVoiceSmall.rawValue)
        case "whisperkit-medium":
            try await downloadWhisperKitModel(modelName: "medium", modelId: modelId)
            return
        case "funasr-paraformer":
            downloadURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-paraformer-zh-2024-03-09.tar.bz2")!
            destinationPath = modelsDirectory.appendingPathComponent(SherpaOnnxModel.funASR.rawValue)
        case "qwen3-asr-0.6b":
            downloadURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2")!
            destinationPath = modelsDirectory.appendingPathComponent(SherpaOnnxModel.qwen3ASR.rawValue)
        case "parakeet-tdt-0.6b-v2":
            downloadURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2")!
            destinationPath = modelsDirectory.appendingPathComponent(SherpaOnnxModel.parakeet.rawValue)
        default:
            throw LocalASRError.unsupportedModel(modelId)
        }

        try await ensureSherpaRuntime(modelId: modelId)
        try await downloadAndInstallArchive(
            from: downloadURL,
            destination: destinationPath,
            modelId: modelId
        )

        guard isSherpaModelInstalled(modelType(for: modelId)) else {
            throw LocalASRError.extractionFailed("模型包缺少所需文件")
        }
    }

    private func ensureSherpaRuntime(modelId: String) async throws {
        let decoder = SherpaOnnxCommandLineDecoder(
            model: .senseVoiceSmall,
            modelIdentifier: SherpaOnnxModel.senseVoiceSmall.defaultModelIdentifier,
            modelFolder: modelsDirectory.path
        )
        guard !decoder.isRuntimeInstalled(storageURL: modelsDirectory) else { return }

        #if arch(arm64)
        let archiveName = "sherpa-onnx-v1.13.2-osx-arm64-shared-no-tts.tar.bz2"
        #else
        let archiveName = "sherpa-onnx-v1.13.2-osx-x64-shared-no-tts.tar.bz2"
        #endif
        let url = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.2/\(archiveName)")!
        let destination = modelsDirectory.appendingPathComponent("sherpa-onnx-macos", isDirectory: true)
        try await downloadAndInstallArchive(from: url, destination: destination, modelId: modelId)

        guard decoder.isRuntimeInstalled(storageURL: modelsDirectory) else {
            throw LocalASRError.extractionFailed("sherpa-onnx macOS 运行时文件不完整")
        }
    }

    private func downloadAndInstallArchive(
        from downloadURL: URL,
        destination: URL,
        modelId: String
    ) async throws {
        let session = URLSession(configuration: .default)
        let (asyncBytes, response) = try await session.bytes(from: downloadURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LocalASRError.downloadFailed("服务器返回错误")
        }
        
        let expectedLength = response.expectedContentLength
        var downloadedBytes: Int64 = 0
        
        let tempFile = modelsDirectory.appendingPathComponent("\(UUID().uuidString).tar.bz2.tmp")
        let staging = modelsDirectory.appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempFile)
            try? FileManager.default.removeItem(at: staging)
        }
        try Data().write(to: tempFile)
        let fileHandle = try FileHandle(forWritingTo: tempFile)
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in asyncBytes {
            try Task.checkCancellation()
            buffer.append(byte)
            downloadedBytes += 1
            if buffer.count == 64 * 1024 {
                try fileHandle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
                let progress = DownloadProgress(
                    modelId: modelId,
                    bytesDownloaded: downloadedBytes,
                    totalBytes: expectedLength > 0 ? expectedLength : downloadedBytes
                )
                let handler = onDownloadProgress
                await MainActor.run {
                    handler?(progress)
                }
            }
        }
        if !buffer.isEmpty { try fileHandle.write(contentsOf: buffer) }
        try fileHandle.close()

        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xjf", tempFile.path, "-C", staging.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LocalASRError.extractionFailed("tar 解压失败")
        }

        try Self.installExtractedContents(from: staging, to: destination)
    }

    static func installExtractedContents(from staging: URL, to destination: URL) throws {
        let fm = FileManager.default
        let entries = try fm.contentsOfDirectory(
            at: staging,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        guard !entries.isEmpty else { throw LocalASRError.extractionFailed("压缩包为空") }

        let source: URL
        if entries.count == 1,
           (try entries[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            source = entries[0]
        } else {
            source = staging
        }

        let replacement = destination.deletingLastPathComponent()
            .appendingPathComponent(".replacement-\(UUID().uuidString)", isDirectory: true)
        if source == staging {
            try fm.createDirectory(at: replacement, withIntermediateDirectories: true)
            for entry in entries {
                try fm.moveItem(at: entry, to: replacement.appendingPathComponent(entry.lastPathComponent))
            }
        } else {
            try fm.moveItem(at: source, to: replacement)
        }
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: replacement, to: destination)
    }

    private func modelType(for modelId: String) -> SherpaOnnxModel {
        switch modelId {
        case "sensevoice-small": return .senseVoiceSmall
        case "funasr-paraformer": return .funASR
        case "qwen3-asr-0.6b": return .qwen3ASR
        case "parakeet-tdt-0.6b-v2": return .parakeet
        default: preconditionFailure("validated model id")
        }
    }

    private func downloadWhisperKitModel(modelName: String, modelId: String) async throws {
        #if canImport(WhisperKit)
        let modelDirectory = modelsDirectory.appendingPathComponent(modelId, isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        let transcriber = WhisperKitTranscriber(
            modelName: modelName,
            downloadBase: modelDirectory
        )
        try await transcriber.prepare { [weak self] progress, _ in
            guard let self else { return }
            let total: Int64 = 1_000
            let downloaded = Int64((progress.clamped(to: 0...1) * Double(total)).rounded())
            let update = DownloadProgress(
                modelId: modelId,
                bytesDownloaded: downloaded,
                totalBytes: total
            )
            Task { await self.emitProgress(update) }
        }
        #else
        throw LocalASRError.unsupportedModel(modelId)
        #endif
    }

    private func emitProgress(_ progress: DownloadProgress) async {
        let handler = onDownloadProgress
        await MainActor.run {
            handler?(progress)
        }
    }
    
    private func completeDownload(modelId: String) async {
        downloadTasks.removeValue(forKey: modelId)
        let handler = onDownloadComplete
        await MainActor.run {
            handler?(modelId)
        }
    }
    
    private func failDownload(modelId: String, error: Error) async {
        downloadTasks.removeValue(forKey: modelId)
        let handler = onDownloadError
        await MainActor.run {
            handler?(modelId, error)
        }
    }

    private func isSherpaModelInstalled(_ model: SherpaOnnxModel) -> Bool {
        let decoder = SherpaOnnxCommandLineDecoder(
            model: model,
            modelIdentifier: model.defaultModelIdentifier,
            modelFolder: modelsDirectory.path
        )
        return decoder.isModelInstalled(storageURL: modelsDirectory)
    }

    private func isWhisperKitModelInstalled(at url: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return false }
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        for case let child as URL in enumerator {
            let name = child.lastPathComponent.lowercased()
            if name.hasSuffix(".mlmodelc") || name.hasSuffix(".mlpackage") || name.hasSuffix(".bin") {
                return true
            }
        }
        return false
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

public enum LocalASRError: Error, LocalizedError {
    case modelNotFound
    case downloadFailed(String)
    case unsupportedModel(String)
    case extractionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "模型未找到"
        case .downloadFailed(let message):
            return "下载失败: \(message)"
        case .unsupportedModel(let modelId):
            return "不支持的模型: \(modelId)"
        case .extractionFailed(let message):
            return "解压失败: \(message)"
        }
    }
}
