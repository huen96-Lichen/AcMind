import XCTest
@testable import AcMindKit

final class CaptureServiceVoiceTests: XCTestCase {
    func testCaptureFromVoiceWaitsForFinishNotification() async throws {
        let sourceItemId = UUID().uuidString
        let storage = CaptureVoiceStorageStub(sourceItem: SourceItem(
            id: sourceItemId,
            type: .audio,
            source: .voice,
            status: .captured,
            title: "语音记录",
            previewText: "语音记录",
            assetFileIds: []
        ))
        let voiceService = CaptureVoiceServiceStub(sourceItemId: sourceItemId)
        let captureService = CaptureService(
            storage: storage,
            assetStore: AssetStore(database: Database.shared),
            voiceService: voiceService
        )

        let task = Task {
            try await captureService.captureFromVoice()
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(voiceService.didStartRecording)
        XCTAssertFalse(voiceService.didStopRecording)

        NotificationCenter.default.post(name: .companionVoiceFinishRequested, object: nil)

        let result = try await task.value
        XCTAssertEqual(result.sourceItem.id, sourceItemId)
        XCTAssertTrue(voiceService.didStopRecording)
        XCTAssertEqual(storage.getSourceItemCallCount, 1)
    }
}

private final class CaptureVoiceStorageStub: StorageServiceProtocol, @unchecked Sendable {
    private let sourceItem: SourceItem
    private(set) var getSourceItemCallCount = 0

    init(sourceItem: SourceItem) {
        self.sourceItem = sourceItem
    }

    func insertSourceItem(_ item: SourceItem) async throws {}
    func getSourceItem(id: String) async throws -> SourceItem? {
        getSourceItemCallCount += 1
        return sourceItem
    }
    func listSourceItems(filter: SourceItemFilter?) async throws -> [SourceItem] { [] }
    func updateSourceItem(_ item: SourceItem) async throws {}
    func deleteSourceItem(id: String) async throws {}

    func insertChatSession(_ session: ChatSession) async throws {}
    func getChatSession(id: String) async throws -> ChatSession? { nil }
    func listChatSessions(status: String?) async throws -> [ChatSession] { [] }
    func updateChatSession(_ session: ChatSession) async throws {}
    func deleteChatSession(id: String) async throws {}
    func insertChatMessage(_ message: ChatMessage) async throws {}
    func listChatMessages(sessionId: String) async throws -> [ChatMessage] { [] }

    func insertDistilledNote(_ note: DistilledNote) async throws {}
    func updateDistilledNote(_ note: DistilledNote) async throws {}
    func deleteDistilledNote(id: String) async throws {}
    func listDistilledNotes() async throws -> [DistilledNote] { [] }

    func insertExportRecord(_ record: ExportRecord) async throws {}
    func listExportRecords() async throws -> [ExportRecord] { [] }

    func insertKnowledgeCard(_ card: KnowledgeCard) async throws {}
    func updateKnowledgeCard(_ card: KnowledgeCard) async throws {}
    func listKnowledgeCards(status: KnowledgeCardStatus?) async throws -> [KnowledgeCard] { [] }

    func insertKnowledgeEdge(_ edge: KnowledgeEdge) async throws {}
    func listKnowledgeEdges(fromCardId: String?, toCardId: String?) async throws -> [KnowledgeEdge] { [] }
    func deleteKnowledgeEdge(id: String) async throws {}

    func insertClipboardItem(_ item: ClipboardItem) async throws {}
    func listClipboardItems(limit: Int?) async throws -> [ClipboardItem] { [] }
    func updateClipboardItem(_ item: ClipboardItem) async throws {}
    func deleteClipboardItem(id: String) async throws {}

    func listProviders() async -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}

    func getSetting(key: String) async throws -> String? { nil }
    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }
    func setSetting(key: String, value: String) async throws {}

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}

private final class CaptureVoiceServiceStub: VoiceServiceProtocol, @unchecked Sendable {
    let sourceItemId: String
    private(set) var didStartRecording = false
    private(set) var didStopRecording = false

    init(sourceItemId: String) {
        self.sourceItemId = sourceItemId
    }

    func startRecording() async throws {
        didStartRecording = true
    }

    func stopRecording() async throws -> String {
        didStopRecording = true
        return sourceItemId
    }

    func transcribe(audioURL: URL) async throws -> String { "" }
    func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String { text }
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?) async throws -> String { text }
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?, language: String) async throws -> String { text }
    func getRecordingStatus() async -> RecordingStatus { .idle }
}
