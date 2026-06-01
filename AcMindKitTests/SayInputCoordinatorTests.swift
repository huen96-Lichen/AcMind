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
        let polishedText = "你好！。"

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
}

private final class VoiceServiceStub: VoiceServiceProtocol, @unchecked Sendable {
    private var stopRecordingResults: [String]
    private let polishedTextProvider: (String) -> String
    private(set) var startRecordingCalls = 0
    private(set) var stopRecordingCalls = 0
    private(set) var polishRequests: [String] = []
    private(set) var status: RecordingStatus = .idle

    init(stopRecordingResult: String, polishedText: String) {
        self.stopRecordingResults = [stopRecordingResult]
        self.polishedTextProvider = { _ in polishedText }
    }

    init(stopRecordingResult: String, polishedTextProvider: @escaping (String) -> String) {
        self.stopRecordingResults = [stopRecordingResult]
        self.polishedTextProvider = polishedTextProvider
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

    func transcribe(audioURL: URL) async throws -> String {
        ""
    }

    func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String {
        polishRequests.append(text)
        return polishedTextProvider(text)
    }

    func getRecordingStatus() async -> RecordingStatus {
        status
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
