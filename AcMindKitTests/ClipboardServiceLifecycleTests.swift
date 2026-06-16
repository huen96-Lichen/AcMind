import XCTest
@testable import AcMindKit

@MainActor
final class ClipboardServiceLifecycleTests: XCTestCase {
    func testPauseAndResumeWatchingToggleMonitoringState() async throws {
        let storage = ClipboardStorageMock()
        let service = ClipboardService(storage: storage, assetStore: AssetStore(), settingsDefaults: UserDefaults(suiteName: "ClipboardServiceLifecycleTests.\(UUID().uuidString)")!)

        await service.startWatching()
        XCTAssertEqual(service.monitoringState(), .active)
        XCTAssertTrue(service.isWatchingActiveForTesting)
        XCTAssertFalse(service.isWatchingPausedForTesting)

        await service.pauseWatching()
        XCTAssertEqual(service.monitoringState(), .paused)
        XCTAssertTrue(service.isWatchingActiveForTesting)
        XCTAssertTrue(service.isWatchingPausedForTesting)

        await service.resumeWatching()
        XCTAssertEqual(service.monitoringState(), .active)
        XCTAssertTrue(service.isWatchingActiveForTesting)
        XCTAssertFalse(service.isWatchingPausedForTesting)

        await service.stopWatching()
        XCTAssertEqual(service.monitoringState(), .stopped)
        XCTAssertFalse(service.isWatchingActiveForTesting)
        XCTAssertFalse(service.isWatchingPausedForTesting)
    }

    func testClipboardStatsAreAvailableThroughProtocol() async throws {
        let items = [
            ClipboardItem(type: .text, content: "Hello", textContent: "Hello"),
            ClipboardItem(type: .image, content: "asset-1", textContent: "[图片] shot.png", isPinned: true),
            ClipboardItem(type: .url, content: "https://example.com", textContent: "https://example.com")
        ]
        let storage = ClipboardStorageMock(clipboardItems: items)
        let service: ClipboardServiceProtocol = ClipboardService(
            storage: storage,
            assetStore: AssetStore(),
            settingsDefaults: UserDefaults(suiteName: "ClipboardServiceLifecycleTests.\(UUID().uuidString)")!
        )

        await service.startWatching()
        let stats = await service.getStats()

        XCTAssertEqual(stats.totalCount, 3)
        XCTAssertEqual(stats.pinnedCount, 1)
        XCTAssertEqual(stats.textCount, 1)
        XCTAssertEqual(stats.imageCount, 1)
        XCTAssertEqual(stats.fileCount, 0)
        XCTAssertEqual(stats.urlCount, 1)
    }

    func testCopyTextIsAvailableThroughProtocol() async throws {
        let storage = ClipboardStorageMock()
        let service: ClipboardServiceProtocol = ClipboardService(
            storage: storage,
            assetStore: AssetStore(),
            settingsDefaults: UserDefaults(suiteName: "ClipboardServiceLifecycleTests.\(UUID().uuidString)")!
        )

        await service.copyText("Protocol route")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Protocol route")
    }
}

private final class ClipboardStorageMock: StorageServiceProtocol {
    let clipboardItems: [ClipboardItem]

    init(clipboardItems: [ClipboardItem] = []) {
        self.clipboardItems = clipboardItems
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
    func listClipboardItems(limit: Int?) async throws -> [ClipboardItem] { clipboardItems }
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

    func getSetting(key: String) async throws -> String? { nil }
    func setSetting(key: String, value: String) async throws {}

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }

    func getDatabasePath() -> String { "" }
    func getDatabaseVersion() async throws -> Int { 0 }
}
