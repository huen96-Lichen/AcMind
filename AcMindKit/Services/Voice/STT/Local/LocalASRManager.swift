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
        case .parakeet: return "英文（优化）、中文"
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
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let acmindDir = appSupport.appendingPathComponent("AcMind", isDirectory: true)
        self.modelsDirectory = acmindDir.appendingPathComponent("LocalModels", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
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
        
        let senseVoicePath = modelsDirectory.appendingPathComponent("sense_voice_small")
        models.append(LocalASRModelInfo(
            id: "sensevoice-small",
            type: .senseVoice,
            name: "SenseVoice Small",
            storagePath: senseVoicePath.path,
            version: "1.0",
            isDownloaded: FileManager.default.fileExists(atPath: senseVoicePath.path)
        ))
        
        let whisperKitPath = modelsDirectory.appendingPathComponent("whisperkit")
        models.append(LocalASRModelInfo(
            id: "whisperkit-medium",
            type: .whisperKit,
            name: "WhisperKit Medium",
            storagePath: whisperKitPath.path,
            version: "0.10.0",
            isDownloaded: FileManager.default.fileExists(atPath: whisperKitPath.path)
        ))
        
        let funASRPath = modelsDirectory.appendingPathComponent("fun_asr")
        models.append(LocalASRModelInfo(
            id: "funasr-paraformer",
            type: .funASR,
            name: "FunASR Paraformer",
            storagePath: funASRPath.path,
            version: "1.0",
            isDownloaded: FileManager.default.fileExists(atPath: funASRPath.path)
        ))
        
        let qwen3Path = modelsDirectory.appendingPathComponent("qwen3_asr")
        models.append(LocalASRModelInfo(
            id: "qwen3-asr-0.6b",
            type: .qwen3ASR,
            name: "Qwen3-ASR 0.6B",
            storagePath: qwen3Path.path,
            version: "1.0",
            isDownloaded: FileManager.default.fileExists(atPath: qwen3Path.path)
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
        guard downloadTasks[modelId] == nil else {
            return
        }

        if modelId == "whisperkit-medium" {
            throw LocalASRError.unsupportedModel("whisperkit-medium")
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
            downloadURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.1.10/sherpa-onnx-sense-voice-small-linux-x86_64.tar.bz2")!
            destinationPath = modelsDirectory.appendingPathComponent("sense_voice_small")
        case "whisperkit-medium":
            throw LocalASRError.unsupportedModel(modelId)
        case "funasr-paraformer":
            downloadURL = URL(string: "https://huggingface.co/spaces/sherpa/sherpa-onnx-int8-paraformer-zh-en/raw/main/paraformer.tar.bz2")!
            destinationPath = modelsDirectory.appendingPathComponent("fun_asr")
        case "qwen3-asr-0.6b":
            downloadURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.1.10/sherpa-onnx-qwen3-asr.tar.bz2")!
            destinationPath = modelsDirectory.appendingPathComponent("qwen3_asr")
        default:
            throw LocalASRError.unsupportedModel(modelId)
        }
        
        let session = URLSession(configuration: .default)
        let (asyncBytes, response) = try await session.bytes(from: downloadURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LocalASRError.downloadFailed("服务器返回错误")
        }
        
        let expectedLength = response.expectedContentLength
        var downloadedBytes: Int64 = 0
        
        let tempFile = modelsDirectory.appendingPathComponent("\(modelId).tar.bz2.tmp")
        try Data().write(to: tempFile)
        let fileHandle = try FileHandle(forWritingTo: tempFile)
        defer { try? fileHandle.close() }
        
        for try await byte in asyncBytes {
            try fileHandle.write(contentsOf: Data([byte]))
            downloadedBytes += 1
            
            if downloadedBytes % 1024 == 0 {
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
        
        try FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xjf", tempFile.path, "-C", destinationPath.path]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw LocalASRError.extractionFailed("tar 解压失败")
        }
        
        try FileManager.default.removeItem(at: tempFile)
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
