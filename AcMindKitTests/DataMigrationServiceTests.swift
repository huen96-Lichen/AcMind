import XCTest
@testable import AcMindKit

final class DataMigrationServiceTests: XCTestCase {
    func testLegacyDatabaseMigratesKeyTablesAndMarksBackup() async throws {
        let fileManager = FileManager.default
        let legacyPath = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("AcMind/pinmind.db")
        let legacyDirectory = legacyPath.deletingLastPathComponent()
        let migratedBackupPath = legacyPath.appendingPathExtension("migrated")
        let targetURL = fileManager.temporaryDirectory
            .appendingPathComponent("AcMindMigrationTests", isDirectory: true)
            .appendingPathComponent("swift-target-\(UUID().uuidString).db")

        try fileManager.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let hadExistingLegacy = fileManager.fileExists(atPath: legacyPath.path)
        let legacyRestoreURL = fileManager.temporaryDirectory.appendingPathComponent("AcMind-legacy-restore-\(UUID().uuidString).db")

        if hadExistingLegacy {
            if fileManager.fileExists(atPath: legacyRestoreURL.path) {
                try fileManager.removeItem(at: legacyRestoreURL)
            }
            try fileManager.moveItem(at: legacyPath, to: legacyRestoreURL)
        }

        defer {
            try? fileManager.removeItem(at: migratedBackupPath)
            try? fileManager.removeItem(at: targetURL)
            try? fileManager.removeItem(at: targetURL.deletingLastPathComponent())
            if hadExistingLegacy, fileManager.fileExists(atPath: legacyRestoreURL.path) {
                try? fileManager.removeItem(at: legacyPath)
                try? fileManager.moveItem(at: legacyRestoreURL, to: legacyPath)
            } else {
                try? fileManager.removeItem(at: legacyPath)
            }
        }

        try createLegacyDatabase(at: legacyPath)
        try createTargetDatabase(at: targetURL)

        let migrationService = DataMigrationService(swiftDBPath: targetURL)
        let result = try await migrationService.runIfNeeded()

        XCTAssertTrue(result.migrated)
        XCTAssertEqual(result.tables["source_items"], 1)
        XCTAssertEqual(result.tables["app_settings"], 1)
        XCTAssertEqual(result.tables["vault_config"], 1)
        XCTAssertEqual(result.tables["distilled_notes"], 1)
        XCTAssertTrue(fileManager.fileExists(atPath: migratedBackupPath.path))

        let target = try SQLiteConnection(path: targetURL.path, readOnly: true)
        let migratedSourceItems = try target.query("SELECT id, title, status FROM source_items ORDER BY created_at DESC") { row in
            [
                row.string("id") ?? "",
                row.string("title") ?? "",
                row.string("status") ?? ""
            ]
        }
        XCTAssertEqual(migratedSourceItems.first, ["legacy-source-item", "旧版收集内容", "distilled"])

        let migratedFlags = try target.query("SELECT value FROM _migration WHERE key = ?", arguments: ["legacy_imported"]) { row in
            row.string("value") ?? ""
        }
        XCTAssertEqual(migratedFlags.first, "true")
    }

    private func createLegacyDatabase(at url: URL) throws {
        let db = try SQLiteConnection(path: url.path)
        try db.execute("""
            CREATE TABLE source_items (
                id TEXT PRIMARY KEY,
                title TEXT,
                status TEXT,
                created_at INTEGER,
                updated_at INTEGER
            )
        """)
        try db.execute("""
            CREATE TABLE app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
        """)
        try db.execute("""
            CREATE TABLE vault_config (
                id INTEGER PRIMARY KEY,
                vault_path TEXT,
                default_folder TEXT,
                template TEXT,
                path_rule TEXT,
                conflict_strategy TEXT,
                auto_frontmatter INTEGER,
                frontmatter_template TEXT
            )
        """)
        try db.execute("""
            CREATE TABLE distilled_notes (
                id TEXT PRIMARY KEY,
                source_item_id TEXT NOT NULL,
                title TEXT,
                summary TEXT,
                category TEXT,
                tags TEXT,
                content_markdown TEXT,
                created_at INTEGER,
                updated_at INTEGER
            )
        """)

        try db.execute(
            "INSERT INTO source_items (id, title, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
            arguments: ["legacy-source-item", "旧版收集内容", "distilled", 1_700_000_000, 1_700_000_100]
        )
        try db.execute(
            "INSERT INTO app_settings (key, value) VALUES (?, ?)",
            arguments: ["theme", "dark"]
        )
        try db.execute(
            """
            INSERT INTO vault_config (id, vault_path, default_folder, template, path_rule, conflict_strategy, auto_frontmatter, frontmatter_template)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [1, "/tmp/legacy-vault", "Inbox", "# {{title}}", "source_type", "rename", 1, "{}"]
        )
        try db.execute(
            """
            INSERT INTO distilled_notes (id, source_item_id, title, summary, category, tags, content_markdown, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: ["legacy-note", "legacy-source-item", "旧版笔记", "summary", "workbench", "[\"legacy\"]", "content", 1_700_000_200, 1_700_000_300]
        )
    }

    private func createTargetDatabase(at url: URL) throws {
        let db = try SQLiteConnection(path: url.path)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS source_items (
                id TEXT PRIMARY KEY,
                capture_item_id TEXT,
                type TEXT NOT NULL DEFAULT 'text',
                source TEXT NOT NULL DEFAULT 'manual',
                content_path TEXT NOT NULL DEFAULT '',
                content_text TEXT,
                content_type TEXT,
                content_hash TEXT,
                preview_text TEXT,
                ocr_text TEXT,
                transcript TEXT,
                polished_transcript TEXT,
                source_app TEXT,
                original_url TEXT,
                tags TEXT,
                vault_import_path TEXT,
                metadata TEXT NOT NULL DEFAULT '{}',
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
                status TEXT NOT NULL DEFAULT 'inbox',
                title TEXT
            )
        """)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
        """)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS vault_config (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                vault_path TEXT NOT NULL DEFAULT '',
                default_folder TEXT NOT NULL DEFAULT 'Inbox',
                template TEXT NOT NULL DEFAULT '',
                path_rule TEXT NOT NULL DEFAULT 'category_date',
                conflict_strategy TEXT NOT NULL DEFAULT 'rename',
                auto_frontmatter INTEGER NOT NULL DEFAULT 1,
                frontmatter_template TEXT NOT NULL DEFAULT '{}'
            )
        """)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS distilled_notes (
                id TEXT PRIMARY KEY,
                source_item_id TEXT NOT NULL,
                task_id TEXT,
                title TEXT,
                summary TEXT,
                category TEXT,
                tags TEXT,
                document_type TEXT,
                content_markdown TEXT,
                value_score REAL,
                clean_suggestion TEXT,
                confidence REAL,
                review_status TEXT NOT NULL DEFAULT 'pending',
                reviewed_at INTEGER,
                accepted_knowledge_card_id TEXT,
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
        """)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS _migration (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
        """)
    }
}
