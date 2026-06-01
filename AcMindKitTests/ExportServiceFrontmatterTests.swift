import XCTest
@testable import AcMindKit

@MainActor
final class ExportServiceFrontmatterTests: XCTestCase {

    func testExportAppliesFrontmatterTemplateAndAutoFrontmatter() async throws {
        let storage = FrontmatterStorageStub()
        let service = ExportService(storage: storage)

        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind-ExportService-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let note = DistilledNote(
            id: UUID().uuidString,
            sourceItemId: UUID().uuidString,
            title: "导出测试",
            summary: "验证模板是否注入",
            category: "inbox",
            tags: ["acmind", "export"],
            documentType: "note",
            contentMarkdown: "正文内容",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let config = ExportConfig(
            target: .markdown,
            vaultPath: vaultURL.path,
            defaultFolder: "Inbox",
            pathRule: .flat,
            conflictStrategy: .rename,
            autoFrontmatter: true,
            frontmatterTemplate: [
                "vault_tag": "AcMind",
                "review_status": "approved"
            ]
        )

        let record = try await service.export(note: note, config: config)
        let exportedURL = vaultURL.appendingPathComponent(record.relativeFilePath)
        let content = try String(contentsOf: exportedURL, encoding: .utf8)

        XCTAssertTrue(content.contains("vault_tag: AcMind"))
        XCTAssertTrue(content.contains("review_status: approved"))
        XCTAssertTrue(content.contains("# 导出测试"))
        XCTAssertTrue(content.contains("正文内容"))
        XCTAssertEqual(record.frontmatter["vault_tag"], "AcMind")
        XCTAssertEqual(record.frontmatter["review_status"], "approved")
    }

    func testExportCanDisableFrontmatter() async throws {
        let storage = FrontmatterStorageStub()
        let service = ExportService(storage: storage)

        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind-ExportService-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let note = DistilledNote(
            id: UUID().uuidString,
            sourceItemId: UUID().uuidString,
            title: "无 Frontmatter",
            summary: nil,
            category: nil,
            tags: [],
            contentMarkdown: "只有正文",
            createdAt: Date(timeIntervalSince1970: 1_700_100_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_100_100)
        )

        let config = ExportConfig(
            target: .markdown,
            vaultPath: vaultURL.path,
            defaultFolder: "Inbox",
            pathRule: .flat,
            conflictStrategy: .rename,
            autoFrontmatter: false,
            frontmatterTemplate: ["vault_tag": "AcMind"]
        )

        let record = try await service.export(note: note, config: config)
        let exportedURL = vaultURL.appendingPathComponent(record.relativeFilePath)
        let content = try String(contentsOf: exportedURL, encoding: .utf8)

        XCTAssertFalse(content.contains("---"))
        XCTAssertTrue(content.contains("无 Frontmatter"))
        XCTAssertTrue(content.contains("只有正文"))
        XCTAssertEqual(record.frontmatter["vault_tag"], "AcMind")
    }

    func testPreviewUsesFrontmatterTemplate() async throws {
        let storage = FrontmatterStorageStub()
        let service = ExportService(storage: storage)

        let note = DistilledNote(
            id: UUID().uuidString,
            sourceItemId: UUID().uuidString,
            title: "预览测试",
            summary: nil,
            category: nil,
            tags: ["preview"],
            contentMarkdown: "预览正文",
            createdAt: Date(timeIntervalSince1970: 1_700_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_200_100)
        )

        let config = ExportConfig(
            target: .markdown,
            vaultPath: FileManager.default.temporaryDirectory.path,
            defaultFolder: "Inbox",
            pathRule: .flat,
            conflictStrategy: .rename,
            autoFrontmatter: true,
            frontmatterTemplate: [
                "vault_tag": "AcMind"
            ]
        )

        let preview = try await service.preview(note: note, config: config)

        XCTAssertTrue(preview.contains("vault_tag: AcMind"))
        XCTAssertTrue(preview.contains("预览正文"))
    }

    func testExportUsesPathRuleAndDefaultFolder() async throws {
        let storage = FrontmatterStorageStub()
        let service = ExportService(storage: storage)

        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind-ExportService-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let note = DistilledNote(
            id: UUID().uuidString,
            sourceItemId: UUID().uuidString,
            title: "路径规则测试",
            category: "capture",
            tags: [],
            documentType: "note",
            contentMarkdown: "路径内容",
            createdAt: Date(timeIntervalSince1970: 1_700_300_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_300_100)
        )
        let sourceItem = SourceItem(
            id: note.sourceItemId,
            type: .webpage,
            source: .webpage,
            status: .inbox,
            title: "网页来源",
            createdAt: Date(timeIntervalSince1970: 1_700_300_000)
        )

        let config = ExportConfig(
            target: .markdown,
            vaultPath: vaultURL.path,
            defaultFolder: "Project Inbox",
            pathRule: .sourceType,
            conflictStrategy: .rename,
            autoFrontmatter: true,
            frontmatterTemplate: [:]
        )

        let record = try await service.export(note: note, sourceItem: sourceItem, config: config)

        XCTAssertEqual(record.relativeFilePath, "Project Inbox/\(SourceType.webpage.displayName)/路径规则测试.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent(record.relativeFilePath).path))
    }

    func testConflictStrategiesAffectExportedFilePathAndContent() async throws {
        let storage = FrontmatterStorageStub()
        let service = ExportService(storage: storage)

        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind-ExportService-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let note = DistilledNote(
            id: UUID().uuidString,
            sourceItemId: UUID().uuidString,
            title: "冲突测试",
            contentMarkdown: "第一版内容",
            createdAt: Date(timeIntervalSince1970: 1_700_400_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_400_100)
        )

        let baseConfig = ExportConfig(
            target: .markdown,
            vaultPath: vaultURL.path,
            defaultFolder: "Inbox",
            pathRule: .flat,
            conflictStrategy: .rename,
            autoFrontmatter: false,
            frontmatterTemplate: [:]
        )

        let firstRecord = try await service.export(note: note, config: baseConfig)
        let firstPath = vaultURL.appendingPathComponent(firstRecord.relativeFilePath)

        try "existing file".write(to: firstPath, atomically: true, encoding: .utf8)

        let renamedRecord = try await service.export(note: note, config: baseConfig)
        XCTAssertNotEqual(renamedRecord.relativeFilePath, firstRecord.relativeFilePath)
        XCTAssertTrue(renamedRecord.relativeFilePath.contains("(1)"))

        let overwriteConfig = ExportConfig(
            target: .markdown,
            vaultPath: vaultURL.path,
            defaultFolder: "Inbox",
            pathRule: .flat,
            conflictStrategy: .overwrite,
            autoFrontmatter: false,
            frontmatterTemplate: [:]
        )

        _ = try await service.export(note: note, config: overwriteConfig)
        let overwrittenContent = try String(contentsOf: firstPath, encoding: .utf8)
        XCTAssertTrue(overwrittenContent.contains("第一版内容"))

        let skipConfig = ExportConfig(
            target: .markdown,
            vaultPath: vaultURL.path,
            defaultFolder: "Inbox",
            pathRule: .flat,
            conflictStrategy: .skip,
            autoFrontmatter: false,
            frontmatterTemplate: [:]
        )

        do {
            _ = try await service.export(note: note, config: skipConfig)
            XCTFail("Expected conflictSkipped error")
        } catch let exportError as ExportError {
            switch exportError {
            case .conflictSkipped:
                break
            default:
                XCTFail("Expected conflictSkipped error, got \(exportError)")
            }
        } catch {
            XCTFail("Expected ExportError, got \(error)")
        }
    }
}

private final class FrontmatterStorageStub: StorageServiceProtocol, @unchecked Sendable {
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

    func setSetting(key: String, value: String) async throws {
        settings[key] = value
    }

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}
