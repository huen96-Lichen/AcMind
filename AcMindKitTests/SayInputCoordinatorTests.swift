import XCTest
@testable import AcMindKit

@MainActor
final class SayInputCoordinatorTests: XCTestCase {
    func testFocusedTargetUsesPolishedTextAndDirectInsertion() async throws {
        let sourceItemId = UUID().uuidString
        let rawText = "我想把这个内容整理一下"
        let polishedText = "我想把这个内容整理一下。"

        let voiceService = VoiceServiceStub(stopRecordingResult: sourceItemId, polishedText: polishedText)
        let storage = SayInputSourceStoreStub(items: [
            sourceItemId: SourceItem(
                id: sourceItemId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: rawText,
                transcript: rawText
            )
        ])
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = true
                snapshot.isFocusedTarget = true
                snapshot.source = "accessibility"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        let outcome = try await coordinator.processCapturedVoice(
            sourceItemId: sourceItemId,
            configuration: SayInputConfiguration(
                autoPolish: true,
                polishMode: .light,
                outputMode: .copyToClipboard,
                saveToInbox: true
            )
        )

        XCTAssertEqual(outcome.deliveryState, SayInputDeliveryState.insertedIntoFocusedField)
        XCTAssertEqual(textInjector.insertedTexts, [polishedText])
        XCTAssertTrue(clipboard.writtenStrings.isEmpty)
        XCTAssertEqual(voiceService.polishRequests, [rawText])

        let updated = try await storage.getSourceItem(id: sourceItemId)
        XCTAssertEqual(updated?.polishedTranscript, polishedText)
        XCTAssertEqual(updated?.previewText, polishedText)
    }

    func testUnfocusedTargetCopiesPolishedTextToClipboardAndUpdatesInboxItem() async throws {
        let sourceItemId = UUID().uuidString
        let rawText = "把这个内容先保存起来"
        let polishedText = "把这个内容先保存起来。"

        let voiceService = VoiceServiceStub(stopRecordingResult: sourceItemId, polishedText: polishedText)
        let storage = SayInputSourceStoreStub(items: [
            sourceItemId: SourceItem(
                id: sourceItemId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: rawText,
                transcript: rawText
            )
        ])
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = false
                snapshot.isFocusedTarget = false
                snapshot.source = "none"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        let outcome = try await coordinator.processCapturedVoice(
            sourceItemId: sourceItemId,
            configuration: SayInputConfiguration(
                autoPolish: true,
                polishMode: .light,
                outputMode: .copyToClipboard,
                saveToInbox: true
            )
        )

        XCTAssertEqual(outcome.deliveryState, SayInputDeliveryState.copiedAndSavedToInbox)
        XCTAssertTrue(textInjector.insertedTexts.isEmpty)
        XCTAssertEqual(clipboard.writtenStrings, [polishedText])
        XCTAssertEqual(voiceService.polishRequests, [rawText])

        let updated = try await storage.getSourceItem(id: sourceItemId)
        XCTAssertEqual(updated?.polishedTranscript, polishedText)
        XCTAssertEqual(updated?.previewText, polishedText)
    }

    func testUnfocusedContinuationAppendsToPreviousClipboardText() async throws {
        let firstSourceId = UUID().uuidString
        let secondSourceId = UUID().uuidString

        let voiceService = VoiceServiceStub(
            stopRecordingResult: firstSourceId,
            polishedTextProvider: { $0 + "。"}
        )
        voiceService.enqueueStopRecordingResult(secondSourceId)

        let storage = SayInputSourceStoreStub(items: [
            firstSourceId: SourceItem(
                id: firstSourceId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: "先说第一句",
                transcript: "先说第一句"
            ),
            secondSourceId: SourceItem(
                id: secondSourceId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: "再补第二句",
                transcript: "再补第二句"
            )
        ])
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = false
                snapshot.isFocusedTarget = false
                snapshot.source = "none"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        _ = try await coordinator.processCapturedVoice(
            sourceItemId: firstSourceId,
            configuration: SayInputConfiguration(
                autoPolish: true,
                polishMode: .light,
                outputMode: .copyToClipboard,
                saveToInbox: true,
                allowContinuation: true,
                continuationWindow: 30
            )
        )

        _ = try await coordinator.processCapturedVoice(
            sourceItemId: secondSourceId,
            configuration: SayInputConfiguration(
                autoPolish: true,
                polishMode: .light,
                outputMode: .copyToClipboard,
                saveToInbox: true,
                allowContinuation: true,
                continuationWindow: 30
            )
        )

        XCTAssertEqual(clipboard.writtenStrings.last, "先说第一句。\n再补第二句。")
    }

    func testPunctuationAppending() async throws {
        let sourceItemId = UUID().uuidString
        let rawText = "你好"

        let voiceService = VoiceServiceStub(stopRecordingResult: sourceItemId, polishedTextProvider: { $0 + "。" })
        let storage = SayInputSourceStoreStub(items: [
            sourceItemId: SourceItem(
                id: sourceItemId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: rawText,
                transcript: rawText
            )
        ])
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = false
                snapshot.isFocusedTarget = false
                snapshot.source = "none"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        await coordinator.handlePunctuationCapture("！")
        await coordinator.handlePunctuationCapture("？")

        let outcome = try await coordinator.processCapturedVoice(
            sourceItemId: sourceItemId,
            configuration: SayInputConfiguration(
                autoPolish: true,
                polishMode: .light,
                outputMode: .copyToClipboard,
                saveToInbox: true
            )
        )

        XCTAssertEqual(outcome.rawText, "你好！？")
        XCTAssertEqual(voiceService.polishRequests, ["你好！？"])
    }

    func testTranslateOutputModeUsesTranslatedText() async throws {
        let sourceItemId = UUID().uuidString
        let rawText = "Please translate this sentence"
        let translatedText = "请翻译这句话"

        let voiceService = VoiceServiceStub(
            stopRecordingResult: sourceItemId,
            translatedText: translatedText
        )

        let storage = SayInputSourceStoreStub(items: [
            sourceItemId: SourceItem(
                id: sourceItemId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: rawText,
                transcript: rawText
            )
        ])
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = false
                snapshot.isFocusedTarget = false
                snapshot.source = "none"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        let outcome = try await coordinator.processCapturedVoice(
            sourceItemId: sourceItemId,
            configuration: SayInputConfiguration(
                autoPolish: false,
                polishMode: .none,
                outputMode: .translate,
                saveToInbox: true,
                preferredLanguage: "auto",
                translationLanguage: "zh"
            )
        )

        XCTAssertEqual(outcome.polishedText, translatedText)
        XCTAssertEqual(outcome.deliveryState, .copiedAndSavedToInbox)
        XCTAssertEqual(clipboard.writtenStrings, [translatedText])
        XCTAssertEqual(voiceService.translationRequests, [rawText])

        let updated = try await storage.getSourceItem(id: sourceItemId)
        XCTAssertEqual(updated?.polishedTranscript, translatedText)
        XCTAssertEqual(updated?.previewText, translatedText)
    }

    func testStreamingPolishCallbackReceivesAccumulatedChunks() async throws {
        let sourceItemId = UUID().uuidString
        let rawText = "请把这段话整理一下"
        let polishedText = "请把这段话整理一下。"

        let voiceService = VoiceServiceStub(stopRecordingResult: sourceItemId, polishedTextProvider: { $0 + "。" })
        voiceService.streamChunks = ["请把", "这段话", "整理一下。"]

        let storage = SayInputSourceStoreStub(items: [
            sourceItemId: SourceItem(
                id: sourceItemId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: rawText,
                transcript: rawText
            )
        ])
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = false
                snapshot.isFocusedTarget = false
                snapshot.source = "none"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        let streamedUpdates = StreamedUpdatesBox()
        let outcome = try await coordinator.processCapturedVoice(
            sourceItemId: sourceItemId,
            configuration: SayInputConfiguration(
                autoPolish: true,
                polishMode: .light,
                outputMode: .copyToClipboard,
                saveToInbox: true
            ),
            onPolishChunk: { chunk in
                await streamedUpdates.append(chunk)
            }
        )

        XCTAssertEqual(outcome.polishedText, polishedText)
        let streamedSnapshot = await streamedUpdates.snapshot()
        XCTAssertEqual(streamedSnapshot, ["请把", "请把这段话", "请把这段话整理一下。"])
    }

    func testSilenceTimeoutAutoStop() async throws {
        let sourceItemId = UUID().uuidString
        let rawText = "测试静音停止"
        let polishedText = "测试静音停止。"

        let voiceService = VoiceServiceStub(stopRecordingResult: sourceItemId, polishedText: polishedText)
        let storage = SayInputSourceStoreStub(items: [
            sourceItemId: SourceItem(
                id: sourceItemId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: rawText,
                transcript: rawText
            )
        ])
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = false
                snapshot.isFocusedTarget = false
                snapshot.source = "none"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        let outcome = try await coordinator.stopRecording(
            configuration: SayInputConfiguration(
                autoPolish: true,
                polishMode: .light,
                outputMode: .copyToClipboard,
                saveToInbox: true,
                silenceTimeout: 3.0,
                enableSilenceDetection: true
            )
        )

        XCTAssertEqual(voiceService.stopRecordingCalls, 1)
        XCTAssertEqual(outcome.deliveryState, .copiedAndSavedToInbox)
        XCTAssertEqual(outcome.rawText, rawText)
        XCTAssertEqual(outcome.polishedText, polishedText)
    }

    func testRealtimeTranscriptionCallbackReceivesUpdates() async throws {
        let sourceItemId = UUID().uuidString
        let realtimeText = "实时转写的结果"

        let voiceService = VoiceServiceStub(stopRecordingResult: sourceItemId, polishedTextProvider: { $0 + "。" })
        voiceService.realtimeFinalText = realtimeText

        let storage = SayInputSourceStoreStub(items: [
            sourceItemId: SourceItem(
                id: sourceItemId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: realtimeText,
                transcript: realtimeText
            )
        ])
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = false
                snapshot.isFocusedTarget = false
                snapshot.source = "none"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        let realtimeCallbacks = LockedStringRecorder()
        coordinator.onRealtimeTranscriptUpdate = { text in
            realtimeCallbacks.append(text)
        }

        try await coordinator.startRecording()
        XCTAssertTrue(voiceService.realtimeStarted)
        XCTAssertEqual(realtimeCallbacks.values, ["实时转写的结果"])

        let outcome = try await coordinator.stopRecording(
            configuration: SayInputConfiguration(
                autoPolish: false,
                polishMode: .none,
                outputMode: .copyToClipboard,
                saveToInbox: true
            )
        )

        XCTAssertTrue(voiceService.realtimeStopped)
        XCTAssertEqual(outcome.rawText, realtimeText)
        XCTAssertEqual(clipboard.writtenStrings, [realtimeText])
    }

    func testUnsupportedRealtimeEngineFallsBackToBatch() async throws {
        let sourceItemId = UUID().uuidString
        let rawText = "批量转写结果"
        let polishedText = "批量转写结果。"

        let voiceService = VoiceServiceStub(stopRecordingResult: sourceItemId, polishedText: polishedText)
        voiceService.realtimeShouldThrow = true

        let storage = SayInputSourceStoreStub(items: [
            sourceItemId: SourceItem(
                id: sourceItemId,
                type: .audio,
                source: .voice,
                status: .captured,
                previewText: rawText,
                transcript: rawText
            )
        ])
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = false
                snapshot.isFocusedTarget = false
                snapshot.source = "none"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        try await coordinator.startRecording()
        XCTAssertFalse(voiceService.realtimeStarted)

        let outcome = try await coordinator.stopRecording(
            configuration: SayInputConfiguration(
                autoPolish: true,
                polishMode: .light,
                outputMode: .copyToClipboard,
                saveToInbox: true
            )
        )

        XCTAssertEqual(outcome.rawText, rawText)
        XCTAssertEqual(outcome.polishedText, polishedText)
    }

    func testLastRealtimeResultSkipsSourceItemPolling() async throws {
        let sourceItemId = UUID().uuidString
        let realtimeText = "实时结果优先使用"

        let voiceService = VoiceServiceStub(stopRecordingResult: sourceItemId, polishedTextProvider: { $0 + "。" })
        voiceService.realtimeFinalText = realtimeText

        let storage = SayInputSourceStoreStub()
        let textInjector = SayInputTextInjectorStub(
            selectionSnapshot: {
                var snapshot = TextSelectionSnapshot()
                snapshot.isEditable = false
                snapshot.isFocusedTarget = false
                snapshot.source = "none"
                return snapshot
            }()
        )
        let clipboard = SayInputClipboardStub()

        let coordinator = SayInputCoordinator(
            voiceService: voiceService,
            sourceStore: storage,
            textInjector: textInjector,
            clipboard: clipboard
        )

        try await coordinator.startRecording()

        let outcome = try await coordinator.stopRecording(
            configuration: SayInputConfiguration(
                autoPolish: false,
                polishMode: .none,
                outputMode: .copyToClipboard,
                saveToInbox: false
            )
        )

        XCTAssertEqual(outcome.rawText, realtimeText)
        XCTAssertEqual(outcome.polishedText, realtimeText)
    }
}

private final class LockedStringRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: String) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}

private final class VoiceServiceStub: VoiceServiceProtocol, @unchecked Sendable {
    private var stopRecordingResults: [String]
    private let polishedTextProvider: (String) -> String
    private let translatedTextProvider: (String) -> String
    private(set) var startRecordingCalls = 0
    private(set) var stopRecordingCalls = 0
    private(set) var polishRequests: [String] = []
    private(set) var translationRequests: [String] = []
    var streamChunks: [String] = []
    private(set) var status: RecordingStatus = .idle

    var realtimeFinalText: String?
    var realtimeShouldThrow: Bool = false
    private(set) var realtimeStarted: Bool = false
    private(set) var realtimeStopped: Bool = false
    private var realtimeUpdateHandler: (@Sendable (TranscriptionSnapshot) -> Void)?

    init(stopRecordingResult: String, polishedText: String) {
        self.stopRecordingResults = [stopRecordingResult]
        self.polishedTextProvider = { _ in polishedText }
        self.translatedTextProvider = { _ in polishedText }
    }

    init(stopRecordingResult: String, polishedTextProvider: @escaping (String) -> String) {
        self.stopRecordingResults = [stopRecordingResult]
        self.polishedTextProvider = polishedTextProvider
        self.translatedTextProvider = polishedTextProvider
    }

    init(stopRecordingResult: String, translatedText: String) {
        self.stopRecordingResults = [stopRecordingResult]
        self.polishedTextProvider = { $0 }
        self.translatedTextProvider = { _ in translatedText }
    }

    func enqueueStopRecordingResult(_ value: String) {
        stopRecordingResults.append(value)
    }

    func startRecording() async throws {
        startRecordingCalls += 1
        status = .recording
    }

    func stopRecording() async throws -> String {
        stopRecordingCalls += 1
        status = .processing
        if stopRecordingResults.isEmpty {
            return UUID().uuidString
        }
        return stopRecordingResults.removeFirst()
    }

    func setStatusHandler(_ handler: @escaping @Sendable (RecordingStatus) -> Void) async {}

    func transcribe(audioURL: URL) async throws -> String {
        ""
    }

    func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String {
        polishRequests.append(text)
        return polishedTextProvider(text)
    }

    func polishTranscriptStream(
        _ text: String,
        mode: VoicePolishMode,
        hotwords: [String],
        customSystemPrompt: String?,
        contextInfo: String?,
        language: String,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        polishRequests.append(text)
        if streamChunks.isEmpty {
            let final = polishedTextProvider(text)
            await onChunk(final)
            return final
        }

        for chunk in streamChunks {
            await onChunk(chunk)
        }
        return streamChunks.joined()
    }

    func translateTranscript(
        _ text: String,
        targetLanguage: String,
        contextInfo: String?
    ) async throws -> String {
        translationRequests.append(text)
        return translatedTextProvider(text)
    }

    func translateTranscriptStream(
        _ text: String,
        targetLanguage: String,
        contextInfo: String?,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        translationRequests.append(text)
        let translated = translatedTextProvider(text)
        await onChunk(translated)
        return translated
    }

    func getRecordingStatus() async -> RecordingStatus {
        status
    }

    func startRealtimeTranscription(onUpdate: @escaping @Sendable (TranscriptionSnapshot) -> Void) async throws {
        if realtimeShouldThrow {
            throw NSError(domain: "VoiceService", code: -1)
        }
        realtimeStarted = true
        realtimeUpdateHandler = onUpdate
        if let text = realtimeFinalText {
            onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
        }
    }

    func stopRealtimeTranscription() async throws -> String {
        realtimeStopped = true
        return realtimeFinalText ?? ""
    }

    var isRealtimeActive: Bool {
        get async { realtimeStarted && realtimeStopped == false }
    }
}

private final class SayInputTextInjectorStub: TextInjector, @unchecked Sendable {
    let selectionSnapshot: TextSelectionSnapshot
    private(set) var insertedTexts: [String] = []
    private(set) var replacedTexts: [String] = []

    init(selectionSnapshot: TextSelectionSnapshot) {
        self.selectionSnapshot = selectionSnapshot
    }

    func getSelectionSnapshot() async -> TextSelectionSnapshot {
        selectionSnapshot
    }

    func currentInputTextSnapshot() async -> CurrentInputTextSnapshot {
        var snapshot = CurrentInputTextSnapshot()
        snapshot.isEditable = selectionSnapshot.isEditable
        snapshot.isFocusedTarget = selectionSnapshot.isFocusedTarget
        snapshot.role = selectionSnapshot.role
        return snapshot
    }

    func currentInputText() async -> String? {
        nil
    }

    func insert(text: String) throws {
        insertedTexts.append(text)
    }

    func replaceSelection(text: String) throws {
        replacedTexts.append(text)
    }
}

private final class SayInputClipboardStub: SayInputClipboard, @unchecked Sendable {
    private(set) var writtenStrings: [String] = []

    func setString(_ value: String) {
        writtenStrings.append(value)
    }

    func string() -> String? {
        writtenStrings.last
    }

    func clear() {
        writtenStrings.removeAll()
    }
}

private final class SayInputSourceStoreStub: SayInputSourceItemStore, @unchecked Sendable {
    private var items: [String: SourceItem]

    init(items: [String: SourceItem] = [:]) {
        self.items = items
    }

    func getSourceItem(id: String) async throws -> SourceItem? {
        items[id]
    }

    func updateSourceItem(_ item: SourceItem) async throws {
        items[item.id] = item
    }

    func deleteSourceItem(id: String) async throws {
        items.removeValue(forKey: id)
    }
}

private actor StreamedUpdatesBox {
    private var storage: [String] = []

    func append(_ value: String) {
        storage.append(value)
    }

    func snapshot() -> [String] {
        storage
    }
}
