import Foundation

extension Database {
    // MARK: - Process Jobs

    public func insertProcessJob(_ job: ProcessJob) async throws {
        let inputJSON = job.input.map { String(data: (try? JSONEncoder().encode($0)) ?? Data(), encoding: .utf8) ?? "{}" } ?? "{}"
        let outputJSON: String? = job.output.map { String(data: (try? JSONEncoder().encode($0)) ?? Data(), encoding: .utf8) ?? "{}" }
        try db().execute(
            """
            INSERT INTO process_jobs (id, source_item_id, job_type, status, input, output, error, progress, result, created_at, started_at, finished_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                status = excluded.status,
                output = excluded.output,
                error = excluded.error,
                progress = excluded.progress,
                result = excluded.result,
                started_at = excluded.started_at,
                finished_at = excluded.finished_at
            """,
            arguments: [
                job.id, job.sourceItemId as Any, job.jobType.rawValue, job.status.rawValue,
                inputJSON, outputJSON as Any, job.error as Any,
                job.progress as Any, job.result as Any,
                Int(job.createdAt.timeIntervalSince1970),
                job.startedAt.map { Int($0.timeIntervalSince1970) } as Any,
                job.finishedAt.map { Int($0.timeIntervalSince1970) } as Any
            ]
        )
    }

    public func getProcessJob(id: String) async throws -> ProcessJob? {
        try db().queryOne("SELECT * FROM process_jobs WHERE id = ? LIMIT 1", arguments: [id]) { row in
            self.rowToProcessJob(row)
        }
    }

    public func listProcessJobs(status: ProcessJobStatus? = nil) async throws -> [ProcessJob] {
        var sql = "SELECT * FROM process_jobs"
        var args: [Any] = []
        if let status = status {
            sql += " WHERE status = ?"
            args.append(status.rawValue)
        }
        sql += " ORDER BY created_at DESC"
        return try db().query(sql, arguments: args) { row in
            self.rowToProcessJob(row)
        }
    }

    public func updateProcessJobStatus(id: String, status: ProcessJobStatus, progress: Double?, result: String?) async throws {
        try db().execute(
            "UPDATE process_jobs SET status = ?, progress = ?, result = ? WHERE id = ?",
            arguments: [status.rawValue, progress as Any, result as Any, id]
        )
    }

    public func deleteProcessJob(id: String) async throws {
        try db().execute("DELETE FROM process_jobs WHERE id = ?", arguments: [id])
    }

    func rowToProcessJob(_ row: SQLiteRow) -> ProcessJob {
        let inputStr = row.string("input") ?? "{}"
        let outputStr = row.string("output")
        let input: [String: AnyCodable]? = (try? JSONDecoder().decode([String: AnyCodable].self, from: inputStr.data(using: .utf8) ?? Data()))
        let output: [String: AnyCodable]? = outputStr.flatMap { try? JSONDecoder().decode([String: AnyCodable].self, from: $0.data(using: .utf8) ?? Data()) }
        return ProcessJob(
            id: row.string("id") ?? UUID().uuidString,
            sourceItemId: row.string("source_item_id"),
            jobType: ProcessJobType(rawValue: row.string("job_type") ?? "ocr") ?? .ocr,
            status: ProcessJobStatus(rawValue: row.string("status") ?? "queued") ?? .queued,
            input: input,
            output: output,
            error: row.string("error"),
            createdAt: Date(timeIntervalSince1970: TimeInterval(row.int("created_at") ?? Int(Date().timeIntervalSince1970))),
            startedAt: row.int("started_at").map { Date(timeIntervalSince1970: TimeInterval($0)) },
            finishedAt: row.int("finished_at").map { Date(timeIntervalSince1970: TimeInterval($0)) },
            progress: row.double("progress"),
            result: row.string("result")
        )
    }

    // MARK: - Knowledge Cards

    func rowToKnowledgeCard(_ row: SQLiteRow) -> KnowledgeCard {
        let tags = (row.string("tags") ?? "").split(separator: ",").map(String.init)
        let status = KnowledgeCardStatus(rawValue: row.string("status") ?? "active") ?? .active
        let createdAt = Date(timeIntervalSince1970: TimeInterval(row.int("created_at") ?? 0))
        let updatedAt = Date(timeIntervalSince1970: TimeInterval(row.int("updated_at") ?? 0))

        return KnowledgeCard(
            id: row.string("id") ?? UUID().uuidString,
            sourceItemId: row.string("source_item_id") ?? "",
            distilledOutputId: row.string("distilled_output_id"),
            exportRecordId: row.string("export_record_id"),
            canonicalTitle: row.string("canonical_title") ?? row.string("title") ?? "",
            summary: row.string("summary"),
            category: row.string("category"),
            tags: tags,
            body: row.string("body"),
            valueScore: row.double("value_score"),
            confidence: row.double("confidence"),
            status: status,
            vaultFilePath: row.string("vault_file_path"),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Knowledge Edges

    public func insertKnowledgeEdge(_ edge: KnowledgeEdge) async throws {
        try db().execute(
            """
            INSERT INTO knowledge_edges (id, from_knowledge_card_id, to_knowledge_card_id, relation_type, status, confidence, reason, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                relation_type = excluded.relation_type,
                status = excluded.status,
                confidence = excluded.confidence,
                reason = excluded.reason,
                updated_at = excluded.updated_at
            """,
            arguments: [
                edge.id, edge.fromKnowledgeCardId, edge.toKnowledgeCardId, edge.relationType,
                edge.status.rawValue,
                edge.confidence as Any,
                edge.reason as Any,
                Int(edge.createdAt.timeIntervalSince1970),
                Int(edge.updatedAt.timeIntervalSince1970)
            ]
        )
    }

    public func listKnowledgeEdges(fromCardId: String? = nil, toCardId: String? = nil) async throws -> [KnowledgeEdge] {
        var sql = "SELECT * FROM knowledge_edges"
        var args: [Any] = []
        if let fromId = fromCardId {
            sql += " WHERE from_knowledge_card_id = ?"
            args.append(fromId)
        } else if let toId = toCardId {
            sql += " WHERE to_knowledge_card_id = ?"
            args.append(toId)
        }
        sql += " ORDER BY created_at DESC"
        return try db().query(sql, arguments: args) { row in
            self.rowToKnowledgeEdge(row)
        }
    }

    public func deleteKnowledgeEdge(id: String) async throws {
        try db().execute("DELETE FROM knowledge_edges WHERE id = ?", arguments: [id])
    }

    func rowToKnowledgeEdge(_ row: SQLiteRow) -> KnowledgeEdge {
        KnowledgeEdge(
            id: row.string("id") ?? UUID().uuidString,
            fromKnowledgeCardId: row.string("from_knowledge_card_id") ?? "",
            toKnowledgeCardId: row.string("to_knowledge_card_id") ?? "",
            relationType: row.string("relation_type") ?? "",
            status: EdgeStatus(rawValue: row.string("status") ?? "suggested") ?? .suggested,
            confidence: row.double("confidence"),
            reason: row.string("reason"),
            createdAt: Date(timeIntervalSince1970: TimeInterval(row.int("created_at") ?? Int(Date().timeIntervalSince1970))),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(row.int("updated_at") ?? Int(Date().timeIntervalSince1970)))
        )
    }

    // MARK: - Scheduled Agent Tasks

    public func insertScheduledAgentTask(_ task: ScheduledAgentTask) async throws {
        let paramsJSON = task.inputParams.isEmpty ? "{}" : (String(data: (try? JSONEncoder().encode(task.inputParams)) ?? Data(), encoding: .utf8) ?? "{}")
        try db().execute(
            """
            INSERT INTO scheduled_agent_tasks (id, name, cron_expression, skill_name, input_params, enabled, last_run_at, last_run_status, last_run_task_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                cron_expression = excluded.cron_expression,
                skill_name = excluded.skill_name,
                input_params = excluded.input_params,
                enabled = excluded.enabled,
                last_run_at = excluded.last_run_at,
                last_run_status = excluded.last_run_status,
                last_run_task_id = excluded.last_run_task_id,
                updated_at = excluded.updated_at
            """,
            arguments: [
                task.id, task.name, task.cronExpression, task.skillName, paramsJSON,
                task.enabled ? 1 : 0,
                task.lastRunAt.map { Int($0.timeIntervalSince1970) } as Any,
                task.lastRunStatus as Any,
                task.lastRunTaskId as Any,
                Int(task.createdAt.timeIntervalSince1970),
                Int(task.updatedAt.timeIntervalSince1970)
            ]
        )
    }

    public func getScheduledAgentTask(id: String) async throws -> ScheduledAgentTask? {
        try db().queryOne("SELECT * FROM scheduled_agent_tasks WHERE id = ? LIMIT 1", arguments: [id]) { row in
            self.rowToScheduledAgentTask(row)
        }
    }

    public func listScheduledAgentTasks() async throws -> [ScheduledAgentTask] {
        try db().query("SELECT * FROM scheduled_agent_tasks ORDER BY created_at DESC") { row in
            self.rowToScheduledAgentTask(row)
        }
    }

    public func deleteScheduledAgentTask(id: String) async throws {
        try db().execute("DELETE FROM scheduled_agent_tasks WHERE id = ?", arguments: [id])
    }

    func rowToScheduledAgentTask(_ row: SQLiteRow) -> ScheduledAgentTask {
        let paramsStr = row.string("input_params") ?? "{}"
        let params: [String: String] = (try? JSONDecoder().decode([String: String].self, from: paramsStr.data(using: .utf8) ?? Data())) ?? [:]
        return ScheduledAgentTask(
            id: row.string("id") ?? UUID().uuidString,
            name: row.string("name") ?? "",
            cronExpression: row.string("cron_expression") ?? "",
            skillName: row.string("skill_name") ?? "",
            inputParams: params,
            enabled: (row.int("enabled") ?? 1) == 1,
            lastRunAt: row.int("last_run_at").map { Date(timeIntervalSince1970: TimeInterval($0)) },
            lastRunStatus: row.string("last_run_status"),
            lastRunTaskId: row.string("last_run_task_id"),
            createdAt: Date(timeIntervalSince1970: TimeInterval(row.int("created_at") ?? Int(Date().timeIntervalSince1970))),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(row.int("updated_at") ?? Int(Date().timeIntervalSince1970)))
        )
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
