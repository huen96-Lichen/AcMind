import XCTest
@testable import AcMindKit

@MainActor
final class AgentMemoryServiceTests: XCTestCase {
    var storage: MockMemoryStorage!
    var service: AgentMemoryService!

    override func setUp() async throws {
        try await super.setUp()
        storage = MockMemoryStorage()
        service = AgentMemoryService(storage: storage)
    }

    override func tearDown() async throws {
        service = nil
        storage = nil
        try await super.tearDown()
    }

    func testSaveAndGetMemory() async throws {
        let id = "mem-\(UUID().uuidString)"
        let memory = AgentMemory(
            id: id,
            type: .preference,
            key: "theme",
            value: "dark",
            tags: ["ui"],
            relevanceScore: 0.9
        )

        try await service.saveMemory(memory)
        let retrieved = try await service.getMemory(id: id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, id)
        XCTAssertEqual(retrieved?.type, .preference)
        XCTAssertEqual(retrieved?.key, "theme")
        XCTAssertEqual(retrieved?.value, "dark")
        XCTAssertEqual(retrieved?.tags, ["ui"])
        XCTAssertEqual(retrieved!.relevanceScore, 0.9, accuracy: 0.001)
    }

    func testListMemoriesWithFilter() async throws {
        let id1 = "mem-\(UUID().uuidString)"
        let id2 = "mem-\(UUID().uuidString)"
        let id3 = "mem-\(UUID().uuidString)"

        try await service.saveMemory(AgentMemory(id: id1, type: .preference, key: "lang", value: "zh"))
        try await service.saveMemory(AgentMemory(id: id2, type: .project, key: "proj", value: "AcMind"))
        try await service.saveMemory(AgentMemory(id: id3, type: .task, key: "task1", value: "build"))

        let prefOnly = try await service.listMemories(filter: MemoryFilter(types: [.preference]))
        XCTAssertTrue(prefOnly.allSatisfy { $0.type == .preference })
        XCTAssertTrue(prefOnly.contains { $0.id == id1 })
        XCTAssertFalse(prefOnly.contains { $0.id == id2 })
    }

    func testGetMemoryContext() async throws {
        try await service.saveMemory(AgentMemory(type: .preference, key: "theme", value: "dark"))
        try await service.saveMemory(AgentMemory(type: .project, key: "proj", value: "AcMind"))
        try await service.saveMemory(AgentMemory(type: .task, key: "task1", value: "build"))

        let context = try await service.getMemoryContext(types: nil, query: nil)

        XCTAssertFalse(context.isEmpty)
        XCTAssertFalse(context.preferenceMemories.isEmpty)
        XCTAssertFalse(context.projectMemories.isEmpty)
        XCTAssertFalse(context.taskMemories.isEmpty)

        let prompt = context.toPromptString()
        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains("dark"))
        XCTAssertTrue(prompt.contains("AcMind"))
    }

    func testRecordAccess() async throws {
        let id = "mem-\(UUID().uuidString)"
        let memory = AgentMemory(
            id: id,
            type: .preference,
            key: "theme",
            value: "dark",
            accessCount: 0
        )

        try await service.saveMemory(memory)

        let before = try await service.getMemory(id: id)
        XCTAssertEqual(before?.accessCount, 0)

        try await service.recordAccess(memoryId: id)

        let after = try await service.getMemory(id: id)
        XCTAssertEqual(after?.accessCount, 1)

        try await service.recordAccess(memoryId: id)
        let afterTwice = try await service.getMemory(id: id)
        XCTAssertEqual(afterTwice?.accessCount, 2)
    }
}

final class MockMemoryStorage: StorageServiceProtocol, @unchecked Sendable {
    private var settings: [String: String] = [:]
    private var memoryIds: [String] = []

    func setSetting(key: String, value: String) async throws {
        settings[key] = value
        if key.hasPrefix("memory_") && !key.contains("index") && !value.isEmpty {
            let id = String(key.dropFirst("memory_".count))
            if !memoryIds.contains(id) {
                memoryIds.append(id)
            }
        }
    }

    func getSetting(key: String) async throws -> String? {
        if key.hasPrefix("memory_index_") {
            let indexStr = String(key.dropFirst("memory_index_".count))
            guard let index = Int(indexStr), index == 0 else { return nil }
            return memoryIds.joined(separator: ",")
        }
        return settings[key]
    }

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
    func insertScheduledAgentTask(_ task: ScheduledAgentTask) async throws {}
    func getScheduledAgentTask(id: String) async throws -> ScheduledAgentTask? { nil }
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask] { [] }
    func deleteScheduledAgentTask(id: String) async throws {}
    func listProviders() async throws -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}
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
