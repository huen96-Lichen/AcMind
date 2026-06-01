import XCTest
@testable import AcMindKit

@MainActor
final class PersonalDictionaryServiceTests: XCTestCase {

    func testAddWordAddsNewWord() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        try await service.addWord("AcMind", category: .product, priority: .high)

        let words = await service.getAllWords()
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words.first?.word, "AcMind")
        XCTAssertEqual(words.first?.category, .product)
        XCTAssertEqual(words.first?.priority, .high)
        XCTAssertEqual(words.first?.usageCount, 1)
    }

    func testAddDuplicateWordUpdatesUsageCount() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        try await service.addWord("AcMind", category: .product, priority: .high)
        try await service.addWord("AcMind", category: .product, priority: .high)
        try await service.addWord("acmind", category: .product, priority: .high)

        let words = await service.getAllWords()
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words.first?.usageCount, 3)
    }

    func testRemoveWord() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        try await service.addWord("AcMind")
        try await service.addWord("Xcode")
        try await service.removeWord("AcMind")

        let words = await service.getAllWords()
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words.first?.word, "Xcode")
    }

    func testGetHotwordsSortedByPriorityThenUsage() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        try await service.addWord("low", priority: .low)
        try await service.addWord("critical", priority: .critical)
        try await service.addWord("normalA", priority: .normal)
        try await service.addWord("normalB", priority: .normal)
        try await service.addWord("normalB", priority: .normal)

        let hotwords = await service.getHotwords(limit: 10)
        XCTAssertEqual(hotwords.first, "critical")
        XCTAssertEqual(hotwords[1], "normalB")
        XCTAssertEqual(hotwords[2], "normalA")
        XCTAssertEqual(hotwords.last, "low")
    }

    func testSearchWordsFindsMatches() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        try await service.addWord("Apple", category: .company)
        try await service.addWord("AcMind", category: .product)
        try await service.addWord("Xcode", category: .technical)

        let results = await service.searchWords(query: "ac")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(where: { $0.word == "AcMind" }))
    }

    func testImportAndExportRoundtrip() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        let wordsToImport = ["Swift", "Objective-C", "Rust"]
        try await service.importWords(wordsToImport, category: .technical)

        let exported = await service.exportWords()
        XCTAssertEqual(Set(exported), Set(wordsToImport))
    }

    func testSearchWordsByCategoryDisplayName() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        try await service.addWord("Apple", category: .company)
        try await service.addWord("Tim", category: .person)

        let results = await service.searchWords(query: "公司")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.word, "Apple")
    }

    func testClearDictionary() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        try await service.addWord("A")
        try await service.addWord("B")
        try await service.clearDictionary()

        let allWords = await service.getAllWords()
        let exportedWords = await service.exportWords()
        XCTAssertTrue(allWords.isEmpty)
        XCTAssertTrue(exportedWords.isEmpty)
    }

    func testGetHotwordsRespectsLimit() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        for i in 0..<10 {
            try await service.addWord("word\(i)")
        }

        let hotwords = await service.getHotwords(limit: 5)
        XCTAssertEqual(hotwords.count, 5)
    }

    func testAddWordTrimsWhitespace() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        try await service.addWord("  hello  ")

        let words = await service.getAllWords()
        XCTAssertEqual(words.first?.word, "hello")
    }

    func testRecordUsageIncrementsCount() async throws {
        let storage = InMemoryStorageStub()
        let service = PersonalDictionaryService(storage: storage)

        try await service.addWord("test")
        try await service.recordUsage("test")
        try await service.recordUsage("test")

        let words = await service.getAllWords()
        XCTAssertEqual(words.first?.usageCount, 3)
    }
}

private final class InMemoryStorageStub: StorageServiceProtocol, @unchecked Sendable {
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
