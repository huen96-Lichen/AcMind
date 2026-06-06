import XCTest
@testable import AcMindKit

final class DistillServiceTests: XCTestCase {

    func testDistillText() async throws {
        let storage = DistillStorageStub()
        let aiRuntime = DistillAIRuntimeMock(response: ChatResponse(
            content: """
            ```json
            {
                "title": "测试标题",
                "summary": "测试摘要",
                "category": "技术",
                "tags": ["test"],
                "documentType": "笔记",
                "contentMarkdown": "详细内容",
                "valueScore": 0.85
            }
            ```
            """,
            model: "mock-model",
            providerId: "mock-provider"
        ))

        let service = DistillService(aiRuntime: aiRuntime, storage: storage)
        let sourceItem = SourceItem(
            id: UUID().uuidString,
            type: .text,
            source: .manual,
            status: .captured,
            title: "测试输入",
            previewText: "这是需要蒸馏的内容"
        )

        let note = try await service.distill(sourceItem: sourceItem)

        XCTAssertEqual(note.title, "测试标题")
        XCTAssertEqual(note.summary, "测试摘要")
        XCTAssertEqual(note.category, "技术")
        XCTAssertEqual(note.tags, ["test"])
        XCTAssertEqual(note.sourceItemId, sourceItem.id)
        XCTAssertEqual(note.reviewStatus, .pending)
        XCTAssertEqual(storage.savedNotes.count, 1)
        XCTAssertEqual(storage.savedNotes.first?.id, note.id)
    }

    func testDistillWithEmptyInput() async throws {
        let storage = DistillStorageStub()
        let aiRuntime = DistillAIRuntimeMock(response: ChatResponse(
            content: "(空)",
            model: "mock-model",
            providerId: "mock-provider"
        ))

        let service = DistillService(aiRuntime: aiRuntime, storage: storage)
        let sourceItem = SourceItem(
            id: UUID().uuidString,
            type: .text,
            source: .manual,
            status: .inbox
        )

        let note = try await service.distill(sourceItem: sourceItem)

        XCTAssertNotNil(note.id)
        XCTAssertEqual(note.sourceItemId, sourceItem.id)
        XCTAssertEqual(note.reviewStatus, .pending)
        XCTAssertEqual(storage.savedNotes.count, 1)
    }
}

private final class DistillAIRuntimeMock: AIRuntimeProtocol, @unchecked Sendable {
    var response: ChatResponse
    private(set) var lastMessages: [ChatMessage]?

    init(response: ChatResponse = ChatResponse(content: "mock-response")) {
        self.response = response
    }

    func listProviders() async -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}
    func setDefaultProvider(id: String) throws {}
    func healthCheck(providerId: String) async throws -> Bool { true }
    func listModels(providerId: String) async throws -> [String] { [] }
    func listJobs() async throws -> [ProcessJob] { [] }
    func cancelJob(id: String) async throws {}
    func runDistillation(sourceItem: SourceItem) async throws -> DistilledNote { throw AIError.noProvider }

    func chat(messages: [ChatMessage]) async throws -> ChatResponse {
        lastMessages = messages
        return response
    }

    func chat(messages: [ChatMessage], providerId: String, model: String?) async throws -> ChatResponse {
        lastMessages = messages
        return response
    }

    func chatStream(messages: [ChatMessage]) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(self.response)
            continuation.finish()
        }
    }
}

private final class DistillStorageStub: StorageServiceProtocol, @unchecked Sendable {
    private(set) var savedNotes: [DistilledNote] = []

    func insertSourceItem(_ item: SourceItem) async throws {}
    func getSourceItem(id: String) async throws -> SourceItem? { nil }
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

    func insertDistilledNote(_ note: DistilledNote) async throws { savedNotes.append(note) }
    func updateDistilledNote(_ note: DistilledNote) async throws {}
    func deleteDistilledNote(id: String) async throws {}
    func listDistilledNotes() async throws -> [DistilledNote] { savedNotes }

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
    func setSetting(key: String, value: String) async throws {}

    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}
