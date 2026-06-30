import Foundation
import AppKit
import Carbon

// MARK: - Say Input Delivery Mode

public enum SayInputOutputMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case copyToClipboard = "copyToClipboard"
    case autoPaste = "autoPaste"
    case ask = "ask"
    case translate = "translate"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .copyToClipboard: return "复制到剪贴板"
        case .autoPaste: return "自动粘贴"
        case .ask: return "询问"
        case .translate: return "翻译"
        }
    }
}

// MARK: - Say Input Trigger Mode

public enum SayInputTriggerMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case hold = "hold"
    case tap = "tap"
    case doubleTapLock = "doubleTapLock"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hold: return "长按录音"
        case .tap: return "点击切换"
        case .doubleTapLock: return "双击锁定"
        }
    }

    public var description: String {
        switch self {
        case .hold: return "按住 Fn 键录音，松开停止"
        case .tap: return "单击开始/停止录音"
        case .doubleTapLock: return "双击锁定录音，再次单击停止"
        }
    }
}

// MARK: - Say Input Configuration

public struct SayInputConfiguration: Sendable, Equatable {
    public var autoPolish: Bool
    public var polishMode: VoicePolishMode
    public var outputMode: SayInputOutputMode
    public var saveToInbox: Bool
    public var allowContinuation: Bool
    public var continuationWindow: TimeInterval
    public var transcriptTimeout: TimeInterval
    public var transcriptPollInterval: TimeInterval
    public var triggerMode: SayInputTriggerMode
    public var silenceTimeout: TimeInterval
    public var enableSilenceDetection: Bool
    public var preferredLanguage: String
    public var translationLanguage: String
    public var correctionRules: [CorrectionRule]
    public var muteSystemAudioDuringRecording: Bool
    public var enablePunctuationAppend: Bool
    public var injectionStrategy: String

    public init(
        autoPolish: Bool = true,
        polishMode: VoicePolishMode = .light,
        outputMode: SayInputOutputMode = .copyToClipboard,
        saveToInbox: Bool = true,
        allowContinuation: Bool = true,
        continuationWindow: TimeInterval = 12,
        transcriptTimeout: TimeInterval = 30,
        transcriptPollInterval: TimeInterval = 1,
        triggerMode: SayInputTriggerMode = .hold,
        silenceTimeout: TimeInterval = 3.0,
        enableSilenceDetection: Bool = false,
        preferredLanguage: String = "auto",
        translationLanguage: String = "zh",
        correctionRules: [CorrectionRule] = [],
        muteSystemAudioDuringRecording: Bool = false,
        enablePunctuationAppend: Bool = false,
        injectionStrategy: String = "postToPid"
    ) {
        self.autoPolish = autoPolish
        self.polishMode = polishMode
        self.outputMode = outputMode
        self.saveToInbox = saveToInbox
        self.allowContinuation = allowContinuation
        self.continuationWindow = continuationWindow
        self.transcriptTimeout = transcriptTimeout
        self.transcriptPollInterval = transcriptPollInterval
        self.triggerMode = triggerMode
        self.silenceTimeout = silenceTimeout
        self.enableSilenceDetection = enableSilenceDetection
        self.preferredLanguage = preferredLanguage
        self.translationLanguage = translationLanguage
        self.correctionRules = correctionRules
        self.muteSystemAudioDuringRecording = muteSystemAudioDuringRecording
        self.enablePunctuationAppend = enablePunctuationAppend
        self.injectionStrategy = injectionStrategy
    }
}

// MARK: - Say Input Delivery State

public enum SayInputDeliveryState: Sendable, Equatable {
    case insertedIntoFocusedField
    case copiedAndSavedToInbox
    case copiedToClipboard
    case awaitingUserChoice
}

// MARK: - Say Input Outcome

public struct SayInputOutcome: Sendable, Equatable {
    public let sourceItemId: String
    public let rawText: String
    public let polishedText: String
    public let deliveryState: SayInputDeliveryState
    public let focusedTarget: Bool

    public init(
        sourceItemId: String,
        rawText: String,
        polishedText: String,
        deliveryState: SayInputDeliveryState,
        focusedTarget: Bool
    ) {
        self.sourceItemId = sourceItemId
        self.rawText = rawText
        self.polishedText = polishedText
        self.deliveryState = deliveryState
        self.focusedTarget = focusedTarget
    }
}

// MARK: - Say Input Store

public protocol SayInputSourceItemStore: Sendable {
    func getSourceItem(id: String) async throws -> SourceItem?
    func updateSourceItem(_ item: SourceItem) async throws
    func deleteSourceItem(id: String) async throws
}

public struct StorageSayInputSourceItemStore: SayInputSourceItemStore {
    private let storage: StorageServiceProtocol

    public init(storage: StorageServiceProtocol) {
        self.storage = storage
    }

    public func getSourceItem(id: String) async throws -> SourceItem? {
        try await storage.getSourceItem(id: id)
    }

    public func updateSourceItem(_ item: SourceItem) async throws {
        try await storage.updateSourceItem(item)
    }

    public func deleteSourceItem(id: String) async throws {
        try await storage.deleteSourceItem(id: id)
    }
}

// MARK: - Say Input Clipboard

public protocol SayInputClipboard: Sendable {
    func setString(_ value: String)
    func string() -> String?
    func clear()
}

public final class SystemSayInputClipboard: SayInputClipboard, @unchecked Sendable {
    private let pasteboard: NSPasteboard = .general

    public init() {}

    public func setString(_ value: String) {
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    public func string() -> String? {
        pasteboard.string(forType: .string)
    }

    public func clear() {
        pasteboard.clearContents()
    }
}

// MARK: - Say Input Errors

public enum SayInputError: Error, LocalizedError {
    case transcriptTimeout
    case emptyTranscript
    case missingSourceItem
    case alreadyRecording
    case notRecording

    public var errorDescription: String? {
        switch self {
        case .transcriptTimeout:
            return "等待转写结果超时"
        case .emptyTranscript:
            return "未获取到有效转写结果"
        case .missingSourceItem:
            return "未找到语音记录"
        case .alreadyRecording:
            return "已经在录音中"
        case .notRecording:
            return "当前不在录音状态"
        }
    }
}

// MARK: - Say Input Coordinator

public actor SayInputCoordinator {
    private static let logger = AcMindLogger(category: .input)
    private let voiceService: VoiceServiceProtocol
    private let sourceStore: SayInputSourceItemStore
    private let textInjector: TextInjector
    private let clipboard: SayInputClipboard
    private let assetStore: AssetStoreProtocol?
    private var lastClipboardText: String?
    private var lastClipboardDeliveryAt: Date?
    private var isRecording: Bool = false
    private var isLockedRecording: Bool = false
    private var capturedPunctuation: [String] = []
    private var streamingWriter: StreamingKeyboardWriter?
    var currentConfiguration: SayInputConfiguration?
    private let audioMuteGuard = AudioMuteGuard.shared

    nonisolated(unsafe) public var onRealtimeTranscriptUpdate: (@Sendable (String) -> Void)?
    private var isRealtimeASRActive: Bool = false
    private var lastRealtimeResult: String?

    private static let cjkInputSourcePatterns: [String] = [
        "com.apple.inputmethod.SCIM",
        "com.apple.inputmethod.TCIM",
        "com.apple.inputmethod.Japanese",
        "com.apple.inputmethod.Korean",
        "com.apple.inputmethod.ChineseHandwriting",
        "com.apple.inputmethod.Chinese",
        "com.google.inputmethod.Japanese",
        "com.sogou.inputmethod",
        "com.baidu.inputmethod",
        "com.tencent.inputmethod",
        "com.alibaba.inputmethod",
        "com.microsoft.inputmethod",
    ]

    public init(
        voiceService: VoiceServiceProtocol,
        sourceStore: SayInputSourceItemStore,
        textInjector: TextInjector,
        clipboard: SayInputClipboard = SystemSayInputClipboard(),
        assetStore: AssetStoreProtocol? = nil
    ) {
        self.voiceService = voiceService
        self.sourceStore = sourceStore
        self.textInjector = textInjector
        self.clipboard = clipboard
        self.assetStore = assetStore
    }

    // MARK: - Recording Lifecycle

    public func startRecording() async throws {
        isRecording = true
        capturedPunctuation = []
        lastRealtimeResult = nil

        if let config = currentConfiguration, config.muteSystemAudioDuringRecording {
            audioMuteGuard.mute()
        }

        do {
            try await voiceService.startRealtimeTranscription { [weak self] snapshot in
                Task { @MainActor in
                    self?.onRealtimeTranscriptUpdate?(snapshot.text)
                }
            }
            isRealtimeASRActive = true
        } catch {
            isRealtimeASRActive = false
            try await voiceService.startRecording()
        }

        // 启动静音检测
        if let config = currentConfiguration, config.enableSilenceDetection {
            try await SilenceDetectionService.shared.startMonitoring(
                silenceThreshold: -30.0,
                silenceTimeout: config.silenceTimeout,
                onSilenceDetected: { [weak self] in
                    Task { await self?.handleSilenceTimeout() }
                },
                onSpeechDetected: {},
                onEnergyChanged: { _ in }
            )
        }

        // 启动录音快捷键
        try await RecordingHotkeyService.shared.startListening()
        await registerRecordingHotkeys()
    }

    public func stopRecording(
        configuration: SayInputConfiguration,
        onPolishChunk: (@Sendable (String) async -> Void)? = nil
    ) async throws -> SayInputOutcome {
        // 停止所有监听服务
        await SilenceDetectionService.shared.stopMonitoring()
        await RecordingHotkeyService.shared.stopListening()
        audioMuteGuard.unmute()

        let sourceItemId: String
        if isRealtimeASRActive {
            lastRealtimeResult = try? await voiceService.stopRealtimeTranscription()
            isRealtimeASRActive = false
            sourceItemId = try await voiceService.stopRecording()
        } else {
            sourceItemId = try await voiceService.stopRecording()
        }
        isRecording = false
        isLockedRecording = false
        currentConfiguration = configuration
        return try await processCapturedVoice(
            sourceItemId: sourceItemId,
            configuration: configuration,
            onPolishChunk: onPolishChunk
        )
    }

    public func cancelRecording() async throws {
        // 停止所有监听服务
        await SilenceDetectionService.shared.stopMonitoring()
        await RecordingHotkeyService.shared.stopListening()
        audioMuteGuard.unmute()

        let sourceItemId: String
        if isRealtimeASRActive {
            _ = try? await voiceService.stopRealtimeTranscription()
            isRealtimeASRActive = false
            sourceItemId = try await voiceService.stopRecording()
        } else {
            sourceItemId = try await voiceService.stopRecording()
        }
        isRecording = false
        isLockedRecording = false
        capturedPunctuation = []
        lastRealtimeResult = nil
        try await sourceStore.deleteSourceItem(id: sourceItemId)
        if let assetStore {
            try? await assetStore.deleteAssetsForSourceItem(sourceItemId: sourceItemId)
        }
    }

    // MARK: - Trigger Modes

    public func toggleRecording(configuration: SayInputConfiguration) async throws -> SayInputOutcome? {
        currentConfiguration = configuration
        
        if isRecording {
            if isLockedRecording {
                return try await stopRecording(configuration: configuration)
            } else {
                return nil
            }
        } else {
            try await startRecording()
            return nil
        }
    }

    public func handleTap(configuration: SayInputConfiguration) async throws -> SayInputOutcome? {
        switch configuration.triggerMode {
        case .hold:
            return nil
        case .tap:
            return try await toggleRecording(configuration: configuration)
        case .doubleTapLock:
            if isLockedRecording {
                return try await stopRecording(configuration: configuration)
            } else if isRecording {
                isLockedRecording = true
                return nil
            } else {
                try await startRecording()
                isLockedRecording = false
                return nil
            }
        }
    }

    public func handleDoubleTap(configuration: SayInputConfiguration) async throws {
        switch configuration.triggerMode {
        case .hold, .tap:
            return
        case .doubleTapLock:
            if isRecording {
                isLockedRecording = true
            } else {
                try await startRecording()
                isLockedRecording = true
            }
        }
    }

    public func currentRecordingState() -> (isRecording: Bool, isLocked: Bool) {
        return (isRecording, isLockedRecording)
    }

    public func handlePunctuationCapture(_ character: Character) {
        capturedPunctuation.append(String(character))
    }

    // MARK: - App-Aware Configuration

    /// 读取前台应用规则，合并到当前配置
    public func applyAppAwareConfiguration() async {
        let appService = AppAwareSettingsService.shared
        try? await appService.loadAppRules()

        let polishMode = await appService.getCurrentPolishMode()
        let triggerMode = await appService.getCurrentTriggerMode()
        let silenceSettings = await appService.getCurrentSilenceSettings()

        var config = currentConfiguration ?? SayInputConfiguration()
        config.polishMode = polishMode
        config.triggerMode = triggerMode
        config.enableSilenceDetection = silenceSettings.enabled
        config.silenceTimeout = silenceSettings.timeout
        currentConfiguration = config
    }

    // MARK: - Silence Detection

    private func handleSilenceTimeout() async {
        guard isRecording else { return }
        guard let configuration = currentConfiguration else { return }
        do {
            _ = try await stopRecording(configuration: configuration)
        } catch {
            Self.logger.error("Silence timeout stop failed: \(error)")
        }
    }

    // MARK: - Recording Hotkeys

    private func registerRecordingHotkeys() async {
        let hotkeyService = RecordingHotkeyService.shared

        // ESC → 取消录音
        await hotkeyService.registerHandler(for: .cancel) { [weak self] in
            Task { try? await self?.cancelRecording() }
        }

        // Space/Backspace → 立即注入，跳过润色
        await hotkeyService.registerHandler(for: .immediateInject) { [weak self] in
            Task {
                guard let self = self else { return }
                let state = await self.currentRecordingState()
                guard state.isRecording else { return }
                var config = await self.currentConfiguration ?? SayInputConfiguration()
                config.autoPolish = false
                _ = try? await self.stopRecording(configuration: config)
            }
        }

        await hotkeyService.setPunctuationHandler { [weak self] character in
            Task { [weak self] in
                await self?.handlePunctuationCapture(character)
            }
        }
    }

    // MARK: - Voice Processing

    public func processCapturedVoice(
        sourceItemId: String,
        configuration: SayInputConfiguration,
        onPolishChunk: (@Sendable (String) async -> Void)? = nil
    ) async throws -> SayInputOutcome {
        let contextTask = ContextCaptureService.shared.captureContextNonBlocking()

        var sourceItem: SourceItem?
        let rawText: String

        if let realtimeResult = lastRealtimeResult, !realtimeResult.isEmpty {
            rawText = realtimeResult
            sourceItem = try? await sourceStore.getSourceItem(id: sourceItemId)
        } else {
            sourceItem = try await waitForSourceItem(
                id: sourceItemId,
                timeout: configuration.transcriptTimeout,
                pollInterval: configuration.transcriptPollInterval
            )
            guard let fetchedItem = sourceItem else {
                throw SayInputError.missingSourceItem
            }
            rawText = bestAvailableText(from: fetchedItem)
        }
        lastRealtimeResult = nil
        var textWithPunctuation = rawText + capturedPunctuation.joined()
        if configuration.enablePunctuationAppend && !textWithPunctuation.isEmpty {
            let lastChar = textWithPunctuation.last!
            if !".!?。！？".contains(lastChar) {
                textWithPunctuation += "。"
            }
        }
        guard textWithPunctuation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw SayInputError.emptyTranscript
        }

        let correctedText = await CorrectionService.shared.applyCorrections(
            to: textWithPunctuation,
            rules: configuration.correctionRules
        )

        let hotwords = await PersonalDictionaryService.shared.getHotwords()
        let customPrompt = await CustomPromptService.shared.getPrompt(for: configuration.polishMode)

        let context = await contextTask.value
        let contextInfo = context.hasContext ? context.formattedContext() : nil

        let snapshot = await textInjector.getSelectionSnapshot()
        var usedStreamingKeyboard = false

        let polishedText: String
        if configuration.autoPolish, configuration.polishMode != .none {
            if let onPolishChunk, snapshot.isFocusedTarget, configuration.outputMode != .translate {
                let writer = StreamingKeyboardWriter()
                streamingWriter = writer
                let streamedText = StreamedTextBuffer()
                polishedText = try await voiceService.polishTranscriptStream(
                    correctedText,
                    mode: configuration.polishMode,
                    hotwords: hotwords,
                    customSystemPrompt: customPrompt,
                    contextInfo: contextInfo,
                    language: configuration.preferredLanguage
                ) { chunk in
                    let fullText = await streamedText.append(chunk)
                    await onPolishChunk(fullText)
                    await writer.write(chunk: chunk)
                }
                let writeSuccess = await writer.finish()
                streamingWriter = nil
                if writeSuccess {
                    usedStreamingKeyboard = true
                }
            } else if let onPolishChunk {
                let streamedText = StreamedTextBuffer()
                polishedText = try await voiceService.polishTranscriptStream(
                    correctedText,
                    mode: configuration.polishMode,
                    hotwords: hotwords,
                    customSystemPrompt: customPrompt,
                    contextInfo: contextInfo,
                    language: configuration.preferredLanguage
                ) { chunk in
                    let fullText = await streamedText.append(chunk)
                    await onPolishChunk(fullText)
                }
            } else {
                polishedText = try await voiceService.polishTranscript(
                    correctedText,
                    mode: configuration.polishMode,
                    hotwords: hotwords,
                    customSystemPrompt: customPrompt,
                    contextInfo: contextInfo,
                    language: configuration.preferredLanguage
                )
            }
        } else {
            polishedText = correctedText
        }

        let outputText: String
        if configuration.outputMode == .translate {
            if let onPolishChunk {
                let streamedText = StreamedTextBuffer()
                outputText = try await voiceService.translateTranscriptStream(
                    polishedText,
                    targetLanguage: configuration.translationLanguage,
                    contextInfo: contextInfo
                ) { chunk in
                    let fullText = await streamedText.append(chunk)
                    await onPolishChunk(fullText)
                }
            } else {
                outputText = try await voiceService.translateTranscript(
                    polishedText,
                    targetLanguage: configuration.translationLanguage,
                    contextInfo: contextInfo
                )
            }
        } else {
            outputText = polishedText
        }

        let deliveryState: SayInputDeliveryState
        let now = Date()
        let previousClipboard = clipboard.string()
        var clipboardOverwritten = false

        if usedStreamingKeyboard {
            deliveryState = .insertedIntoFocusedField
            lastClipboardText = outputText
            lastClipboardDeliveryAt = now
        } else if configuration.injectionStrategy == "clipboard" {
            let deliveredText = mergeWithContinuationIfNeeded(
                outputText,
                now: now,
                allowContinuation: configuration.allowContinuation,
                continuationWindow: configuration.continuationWindow
            )
            clipboard.setString(deliveredText)
            clipboardOverwritten = true
            lastClipboardText = deliveredText
            lastClipboardDeliveryAt = now
            deliveryState = .copiedToClipboard
        } else if configuration.injectionStrategy == "streaming" && snapshot.isFocusedTarget {
            let writer = StreamingKeyboardWriter()
            await writer.write(chunk: outputText)
            let writeSuccess = await writer.finish()
            if writeSuccess {
                deliveryState = .insertedIntoFocusedField
                lastClipboardText = outputText
                lastClipboardDeliveryAt = now
            } else {
                let deliveredText = mergeWithContinuationIfNeeded(
                    outputText,
                    now: now,
                    allowContinuation: configuration.allowContinuation,
                    continuationWindow: configuration.continuationWindow
                )
                clipboard.setString(deliveredText)
                clipboardOverwritten = true
                lastClipboardText = deliveredText
                lastClipboardDeliveryAt = now
                deliveryState = configuration.saveToInbox ? .copiedAndSavedToInbox : .copiedToClipboard
            }
        } else if snapshot.isFocusedTarget {
            do {
                if snapshot.canReplaceSelection {
                    try await textInjector.replaceSelection(text: outputText)
                } else {
                    try await textInjector.insert(text: outputText)
                }
                deliveryState = .insertedIntoFocusedField
                lastClipboardText = outputText
                lastClipboardDeliveryAt = now
            } catch {
                let deliveredText = mergeWithContinuationIfNeeded(
                    outputText,
                    now: now,
                    allowContinuation: configuration.allowContinuation,
                    continuationWindow: configuration.continuationWindow
                )
                clipboard.setString(deliveredText)
                clipboardOverwritten = true
                lastClipboardText = deliveredText
                lastClipboardDeliveryAt = now
                deliveryState = configuration.saveToInbox ? .copiedAndSavedToInbox : .copiedToClipboard
            }
        } else {
            let deliveredText = mergeWithContinuationIfNeeded(
                outputText,
                now: now,
                allowContinuation: configuration.allowContinuation,
                continuationWindow: configuration.continuationWindow
            )
            switch configuration.outputMode {
            case .ask:
                clipboard.setString(deliveredText)
                clipboardOverwritten = true
                deliveryState = .awaitingUserChoice
            case .copyToClipboard, .autoPaste, .translate:
                clipboard.setString(deliveredText)
                clipboardOverwritten = true
                deliveryState = configuration.saveToInbox ? .copiedAndSavedToInbox : .copiedToClipboard
            }
            lastClipboardText = deliveredText
            lastClipboardDeliveryAt = now
        }

        if clipboardOverwritten {
            Task {
                try? await Task.sleep(nanoseconds: 750_000_000)
                if let prev = previousClipboard {
                    clipboard.setString(prev)
                }
            }
        }

        if configuration.saveToInbox, var updated = sourceItem {
            updated.transcript = textWithPunctuation
            updated.polishedTranscript = outputText
            updated.previewText = outputText.prefix(200).description
            updated.status = .parsed
            try await sourceStore.updateSourceItem(updated)
        }

        return SayInputOutcome(
            sourceItemId: sourceItemId,
            rawText: textWithPunctuation,
            polishedText: outputText,
            deliveryState: deliveryState,
            focusedTarget: snapshot.isFocusedTarget
        )
    }

    public func currentClipboardText() -> String? {
        clipboard.string()
    }

    // MARK: - Private Helpers

    private func waitForSourceItem(
        id: String,
        timeout: TimeInterval,
        pollInterval: TimeInterval
    ) async throws -> SourceItem? {
        let nanos = UInt64(max(0.05, pollInterval) * 1_000_000_000)
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let item = try await sourceStore.getSourceItem(id: id) {
                if bestAvailableText(from: item).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return item
                }
            }

            try await Task.sleep(nanoseconds: nanos)
        }

        if let item = try await sourceStore.getSourceItem(id: id) {
            return item
        }

        throw SayInputError.transcriptTimeout
    }

    private func bestAvailableText(from sourceItem: SourceItem) -> String {
        let candidates = [
            sourceItem.polishedTranscript,
            sourceItem.transcript,
            sourceItem.previewText
        ]

        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty == false {
                return trimmed
            }
        }

        return ""
    }

    private func mergeWithContinuationIfNeeded(
        _ text: String,
        now: Date,
        allowContinuation: Bool,
        continuationWindow: TimeInterval
    ) -> String {
        guard allowContinuation,
              let lastClipboardText,
              let lastClipboardDeliveryAt,
              now.timeIntervalSince(lastClipboardDeliveryAt) <= continuationWindow,
              lastClipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return text
        }

        return lastClipboardText + "\n" + text
    }
}

private actor StreamedTextBuffer {
    private var text = ""

    func append(_ chunk: String) -> String {
        text += chunk
        return text
    }
}
