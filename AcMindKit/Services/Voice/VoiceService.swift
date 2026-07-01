import Foundation
import AVFoundation
import CoreAudio

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
    private static let logger = AcMindLogger(category: .input)

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
    private var restoredInputDeviceID: AudioDeviceID?

    // MARK: - Realtime Transcription

    private var realtimeSession: RealtimeTranscriptionSession?
    private var audioEngineForRealtime: AVAudioEngine?
    private var recorderWasRecording: Bool = false

    public var isRealtimeActive: Bool {
        audioEngineForRealtime != nil && realtimeSession != nil
    }

    // MARK: - ASR Configuration

    private var sttProvider: STTProvider = .appleSpeech

    // Legacy: 保留旧枚举以兼容
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

        do {
            applyPreferredMicrophoneSelectionIfNeeded()

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
        } catch {
            restoreDefaultMicrophoneSelectionIfNeeded()
            throw error
        }
    }

    public func stopRecording() async throws -> String {
        updateStatus(.processing)
        restoreDefaultMicrophoneSelectionIfNeeded()
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        if let recorder = recorder {
            if recorder.isRecording {
                recorder.stop()
            }

            if let recordingURL = currentRecordingURL {
                let assetFile = try await saveRecordingToAssetStore(url: recordingURL)
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
                Task {
                    await performTranscription(sourceItem: sourceItem, assetFile: assetFile)
                }
                return sourceItem.id
            }
        }

        let sourceItem = SourceItem(
            type: .audio,
            source: .voice,
            status: .captured,
            title: "语音记录 \(formatDate())",
            previewText: "录音时长: \(formatDuration(duration))",
            assetFileIds: [],
            metadata: [
                "duration": String(duration),
                "asrProvider": sttProvider.rawValue
            ]
        )
        try await storage.insertSourceItem(sourceItem)
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
        if let router = sttRouter {
            let audioFile = AudioFile(url: audioURL)
            return try await router.transcribe(audioFile: audioFile)
        }

        switch sttProvider {
        case .openAI:
            return try await transcribeWithWhisperAPI(audioURL: audioURL)
        case .appleSpeech:
            return try await transcribeWithAppleSpeech(audioURL: audioURL)
        default:
            return try await transcribeWithWhisperAPI(audioURL: audioURL)
        }
    }

    public func transcribe(audioURL: URL, language: String) async throws -> String {
        guard language != "auto" else {
            return try await transcribe(audioURL: audioURL)
        }

        if let router = sttRouter {
            let audioFile = AudioFile(url: audioURL)
            return try await router.transcribe(audioFile: audioFile, language: language)
        }

        return try await transcribe(audioURL: audioURL)
    }

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

    // MARK: - Realtime Transcription

    public func startRealtimeTranscription(onUpdate: @escaping @Sendable (TranscriptionSnapshot) -> Void) async throws {
        guard let router = sttRouter else {
            throw VoiceError.asrNotAvailable("STTRouter 未初始化")
        }

        let transcriber = try await router.getTranscriber()
        guard var session = transcriber.createRealtimeSession() else {
            throw VoiceError.asrNotAvailable("当前引擎不支持实时转写")
        }
        session.onUpdate = onUpdate
        realtimeSession = session

        recorderWasRecording = recorder?.isRecording == true
        if recorderWasRecording {
            recorder?.pause()
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            let pcmData = self.convertToPCM16(buffer: buffer)
            Task {
                try? await self.realtimeSession?.sendAudioData(pcmData)
            }
        }

        engine.prepare()
        try engine.start()
        audioEngineForRealtime = engine
    }

    public func stopRealtimeTranscription() async throws -> String {
        audioEngineForRealtime?.stop()
        audioEngineForRealtime?.inputNode.removeTap(onBus: 0)
        audioEngineForRealtime = nil

        guard let session = realtimeSession else { return "" }
        realtimeSession = nil
        return try await session.finish()
    }

    nonisolated private func convertToPCM16(buffer: AVAudioPCMBuffer) -> Data {
        let channelData = buffer.floatChannelData![0]
        let frames = buffer.frameLength
        var pcm16 = Data(count: Int(frames) * 2)
        pcm16.withUnsafeMutableBytes { rawBuffer in
            let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<Int(frames) {
                let sample = max(-1.0, min(1.0, channelData[i]))
                int16Buffer[i] = Int16(sample * 32767)
            }
        }
        return pcm16
    }

    private func performTranscription(sourceItem: SourceItem, assetFile: AssetFile) async {
        do {
            let audioURL = URL(fileURLWithPath: assetFile.filePath)
            let preferredLanguage = (try? await getVoiceSettings())?.preferredLanguage ?? "auto"
            let transcript = try await transcribe(audioURL: audioURL, language: preferredLanguage)

            var updatedItem = sourceItem
            updatedItem.transcript = transcript
            updatedItem.previewText = transcript.prefix(200).description
            updatedItem.status = .parsed

            try await storage.updateSourceItem(updatedItem)

            if let settings = try? await getVoiceSettings(),
               settings.autoPolish,
               settings.voicePolishMode != .none {
                let polished = try await polishTranscript(
                    transcript,
                    mode: settings.voicePolishMode,
                    language: preferredLanguage
                )
                updatedItem.polishedTranscript = polished
                try await storage.updateSourceItem(updatedItem)
            }

            updateStatus(.idle)

        } catch {
            updateStatus(.error)
            Self.logger.error("转写失败: \(error)")
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
        guard let apiKey = await SecretStore.shared.getAPIKey(for: "openai") else {
            throw VoiceError.asrNotAvailable("OpenAI API Key 未配置")
        }

        let transcriber = OpenAIWhisperTranscriber(apiKey: apiKey)
        return try await transcriber.transcribe(audioFile: AudioFile(url: audioURL))
    }

    // MARK: - Polish

    public func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String {
        try await polishTranscript(text, mode: mode, hotwords: [], customSystemPrompt: nil, contextInfo: nil)
    }

    public func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?) async throws -> String {
        try await polishTranscript(text, mode: mode, hotwords: hotwords, customSystemPrompt: customSystemPrompt, contextInfo: contextInfo, language: "auto")
    }

    public func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?, language: String) async throws -> String {
        guard mode != .none else { return text }

        var enhancedSystemPrompt = customSystemPrompt
        if enhancedSystemPrompt == nil || enhancedSystemPrompt?.isEmpty == true {
            if language != "auto" {
                if hotwords.isEmpty {
                    enhancedSystemPrompt = PolishPrompts.systemPrompt(for: mode, language: language)
                } else {
                    enhancedSystemPrompt = PolishPrompts.systemPrompt(for: mode, language: language, hotwords: hotwords)
                }
            } else if hotwords.isEmpty {
                enhancedSystemPrompt = nil
            } else {
                enhancedSystemPrompt = PolishPrompts.systemPrompt(for: mode, hotwords: hotwords)
            }
        }

        var enhancedText = text
        if let context = contextInfo, !context.isEmpty {
            if language.hasPrefix("en") {
                enhancedText = "Context information:\n\(context)\n\nText to polish:\n\(text)"
            } else {
                enhancedText = "上下文信息：\n\(context)\n\n需要润色的文本：\n\(text)"
            }
        }

        if let service = polishService {
            return try await service.polish(
                text: enhancedText,
                mode: mode,
                hotwords: hotwords,
                customSystemPrompt: enhancedSystemPrompt,
                language: language
            )
        }

        guard let aiRuntime = aiRuntime else {
            throw VoiceError.polishFailed("AI Runtime 未初始化")
        }

        let prompt: String
        if language.hasPrefix("en") {
            switch mode {
            case .light:
                prompt = "Please polish the following text to make it more fluent:\n\n\(text)"
            case .structured:
                prompt = "Please organize the following text into a structured format:\n\n\(text)"
            case .formal:
                prompt = "Please rewrite the following text in formal expression:\n\n\(text)"
            case .raw:
                prompt = "Please organize the following text, only add punctuation:\n\n\(text)"
            case .aiPrompt:
                prompt = "Please organize the following text into a structured AI prompt format:\n\n\(text)"
            case .none:
                return text
            }
        } else {
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
        }

        let systemMessage = language.hasPrefix("en")
            ? "You are a professional text polishing assistant."
            : "你是一个专业的文本润色助手。"

        let messages = [
            ChatMessage(role: "system", content: systemMessage),
            ChatMessage(role: "user", content: prompt)
        ]

        let response = try await aiRuntime.chat(messages: messages)
        return response.content
    }

    public func polishTranscriptStream(
        _ text: String,
        mode: VoicePolishMode,
        hotwords: [String],
        customSystemPrompt: String?,
        contextInfo: String?,
        language: String,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        guard mode != .none else {
            await onChunk(text)
            return text
        }

        var enhancedSystemPrompt = customSystemPrompt
        if enhancedSystemPrompt == nil || enhancedSystemPrompt?.isEmpty == true {
            if language != "auto" {
                if hotwords.isEmpty {
                    enhancedSystemPrompt = PolishPrompts.systemPrompt(for: mode, language: language)
                } else {
                    enhancedSystemPrompt = PolishPrompts.systemPrompt(for: mode, language: language, hotwords: hotwords)
                }
            } else if hotwords.isEmpty {
                enhancedSystemPrompt = nil
            } else {
                enhancedSystemPrompt = PolishPrompts.systemPrompt(for: mode, hotwords: hotwords)
            }
        }

        var enhancedText = text
        if let context = contextInfo, !context.isEmpty {
            if language.hasPrefix("en") {
                enhancedText = "Context information:\n\(context)\n\nText to polish:\n\(text)"
            } else {
                enhancedText = "上下文信息：\n\(context)\n\n需要润色的文本：\n\(text)"
            }
        }

        guard let service = polishService else {
            let fallback = try await polishTranscript(
                enhancedText,
                mode: mode,
                hotwords: hotwords,
                customSystemPrompt: enhancedSystemPrompt,
                contextInfo: contextInfo,
                language: language
            )
            await onChunk(fallback)
            return fallback
        }

        let polished = try await service.polishStream(
            text: enhancedText,
            mode: mode,
            hotwords: hotwords,
            customSystemPrompt: enhancedSystemPrompt,
            language: language,
            onChunk: onChunk
        )

        return polished
    }

    // MARK: - Translation

    public func translateTranscript(
        _ text: String,
        targetLanguage: String,
        contextInfo: String?
    ) async throws -> String {
        let resolvedTargetLanguage = normalizeTranslationLanguage(targetLanguage)
        guard let aiRuntime else {
            throw VoiceError.translationFailed("AI Runtime 未初始化")
        }

        let systemMessage = translationSystemPrompt(targetLanguage: resolvedTargetLanguage)
        let userMessage = translationUserPrompt(
            text: text,
            targetLanguage: resolvedTargetLanguage,
            contextInfo: contextInfo
        )

        let messages = [
            ChatMessage(role: "system", content: systemMessage),
            ChatMessage(role: "user", content: userMessage)
        ]

        let response = try await aiRuntime.chat(messages: messages)
        return cleanTranslationOutput(response.content)
    }

    public func translateTranscriptStream(
        _ text: String,
        targetLanguage: String,
        contextInfo: String?,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let resolvedTargetLanguage = normalizeTranslationLanguage(targetLanguage)
        guard let aiRuntime else {
            let fallback = try await translateTranscript(
                text,
                targetLanguage: resolvedTargetLanguage,
                contextInfo: contextInfo
            )
            await onChunk(fallback)
            return fallback
        }

        let systemMessage = translationSystemPrompt(targetLanguage: resolvedTargetLanguage)
        let userMessage = translationUserPrompt(
            text: text,
            targetLanguage: resolvedTargetLanguage,
            contextInfo: contextInfo
        )

        let messages = [
            ChatMessage(role: "system", content: systemMessage),
            ChatMessage(role: "user", content: userMessage)
        ]

        var fullContent = ""
        let stream = aiRuntime.chatStream(messages: messages)

        for try await response in stream {
            let chunk = response.content
            fullContent += chunk
            await onChunk(chunk)
        }

        return cleanTranslationOutput(fullContent)
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
            try await injector.insert(text: polished)
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
        case .senseVoice, .whisperKit, .qwen3ASR, .funASR, .parakeet:
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
        let selectableProvider = STTProvider.selectableProvider(from: provider)
        sttProvider = selectableProvider
        sttRouter?.setProvider(selectableProvider)
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

    private func applyPreferredMicrophoneSelectionIfNeeded() {
        let selection = VoiceMicrophonePreferenceStore.load()
        guard selection != VoiceMicrophonePreferenceStore.defaultName else {
            return
        }

        restoredInputDeviceID = VoiceMicrophoneDeviceCatalog.applySelection(selection)
    }

    private func restoreDefaultMicrophoneSelectionIfNeeded() {
        guard let deviceID = restoredInputDeviceID else { return }
        VoiceMicrophoneDeviceCatalog.restoreDefaultInputDevice(id: deviceID)
        restoredInputDeviceID = nil
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
        let settingsService = SettingsService(storage: storage)
        return await settingsService.getVoiceSettings()
    }

    private func normalizeTranslationLanguage(_ language: String) -> String {
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "auto" ? "zh" : trimmed
    }

    private func translationSystemPrompt(targetLanguage: String) -> String {
        let isEnglish = targetLanguage.hasPrefix("en")
        let targetName = translationLanguageDisplayName(targetLanguage, english: isEnglish)
        if isEnglish {
            return """
            You are a professional translation assistant.
            Translate the provided text into \(targetName).
            Preserve the original meaning, tone, names, code, URLs, numbers, units, and formatting where sensible.
            Do not explain your work. Output only the translated text.
            """
        }

        return """
        你是专业翻译助手。
        请将输入文本翻译成\(targetName)。
        保留原意、语气、人名、专有名词、代码、URL、数字、单位和合理的格式。
        不要解释你的处理过程，只输出译文正文。
        """
    }

    private func translationUserPrompt(text: String, targetLanguage: String, contextInfo: String?) -> String {
        let targetName = translationLanguageDisplayName(targetLanguage)
        let escapedText = text.replacingOccurrences(of: "</raw_text>", with: "<\\/raw_text>")

        if let contextInfo, contextInfo.isEmpty == false {
            let escapedContext = contextInfo.replacingOccurrences(of: "</context>", with: "<\\/context>")
            return """
            请将以下文本翻译成\(targetName)。如果上下文中的术语、对象或指代能帮助翻译，请优先参考上下文，但不要添加原文没有的信息。

            <context>
            \(escapedContext)
            </context>

            <raw_text>
            \(escapedText)
            </raw_text>
            """
        }

        return """
        请将以下文本翻译成\(targetName)。只输出译文正文，不要添加解释、注释或前后缀。

        <raw_text>
        \(escapedText)
        </raw_text>
        """
    }

    private func translationLanguageDisplayName(_ language: String, english: Bool = false) -> String {
        let lower = language.lowercased()
        if lower.hasPrefix("zh") { return english ? "Chinese" : "中文" }
        if lower.hasPrefix("en") { return english ? "English" : "英文" }
        if lower.hasPrefix("ja") { return english ? "Japanese" : "日文" }
        if lower.hasPrefix("ko") { return english ? "Korean" : "韩文" }
        if lower.hasPrefix("fr") { return english ? "French" : "法语" }
        if lower.hasPrefix("de") { return english ? "German" : "德语" }
        if lower.hasPrefix("es") { return english ? "Spanish" : "西班牙语" }
        return language
    }

    private func cleanTranslationOutput(_ content: String) -> String {
        var output = content
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        output = stripMarkdownFence(output)
        output = stripLeadingTranslationBoilerplate(output)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripMarkdownFence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("```") && trimmed.hasSuffix("```") else {
            return text
        }

        var lines = trimmed.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return text }

        lines.removeFirst()
        lines.removeLast()

        return lines.joined(separator: "\n")
    }

    private func stripLeadingTranslationBoilerplate(_ text: String) -> String {
        let prefixes = [
            "以下是翻译结果：",
            "翻译如下：",
            "译文如下：",
            "Here is the translation:",
            "Translation:",
            "Translated text:"
        ]

        var result = text
        for prefix in prefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                break
            }
        }
        return result
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
    case translationFailed(String)
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
        case .translationFailed(let message):
            return "翻译失败: \(message)"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "请前往系统设置 > 隐私与安全性 > 麦克风，授予 AcWork 权限"
        case .asrNotAvailable:
            return "请检查 ASR 配置或安装本地 Whisper"
        default:
            return nil
        }
    }
}
