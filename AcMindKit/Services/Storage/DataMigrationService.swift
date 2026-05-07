import Foundation

// MARK: - DataMigrationService

/// Electron → Swift 数据迁移服务
///
/// 采用本地 SQLite 直接读取旧库并写入新库，不依赖外部 ORM 包。
public actor DataMigrationService: Sendable {

    // MARK: - Types

    public struct MigrationResult: Sendable {
        public let migrated: Bool
        public let tables: [String: Int]
        public let errors: [String]
        public let duration: TimeInterval

        public init(migrated: Bool, tables: [String: Int], errors: [String], duration: TimeInterval) {
            self.migrated = migrated
            self.tables = tables
            self.errors = errors
            self.duration = duration
        }
    }

    public enum MigrationError: Error, LocalizedError {
        case electronDatabaseNotFound
        case swiftDatabaseNotReady
        case tableReadFailed(table: String, underlying: Error)
        case tableWriteFailed(table: String, underlying: Error)
        case migrationAlreadyCompleted

        public var errorDescription: String? {
            switch self {
            case .electronDatabaseNotFound:
                return "未找到 Electron 数据库，无需迁移"
            case .swiftDatabaseNotReady:
                return "Swift 数据库未就绪，无法执行迁移"
            case .tableReadFailed(let table, let underlying):
                return "读取表 '\(table)' 失败: \(underlying.localizedDescription)"
            case .tableWriteFailed(let table, let underlying):
                return "写入表 '\(table)' 失败: \(underlying.localizedDescription)"
            case .migrationAlreadyCompleted:
                return "数据迁移已完成，跳过"
            }
        }
    }

    private struct Plan {
        let name: String
        let migrate: (_ source: SQLiteConnection, _ target: SQLiteConnection) throws -> Int
    }

    // MARK: - Properties

    private let electronDBPath: URL?
    private let swiftDBPath: URL
    private let fileManager: FileManager

    // MARK: - Init

    public init(swiftDBPath: URL) {
        self.swiftDBPath = swiftDBPath
        self.fileManager = FileManager.default

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let electronPath = appSupport.appendingPathComponent("AcMind/acmind.db")
        let legacyPath = appSupport.appendingPathComponent("AcMind/pinmind.db")

        if fileManager.fileExists(atPath: electronPath.path) {
            self.electronDBPath = electronPath
        } else if fileManager.fileExists(atPath: legacyPath.path) {
            self.electronDBPath = legacyPath
        } else {
            self.electronDBPath = nil
        }
    }

    // MARK: - Public API

    public var needsMigration: Bool {
        electronDBPath != nil
    }

    public func runIfNeeded() async throws -> MigrationResult {
        guard let electronDBPath else {
            throw MigrationError.electronDatabaseNotFound
        }

        let startTime = Date()
        let target = try SQLiteConnection(path: swiftDBPath.path)

        if try isMigrationCompleted(in: target) {
            throw MigrationError.migrationAlreadyCompleted
        }

        let source = try SQLiteConnection(path: electronDBPath.path, readOnly: true)
        var tableCounts: [String: Int] = [:]
        var errors: [String] = []

        for plan in migrationPlans() {
            do {
                let count = try plan.migrate(source, target)
                tableCounts[plan.name] = count
            } catch {
                errors.append("\(plan.name): \(error.localizedDescription)")
            }
        }

        do {
            try target.execute(
                "INSERT INTO _migration (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                arguments: ["electron_imported", "true"]
            )
        } catch {
            errors.append("_migration 标记写入失败: \(error.localizedDescription)")
        }

        let backupPath = electronDBPath.appendingPathExtension("migrated")
        do {
            if fileManager.fileExists(atPath: backupPath.path) {
                try fileManager.removeItem(at: backupPath)
            }
            try fileManager.moveItem(at: electronDBPath, to: backupPath)
        } catch {
            errors.append("旧数据库备份失败: \(error.localizedDescription)")
        }

        return MigrationResult(
            migrated: true,
            tables: tableCounts,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Private

    private func isMigrationCompleted(in connection: SQLiteConnection) throws -> Bool {
        let rows = try connection.query(
            "SELECT value FROM _migration WHERE key = ? LIMIT 1",
            arguments: ["electron_imported"]
        ) { row in
            row.string("value") ?? ""
        }
        return rows.first == "true"
    }

    private func migrationPlans() -> [Plan] {
        [
            Plan(name: "source_items") { source, target in
                try self.migrateRows(
                    table: "source_items",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO source_items (
                            id, capture_item_id, type, source, content_path, content_text, content_type, content_hash,
                            preview_text, ocr_text, source_app, original_url, tags, vault_import_path, created_at,
                            updated_at, status, title
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            capture_item_id = excluded.capture_item_id,
                            type = excluded.type,
                            source = excluded.source,
                            content_path = excluded.content_path,
                            content_text = excluded.content_text,
                            content_type = excluded.content_type,
                            content_hash = excluded.content_hash,
                            preview_text = excluded.preview_text,
                            ocr_text = excluded.ocr_text,
                            source_app = excluded.source_app,
                            original_url = excluded.original_url,
                            tags = excluded.tags,
                            vault_import_path = excluded.vault_import_path,
                            created_at = excluded.created_at,
                            updated_at = excluded.updated_at,
                            status = excluded.status,
                            title = excluded.title
                    """,
                    mapRow: { row in
                        let createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
                        let updatedAt = row.int("updated_at") ?? createdAt
                        return [
                            row.string("id") ?? UUID().uuidString,
                            row.string("capture_item_id"),
                            row.string("type") ?? row.string("content_type") ?? "text",
                            row.string("source") ?? "imported",
                            row.string("content_path") ?? "",
                            row.string("content_text") ?? row.string("preview_text"),
                            row.string("content_type"),
                            row.string("content_hash"),
                            row.string("preview_text") ?? row.string("content_text"),
                            row.string("ocr_text"),
                            row.string("source_app"),
                            row.string("original_url") ?? row.string("source_url"),
                            row.string("tags") ?? row.string("metadata_json"),
                            row.string("vault_import_path"),
                            createdAt,
                            updatedAt,
                            row.string("status") ?? "inbox",
                            row.string("title")
                        ]
                    }
                )
            },
            Plan(name: "chat_sessions") { source, target in
                try self.migrateRows(
                    table: "chat_sessions",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO chat_sessions (
                            id, title, provider_id, model_id, status, metadata, created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            title = excluded.title,
                            provider_id = excluded.provider_id,
                            model_id = excluded.model_id,
                            status = excluded.status,
                            metadata = excluded.metadata,
                            created_at = excluded.created_at,
                            updated_at = excluded.updated_at
                    """,
                    mapRow: { row in
                        let createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
                        let updatedAt = row.int("updated_at") ?? createdAt
                        return [
                            row.string("id") ?? UUID().uuidString,
                            row.string("title") ?? "新对话",
                            row.string("provider_id") ?? row.string("provider"),
                            row.string("model_id") ?? row.string("model"),
                            row.string("status") ?? "active",
                            row.string("metadata") ?? row.string("metadata_json") ?? "{}",
                            createdAt,
                            updatedAt
                        ]
                    }
                )
            },
            Plan(name: "chat_messages") { source, target in
                try self.migrateRows(
                    table: "chat_messages",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO chat_messages (
                            id, session_id, role, content, status, model_id, provider_id,
                            prompt_tokens, completion_tokens, latency_ms, error, action_proposals, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                    """,
                    mapRow: { row in
                        [
                            row.string("id") ?? UUID().uuidString,
                            row.string("session_id") ?? "",
                            row.string("role") ?? "assistant",
                            row.string("content") ?? "",
                            row.string("status") ?? "pending",
                            row.string("model_id") ?? row.string("model"),
                            row.string("provider_id") ?? row.string("provider"),
                            row.int("prompt_tokens") ?? row.int("tokens_in"),
                            row.int("completion_tokens") ?? row.int("tokens_out"),
                            row.int("latency_ms"),
                            row.string("error") ?? row.string("error_message"),
                            row.string("action_proposals") ?? "[]",
                            row.int("created_at") ?? Int(Date().timeIntervalSince1970)
                        ]
                    }
                )
            },
            Plan(name: "app_settings") { source, target in
                try self.migrateRows(
                    table: "app_settings",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO app_settings (key, value) VALUES (?, ?)
                        ON CONFLICT(key) DO UPDATE SET value = excluded.value
                    """,
                    mapRow: { row in
                        [row.string("key") ?? "", row.string("value") ?? ""]
                    }
                )
            },
            Plan(name: "asset_files") { source, target in
                try self.migrateRows(
                    table: "asset_files",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO asset_files (
                            id, source_item_id, file_name, file_path, mime_type, file_size, kind, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            source_item_id = excluded.source_item_id,
                            file_name = excluded.file_name,
                            file_path = excluded.file_path,
                            mime_type = excluded.mime_type,
                            file_size = excluded.file_size,
                            kind = excluded.kind,
                            created_at = excluded.created_at
                    """,
                    mapRow: { row in
                        [
                            row.string("id") ?? UUID().uuidString,
                            row.string("source_item_id"),
                            row.string("file_name") ?? row.string("name") ?? "",
                            row.string("file_path") ?? row.string("path") ?? "",
                            row.string("mime_type"),
                            row.int("file_size"),
                            row.string("kind") ?? "other",
                            row.int("created_at") ?? Int(Date().timeIntervalSince1970)
                        ]
                    }
                )
            },
            Plan(name: "clipboard_items") { source, target in
                try self.migrateRows(
                    table: "clipboard_items",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO clipboard_items (
                            id, type, content, text_content, source_app, is_pinned, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            type = excluded.type,
                            content = excluded.content,
                            text_content = excluded.text_content,
                            source_app = excluded.source_app,
                            is_pinned = excluded.is_pinned,
                            created_at = excluded.created_at
                    """,
                    mapRow: { row in
                        [
                            row.string("id") ?? UUID().uuidString,
                            row.string("type") ?? "text",
                            row.string("content") ?? row.string("text_content"),
                            row.string("text_content") ?? row.string("content"),
                            row.string("source_app"),
                            row.bool("is_pinned") ?? false,
                            row.int("created_at") ?? Int(Date().timeIntervalSince1970)
                        ]
                    }
                )
            },
            Plan(name: "shelf_items") { source, target in
                try self.migrateRows(
                    table: "shelf_items",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO shelf_items (
                            id, source_item_id, file_path, label, status, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            source_item_id = excluded.source_item_id,
                            file_path = excluded.file_path,
                            label = excluded.label,
                            status = excluded.status,
                            created_at = excluded.created_at
                    """,
                    mapRow: { row in
                        [
                            row.string("id") ?? UUID().uuidString,
                            row.string("source_item_id"),
                            row.string("file_path"),
                            row.string("label") ?? row.string("name"),
                            row.string("status") ?? "pending",
                            row.int("created_at") ?? Int(Date().timeIntervalSince1970)
                        ]
                    }
                )
            },
            Plan(name: "distilled_notes") { source, target in
                try self.migrateRows(
                    table: "distilled_notes",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO distilled_notes (
                            id, source_item_id, title, content, tags, category, created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            source_item_id = excluded.source_item_id,
                            title = excluded.title,
                            content = excluded.content,
                            tags = excluded.tags,
                            category = excluded.category,
                            created_at = excluded.created_at,
                            updated_at = excluded.updated_at
                    """,
                    mapRow: { row in
                        let createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
                        let updatedAt = row.int("updated_at") ?? createdAt
                        return [
                            row.string("id") ?? UUID().uuidString,
                            row.string("source_item_id") ?? "",
                            row.string("title"),
                            row.string("content") ?? row.string("summary"),
                            row.string("tags"),
                            row.string("category"),
                            createdAt,
                            updatedAt
                        ]
                    }
                )
            },
            Plan(name: "process_jobs") { source, target in
                try self.migrateRows(
                    table: "process_jobs",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO process_jobs (
                            id, source_item_id, job_type, status, input, output, error, created_at, started_at, finished_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            source_item_id = excluded.source_item_id,
                            job_type = excluded.job_type,
                            status = excluded.status,
                            input = excluded.input,
                            output = excluded.output,
                            error = excluded.error,
                            created_at = excluded.created_at,
                            started_at = excluded.started_at,
                            finished_at = excluded.finished_at
                    """,
                    mapRow: { row in
                        [
                            row.string("id") ?? UUID().uuidString,
                            row.string("source_item_id"),
                            row.string("job_type") ?? row.string("type") ?? "parse",
                            row.string("status") ?? "queued",
                            row.string("input") ?? row.string("metadata_json") ?? "{}",
                            row.string("output"),
                            row.string("error"),
                            row.int("created_at") ?? Int(Date().timeIntervalSince1970),
                            row.int("started_at"),
                            row.int("finished_at")
                        ]
                    }
                )
            },
            Plan(name: "provider_configs") { source, target in
                try self.migrateRows(
                    table: "provider_configs",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO provider_configs (
                            id, name, provider_type, tier, base_url, api_key_ref, model_id, enabled, capabilities, created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            name = excluded.name,
                            provider_type = excluded.provider_type,
                            tier = excluded.tier,
                            base_url = excluded.base_url,
                            api_key_ref = excluded.api_key_ref,
                            model_id = excluded.model_id,
                            enabled = excluded.enabled,
                            capabilities = excluded.capabilities,
                            created_at = excluded.created_at,
                            updated_at = excluded.updated_at
                    """,
                    mapRow: { row in
                        let enabled = row.bool("enabled") ?? ((row.int("is_active") ?? 1) != 0)
                        let createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
                        let updatedAt = row.int("updated_at") ?? createdAt
                        return [
                            row.string("id") ?? UUID().uuidString,
                            row.string("name") ?? "",
                            row.string("provider_type") ?? row.string("type") ?? "ollama",
                            row.string("tier") ?? "local_light",
                            row.string("base_url") ?? "",
                            row.string("api_key_ref") ?? row.string("api_key"),
                            row.string("model_id") ?? row.string("default_model") ?? "",
                            enabled,
                            row.string("capabilities") ?? row.string("metadata_json") ?? "[]",
                            createdAt,
                            updatedAt
                        ]
                    }
                )
            },
            Plan(name: "vault_config") { source, target in
                try self.migrateRows(
                    table: "vault_config",
                    source: source,
                    target: target,
                    insertSQL: """
                        INSERT INTO vault_config (
                            id, vault_path, default_folder, template, path_rule, conflict_strategy, auto_frontmatter, frontmatter_template
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET
                            vault_path = excluded.vault_path,
                            default_folder = excluded.default_folder,
                            template = excluded.template,
                            path_rule = excluded.path_rule,
                            conflict_strategy = excluded.conflict_strategy,
                            auto_frontmatter = excluded.auto_frontmatter,
                            frontmatter_template = excluded.frontmatter_template
                    """,
                    mapRow: { row in
                        return [
                            1,
                            row.string("vault_path") ?? row.string("path") ?? "",
                            row.string("default_folder") ?? row.string("name") ?? "Inbox",
                            row.string("template") ?? "",
                            row.string("path_rule") ?? "category_date",
                            row.string("conflict_strategy") ?? "rename",
                            row.bool("auto_frontmatter") ?? true,
                            row.string("frontmatter_template") ?? row.string("metadata_json") ?? "{}"
                        ]
                    }
                )
            }
        ]
    }

    private func migrateRows(
        table: String,
        source: SQLiteConnection,
        target: SQLiteConnection,
        insertSQL: String,
        mapRow: @escaping (SQLiteRow) -> [Any?]
    ) throws -> Int {
        guard try source.tableExists(table) else { return 0 }

        let rows = try source.query("SELECT * FROM \(table)") { row in row }
        guard !rows.isEmpty else { return 0 }

        var count = 0
        for row in rows {
            do {
                try target.execute(insertSQL, arguments: mapRow(row))
                count += 1
            } catch {
                // 单条失败不阻断整表迁移
            }
        }
        return count
    }
}
