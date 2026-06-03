import XCTest
@testable import AcMindKit

final class CompanionConfigurationStoreTests: XCTestCase {
    func testCompanionConfigurationRoundTripThroughStorage() async throws {
        let storage = CompanionSettingsStorageStub()
        let expected = CompanionConfiguration(
            companionEnabled: false,
            capsuleEnabled: false,
            capsuleShowOnLaunch: false,
            capsulePosition: "topRight",
            capsuleExpandedByDefault: true,
            voiceEnabled: false,
            voiceShortcut: "⌥V",
            voiceOutputMode: "pasteboardFallback",
            voiceSaveToInbox: false,
            shortcutsEnabled: false,
            captureEnabled: false,
            captureScreenshotShortcut: "⌘⇧9",
            captureShortcut: "⌘⇧8",
            agentShortcut: "⌘9",
            scheduleShortcut: "⌘8",
            captureAutoSaveToInbox: false,
            captureTextEnabled: false,
            captureLinkEnabled: false,
            captureSaveDestinationIndex: 2
        )

        try await CompanionConfigurationStore.save(expected, to: storage)

        let loaded = await CompanionConfigurationStore.load(from: storage)

        XCTAssertEqual(loaded, expected)
        XCTAssertNotNil(storage.settings["companion_config"])
    }

    func testCompanionConfigurationDefaultsWhenMissing() async {
        let storage = CompanionSettingsStorageStub()

        let loaded = await CompanionConfigurationStore.load(from: storage)

        XCTAssertEqual(loaded, .default)
    }

    func testCompanionConfigurationDefaultsMissingGlobalFlagToEnabled() async throws {
        let storage = CompanionSettingsStorageStub()
        storage.settings["companion_config"] = """
        {
          "capsuleEnabled": false,
          "captureEnabled": false
        }
        """

        let loaded = await CompanionConfigurationStore.load(from: storage)

        XCTAssertTrue(loaded.companionEnabled)
        XCTAssertFalse(loaded.capsuleEnabled)
        XCTAssertFalse(loaded.captureEnabled)
    }
}

private final class CompanionSettingsStorageStub: StorageServiceProtocol, @unchecked Sendable {
    var settings: [String: String] = [:]

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

    func getSetting(key: String) async throws -> String? { settings[key] }
    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }
    func setSetting(key: String, value: String) async throws { settings[key] = value }

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}
