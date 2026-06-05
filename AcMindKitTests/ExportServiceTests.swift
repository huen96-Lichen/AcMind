import XCTest
@testable import AcMindKit

final class ExportServiceTests: XCTestCase {

    func testExportToMarkdown() async throws {
        let storage = ExportTestStorageStub()
        let service = ExportService(storage: storage)

        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind-ExportServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let note = DistilledNote(
            id: UUID().uuidString,
            sourceItemId: UUID().uuidString,
            title: "Markdown 导出测试",
            summary: "验证导出内容",
            category: "技术",
            tags: ["swift", "test"],
            documentType: "笔记",
            contentMarkdown: "## 正文\n\n这是导出的正文内容。",
            valueScore: 0.9,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let config = ExportConfig(
            target: .markdown,
            vaultPath: vaultURL.path,
            defaultFolder: "Export",
            pathRule: .flat,
            conflictStrategy: .rename,
            autoFrontmatter: true,
            frontmatterTemplate: [:]
        )

        let record = try await service.export(note: note, config: config)

        let exportedURL = vaultURL.appendingPathComponent(record.relativeFilePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))

        let content = try String(contentsOf: exportedURL, encoding: .utf8)
        XCTAssertTrue(content.contains("# Markdown 导出测试"))
        XCTAssertTrue(content.contains("验证导出内容"))
        XCTAssertTrue(content.contains("## 正文"))
        XCTAssertTrue(content.contains("这是导出的正文内容"))
        XCTAssertTrue(content.contains("---"))
        XCTAssertEqual(record.status, .success)
        XCTAssertEqual(record.sourceItemId, note.sourceItemId)
    }

    func testExportToJSON() async throws {
        let note = DistilledNote(
            id: UUID().uuidString,
            sourceItemId: UUID().uuidString,
            title: "JSON 编码测试",
            summary: "验证 JSON 序列化",
            category: "测试",
            tags: ["json"],
            documentType: "笔记",
            contentMarkdown: "正文",
            valueScore: 0.75,
            createdAt: Date(timeIntervalSince1970: 1_700_100_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_100_000)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(note)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DistilledNote.self, from: data)

        XCTAssertEqual(decoded.id, note.id)
        XCTAssertEqual(decoded.title, note.title)
        XCTAssertEqual(decoded.summary, note.summary)
        XCTAssertEqual(decoded.category, note.category)
        XCTAssertEqual(decoded.tags, note.tags)
        XCTAssertEqual(decoded.contentMarkdown, note.contentMarkdown)
        XCTAssertEqual(decoded.valueScore, note.valueScore)
        XCTAssertEqual(decoded.sourceItemId, note.sourceItemId)

        let record = ExportRecord(
            sourceItemId: note.sourceItemId,
            distilledOutputId: note.id,
            vaultPath: "/tmp/vault",
            relativeFilePath: "Export/JSON测试.md",
            status: .success
        )
        let recordData = try encoder.encode(record)
        let decodedRecord = try decoder.decode(ExportRecord.self, from: recordData)

        XCTAssertEqual(decodedRecord.id, record.id)
        XCTAssertEqual(decodedRecord.sourceItemId, record.sourceItemId)
        XCTAssertEqual(decodedRecord.vaultPath, "/tmp/vault")
        XCTAssertEqual(decodedRecord.relativeFilePath, "Export/JSON测试.md")
        XCTAssertEqual(decodedRecord.status, .success)
    }
}

private final class ExportTestStorageStub: StorageServiceProtocol, @unchecked Sendable {
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
