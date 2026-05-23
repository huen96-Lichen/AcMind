import Foundation

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
    public var transcript: String?
    public var polishedTranscript: String?
    public var sourceApp: String?
    public var originalUrl: String?
    public var tags: String?
    public var vaultImportPath: String?
    public var metadata: String?
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
        transcript: String? = nil,
        polishedTranscript: String? = nil,
        sourceApp: String? = nil,
        originalUrl: String? = nil,
        tags: String? = nil,
        vaultImportPath: String? = nil,
        metadata: String? = nil,
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
        self.transcript = transcript
        self.polishedTranscript = polishedTranscript
        self.sourceApp = sourceApp
        self.originalUrl = originalUrl
        self.tags = tags
        self.vaultImportPath = vaultImportPath
        self.metadata = metadata
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
        self.transcript = item.transcript
        self.polishedTranscript = item.polishedTranscript
        self.sourceApp = item.sourceApp
        self.originalUrl = item.originalUrl
        self.tags = item.tags.isEmpty ? nil : String(data: (try? JSONEncoder().encode(item.tags)) ?? Data(), encoding: .utf8)
        self.vaultImportPath = item.vaultImportPath
        self.metadata = item.metadata.isEmpty ? nil : String(data: (try? JSONEncoder().encode(item.metadata)) ?? Data(), encoding: .utf8)
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
        self.transcript = row.string("transcript")
        self.polishedTranscript = row.string("polished_transcript")
        self.sourceApp = row.string("source_app")
        self.originalUrl = row.string("original_url")
        self.tags = row.string("tags")
        self.vaultImportPath = row.string("vault_import_path")
        self.metadata = row.string("metadata")
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
            transcript: transcript,
            polishedTranscript: polishedTranscript,
            sourceApp: sourceApp,
            originalUrl: originalUrl,
            tags: decodedTags(),
            captureItemId: captureItemId,
            vaultImportPath: vaultImportPath,
            assetFileIds: [],
            metadata: decodedMetadata(),
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

    private func decodedMetadata() -> [String: String] {
        guard let metadata, !metadata.isEmpty else { return [:] }
        if let data = metadata.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            return decoded
        }
        return [:]
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

public struct ProviderConfigRecord: Sendable, Codable, Equatable {
    public var id: String
    public var name: String
    public var providerType: String
    public var tier: String
    public var baseURL: String
    public var apiKeyRef: String?
    public var modelId: String
    public var enabled: Int
    public var capabilities: String
    public var createdAt: Int
    public var updatedAt: Int

    var bindings: [Any?] {
        [
            id, name, providerType, tier, baseURL, apiKeyRef, modelId,
            enabled, capabilities, createdAt, updatedAt
        ]
    }

    var upsertSQL: String {
        """
        INSERT INTO provider_configs (
            id, name, provider_type, tier, base_url, api_key_ref, model_id,
            enabled, capabilities, created_at, updated_at
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
            updated_at = excluded.updated_at
        """
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        providerType: String,
        tier: String,
        baseURL: String,
        apiKeyRef: String? = nil,
        modelId: String,
        enabled: Bool = true,
        capabilities: [String] = [],
        createdAt: Int = Int(Date().timeIntervalSince1970),
        updatedAt: Int = Int(Date().timeIntervalSince1970)
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.tier = tier
        self.baseURL = baseURL
        self.apiKeyRef = apiKeyRef
        self.modelId = modelId
        self.enabled = enabled ? 1 : 0
        self.capabilities = String(data: (try? JSONEncoder().encode(capabilities)) ?? Data(), encoding: .utf8) ?? "[]"
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from config: ProviderConfig, createdAt: Int = Int(Date().timeIntervalSince1970), updatedAt: Int = Int(Date().timeIntervalSince1970)) {
        self.init(
            id: config.id,
            name: config.name,
            providerType: config.providerType.storageValue,
            tier: config.tier.storageValue,
            baseURL: config.baseURL,
            apiKeyRef: config.apiKeyRef,
            modelId: config.modelId,
            enabled: config.enabled,
            capabilities: config.capabilities,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public init(row: SQLiteRow) {
        self.id = row.string("id") ?? UUID().uuidString
        self.name = row.string("name") ?? ""
        self.providerType = row.string("provider_type") ?? "ollama"
        self.tier = row.string("tier") ?? "local_light"
        self.baseURL = row.string("base_url") ?? ""
        self.apiKeyRef = row.string("api_key_ref")
        self.modelId = row.string("model_id") ?? ""
        self.enabled = row.int("enabled") ?? 1
        self.capabilities = row.string("capabilities") ?? "[]"
        self.createdAt = row.int("created_at") ?? Int(Date().timeIntervalSince1970)
        self.updatedAt = row.int("updated_at") ?? createdAt
    }

    public func toProviderConfig() -> ProviderConfig {
        let data = capabilities.data(using: .utf8) ?? Data()
        let decoded = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return ProviderConfig(
            id: id,
            name: name,
            providerType: ProviderType.fromStorageValue(providerType),
            tier: ProviderTier.fromStorageValue(tier),
            baseURL: baseURL,
            apiKeyRef: apiKeyRef,
            modelId: modelId,
            enabled: enabled == 1,
            capabilities: decoded
        )
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
