import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - SQLite Primitives

internal enum SQLiteStoredValue: Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    var stringValue: String? {
        switch self {
        case .null:
            return nil
        case .integer(let value):
            return String(value)
        case .real(let value):
            return String(value)
        case .text(let value):
            return value
        case .blob(let value):
            return String(data: value, encoding: .utf8)
        }
    }

    var intValue: Int? {
        switch self {
        case .null:
            return nil
        case .integer(let value):
            return Int(value)
        case .real(let value):
            return Int(value)
        case .text(let value):
            return Int(value)
        case .blob:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .null:
            return nil
        case .integer(let value):
            return Double(value)
        case .real(let value):
            return value
        case .text(let value):
            return Double(value)
        case .blob:
            return nil
        }
    }

    var boolValue: Bool? {
        guard let value = intValue else { return nil }
        return value != 0
    }

    var dataValue: Data? {
        switch self {
        case .blob(let value):
            return value
        case .text(let value):
            return value.data(using: .utf8)
        default:
            return nil
        }
    }
}

public struct SQLiteRow: Sendable {
    private let values: [String: SQLiteStoredValue]

    init(values: [String: SQLiteStoredValue]) {
        self.values = values
    }

    subscript(_ key: String) -> SQLiteStoredValue? {
        values[key]
    }

    func string(_ key: String) -> String? {
        values[key]?.stringValue
    }

    func int(_ key: String) -> Int? {
        values[key]?.intValue
    }

    func double(_ key: String) -> Double? {
        values[key]?.doubleValue
    }

    func bool(_ key: String) -> Bool? {
        values[key]?.boolValue
    }

    func data(_ key: String) -> Data? {
        values[key]?.dataValue
    }
}

internal final class SQLiteConnection {
    private var handle: OpaquePointer?

    init(path: String, readOnly: Bool = false) throws {
        var db: OpaquePointer?
        let flags = readOnly
            ? (SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
            : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX)

        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK, let opened = db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite open error"
            throw SQLiteError.openFailed(message)
        }

        handle = opened
        sqlite3_busy_timeout(opened, 5_000)

        if !readOnly {
            try execute("PRAGMA foreign_keys = ON")
            // `journal_mode` returns a result row, so it must be consumed via query.
            _ = try query("PRAGMA journal_mode = WAL") { _ in () }
            try execute("PRAGMA synchronous = NORMAL")
        }
    }

    deinit {
        if let handle {
            sqlite3_close_v2(handle)
        }
    }

    var changesCount: Int {
        guard let handle else { return 0 }
        return Int(sqlite3_changes(handle))
    }

    func execute(_ sql: String, arguments: [Any?] = []) throws {
        let statement = try prepare(sql, arguments: arguments)
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.executionFailed(message())
        }
    }

    func query<T>(_ sql: String, arguments: [Any?] = [], mapper: (SQLiteRow) throws -> T) throws -> [T] {
        let statement = try prepare(sql, arguments: arguments)
        defer { sqlite3_finalize(statement) }

        var results: [T] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                results.append(try mapper(makeRow(from: statement)))
            } else if status == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.executionFailed(message())
            }
        }
        return results
    }

    func queryOne<T>(_ sql: String, arguments: [Any?] = [], mapper: (SQLiteRow) throws -> T) throws -> T? {
        try query(sql, arguments: arguments, mapper: mapper).first
    }

    func tableExists(_ table: String) throws -> Bool {
        let rows = try query(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
            arguments: [table]
        ) { row in row.string("name") ?? "" }
        return !rows.isEmpty
    }

    func columnExists(_ table: String, column: String) throws -> Bool {
        let rows = try query("PRAGMA table_info(\(table))") { row in row.string("name") ?? "" }
        return rows.contains(column)
    }

    private func prepare(_ sql: String, arguments: [Any?]) throws -> OpaquePointer? {
        guard let handle else { throw SQLiteError.notOpen }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let prepared = statement else {
            throw SQLiteError.prepareFailed(message())
        }

        try bind(arguments: arguments, to: prepared)
        return prepared
    }

    private func bind(arguments: [Any?], to statement: OpaquePointer) throws {
        for (index, argument) in arguments.enumerated() {
            let position = Int32(index + 1)
            let code: Int32

            switch argument {
            case nil, is NSNull:
                code = sqlite3_bind_null(statement, position)
            case let value as String:
                code = value.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            case let value as NSString:
                let text = value as String
                code = text.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            case let value as Int:
                code = sqlite3_bind_int64(statement, position, sqlite3_int64(value))
            case let value as Int64:
                code = sqlite3_bind_int64(statement, position, value)
            case let value as Int32:
                code = sqlite3_bind_int64(statement, position, sqlite3_int64(value))
            case let value as UInt:
                code = sqlite3_bind_int64(statement, position, sqlite3_int64(value))
            case let value as Double:
                code = sqlite3_bind_double(statement, position, value)
            case let value as Float:
                code = sqlite3_bind_double(statement, position, Double(value))
            case let value as Bool:
                code = sqlite3_bind_int(statement, position, value ? 1 : 0)
            case let value as Date:
                code = sqlite3_bind_int64(statement, position, sqlite3_int64(value.timeIntervalSince1970))
            case let value as Data:
                code = value.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, position, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
                }
            case let value as URL:
                code = value.path.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            case let value as UUID:
                code = value.uuidString.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            default:
                let text = String(describing: argument ?? "")
                code = text.withCString { sqlite3_bind_text(statement, position, $0, -1, SQLITE_TRANSIENT) }
            }

            guard code == SQLITE_OK else {
                throw SQLiteError.bindFailed(message())
            }
        }
    }

    private func makeRow(from statement: OpaquePointer?) -> SQLiteRow {
        guard let statement else { return SQLiteRow(values: [:]) }

        let columnCount = sqlite3_column_count(statement)
        var values: [String: SQLiteStoredValue] = [:]
        values.reserveCapacity(Int(columnCount))

        for index in 0..<columnCount {
            guard let namePointer = sqlite3_column_name(statement, index) else { continue }
            let name = String(cString: namePointer)
            let type = sqlite3_column_type(statement, index)

            switch type {
            case SQLITE_INTEGER:
                values[name] = .integer(sqlite3_column_int64(statement, index))
            case SQLITE_FLOAT:
                values[name] = .real(sqlite3_column_double(statement, index))
            case SQLITE_BLOB:
                if let blob = sqlite3_column_blob(statement, index) {
                    let size = Int(sqlite3_column_bytes(statement, index))
                    values[name] = .blob(Data(bytes: blob, count: size))
                } else {
                    values[name] = .blob(Data())
                }
            case SQLITE_TEXT:
                if let textPointer = sqlite3_column_text(statement, index) {
                    values[name] = .text(String(cString: textPointer))
                } else {
                    values[name] = .null
                }
            default:
                values[name] = .null
            }
        }

        return SQLiteRow(values: values)
    }

    private func message() -> String {
        guard let handle else { return "SQLite error" }
        return String(cString: sqlite3_errmsg(handle))
    }
}

internal enum SQLiteError: Error, LocalizedError {
    case notOpen
    case openFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notOpen:
            return "SQLite connection not open"
        case .openFailed(let message):
            return "SQLite open failed: \(message)"
        case .prepareFailed(let message):
            return "SQLite prepare failed: \(message)"
        case .bindFailed(let message):
            return "SQLite bind failed: \(message)"
        case .executionFailed(let message):
            return "SQLite execution failed: \(message)"
        }
    }
}

// MARK: - Database Actor

public actor Database {
    public static let shared = Database()

    nonisolated public let path: String
    nonisolated public let version: Int = 21

    private var connection: SQLiteConnection?
    private var isReady = false

    private init() {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
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

    private func db() throws -> SQLiteConnection {
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
                content_text TEXT,
                content_type TEXT,
                content_hash TEXT,
                preview_text TEXT,
                ocr_text TEXT,
                source_app TEXT,
                original_url TEXT,
                tags TEXT,
                vault_import_path TEXT,
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
            source_app, original_url, tags, vault_import_path, created_at, updated_at, status, title,
            content_text, content_type, content_hash
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            capture_item_id = excluded.capture_item_id,
            type = excluded.type,
            source = excluded.source,
            content_path = excluded.content_path,
            preview_text = excluded.preview_text,
            ocr_text = excluded.ocr_text,
            source_app = excluded.source_app,
            original_url = excluded.original_url,
            tags = excluded.tags,
            vault_import_path = excluded.vault_import_path,
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
            item.sourceApp,
            item.originalUrl,
            item.tags,
            item.vaultImportPath,
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
            try await insertSourceItem(SourceItemRecord(from: item))
            count += 1
        }
        return count
    }

    public nonisolated func checkElectronDatabase() -> URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let electronPath = appSupport.appendingPathComponent("AcMind/acmind.db")
        if FileManager.default.fileExists(atPath: electronPath.path) {
            return electronPath
        }
        let legacyPath = appSupport.appendingPathComponent("AcMind/pinmind.db")
        if FileManager.default.fileExists(atPath: legacyPath.path) {
            return legacyPath
        }
        return nil
    }

    // MARK: - Asset Files

    public func insertAssetFile(_ asset: AssetFile) async throws {
        try db().execute(
            """
            INSERT INTO asset_files (id, source_item_id, file_name, file_path, mime_type, file_size, kind, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                source_item_id = excluded.source_item_id,
                file_name = excluded.file_name,
                file_path = excluded.file_path,
                mime_type = excluded.mime_type,
                file_size = excluded.file_size,
                kind = excluded.kind,
                created_at = excluded.created_at
            """,
            arguments: [
                asset.id,
                asset.sourceItemId,
                asset.fileName,
                asset.filePath,
                asset.mimeType,
                asset.fileSize,
                asset.kind.rawValue,
                Int(asset.createdAt.timeIntervalSince1970)
            ]
        )
    }

    public func getAssetFile(id: String) async throws -> AssetFile? {
        try db().queryOne("SELECT * FROM asset_files WHERE id = ? LIMIT 1", arguments: [id]) { row in
            AssetFile(row: row)
        }
    }

    public func listAssetFiles(sourceItemId: String? = nil, kind: String? = nil) async throws -> [AssetFile] {
        var sql = "SELECT * FROM asset_files WHERE 1=1"
        var arguments: [Any?] = []

        if let sourceItemId {
            sql += " AND source_item_id = ?"
            arguments.append(sourceItemId)
        }
        if let kind {
            sql += " AND kind = ?"
            arguments.append(kind)
        }

        sql += " ORDER BY created_at DESC"

        return try db().query(sql, arguments: arguments) { row in
            AssetFile(row: row)
        }
    }

    public func deleteAssetFile(id: String) async throws {
        try db().execute("DELETE FROM asset_files WHERE id = ?", arguments: [id])
    }

    public func assetFileExists(path: String) async throws -> Bool {
        try db().queryOne(
            "SELECT 1 AS exists_flag FROM asset_files WHERE file_path = ? LIMIT 1",
            arguments: [path]
        ) { _ in true } ?? false
    }
}

// MARK: - Record Models

public struct SourceItemRecord: Sendable, Codable, Equatable {
    public var id: String
    public var captureItemId: String?
    public var type: String
    public var source: String
    public var contentPath: String
    public var contentText: String?
    public var contentType: String?
    public var contentHash: String?
    public var previewText: String?
    public var ocrText: String?
    public var sourceApp: String?
    public var originalUrl: String?
    public var tags: String?
    public var vaultImportPath: String?
    public var createdAt: Int
    public var updatedAt: Int
    public var status: String
    public var title: String?

    public init(
        id: String = UUID().uuidString,
        captureItemId: String? = nil,
        type: String = "text",
        source: String = "manual",
        contentPath: String = "",
        contentText: String? = nil,
        contentType: String? = nil,
        contentHash: String? = nil,
        previewText: String? = nil,
        ocrText: String? = nil,
        sourceApp: String? = nil,
        originalUrl: String? = nil,
        tags: String? = nil,
        vaultImportPath: String? = nil,
        createdAt: Int = Int(Date().timeIntervalSince1970),
        updatedAt: Int = Int(Date().timeIntervalSince1970),
        status: String = "inbox",
        title: String? = nil
    ) {
        self.id = id
        self.captureItemId = captureItemId
        self.type = type
        self.source = source
        self.contentPath = contentPath
        self.contentText = contentText
        self.contentType = contentType
        self.contentHash = contentHash
        self.previewText = previewText
        self.ocrText = ocrText
        self.sourceApp = sourceApp
        self.originalUrl = originalUrl
        self.tags = tags
        self.vaultImportPath = vaultImportPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.title = title
    }

    public init(from item: SourceItem) {
        self.id = item.id
        self.captureItemId = item.captureItemId
        self.type = item.type.rawValue
        self.source = item.source.rawValue
        self.contentPath = item.contentPath ?? ""
        self.contentText = nil
        self.contentType = nil
        self.contentHash = item.contentHash
        self.previewText = item.previewText
        self.ocrText = item.ocrText
        self.sourceApp = item.sourceApp
        self.originalUrl = item.originalUrl
        self.tags = item.tags.isEmpty ? nil : String(data: (try? JSONEncoder().encode(item.tags)) ?? Data(), encoding: .utf8)
        self.vaultImportPath = item.vaultImportPath
        self.createdAt = Int(item.createdAt.timeIntervalSince1970)
        self.updatedAt = Int((item.updatedAt ?? item.createdAt).timeIntervalSince1970)
        self.status = item.status.rawValue
        self.title = item.title
    }

    public init(row: SQLiteRow) {
        self.id = row.string("id") ?? UUID().uuidString
        self.captureItemId = row.string("capture_item_id")
        self.type = row.string("type") ?? "text"
        self.source = row.string("source") ?? "manual"
        self.contentPath = row.string("content_path") ?? ""
        self.contentText = row.string("content_text")
        self.contentType = row.string("content_type")
        self.contentHash = row.string("content_hash")
        self.previewText = row.string("preview_text")
        self.ocrText = row.string("ocr_text")
        self.sourceApp = row.string("source_app")
        self.originalUrl = row.string("original_url")
        self.tags = row.string("tags")
        self.vaultImportPath = row.string("vault_import_path")
        self.createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
        self.updatedAt = row.int("updated_at") ?? self.createdAt
        self.status = row.string("status") ?? "inbox"
        self.title = row.string("title")
    }

    public func toSourceItem() -> SourceItem {
        SourceItem(
            id: id,
            type: SourceType(rawValue: type) ?? .text,
            source: SourceOrigin(rawValue: source) ?? .manual,
            status: SourceItemStatus(rawValue: status) ?? .inbox,
            title: title,
            contentPath: contentPath.isEmpty ? nil : contentPath,
            contentHash: contentHash,
            previewText: previewText,
            ocrText: ocrText,
            sourceApp: sourceApp,
            originalUrl: originalUrl,
            tags: decodedTags(),
            captureItemId: captureItemId,
            vaultImportPath: vaultImportPath,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedAt))
        )
    }

    private func decodedTags() -> [String] {
        guard let tags, !tags.isEmpty else { return [] }
        if let data = tags.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        return tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

public struct ChatSessionRecord: Sendable, Codable, Equatable {
    public var id: String
    public var title: String
    public var providerId: String?
    public var modelId: String?
    public var status: String
    public var metadata: String
    public var createdAt: Int
    public var updatedAt: Int

    public init(
        id: String = UUID().uuidString,
        title: String = "新对话",
        providerId: String? = nil,
        modelId: String? = nil,
        status: String = "active",
        metadata: String = "{}",
        createdAt: Int = Int(Date().timeIntervalSince1970),
        updatedAt: Int = Int(Date().timeIntervalSince1970)
    ) {
        self.id = id
        self.title = title
        self.providerId = providerId
        self.modelId = modelId
        self.status = status
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(row: SQLiteRow) {
        self.id = row.string("id") ?? UUID().uuidString
        self.title = row.string("title") ?? "新对话"
        self.providerId = row.string("provider_id")
        self.modelId = row.string("model_id")
        self.status = row.string("status") ?? "active"
        self.metadata = row.string("metadata") ?? "{}"
        self.createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
        self.updatedAt = row.int("updated_at") ?? createdAt
    }
}

public struct ChatMessageRecord: Sendable, Codable, Equatable {
    public var id: String
    public var sessionId: String
    public var role: String
    public var content: String
    public var status: String
    public var modelId: String?
    public var providerId: String?
    public var promptTokens: Int?
    public var completionTokens: Int?
    public var latencyMs: Int?
    public var error: String?
    public var actionProposals: String
    public var createdAt: Int

    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        role: String,
        content: String = "",
        status: String = "pending",
        modelId: String? = nil,
        providerId: String? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        latencyMs: Int? = nil,
        error: String? = nil,
        actionProposals: String = "[]",
        createdAt: Int = Int(Date().timeIntervalSince1970)
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.status = status
        self.modelId = modelId
        self.providerId = providerId
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.latencyMs = latencyMs
        self.error = error
        self.actionProposals = actionProposals
        self.createdAt = createdAt
    }

    public init(row: SQLiteRow) {
        self.id = row.string("id") ?? UUID().uuidString
        self.sessionId = row.string("session_id") ?? ""
        self.role = row.string("role") ?? "assistant"
        self.content = row.string("content") ?? ""
        self.status = row.string("status") ?? "pending"
        self.modelId = row.string("model_id")
        self.providerId = row.string("provider_id")
        self.promptTokens = row.int("prompt_tokens")
        self.completionTokens = row.int("completion_tokens")
        self.latencyMs = row.int("latency_ms")
        self.error = row.string("error")
        self.actionProposals = row.string("action_proposals") ?? "[]"
        self.createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
    }
}

public struct DistilledNoteRecord: Sendable, Codable, Equatable {
    public var id: String
    public var sourceItemId: String
    public var taskId: String?
    public var title: String?
    public var summary: String?
    public var category: String?
    public var tags: String?
    public var documentType: String?
    public var contentMarkdown: String?
    public var valueScore: Double?
    public var cleanSuggestion: String?
    public var confidence: Double?
    public var reviewStatus: String
    public var reviewedAt: Int?
    public var acceptedKnowledgeCardId: String?
    public var createdAt: Int
    public var updatedAt: Int

    var bindings: [Any?] {
        [
            id, sourceItemId, taskId, title, summary, category, tags, documentType,
            contentMarkdown, valueScore, cleanSuggestion, confidence, reviewStatus,
            reviewedAt, acceptedKnowledgeCardId, createdAt, updatedAt
        ]
    }

    var upsertSQL: String {
        """
        INSERT INTO distilled_notes (
            id, source_item_id, task_id, title, summary, category, tags, document_type,
            content_markdown, value_score, clean_suggestion, confidence, review_status,
            reviewed_at, accepted_knowledge_card_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            source_item_id = excluded.source_item_id,
            task_id = excluded.task_id,
            title = excluded.title,
            summary = excluded.summary,
            category = excluded.category,
            tags = excluded.tags,
            document_type = excluded.document_type,
            content_markdown = excluded.content_markdown,
            value_score = excluded.value_score,
            clean_suggestion = excluded.clean_suggestion,
            confidence = excluded.confidence,
            review_status = excluded.review_status,
            reviewed_at = excluded.reviewed_at,
            accepted_knowledge_card_id = excluded.accepted_knowledge_card_id,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at
        """
    }

    public init(from note: DistilledNote) {
        self.id = note.id
        self.sourceItemId = note.sourceItemId
        self.taskId = note.taskId
        self.title = note.title
        self.summary = note.summary
        self.category = note.category
        self.tags = String(data: (try? JSONEncoder().encode(note.tags)) ?? Data(), encoding: .utf8)
        self.documentType = note.documentType
        self.contentMarkdown = note.contentMarkdown
        self.valueScore = note.valueScore
        self.cleanSuggestion = note.cleanSuggestion
        self.confidence = note.confidence
        self.reviewStatus = note.reviewStatus.rawValue
        self.reviewedAt = note.reviewedAt.map { Int($0.timeIntervalSince1970) }
        self.acceptedKnowledgeCardId = note.acceptedKnowledgeCardId
        self.createdAt = Int(note.createdAt.timeIntervalSince1970)
        self.updatedAt = Int(note.updatedAt.timeIntervalSince1970)
    }

    public init(row: SQLiteRow) {
        self.id = row.string("id") ?? UUID().uuidString
        self.sourceItemId = row.string("source_item_id") ?? ""
        self.taskId = row.string("task_id")
        self.title = row.string("title")
        self.summary = row.string("summary")
        self.category = row.string("category")
        self.tags = row.string("tags")
        self.documentType = row.string("document_type")
        self.contentMarkdown = row.string("content_markdown")
        self.valueScore = row.double("value_score")
        self.cleanSuggestion = row.string("clean_suggestion")
        self.confidence = row.double("confidence")
        self.reviewStatus = row.string("review_status") ?? "pending"
        self.reviewedAt = row.int("reviewed_at")
        self.acceptedKnowledgeCardId = row.string("accepted_knowledge_card_id")
        self.createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
        self.updatedAt = row.int("updated_at") ?? createdAt
    }

    public func toDistilledNote() -> DistilledNote {
        DistilledNote(
            id: id,
            sourceItemId: sourceItemId,
            taskId: taskId,
            title: title,
            summary: summary,
            category: category,
            tags: decodedTags(),
            documentType: documentType,
            contentMarkdown: contentMarkdown,
            valueScore: valueScore,
            cleanSuggestion: cleanSuggestion,
            confidence: confidence,
            reviewStatus: ReviewStatus(rawValue: reviewStatus) ?? .pending,
            reviewedAt: reviewedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            acceptedKnowledgeCardId: acceptedKnowledgeCardId,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedAt))
        )
    }

    private func decodedTags() -> [String] {
        guard let tags, !tags.isEmpty,
              let data = tags.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }
}

public struct ExportRecordRow: Sendable, Codable, Equatable {
    public var id: String
    public var sourceItemId: String
    public var distilledOutputId: String
    public var knowledgeCardId: String?
    public var vaultPath: String
    public var relativeFilePath: String
    public var frontmatter: String
    public var exportedAt: Int
    public var status: String
    public var conflictResolution: String?

    var bindings: [Any?] {
        [
            id, sourceItemId, distilledOutputId, knowledgeCardId, vaultPath, relativeFilePath,
            frontmatter, exportedAt, status, conflictResolution
        ]
    }

    var upsertSQL: String {
        """
        INSERT INTO export_records (
            id, source_item_id, distilled_output_id, knowledge_card_id, vault_path,
            relative_file_path, frontmatter, exported_at, status, conflict_resolution
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            source_item_id = excluded.source_item_id,
            distilled_output_id = excluded.distilled_output_id,
            knowledge_card_id = excluded.knowledge_card_id,
            vault_path = excluded.vault_path,
            relative_file_path = excluded.relative_file_path,
            frontmatter = excluded.frontmatter,
            exported_at = excluded.exported_at,
            status = excluded.status,
            conflict_resolution = excluded.conflict_resolution
        """
    }

    public init(from record: ExportRecord) {
        self.id = record.id
        self.sourceItemId = record.sourceItemId
        self.distilledOutputId = record.distilledOutputId
        self.knowledgeCardId = record.knowledgeCardId
        self.vaultPath = record.vaultPath
        self.relativeFilePath = record.relativeFilePath
        self.frontmatter = String(data: (try? JSONEncoder().encode(record.frontmatter)) ?? Data(), encoding: .utf8) ?? "{}"
        self.exportedAt = Int(record.exportedAt.timeIntervalSince1970)
        self.status = record.status.rawValue
        self.conflictResolution = record.conflictResolution?.rawValue
    }

    public init(row: SQLiteRow) {
        self.id = row.string("id") ?? UUID().uuidString
        self.sourceItemId = row.string("source_item_id") ?? ""
        self.distilledOutputId = row.string("distilled_output_id") ?? ""
        self.knowledgeCardId = row.string("knowledge_card_id")
        self.vaultPath = row.string("vault_path") ?? ""
        self.relativeFilePath = row.string("relative_file_path") ?? ""
        self.frontmatter = row.string("frontmatter") ?? "{}"
        self.exportedAt = row.int("exported_at") ?? Int(Date().timeIntervalSince1970)
        self.status = row.string("status") ?? "success"
        self.conflictResolution = row.string("conflict_resolution")
    }

    public func toExportRecord() -> ExportRecord {
        let frontmatterData = frontmatter.data(using: .utf8) ?? Data()
        let decoded = (try? JSONDecoder().decode([String: String].self, from: frontmatterData)) ?? [:]
        return ExportRecord(
            id: id,
            sourceItemId: sourceItemId,
            distilledOutputId: distilledOutputId,
            knowledgeCardId: knowledgeCardId,
            vaultPath: vaultPath,
            relativeFilePath: relativeFilePath,
            frontmatter: decoded,
            exportedAt: Date(timeIntervalSince1970: TimeInterval(exportedAt)),
            status: ExportStatus(rawValue: status) ?? .success,
            conflictResolution: conflictResolution.flatMap { ConflictStrategy(rawValue: $0) }
        )
    }
}

public struct KnowledgeCardRecord: Sendable, Codable, Equatable {
    public var id: String
    public var sourceItemId: String
    public var distilledOutputId: String?
    public var exportRecordId: String?
    public var canonicalTitle: String
    public var summary: String?
    public var category: String?
    public var tags: String
    public var body: String?
    public var bodyMarkdown: String?
    public var documentType: String?
    public var valueScore: Double?
    public var confidence: Double?
    public var status: String
    public var vaultFilePath: String?
    public var searchVector: String?
    public var referenceCount: Int
    public var lastAccessedAt: Int?
    public var createdAt: Int
    public var updatedAt: Int

    var bindings: [Any?] {
        [
            id, sourceItemId, distilledOutputId, exportRecordId, canonicalTitle, summary,
            category, tags, body, bodyMarkdown, documentType, valueScore, confidence, status,
            vaultFilePath, searchVector, referenceCount, lastAccessedAt, createdAt, updatedAt
        ]
    }

    var upsertSQL: String {
        """
        INSERT INTO knowledge_cards (
            id, source_item_id, distilled_output_id, export_record_id, canonical_title,
            summary, category, tags, body, body_markdown, document_type, value_score,
            confidence, status, vault_file_path, search_vector, reference_count,
            last_accessed_at, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            source_item_id = excluded.source_item_id,
            distilled_output_id = excluded.distilled_output_id,
            export_record_id = excluded.export_record_id,
            canonical_title = excluded.canonical_title,
            summary = excluded.summary,
            category = excluded.category,
            tags = excluded.tags,
            body = excluded.body,
            body_markdown = excluded.body_markdown,
            document_type = excluded.document_type,
            value_score = excluded.value_score,
            confidence = excluded.confidence,
            status = excluded.status,
            vault_file_path = excluded.vault_file_path,
            search_vector = excluded.search_vector,
            reference_count = excluded.reference_count,
            last_accessed_at = excluded.last_accessed_at,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at
        """
    }

    public init(from card: KnowledgeCard) {
        self.id = card.id
        self.sourceItemId = card.sourceItemId
        self.distilledOutputId = card.distilledOutputId
        self.exportRecordId = card.exportRecordId
        self.canonicalTitle = card.canonicalTitle
        self.summary = card.summary
        self.category = card.category
        self.tags = String(data: (try? JSONEncoder().encode(card.tags)) ?? Data(), encoding: .utf8) ?? "[]"
        self.body = card.body
        self.bodyMarkdown = card.bodyMarkdown
        self.documentType = card.documentType
        self.valueScore = card.valueScore
        self.confidence = card.confidence
        self.status = card.status.rawValue
        self.vaultFilePath = card.vaultFilePath
        self.searchVector = card.searchVector
        self.referenceCount = card.referenceCount
        self.lastAccessedAt = card.lastAccessedAt.map { Int($0.timeIntervalSince1970) }
        self.createdAt = Int(card.createdAt.timeIntervalSince1970)
        self.updatedAt = Int(card.updatedAt.timeIntervalSince1970)
    }

    public init(row: SQLiteRow) {
        self.id = row.string("id") ?? UUID().uuidString
        self.sourceItemId = row.string("source_item_id") ?? ""
        self.distilledOutputId = row.string("distilled_output_id")
        self.exportRecordId = row.string("export_record_id")
        self.canonicalTitle = row.string("canonical_title") ?? ""
        self.summary = row.string("summary")
        self.category = row.string("category")
        self.tags = row.string("tags") ?? "[]"
        self.body = row.string("body")
        self.bodyMarkdown = row.string("body_markdown")
        self.documentType = row.string("document_type")
        self.valueScore = row.double("value_score")
        self.confidence = row.double("confidence")
        self.status = row.string("status") ?? "active"
        self.vaultFilePath = row.string("vault_file_path")
        self.searchVector = row.string("search_vector")
        self.referenceCount = row.int("reference_count") ?? 0
        self.lastAccessedAt = row.int("last_accessed_at")
        self.createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
        self.updatedAt = row.int("updated_at") ?? createdAt
    }

    public func toKnowledgeCard() -> KnowledgeCard {
        let tagsData = tags.data(using: .utf8) ?? Data()
        let decodedTags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        return KnowledgeCard(
            id: id,
            sourceItemId: sourceItemId,
            distilledOutputId: distilledOutputId,
            exportRecordId: exportRecordId,
            canonicalTitle: canonicalTitle,
            summary: summary,
            category: category,
            tags: decodedTags,
            body: body,
            bodyMarkdown: bodyMarkdown,
            documentType: documentType,
            valueScore: valueScore,
            confidence: confidence,
            status: KnowledgeCardStatus(rawValue: status) ?? .active,
            vaultFilePath: vaultFilePath,
            searchVector: searchVector,
            referenceCount: referenceCount,
            lastAccessedAt: lastAccessedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedAt))
        )
    }
}

// MARK: - Errors

public enum DatabaseError: Error, LocalizedError {
    case notInitialized
    case migrationFailed(String)
    case importFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .importFailed(let message):
            return "Import failed: \(message)"
        }
    }
}
