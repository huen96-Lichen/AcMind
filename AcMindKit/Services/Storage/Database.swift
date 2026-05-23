import Foundation
import SQLite3

// MARK: - Database Actor

public actor Database {
    public static let shared = Database()

    nonisolated public let path: String
    nonisolated public let version: Int = 23

    private var connection: SQLiteConnection?
    private var isReady = false

    private init() {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind", isDirectory: true)
        let dbURL = baseDir.appendingPathComponent("acmind-swift.db")
        path = dbURL.path
    }

    public func setup() async throws {
        guard !isReady else { return }

        var lastError: Error?

        for candidateURL in databaseCandidateURLs() {
            do {
                try FileManager.default.createDirectory(
                    at: candidateURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                let candidateConnection = try SQLiteConnection(path: candidateURL.path)
                connection = candidateConnection
                try createSchema()
                isReady = true
                return
            } catch {
                lastError = error
                connection = nil
            }
        }

        throw lastError ?? SQLiteError.openFailed("unable to initialize database")
    }

    func db() throws -> SQLiteConnection {
        guard let connection else { throw DatabaseError.notInitialized }
        return connection
    }

    private func createSchema() throws {
        let statements: [String] = [
            """
            CREATE TABLE IF NOT EXISTS source_items (
                id TEXT PRIMARY KEY,
                capture_item_id TEXT,
                type TEXT NOT NULL DEFAULT 'text',
                source TEXT NOT NULL DEFAULT 'manual',
                content_path TEXT NOT NULL DEFAULT '',
                content_text TEXT,  -- RESERVED: not mapped to SourceItem Model; future use for inline content
                content_type TEXT,  -- RESERVED: not mapped to SourceItem Model; future use for MIME type
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
            """,
            "CREATE INDEX IF NOT EXISTS idx_source_items_status ON source_items(status)",
            "CREATE INDEX IF NOT EXISTS idx_source_items_created_at ON source_items(created_at)",
            """
            CREATE TABLE IF NOT EXISTS ai_tasks (
                id TEXT PRIMARY KEY,
                source_item_id TEXT NOT NULL REFERENCES source_items(id) ON DELETE CASCADE,
                tier TEXT NOT NULL DEFAULT 'local_light',
                operation TEXT NOT NULL DEFAULT 'summarize',
                status TEXT NOT NULL DEFAULT 'queued',
                provider TEXT NOT NULL DEFAULT '',
                model TEXT NOT NULL DEFAULT '',
                input TEXT NOT NULL DEFAULT '{}',
                output TEXT,
                error TEXT,
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                started_at INTEGER,
                finished_at INTEGER,
                latency_ms INTEGER
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_ai_tasks_source_item_id ON ai_tasks(source_item_id)",
            "CREATE INDEX IF NOT EXISTS idx_ai_tasks_status ON ai_tasks(status)",
            """
            -- LEGACY: distilled_outputs is superseded by distilled_notes (v22).
            -- Retained for backward compatibility; no Model/CRUD. Safe to drop in future migration.
            CREATE TABLE IF NOT EXISTS distilled_outputs (
                id TEXT PRIMARY KEY,
                source_item_id TEXT NOT NULL REFERENCES source_items(id) ON DELETE CASCADE,
                task_id TEXT NOT NULL REFERENCES ai_tasks(id) ON DELETE CASCADE,
                operation TEXT,
                suggested_title TEXT,
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
                created_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_distilled_outputs_source_item_id ON distilled_outputs(source_item_id)",
            "CREATE INDEX IF NOT EXISTS idx_distilled_outputs_review_status ON distilled_outputs(review_status)",
            """
            CREATE TABLE IF NOT EXISTS knowledge_cards (
                id TEXT PRIMARY KEY,
                source_item_id TEXT NOT NULL UNIQUE REFERENCES source_items(id) ON DELETE CASCADE,
                distilled_output_id TEXT,
                export_record_id TEXT,
                canonical_title TEXT NOT NULL DEFAULT '',
                summary TEXT,
                category TEXT,
                tags TEXT NOT NULL DEFAULT '[]',
                body TEXT,
                body_markdown TEXT,
                document_type TEXT,
                value_score REAL,
                confidence REAL,
                status TEXT NOT NULL DEFAULT 'active',
                vault_file_path TEXT,
                search_vector TEXT,
                reference_count INTEGER NOT NULL DEFAULT 0,
                last_accessed_at INTEGER,
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_knowledge_cards_status ON knowledge_cards(status)",
            "CREATE INDEX IF NOT EXISTS idx_knowledge_cards_category ON knowledge_cards(category)",
            """
            CREATE TABLE IF NOT EXISTS knowledge_edges (
                id TEXT PRIMARY KEY,
                from_knowledge_card_id TEXT NOT NULL REFERENCES knowledge_cards(id) ON DELETE CASCADE,
                to_knowledge_card_id TEXT NOT NULL REFERENCES knowledge_cards(id) ON DELETE CASCADE,
                relation_type TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'suggested',
                confidence REAL,
                reason TEXT,
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_knowledge_edges_from ON knowledge_edges(from_knowledge_card_id)",
            "CREATE INDEX IF NOT EXISTS idx_knowledge_edges_to ON knowledge_edges(to_knowledge_card_id)",
            "CREATE INDEX IF NOT EXISTS idx_knowledge_edges_status ON knowledge_edges(status)",
            """
            CREATE TABLE IF NOT EXISTS export_records (
                id TEXT PRIMARY KEY,
                source_item_id TEXT NOT NULL REFERENCES source_items(id) ON DELETE CASCADE,
                distilled_output_id TEXT NOT NULL REFERENCES distilled_outputs(id) ON DELETE CASCADE,
                knowledge_card_id TEXT REFERENCES knowledge_cards(id) ON DELETE CASCADE,
                vault_path TEXT NOT NULL DEFAULT '',
                relative_file_path TEXT NOT NULL DEFAULT '',
                frontmatter TEXT NOT NULL DEFAULT '{}',
                exported_at INTEGER NOT NULL DEFAULT (unixepoch()),
                status TEXT NOT NULL DEFAULT 'success',
                conflict_resolution TEXT
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_export_records_source_item_id ON export_records(source_item_id)",
            """
            CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS provider_configs (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL DEFAULT '',
                provider_type TEXT NOT NULL DEFAULT 'ollama',
                tier TEXT NOT NULL DEFAULT 'local_light',
                base_url TEXT NOT NULL DEFAULT '',
                api_key_ref TEXT,
                model_id TEXT NOT NULL DEFAULT '',
                enabled INTEGER NOT NULL DEFAULT 1,
                capabilities TEXT NOT NULL DEFAULT '[]',
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            """
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
            """,
            """
            CREATE TABLE IF NOT EXISTS _migration (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS chat_sessions (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL DEFAULT '新对话',
                provider_id TEXT,
                model_id TEXT,
                status TEXT NOT NULL DEFAULT 'active',
                metadata TEXT NOT NULL DEFAULT '{}',
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_chat_sessions_status ON chat_sessions(status, updated_at)",
            """
            CREATE TABLE IF NOT EXISTS chat_messages (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
                role TEXT NOT NULL,
                content TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'pending',
                model_id TEXT,
                provider_id TEXT,
                prompt_tokens INTEGER,
                completion_tokens INTEGER,
                latency_ms INTEGER,
                error TEXT,
                action_proposals TEXT NOT NULL DEFAULT '[]',
                created_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(session_id, created_at)",
            """
            CREATE TABLE IF NOT EXISTS agent_tasks (
                id TEXT PRIMARY KEY,
                session_id TEXT REFERENCES chat_sessions(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                skill_name TEXT,
                input_params TEXT NOT NULL DEFAULT '{}',
                result TEXT,
                error TEXT,
                started_at INTEGER,
                completed_at INTEGER,
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_agent_tasks_status ON agent_tasks(status, updated_at)",
            """
            CREATE TABLE IF NOT EXISTS agent_task_events (
                id TEXT PRIMARY KEY,
                task_id TEXT NOT NULL REFERENCES agent_tasks(id) ON DELETE CASCADE,
                event_type TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                metadata TEXT NOT NULL DEFAULT '{}',
                created_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_agent_task_events_task ON agent_task_events(task_id, created_at)",
            """
            CREATE TABLE IF NOT EXISTS scheduled_agent_tasks (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                cron_expression TEXT NOT NULL,
                skill_name TEXT NOT NULL,
                input_params TEXT NOT NULL DEFAULT '{}',
                enabled INTEGER NOT NULL DEFAULT 1,
                last_run_at INTEGER,
                last_run_status TEXT,
                last_run_task_id TEXT,
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_scheduled_agent_tasks_enabled ON scheduled_agent_tasks(enabled, updated_at)",
            """
            CREATE TABLE IF NOT EXISTS asset_files (
                id TEXT PRIMARY KEY,
                source_item_id TEXT REFERENCES source_items(id) ON DELETE CASCADE,
                file_name TEXT NOT NULL,
                file_path TEXT NOT NULL,
                mime_type TEXT,
                file_size INTEGER,
                kind TEXT NOT NULL DEFAULT 'other',
                created_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_asset_files_source_item_id ON asset_files(source_item_id)",
            """
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL DEFAULT 'text',
                content TEXT,
                text_content TEXT,
                source_app TEXT,
                is_pinned INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_clipboard_items_created_at ON clipboard_items(created_at)",
            "CREATE INDEX IF NOT EXISTS idx_clipboard_items_is_pinned ON clipboard_items(is_pinned)",
            """
            CREATE TABLE IF NOT EXISTS shelf_items (
                id TEXT PRIMARY KEY,
                source_item_id TEXT REFERENCES source_items(id) ON DELETE CASCADE,
                file_path TEXT,
                label TEXT,
                status TEXT NOT NULL DEFAULT 'pending',
                created_at INTEGER NOT NULL DEFAULT (unixepoch())
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_shelf_items_status ON shelf_items(status)",
            """
            CREATE TABLE IF NOT EXISTS distilled_notes (
                id TEXT PRIMARY KEY,
                source_item_id TEXT NOT NULL REFERENCES source_items(id) ON DELETE CASCADE,
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
            """,
            "CREATE INDEX IF NOT EXISTS idx_distilled_notes_source_item_id ON distilled_notes(source_item_id)",
            """
            CREATE TABLE IF NOT EXISTS process_jobs (
                id TEXT PRIMARY KEY,
                source_item_id TEXT REFERENCES source_items(id) ON DELETE CASCADE,
                job_type TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'queued',
                input TEXT NOT NULL DEFAULT '{}',
                output TEXT,
                error TEXT,
                progress REAL,
                result TEXT,
                created_at INTEGER NOT NULL DEFAULT (unixepoch()),
                started_at INTEGER,
                finished_at INTEGER
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_process_jobs_status ON process_jobs(status)",
            "CREATE INDEX IF NOT EXISTS idx_process_jobs_source_item_id ON process_jobs(source_item_id)"
        ]

        for statement in statements {
            try db().execute(statement)
        }

        // Migration v22: add missing columns to source_items (idempotent)
        let v22Migrations: [String] = [
            "ALTER TABLE source_items ADD COLUMN transcript TEXT",
            "ALTER TABLE source_items ADD COLUMN polished_transcript TEXT",
            "ALTER TABLE source_items ADD COLUMN metadata TEXT NOT NULL DEFAULT '{}'"
        ]
        for sql in v22Migrations {
            try? db().execute(sql)  // ignore "duplicate column" errors for existing DBs
        }

        // Migration v23: add progress/result columns to process_jobs (idempotent)
        let v23Migrations: [String] = [
            "ALTER TABLE process_jobs ADD COLUMN progress REAL",
            "ALTER TABLE process_jobs ADD COLUMN result TEXT"
        ]
        for sql in v23Migrations {
            try? db().execute(sql)
        }
    }

    private func databaseCandidateURLs() -> [URL] {
        let primary = URL(fileURLWithPath: path)
        let fallback = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind", isDirectory: true)
            .appendingPathComponent("acmind-swift.db")
        return [primary, fallback]
    }

    // MARK: - Source Items

    public func insertSourceItem(_ item: SourceItemRecord) async throws {
        let sql = """
        INSERT INTO source_items (
            id, capture_item_id, type, source, content_path, preview_text, ocr_text,
            transcript, polished_transcript,
            source_app, original_url, tags, vault_import_path, metadata,
            created_at, updated_at, status, title,
            content_text, content_type, content_hash
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            capture_item_id = excluded.capture_item_id,
            type = excluded.type,
            source = excluded.source,
            content_path = excluded.content_path,
            preview_text = excluded.preview_text,
            ocr_text = excluded.ocr_text,
            transcript = excluded.transcript,
            polished_transcript = excluded.polished_transcript,
            source_app = excluded.source_app,
            original_url = excluded.original_url,
            tags = excluded.tags,
            vault_import_path = excluded.vault_import_path,
            metadata = excluded.metadata,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at,
            status = excluded.status,
            title = excluded.title,
            content_text = excluded.content_text,
            content_type = excluded.content_type,
            content_hash = excluded.content_hash
        """

        try db().execute(sql, arguments: [
            item.id,
            item.captureItemId,
            item.type,
            item.source,
            item.contentPath,
            item.previewText,
            item.ocrText,
            item.transcript,
            item.polishedTranscript,
            item.sourceApp,
            item.originalUrl,
            item.tags,
            item.vaultImportPath,
            item.metadata ?? "{}",
            item.createdAt,
            Int(Date().timeIntervalSince1970),
            item.status,
            item.title,
            nil as String?,
            nil as String?,
            item.contentHash
        ])
    }

    public func getSourceItem(id: String) async throws -> SourceItemRecord? {
        try db().queryOne("SELECT * FROM source_items WHERE id = ? LIMIT 1", arguments: [id]) { row in
            SourceItemRecord(row: row)
        }
    }

    public func listSourceItems(filter: SourceItemFilter?) async throws -> [SourceItemRecord] {
        var sql = "SELECT * FROM source_items WHERE 1=1"
        var arguments: [Any?] = []

        if let status = filter?.status {
            sql += " AND status = ?"
            arguments.append(status.rawValue)
        }
        if let type = filter?.type {
            sql += " AND type = ?"
            arguments.append(type.rawValue)
        }
        if let searchQuery = filter?.searchQuery, !searchQuery.isEmpty {
            let pattern = "%\(searchQuery)%"
            sql += """
             AND (
                COALESCE(title, '') LIKE ?
                OR COALESCE(preview_text, '') LIKE ?
                OR COALESCE(content_path, '') LIKE ?
                OR COALESCE(original_url, '') LIKE ?
             )
            """
            arguments.append(contentsOf: [pattern, pattern, pattern, pattern])
        }

        sql += " ORDER BY created_at DESC"
        if let limit = filter?.limit {
            sql += " LIMIT ?"
            arguments.append(limit)
        }

        return try db().query(sql, arguments: arguments) { row in
            SourceItemRecord(row: row)
        }
    }

    public func updateSourceItem(_ item: SourceItemRecord) async throws {
        try await insertSourceItem(item)
    }

    public func deleteSourceItem(id: String) async throws {
        try db().execute("DELETE FROM source_items WHERE id = ?", arguments: [id])
    }

    // MARK: - Chat Sessions

    public func insertChatSession(_ session: ChatSessionRecord) async throws {
        let sql = """
        INSERT INTO chat_sessions (id, title, provider_id, model_id, status, metadata, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            provider_id = excluded.provider_id,
            model_id = excluded.model_id,
            status = excluded.status,
            metadata = excluded.metadata,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at
        """
        try db().execute(sql, arguments: [
            session.id, session.title, session.providerId, session.modelId, session.status,
            session.metadata, session.createdAt, session.updatedAt
        ])
    }

    public func getChatSession(id: String) async throws -> ChatSessionRecord? {
        try db().queryOne("SELECT * FROM chat_sessions WHERE id = ? LIMIT 1", arguments: [id]) { row in
            ChatSessionRecord(row: row)
        }
    }

    public func listChatSessions(status: String? = nil) async throws -> [ChatSessionRecord] {
        var sql = "SELECT * FROM chat_sessions WHERE 1=1"
        var arguments: [Any?] = []
        if let status {
            sql += " AND status = ?"
            arguments.append(status)
        }
        sql += " ORDER BY updated_at DESC"
        return try db().query(sql, arguments: arguments) { row in
            ChatSessionRecord(row: row)
        }
    }

    public func updateChatSession(_ session: ChatSessionRecord) async throws {
        try await insertChatSession(session)
    }

    public func deleteChatSession(id: String) async throws {
        try db().execute("DELETE FROM chat_sessions WHERE id = ?", arguments: [id])
    }

    // MARK: - Chat Messages

    public func insertChatMessage(_ message: ChatMessageRecord) async throws {
        let sql = """
        INSERT INTO chat_messages (
            id, session_id, role, content, status, model_id, provider_id,
            prompt_tokens, completion_tokens, latency_ms, error, action_proposals, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            session_id = excluded.session_id,
            role = excluded.role,
            content = excluded.content,
            status = excluded.status,
            model_id = excluded.model_id,
            provider_id = excluded.provider_id,
            prompt_tokens = excluded.prompt_tokens,
            completion_tokens = excluded.completion_tokens,
            latency_ms = excluded.latency_ms,
            error = excluded.error,
            action_proposals = excluded.action_proposals,
            created_at = excluded.created_at
        """
        try db().execute(sql, arguments: [
            message.id, message.sessionId, message.role, message.content, message.status,
            message.modelId, message.providerId, message.promptTokens, message.completionTokens,
            message.latencyMs, message.error, message.actionProposals, message.createdAt
        ])
    }

    public func listChatMessages(sessionId: String) async throws -> [ChatMessageRecord] {
        try db().query(
            "SELECT * FROM chat_messages WHERE session_id = ? ORDER BY created_at ASC",
            arguments: [sessionId]
        ) { row in
            ChatMessageRecord(row: row)
        }
    }

    // MARK: - Distilled Notes

    public func insertDistilledNote(_ note: DistilledNote) async throws {
        let record = DistilledNoteRecord(from: note)
        try db().execute(record.upsertSQL, arguments: record.bindings)
    }

    public func updateDistilledNote(_ note: DistilledNote) async throws {
        try await insertDistilledNote(note)
    }

    public func listDistilledNotes() async throws -> [DistilledNote] {
        try db().query("SELECT * FROM distilled_notes ORDER BY created_at DESC") { row in
            DistilledNoteRecord(row: row).toDistilledNote()
        }
    }

    // MARK: - Export Records

    public func insertExportRecord(_ record: ExportRecord) async throws {
        let row = ExportRecordRow(from: record)
        try db().execute(row.upsertSQL, arguments: row.bindings)
    }

    public func listExportRecords() async throws -> [ExportRecord] {
        try db().query("SELECT * FROM export_records ORDER BY exported_at DESC") { row in
            ExportRecordRow(row: row).toExportRecord()
        }
    }

    // MARK: - Knowledge Cards

    public func insertKnowledgeCard(_ card: KnowledgeCard) async throws {
        let record = KnowledgeCardRecord(from: card)
        try db().execute(record.upsertSQL, arguments: record.bindings)
    }

    public func updateKnowledgeCard(_ card: KnowledgeCard) async throws {
        try await insertKnowledgeCard(card)
    }

    public func listKnowledgeCards(status: KnowledgeCardStatus?) async throws -> [KnowledgeCard] {
        var sql = "SELECT * FROM knowledge_cards"
        if status != nil {
            sql += " WHERE status = ?"
        }
        sql += " ORDER BY updated_at DESC"

        let args: [Any] = status != nil ? [status!.rawValue] : []

        return try db().query(sql, arguments: args) { row in
            self.rowToKnowledgeCard(row)
        }
    }

    // MARK: - Clipboard Items

    public func insertClipboardItem(_ item: ClipboardItem) async throws {
        try db().execute(
            """
            INSERT INTO clipboard_items (id, type, content, text_content, source_app, is_pinned, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                item.id,
                item.type.rawValue,
                item.content,
                item.textContent,
                item.sourceApp ?? NSNull(),
                item.isPinned ? 1 : 0,
                Int(item.createdAt.timeIntervalSince1970)
            ]
        )
    }

    public func listClipboardItems(limit: Int?) async throws -> [ClipboardItem] {
        let limitClause = limit.map { "LIMIT \($0)" } ?? ""
        return try db().query(
            "SELECT * FROM clipboard_items ORDER BY is_pinned DESC, created_at DESC \(limitClause)"
        ) { row in
            ClipboardItem(
                id: row.string("id") ?? UUID().uuidString,
                type: ClipboardContentType(rawValue: row.string("type") ?? "text") ?? .text,
                content: row.string("content"),
                textContent: row.string("text_content"),
                sourceApp: row.string("source_app"),
                isPinned: row.int("is_pinned") == 1,
                createdAt: Date(timeIntervalSince1970: TimeInterval(row.int("created_at") ?? 0))
            )
        }
    }

    public func updateClipboardItem(_ item: ClipboardItem) async throws {
        try db().execute(
            """
            UPDATE clipboard_items SET
                type = ?, content = ?, text_content = ?, source_app = ?, is_pinned = ?
            WHERE id = ?
            """,
            arguments: [
                item.type.rawValue,
                item.content ?? NSNull(),
                item.textContent ?? NSNull(),
                item.sourceApp ?? NSNull(),
                item.isPinned ? 1 : 0,
                item.id
            ]
        )
    }

    public func deleteClipboardItem(id: String) async throws {
        try db().execute("DELETE FROM clipboard_items WHERE id = ?", arguments: [id])
    }

    // MARK: - Provider Configs

    public func insertProvider(_ config: ProviderConfigRecord) async throws {
        try db().execute(config.upsertSQL, arguments: config.bindings)
    }

    public func getProvider(id: String) async throws -> ProviderConfigRecord? {
        try db().queryOne("SELECT * FROM provider_configs WHERE id = ? LIMIT 1", arguments: [id]) { row in
            ProviderConfigRecord(row: row)
        }
    }

    public func listProviders() async throws -> [ProviderConfigRecord] {
        try db().query("SELECT * FROM provider_configs ORDER BY updated_at DESC") { row in
            ProviderConfigRecord(row: row)
        }
    }

    public func updateProvider(_ config: ProviderConfigRecord) async throws {
        try await insertProvider(config)
    }

    public func deleteProvider(id: String) async throws {
        try db().execute("DELETE FROM provider_configs WHERE id = ?", arguments: [id])
    }

    // MARK: - Settings

    public func getSetting(key: String) async throws -> String? {
        try db().queryOne("SELECT value FROM app_settings WHERE key = ? LIMIT 1", arguments: [key]) { row in
            row.string("value") ?? ""
        }
    }

    public func setSetting(key: String, value: String) async throws {
        try db().execute(
            """
            INSERT INTO app_settings (key, value) VALUES (?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value
            """,
            arguments: [key, value]
        )
    }

    // MARK: - Migration

    public func importFromJSON(_ items: [SourceItem]) async throws -> Int {
        var count = 0
        for item in items {
            // Skip if already exists (dedup by id)
            let existing = try db().query(
                "SELECT COUNT(*) AS cnt FROM source_items WHERE id = ?",
                arguments: [item.id],
                mapper: { row in row.int("cnt") ?? 0 }
            )
            if (existing.first ?? 0) > 0 { continue }
            try await insertSourceItem(SourceItemRecord(from: item))
            count += 1
        }
        return count
    }

    public nonisolated func checkMigrationSourceDatabase() -> URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let currentPath = appSupport.appendingPathComponent("AcMind/acmind.db")
        if FileManager.default.fileExists(atPath: currentPath.path) {
            return currentPath
        }
        let previousPath = appSupport.appendingPathComponent("AcMind/pinmind.db")
        if FileManager.default.fileExists(atPath: previousPath.path) {
            return previousPath
        }
        return nil
    }

    // MARK: - Knowledge Edges
}
