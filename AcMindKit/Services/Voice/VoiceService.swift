import Foundation
import AVFoundation

// MARK: - Voice Service

/// 语音服务
/// 职责：
/// 1. 录音控制（开始/停止）
/// 2. 录音文件保存到 AssetStore
/// 3. ASR 转写（支持本地/云端，通过 STTRouter）
/// 4. 润色处理（通过 PolishService）
/// 5. 文本插入（通过 TextInjector）
/// 6. 状态管理和回调
public actor VoiceService: VoiceServiceProtocol {
    
    // MARK: - Dependencies
    
    private let storage: StorageServiceProtocol
    private let assetStore: AssetStore
    private let aiRuntime: AIRuntimeProtocol?
    private nonisolated let permissionManager: PermissionManager?
    
    // 新增模块
    private var sttRouter: STTRouter?
    private var textInjector: TextInjector?
    private var polishService: PolishService?
    
    // MARK: - State
    
    private var recorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var status: RecordingStatus = .idle
    private var recordingStartTime: Date?
    private var statusHandler: (@Sendable (RecordingStatus) -> Void)?
    
    // MARK: - ASR Configuration
    
    private var sttProvider: STTProvider = .appleSpeech
    
    // 保留旧枚举以兼容历史数据
    public enum ASRProvider: String, Sendable, CaseIterable {
        case whisperLocal = "whisper_local"
        case whisperAPI = "whisper_api"
        case system = "system"
        
        public var displayName: String {
            switch self {
            case .whisperLocal: return "本地 Whisper"
            case .whisperAPI: return "Whisper API"
            case .system: return "系统听写"
            }
        }
        
        /// 转换到新的 STTProvider
        public var toSTTProvider: STTProvider {
            switch self {
            case .whisperLocal: return .senseVoice
            case .whisperAPI: return .openAI
            case .system: return .appleSpeech
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(
        storage: StorageServiceProtocol? = nil,
        assetStore: AssetStore? = nil,
        aiRuntime: AIRuntimeProtocol? = nil,
        permissionManager: PermissionManager? = nil,
        sttRouter: STTRouter? = nil,
        textInjector: TextInjector? = nil
    ) {
        self.storage = storage ?? StorageService()
        self.assetStore = assetStore ?? AssetStore()
        self.aiRuntime = aiRuntime ?? AIRuntimeService()
        self.permissionManager = permissionManager
        self.sttRouter = sttRouter
        self.textInjector = textInjector ?? AXTextInjector()
        
        // 初始化润色服务
        if let aiRuntime = self.aiRuntime {
            self.polishService = PolishService(aiRuntime: aiRuntime)
        }
        
        // 初始化 STTRouter（如果未提供）
        if self.sttRouter == nil {
            self.sttRouter = STTRouter(provider: .appleSpeech)
        }
    }
    
    // MARK: - Status Handler
    
    public func setStatusHandler(_ handler: @escaping @Sendable (RecordingStatus) -> Void) {
        self.statusHandler = handler
    }
    
    private func updateStatus(_ newStatus: RecordingStatus) {
        status = newStatus
        let handler = statusHandler
        Task { @MainActor in
            handler?(newStatus)
        }
    }
    
    // MARK: - Recording Control
    
    public func startRecording() async throws {
        // 检查麦克风权限
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            throw VoiceError.permissionDenied
        }
        
        // 配置音频会话（macOS 版本为空实现）
        configureAudioSession()
        
        // 停止之前的录音
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        
        // 创建录音文件路径
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        currentRecordingURL = tempURL
        
        // 配置录音设置
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // 创建录音器
        recorder = try AVAudioRecorder(url: tempURL, settings: settings)
        recorder?.prepareToRecord()
        
        // 开始录音
        guard recorder?.record() == true else {
            throw VoiceError.recordingFailed("无法开始录音")
        }
        
        recordingStartTime = Date()
        updateStatus(.recording)
    }
    
    public func stopRecording() async throws -> String {
        guard let recorder = recorder, recorder.isRecording else {
            throw VoiceError.notRecording
        }
        
        recorder.stop()
        updateStatus(.processing)
        
        guard let recordingURL = currentRecordingURL else {
            throw VoiceError.noRecordingFile
        }
        
        // 保存到 AssetStore
        let assetFile = try await saveRecordingToAssetStore(url: recordingURL)
        
        // 创建 SourceItem
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let sourceItem = SourceItem(
            type: .audio,
            source: .voice,
            status: .captured,
            title: "语音记录 \(formatDate())",
            previewText: "录音时长: \(formatDuration(duration))",
            assetFileIds: [assetFile.id],
            metadata: [
                "duration": String(duration),
                "asrProvider": sttProvider.rawValue
            ]
        )
        
        try await storage.insertSourceItem(sourceItem)
        
        // 异步转写
        Task {
            await performTranscription(sourceItem: sourceItem, assetFile: assetFile)
        }
        
        return sourceItem.id
    }
    
    private func saveRecordingToAssetStore(url: URL) async throws -> AssetFile {
        // 读取录音数据
        let data = try Data(contentsOf: url)
        
        // 保存到 AssetStore
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let assetFile = try await assetStore.saveAudio(data: data, fileName: fileName)
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: url)
        
        return assetFile
    }
    
    // MARK: - Transcription
    
    public func transcribe(audioURL: URL) async throws -> String {
        // 优先使用新的 STTRouter
        if let router = sttRouter {
            let audioFile = AudioFile(url: audioURL)
            return try await router.transcribe(audioFile: audioFile)
        }
        
        // Fallback 到旧实现
        switch sttProvider {
        case .openAI:
            return try await transcribeWithWhisperAPI(audioURL: audioURL)
        case .appleSpeech:
            return try await transcribeWithAppleSpeech(audioURL: audioURL)
        default:
            return try await transcribeWithWhisperAPI(audioURL: audioURL)
        }
    }
    
    /// 流式转写
    public func transcribeStream(
        audioURL: URL,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        guard let router = sttRouter else {
            let text = try await transcribe(audioURL: audioURL)
            await onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
            return text
        }
        
        let audioFile = AudioFile(url: audioURL)
        return try await router.transcribeStream(audioFile: audioFile, onUpdate: onUpdate)
    }
    
    private func performTranscription(sourceItem: SourceItem, assetFile: AssetFile) async {
        do {
            let audioURL = URL(fileURLWithPath: assetFile.filePath)
            let transcript = try await transcribe(audioURL: audioURL)
            
            // 更新 SourceItem
            var updatedItem = sourceItem
            updatedItem.transcript = transcript
            updatedItem.previewText = transcript.prefix(200).description
            updatedItem.status = .parsed
            
            try await storage.updateSourceItem(updatedItem)
            
            // 应用润色（如果开启）
            if let settings = try? await getVoiceSettings(),
               settings.autoPolish,
               settings.voicePolishMode != .none {
                let polished = try await polishTranscript(transcript, mode: settings.voicePolishMode)
                updatedItem.polishedTranscript = polished
                try await storage.updateSourceItem(updatedItem)
            }

            NotificationCenter.default.post(
                name: Notification.Name("companion.voiceTranscriptionCompleted"),
                object: nil,
                userInfo: [
                    "sourceItemId": sourceItem.id,
                    "transcript": transcript
                ]
            )

            updateStatus(.idle)
            
        } catch {
            updateStatus(.error)
            print("转写失败: \(error)")
        }
    }
    
    /// 使用 Apple Speech 转写
    private func transcribeWithAppleSpeech(audioURL: URL) async throws -> String {
        let transcriber = AppleSpeechTranscriber()
        let audioFile = AudioFile(url: audioURL)
        return try await transcriber.transcribe(audioFile: audioFile)
    }
    
    private func transcribeWithLocalWhisper(audioURL: URL) async throws -> String {
        // 检查 whisper.cpp 是否可用
        let whisperPath = Bundle.main.path(forResource: "whisper", ofType: nil)
            ?? "/usr/local/bin/whisper"
        
        guard FileManager.default.fileExists(atPath: whisperPath) else {
            throw VoiceError.asrNotAvailable("本地 Whisper 未安装")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)
        process.arguments = [
            audioURL.path,
            "--model", "base",
            "--language", "zh",
            "--output_format", "txt",
            "--output_dir", FileManager.default.temporaryDirectory.path
        ]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "转写失败"
            throw VoiceError.transcriptionFailed(errorMessage)
        }
        
        // 读取输出文件
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(audioURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("txt")
        
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw VoiceError.transcriptionFailed("输出文件未生成")
        }
        
        let transcript = try String(contentsOf: outputURL, encoding: .utf8)
        try? FileManager.default.removeItem(at: outputURL)
        
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func transcribeWithWhisperAPI(audioURL: URL) async throws -> String {
        guard aiRuntime != nil else {
            throw VoiceError.asrNotAvailable("AI Runtime 未初始化")
        }
        
        // 读取音频数据
        let audioData = try Data(contentsOf: audioURL)
        
        // 使用 OpenAI Whisper API
        // 这里简化处理，实际应该通过 AI Provider 调用
        let apiKey = await SecretStore.shared.getAPIKey(for: "openai")
        guard let key = apiKey else {
            throw VoiceError.asrNotAvailable("OpenAI API Key 未配置")
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/audio/transcriptions") else {
            throw VoiceError.transcriptionFailed("无效转写地址")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        func append(_ string: String) {
            body.append(string.data(using: .utf8) ?? Data())
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
        append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        append("\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("whisper-1")
        append("\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        append("zh")
        append("\r\n")
        append("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VoiceError.transcriptionFailed("API 请求失败")
        }
        
        // 解析响应
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }
        
        throw VoiceError.transcriptionFailed("无法解析响应")
    }
    
    private func transcribeWithSystem(audioURL: URL) async throws -> String {
        // 使用 Apple SFSpeechRecognizer 系统语音识别
        let transcriber = AppleSpeechTranscriber()
        let audioFile = AudioFile(url: audioURL)
        return try await transcriber.transcribe(audioFile: audioFile)
    }
    
    // MARK: - Polish
    
    public func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String {
        guard mode != .none else { return text }
        
        // 优先使用新的 PolishService
        if let service = polishService {
            return try await service.polish(text: text, mode: mode)
        }
        
        // Fallback 到旧实现
        guard let aiRuntime = aiRuntime else {
            throw VoiceError.polishFailed("AI Runtime 未初始化")
        }
        
        let prompt: String
        switch mode {
        case .light:
            prompt = "请润色以下文本，使其更通顺：\n\n\(text)"
        case .structured:
            prompt = "请将以下文本整理为结构化格式：\n\n\(text)"
        case .formal:
            prompt = "请将以下文本改写为正式表达：\n\n\(text)"
        case .raw:
            prompt = "请整理以下文本，仅补全标点：\n\n\(text)"
        case .aiPrompt:
            prompt = "请将以下文本整理为结构化 AI prompt 格式：\n\n\(text)"
        case .none:
            return text
        }
        
        let messages = [
            ChatMessage(role: "system", content: "你是一个专业的文本润色助手。"),
            ChatMessage(role: "user", content: prompt)
        ]
        
        let response = try await aiRuntime.chat(messages: messages)
        return response.content
    }
    
    /// 润色并插入到光标位置
    public func polishAndInsert(
        text: String,
        mode: VoicePolishMode,
        providerId: String? = nil,
        model: String? = nil
    ) async throws {
        let polished = try await polishTranscript(text, mode: mode)
        
        // 插入到光标位置
        if let injector = textInjector {
            try injector.insert(text: polished)
        }
    }
    
    // MARK: - Status
    
    public func getRecordingStatus() async -> RecordingStatus {
        status
    }
    
    public func getRecordingDuration() async -> TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Configuration
    
    public func setASRProvider(_ provider: ASRProvider) {
        sttProvider = provider.toSTTProvider
        sttRouter?.setProvider(provider.toSTTProvider)
    }
    
    public func getASRProvider() -> ASRProvider {
        switch sttProvider {
        case .senseVoice, .whisperKit, .qwen3ASR, .funASR:
            return .whisperLocal
        case .openAI, .groq:
            return .whisperAPI
        case .appleSpeech:
            return .system
        default:
            return .system
        }
    }
    
    /// 设置 STT Provider
    public func setSTTProvider(_ provider: STTProvider) {
        sttProvider = provider
        sttRouter?.setProvider(provider)
    }

    public func configureSpeechInput(provider: STTProvider, modelIdentifier: String? = nil) {
        sttProvider = provider
        sttRouter?.setProvider(provider)

        guard let modelIdentifier else { return }

        switch provider {
        case .whisperKit:
            sttRouter?.setWhisperKitModelName(modelIdentifier)
        case .qwen3ASR:
            sttRouter?.setQwen3ASRModelIdentifier(modelIdentifier)
        default:
            break
        }
    }

    /// 获取 STT Provider
    public func getSTTProvider() -> STTProvider {
        sttProvider
    }
    
    // MARK: - Helpers
    
    private func configureAudioSession() {
        // macOS 不需要配置音频会话，iOS 才需要
        // 这里可以保留为空或添加 macOS 特定的音频配置
    }
    
    private func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    private func getVoiceSettings() async throws -> VoiceSettings {
        let settingsService = await MainActor.run {
            SettingsService(storage: storage)
        }
        return await settingsService.getVoiceSettings()
    }
    
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: Date())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Errors

public enum VoiceError: Error, LocalizedError {
    case permissionDenied
    case recordingFailed(String)
    case notRecording
    case noRecordingFile
    case asrNotAvailable(String)
    case transcriptionFailed(String)
    case polishFailed(String)
    case saveFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要麦克风权限"
        case .recordingFailed(let message):
            return "录音失败: \(message)"
        case .notRecording:
            return "当前未在录音"
        case .noRecordingFile:
            return "录音文件不存在"
        case .asrNotAvailable(let message):
            return "ASR 不可用: \(message)"
        case .transcriptionFailed(let message):
            return "转写失败: \(message)"
        case .polishFailed(let message):
            return "润色失败: \(message)"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "请前往系统设置 > 隐私与安全性 > 麦克风，授予 AcMind 权限"
        case .asrNotAvailable:
            return "请检查 ASR 配置或安装本地 Whisper"
        default:
            return nil
        }
    }
}

// MARK: - Extensions

extension AssetStore {
    func saveAudio(data: Data, fileName: String) async throws -> AssetFile {
        // 实现音频保存逻辑
        // 这里简化处理，实际应该保存到正确的目录
        let assetDir = getAssetDirectory()
        let fileURL = assetDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        
        return AssetFile(
            id: UUID().uuidString,
            sourceItemId: nil,
            fileName: fileName,
            filePath: fileURL.path,
            mimeType: "audio/m4a",
            fileSize: data.count,
            kind: .audio,
            createdAt: Date()
        )
    }
    
    private func getAssetDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let assetDir = appSupport.appendingPathComponent("AcMind/Assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: assetDir, withIntermediateDirectories: true)
        return assetDir
    }
}
