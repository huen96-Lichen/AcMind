import XCTest
import AppKit
@testable import AcMindKit

final class CaptureServiceScreenshotPolicyTests: XCTestCase {
    func testPrepareCapturedScreenshotSkipsRedactorWhenDisabled() async {
        let redactor = ScreenshotRedactorStub()
        let service = CaptureService(
            storage: CapturePolicyStorageStub(),
            assetStore: AssetStore(database: Database.shared),
            screenshotRedactor: redactor
        )
        let image = NSImage(size: NSSize(width: 12, height: 12))
        let preferences = SettingsLocalPreferences(captureAutoRedactionEnabled: false)

        let result = await service.prepareCapturedScreenshot(image, preferences: preferences)

        XCTAssertTrue(result === image)
        XCTAssertEqual(redactor.callCount, 0)
    }

    func testPrepareCapturedScreenshotInvokesRedactorWhenEnabled() async {
        let redactor = ScreenshotRedactorStub()
        let service = CaptureService(
            storage: CapturePolicyStorageStub(),
            assetStore: AssetStore(database: Database.shared),
            screenshotRedactor: redactor
        )
        let image = NSImage(size: NSSize(width: 12, height: 12))
        let preferences = SettingsLocalPreferences(
            captureAutoRedactionEnabled: true,
            captureCensorModeRawValue: CensorMode.blur.rawValue
        )

        let result = await service.prepareCapturedScreenshot(image, preferences: preferences)

        XCTAssertEqual(redactor.callCount, 1)
        XCTAssertEqual(redactor.lastMode, .blur)
        XCTAssertTrue(result !== image)
    }
}

private final class ScreenshotRedactorStub: ScreenshotRedacting, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastMode: CensorMode?

    func redact(_ image: NSImage, mode: CensorMode) async -> NSImage {
        callCount += 1
        lastMode = mode
        return NSImage(size: image.size)
    }
}

private final class CapturePolicyStorageStub: StorageServiceProtocol, @unchecked Sendable {
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
