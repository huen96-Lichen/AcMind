import XCTest
@testable import AcMindKit

/// Tests for SQLite storage layer migration from JSON to GRDB
/// Validates: database initialization, CRUD operations, migration from legacy data
/// All test IDs use UUID() to ensure isolation under parallel testing.
@MainActor
final class StorageTests: XCTestCase {
    
    var storage: StorageService!
    var assetStore: AssetStore!
    
    override func setUp() async throws {
        try await super.setUp()
        storage = StorageService()
        assetStore = AssetStore()
        try await storage.setup()
        try await assetStore.setup()
    }
    
    override func tearDown() async throws {
        storage = nil
        assetStore = nil
        try await super.tearDown()
    }
    
    // MARK: - Database Initialization Tests
    
    func testDatabaseInitialization() async throws {
        let db = Database.shared
        let path = db.path
        
        // Verify database file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        
        // Verify database is accessible
        let version = db.version
        XCTAssertGreaterThan(version, 0)
    }
    
    func testDatabaseTablesExist() async throws {
        // Test that we can perform basic operations on core tables
        let testItem = SourceItem(
            id: UUID().uuidString,
            type: .text,
            source: .manual,
            status: .inbox,
            title: "Test Item",
            createdAt: Date()
        )
        
        try await storage.insertSourceItem(testItem)
        
        let retrieved = try await storage.getSourceItem(id: testItem.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, testItem.title)
    }
    
    // MARK: - SourceItem CRUD Tests
    
    func testSourceItemCRUD() async throws {
        let id = UUID().uuidString
        let item = SourceItem(
            id: id,
            type: .webpage,
            source: .webpage,
            status: .inbox,
            title: "Test Webpage",
            contentPath: "test.html",
            previewText: "Test content",
            sourceApp: "Safari",
            originalUrl: "https://example.com",
            createdAt: Date()
        )
        
        try await storage.insertSourceItem(item)
        
        let retrieved = try await storage.getSourceItem(id: id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "Test Webpage")
        
        var updated = retrieved!
        updated.status = SourceItemStatus.distilled
        try await storage.updateSourceItem(updated)
        
        let afterUpdate = try await storage.getSourceItem(id: id)
        XCTAssertEqual(afterUpdate?.status, .distilled)
        
        try await storage.deleteSourceItem(id: id)
        let afterDelete = try await storage.getSourceItem(id: id)
        XCTAssertNil(afterDelete)
    }

    func testSourceTypeInferenceFromFileURL() {
        let expectations: [(String, SourceType)] = [
            ("photo.png", .image),
            ("scan.pdf", .pdf),
            ("report.docx", .docx),
            ("notes.md", .text),
            ("archive.zip", .unknownFile)
        ]

        for (fileName, expected) in expectations {
            let url = URL(fileURLWithPath: "/tmp/\(fileName)")
            XCTAssertEqual(SourceType.inferred(fromFileURL: url), expected, fileName)
        }
    }
    
    func testSourceItemListWithFilter() async throws {
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        let item1 = SourceItem(
            id: id1, type: .text, source: .manual,
            status: .inbox, title: "Inbox Item", createdAt: Date()
        )
        let item2 = SourceItem(
            id: id2, type: .text, source: .manual,
            status: .distilled, title: "Distilled Item", createdAt: Date()
        )
        
        try await storage.insertSourceItem(item1)
        try await storage.insertSourceItem(item2)
        
        let inboxItems = try await storage.listSourceItems(filter: SourceItemFilter(status: .inbox))
        XCTAssertTrue(inboxItems.contains { $0.id == id1 })
        XCTAssertFalse(inboxItems.contains { $0.id == id2 })
    }
    
    // MARK: - Chat Session Tests
    
    func testChatSessionCRUD() async throws {
        let id = UUID().uuidString
        let session = ChatSession(
            id: id, title: "Test Session",
            providerId: "ollama", modelId: "llama3",
            status: .active, metadata: [:],
            createdAt: Date(), updatedAt: Date()
        )
        
        try await storage.insertChatSession(session)
        
        let retrieved = try await storage.getChatSession(id: id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "Test Session")
        
        var updated = retrieved!
        updated.title = "Updated Session"
        try await storage.updateChatSession(updated)
        
        let afterUpdate = try await storage.getChatSession(id: id)
        XCTAssertEqual(afterUpdate?.title, "Updated Session")
        
        try await storage.deleteChatSession(id: id)
        let afterDelete = try await storage.getChatSession(id: id)
        XCTAssertNil(afterDelete)
    }
    
    func testChatMessageOperations() async throws {
        let sessionId = UUID().uuidString
        let session = ChatSession(id: sessionId, title: "Message Test Session")
        try await storage.insertChatSession(session)
        
        let message = ChatMessage(
            id: UUID().uuidString,
            sessionId: sessionId,
            role: .user,
            content: "Hello",
            status: .completed
        )
        
        try await storage.insertChatMessage(message)
        
        let messages = try await storage.listChatMessages(sessionId: sessionId)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.content, "Hello")
    }
    
    // MARK: - Settings Tests
    
    func testSettingsCRUD() async throws {
        // Use UUID-based key to avoid parallel test collision
        let key = "test_key_\(UUID().uuidString)"
        
        try await storage.setSetting(key: key, value: "test_value")
        
        let value = try await storage.getSetting(key: key)
        XCTAssertEqual(value, "test_value")
        
        try await storage.setSetting(key: key, value: "updated_value")
        let updated = try await storage.getSetting(key: key)
        XCTAssertEqual(updated, "updated_value")
        
        let missing = try await storage.getSetting(key: "non_existent_\(UUID().uuidString)")
        XCTAssertNil(missing)
    }
    
    // MARK: - Migration Tests
    
    func testImportFromJSON() async throws {
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        let legacyItems = [
            SourceItem(
                id: id1, type: .text, source: .manual,
                status: .inbox, title: "Legacy Item 1", createdAt: Date()
            ),
            SourceItem(
                id: id2, type: .webpage, source: .webpage,
                status: .distilled, title: "Legacy Item 2", createdAt: Date()
            )
        ]
        
        let importedCount = try await storage.importFromJSON(legacyItems)
        XCTAssertEqual(importedCount, 2)
        
        let item1 = try await storage.getSourceItem(id: id1)
        XCTAssertNotNil(item1)
        XCTAssertEqual(item1?.title, "Legacy Item 1")
        
        let item2 = try await storage.getSourceItem(id: id2)
        XCTAssertNotNil(item2)
        XCTAssertEqual(item2?.title, "Legacy Item 2")
    }
    
    func testImportFromJSONSkipsDuplicates() async throws {
        let id = UUID().uuidString
        let item = SourceItem(
            id: id, type: .text, source: .manual,
            status: .inbox, title: "Original", createdAt: Date()
        )
        
        let count1 = try await storage.importFromJSON([item])
        XCTAssertEqual(count1, 1)
        
        let count2 = try await storage.importFromJSON([item])
        XCTAssertEqual(count2, 0)
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistsAcrossInstances() async throws {
        let id = UUID().uuidString
        let item = SourceItem(
            id: id, type: .text, source: .manual,
            status: .inbox, title: "Persistence Test", createdAt: Date()
        )
        
        try await storage.insertSourceItem(item)
        
        let newStorage = StorageService()
        try await newStorage.setup()
        
        let retrieved = try await newStorage.getSourceItem(id: id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "Persistence Test")
    }
    
    // MARK: - Asset Store Tests
    
    func testAssetStoreSaveAndRetrieve() async throws {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: NSSize(width: 1, height: 1)).fill()
        image.unlockFocus()
        
        let asset = try await assetStore.saveImage(image, sourceItemId: nil)
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset.kind, .image)
        XCTAssertEqual(asset.mimeType, "image/png")
        
        let retrieved = try await assetStore.getAsset(id: asset.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.fileName, asset.fileName)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.filePath))
    }
    
    func testAssetStoreSaveText() async throws {
        let text = "Test content for asset storage"
        let asset = try await assetStore.saveText(text, sourceItemId: nil, fileName: "test.txt")
        
        XCTAssertEqual(asset.mimeType, "text/plain")
        
        let loadedText = await assetStore.loadText(asset: asset)
        XCTAssertEqual(loadedText, text)
    }
    
    func testAssetStoreDelete() async throws {
        let text = "Content to be deleted"
        let asset = try await assetStore.saveText(text, fileName: "delete-test.txt")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.filePath))
        
        try await assetStore.deleteAsset(id: asset.id)
        
        let retrieved = try await assetStore.getAsset(id: asset.id)
        XCTAssertNil(retrieved)
        XCTAssertFalse(FileManager.default.fileExists(atPath: asset.filePath))
    }
    
    func testAssetStoreGetAssetsForSourceItem() async throws {
        let sourceItemId = UUID().uuidString
        let otherItemId = UUID().uuidString
        
        // Create source items first (required by foreign key constraint)
        let sourceItem = SourceItem(
            id: sourceItemId, type: .text, source: .manual,
            status: .inbox, title: "Multi Asset Source", createdAt: Date()
        )
        let otherItem = SourceItem(
            id: otherItemId, type: .text, source: .manual,
            status: .inbox, title: "Different Source", createdAt: Date()
        )
        try await storage.insertSourceItem(sourceItem)
        try await storage.insertSourceItem(otherItem)
        
        // Create multiple assets for same source item
        let text1 = try await assetStore.saveText("Text 1", sourceItemId: sourceItemId)
        let text2 = try await assetStore.saveText("Text 2", sourceItemId: sourceItemId)
        let text3 = try await assetStore.saveText("Text 3", sourceItemId: otherItemId)
        
        let assets = try await assetStore.getAssetsForSourceItem(sourceItemId: sourceItemId)
        XCTAssertEqual(assets.count, 2)
        XCTAssertTrue(assets.contains { $0.id == text1.id })
        XCTAssertTrue(assets.contains { $0.id == text2.id })
        XCTAssertFalse(assets.contains { $0.id == text3.id })
    }
    
    // MARK: - Performance Tests
    
    func testBulkInsertPerformance() async throws {
        let prefix = UUID().uuidString
        let items = (0..<100).map { i in
            SourceItem(
                id: "\(prefix)-\(i)",
                type: .text, source: .manual,
                status: .inbox,
                title: "Bulk Item \(i)",
                createdAt: Date()
            )
        }
        
        let start = Date()
        let imported = try await storage.importFromJSON(items)
        let duration = Date().timeIntervalSince(start)
        
        XCTAssertEqual(imported, 100)
        XCTAssertLessThan(duration, 5.0)
    }
}
