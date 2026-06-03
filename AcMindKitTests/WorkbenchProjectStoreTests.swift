import XCTest
@testable import AcMindKit

@MainActor
final class WorkbenchProjectStoreTests: XCTestCase {

    func testLoadProjectsReturnsEmptyWhenUnset() async throws {
        let storage = WorkbenchProjectStorageStub()

        let projects = try await WorkbenchProjectStore.loadProjects(from: storage)
        let selectedProjectID = try await WorkbenchProjectStore.loadSelectedProjectID(from: storage)

        XCTAssertTrue(projects.isEmpty)
        XCTAssertNil(selectedProjectID)
    }

    func testProjectsRoundTripThroughStorage() async throws {
        let storage = WorkbenchProjectStorageStub()
        let snapshots = [
            WorkbenchProjectSnapshot(
                id: "project-a",
                name: "项目 A",
                noteCount: 2,
                lastUpdated: Date(timeIntervalSince1970: 1_700_300_000),
                sortOrder: 0
            ),
            WorkbenchProjectSnapshot(
                id: "project-b",
                name: "项目 B",
                noteCount: 1,
                lastUpdated: Date(timeIntervalSince1970: 1_700_300_100),
                sortOrder: 1
            )
        ]

        try await WorkbenchProjectStore.saveProjects(snapshots, to: storage)
        try await WorkbenchProjectStore.saveSelectedProjectID("project-b", to: storage)

        let loadedProjects = try await WorkbenchProjectStore.loadProjects(from: storage)
        let selectedProjectID = try await WorkbenchProjectStore.loadSelectedProjectID(from: storage)

        XCTAssertEqual(loadedProjects, snapshots)
        XCTAssertEqual(selectedProjectID, "project-b")
    }
}

private final class WorkbenchProjectStorageStub: StorageServiceProtocol, @unchecked Sendable {
    private var settings: [String: String] = [:]

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

    func listProviders() async -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}

    func getSetting(key: String) async throws -> String? {
        settings[key]
    }

    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }
    func setSetting(key: String, value: String) async throws {
        settings[key] = value
    }

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}
