import XCTest
@testable import AcMindKit
import GRDB

/// Tests for SQLite storage layer migration from JSON to GRDB
/// Validates: database initialization, CRUD operations, migration from legacy data
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
        let db = Database.shared
        
        // Test that we can perform basic operations on core tables
        let testItem = SourceItem(
            id: UUID().uuidString,
            type: .text,
            source: .manual,
            status: .inbox,
            title: "Test Item",
            contentPath: nil,
            previewText: "Test preview",
            originalUrl: nil,
            sourceApp: nil,
            createdAt: Date()
        )
        
        // Should not throw - indicates tables exist
        try await storage.insertSourceItem(testItem)
        
        // Verify insertion
        let retrieved = try await storage.getSourceItem(id: testItem.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, testItem.title)
    }
    
    // MARK: - SourceItem CRUD Tests
    
    func testSourceItemCRUD() async throws {
        // Create
        let item = SourceItem(
            id: UUID().uuidString,
            type: .webpage,
            source: .capture,
            status: .inbox,
            title: "Test Webpage",
            contentPath: "test.html",
            previewText: "Test content",
            originalUrl: "https://example.com",
            sourceApp: "Safari",
            createdAt: Date()
        )
        
        try await storage.insertSourceItem(item)
        
        // Read
        let retrieved = try await storage.getSourceItem(id: item.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "Test Webpage")
        XCTAssertEqual(retrieved?.type, .webpage)
        XCTAssertEqual(retrieved?.status, .inbox)
        
        // Update
        var updated = retrieved!
        updated.status = .distilled
        try await storage.updateSourceItem(updated)
        
        let afterUpdate = try await storage.getSourceItem(id: item.id)
        XCTAssertEqual(afterUpdate?.status, .distilled)
        
        // Delete
        try await storage.deleteSourceItem(id: item.id)
        let afterDelete = try await storage.getSourceItem(id: item.id)
        XCTAssertNil(afterDelete)
    }
    
    func testSourceItemListWithFilter() async throws {
        // Insert items with different statuses
        let item1 = SourceItem(
            id: UUID().uuidString,
            type: .text,
            source: .manual,
            status: .inbox,
            title: "Inbox Item",
            createdAt: Date()
        )
        
        let item2 = SourceItem(
            id: UUID().uuidString,
            type: .text,
            source: .manual,
            status: .distilled,
            title: "Distilled Item",
            createdAt: Date()
        )
        
        try await storage.insertSourceItem(item1)
        try await storage.insertSourceItem(item2)
        
        // Filter by status
        let inboxItems = try await storage.listSourceItems(filter: SourceItemFilter(status: .inbox))
        XCTAssertTrue(inboxItems.contains { $0.id == item1.id })
        XCTAssertFalse(inboxItems.contains { $0.id == item2.id })
    }
    
    // MARK: - Chat Session Tests
    
    func testChatSessionCRUD() async throws {
        let session = ChatSession(
            id: UUID().uuidString,
            title: "Test Session",
            providerId: "ollama",
            modelId: "llama3",
            status: "active",
            metadata: "{}",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Create
        try await storage.insertChatSession(session)
        
        // Read
        let retrieved = try await storage.getChatSession(id: session.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "Test Session")
        
        // Update
        var updated = retrieved!
        updated.title = "Updated Session"
        try await storage.updateChatSession(updated)
        
        let afterUpdate = try await storage.getChatSession(id: session.id)
        XCTAssertEqual(afterUpdate?.title, "Updated Session")
        
        // Delete
        try await storage.deleteChatSession(id: session.id)
        let afterDelete = try await storage.getChatSession(id: session.id)
        XCTAssertNil(afterDelete)
    }
    
    func testChatMessageOperations() async throws {
        let session = ChatSession(
            id: UUID().uuidString,
            title: "Message Test Session"
        )
        try await storage.insertChatSession(session)
        
        let message = ChatMessage(
            id: UUID().uuidString,
            sessionId: session.id,
            role: "user",
            content: "Hello",
            status: "completed"
        )
        
        try await storage.insertChatMessage(message)
        
        let messages = try await storage.listChatMessages(sessionId: session.id)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.content, "Hello")
    }
    
    // MARK: - Settings Tests
    
    func testSettingsCRUD() async throws {
        // Set
        try await storage.setSetting(key: "test_key", value: "test_value")
        
        // Get
        let value = try await storage.getSetting(key: "test_key")
        XCTAssertEqual(value, "test_value")
        
        // Update
        try await storage.setSetting(key: "test_key", value: "updated_value")
        let updated = try await storage.getSetting(key: "test_key")
        XCTAssertEqual(updated, "updated_value")
        
        // Non-existent key
        let missing = try await storage.getSetting(key: "non_existent")
        XCTAssertNil(missing)
    }
    
    // MARK: - Migration Tests
    
    func testImportFromJSON() async throws {
        // Create legacy JSON-style items
        let legacyItems = [
            SourceItem(
                id: "legacy-1",
                type: .text,
                source: .manual,
                status: .inbox,
                title: "Legacy Item 1",
                createdAt: Date()
            ),
            SourceItem(
                id: "legacy-2",
                type: .webpage,
                source: .capture,
                status: .distilled,
                title: "Legacy Item 2",
                createdAt: Date()
            )
        ]
        
        // Import
        let importedCount = try await storage.importFromJSON(legacyItems)
        XCTAssertEqual(importedCount, 2)
        
        // Verify items exist in database
        let item1 = try await storage.getSourceItem(id: "legacy-1")
        XCTAssertNotNil(item1)
        XCTAssertEqual(item1?.title, "Legacy Item 1")
        
        let item2 = try await storage.getSourceItem(id: "legacy-2")
        XCTAssertNotNil(item2)
        XCTAssertEqual(item2?.title, "Legacy Item 2")
    }
    
    func testImportFromJSONSkipsDuplicates() async throws {
        let item = SourceItem(
            id: "duplicate-test",
            type: .text,
            source: .manual,
            status: .inbox,
            title: "Original",
            createdAt: Date()
        )
        
        // First import
        let count1 = try await storage.importFromJSON([item])
        XCTAssertEqual(count1, 1)
        
        // Second import (duplicate)
        let count2 = try await storage.importFromJSON([item])
        XCTAssertEqual(count2, 0) // Should skip duplicate
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistsAcrossInstances() async throws {
        // Create item
        let item = SourceItem(
            id: "persistence-test",
            type: .text,
            source: .manual,
            status: .inbox,
            title: "Persistence Test",
            createdAt: Date()
        )
        
        try await storage.insertSourceItem(item)
        
        // Create new storage instance (simulates app restart)
        let newStorage = StorageService()
        try await newStorage.setup()
        
        // Verify data exists
        let retrieved = try await newStorage.getSourceItem(id: "persistence-test")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "Persistence Test")
    }
    
    // MARK: - Asset Store Tests
    
    func testAssetStoreSaveAndRetrieve() async throws {
        // Create a simple test image (1x1 red pixel)
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: NSSize(width: 1, height: 1)).fill()
        image.unlockFocus()
        
        // Save
        let asset = try await assetStore.saveImage(image, sourceItemId: "test-item")
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset.kind, .image)
        XCTAssertEqual(asset.mimeType, "image/png")
        
        // Retrieve
        let retrieved = try await assetStore.getAsset(id: asset.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.fileName, asset.fileName)
        
        // Verify file exists on disk
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.filePath))
    }
    
    func testAssetStoreSaveText() async throws {
        let text = "Test content for asset storage"
        let asset = try await assetStore.saveText(text, sourceItemId: "test-item", fileName: "test.txt")
        
        XCTAssertEqual(asset.mimeType, "text/plain")
        
        // Load and verify content
        let loadedText = assetStore.loadText(asset: asset)
        XCTAssertEqual(loadedText, text)
    }
    
    func testAssetStoreDelete() async throws {
        let text = "Content to be deleted"
        let asset = try await assetStore.saveText(text, fileName: "delete-test.txt")
        
        // Verify exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.filePath))
        
        // Delete
        try await assetStore.deleteAsset(id: asset.id)
        
        // Verify deleted
        let retrieved = try await assetStore.getAsset(id: asset.id)
        XCTAssertNil(retrieved)
        XCTAssertFalse(FileManager.default.fileExists(atPath: asset.filePath))
    }
    
    func testAssetStoreGetAssetsForSourceItem() async throws {
        let sourceItemId = "multi-asset-test"
        
        // Create multiple assets for same source item
        let text1 = try await assetStore.saveText("Text 1", sourceItemId: sourceItemId)
        let text2 = try await assetStore.saveText("Text 2", sourceItemId: sourceItemId)
        let text3 = try await assetStore.saveText("Text 3", sourceItemId: "different-item")
        
        // Get assets for source item
        let assets = try await assetStore.getAssetsForSourceItem(sourceItemId: sourceItemId)
        XCTAssertEqual(assets.count, 2)
        XCTAssertTrue(assets.contains { $0.id == text1.id })
        XCTAssertTrue(assets.contains { $0.id == text2.id })
        XCTAssertFalse(assets.contains { $0.id == text3.id })
    }
    
    // MARK: - Performance Tests
    
    func testBulkInsertPerformance() async throws {
        let items = (0..<100).map { i in
            SourceItem(
                id: "bulk-\(i)",
                type: .text,
                source: .manual,
                status: .inbox,
                title: "Bulk Item \(i)",
                createdAt: Date()
            )
        }
        
        let start = Date()
        let imported = try await storage.importFromJSON(items)
        let duration = Date().timeIntervalSince(start)
        
        XCTAssertEqual(imported, 100)
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
    }
}
