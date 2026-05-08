import Foundation

/// Storage service implementation using local SQLite
/// Replaces the legacy JSON-based storage with proper SQLite persistence
public final class StorageService: StorageServiceProtocol, @unchecked Sendable {
    private let db = Database.shared
    
    public init() {}
    
    public func setup() async throws {
        try await db.setup()
    }
    
    // MARK: - SourceItem Operations
    
    public func insertSourceItem(_ item: SourceItem) async throws {
        let record = SourceItemRecord(from: item)
        try await db.insertSourceItem(record)
    }
    
    public func getSourceItem(id: String) async throws -> SourceItem? {
        let record = try await db.getSourceItem(id: id)
        return record?.toSourceItem()
    }
    
    public func listSourceItems(filter: SourceItemFilter?) async throws -> [SourceItem] {
        let records = try await db.listSourceItems(filter: filter)
        return records.map { $0.toSourceItem() }
    }
    
    public func updateSourceItem(_ item: SourceItem) async throws {
        let record = SourceItemRecord(from: item)
        try await db.updateSourceItem(record)
    }
    
    public func deleteSourceItem(id: String) async throws {
        try await db.deleteSourceItem(id: id)
    }
    
    // MARK: - Chat Session Operations
    
    public func insertChatSession(_ session: ChatSession) async throws {
        let record = ChatSessionRecord(from: session)
        try await db.insertChatSession(record)
    }
    
    public func getChatSession(id: String) async throws -> ChatSession? {
        let record = try await db.getChatSession(id: id)
        return record?.toChatSession()
    }
    
    public func listChatSessions(status: String?) async throws -> [ChatSession] {
        let records = try await db.listChatSessions(status: status)
        return records.map { $0.toChatSession() }
    }
    
    public func updateChatSession(_ session: ChatSession) async throws {
        let record = ChatSessionRecord(from: session)
        try await db.updateChatSession(record)
    }
    
    public func deleteChatSession(id: String) async throws {
        try await db.deleteChatSession(id: id)
    }
    
    // MARK: - Chat Message Operations
    
    public func insertChatMessage(_ message: ChatMessage) async throws {
        let record = ChatMessageRecord(from: message)
        try await db.insertChatMessage(record)
    }
    
    public func listChatMessages(sessionId: String) async throws -> [ChatMessage] {
        let records = try await db.listChatMessages(sessionId: sessionId)
        return records.map { $0.toChatMessage() }
    }

    // MARK: - Distilled Note Operations

    public func insertDistilledNote(_ note: DistilledNote) async throws {
        try await db.insertDistilledNote(note)
    }

    public func updateDistilledNote(_ note: DistilledNote) async throws {
        try await db.updateDistilledNote(note)
    }

    public func listDistilledNotes() async throws -> [DistilledNote] {
        try await db.listDistilledNotes()
    }

    // MARK: - Export Record Operations

    public func insertExportRecord(_ record: ExportRecord) async throws {
        try await db.insertExportRecord(record)
    }

    public func listExportRecords() async throws -> [ExportRecord] {
        try await db.listExportRecords()
    }

    // MARK: - Knowledge Card Operations

    public func insertKnowledgeCard(_ card: KnowledgeCard) async throws {
        try await db.insertKnowledgeCard(card)
    }

    public func updateKnowledgeCard(_ card: KnowledgeCard) async throws {
        try await db.updateKnowledgeCard(card)
    }

    public func listKnowledgeCards(status: KnowledgeCardStatus?) async throws -> [KnowledgeCard] {
        try await db.listKnowledgeCards(status: status)
    }

    // MARK: - Knowledge Edge Operations

    public func insertKnowledgeEdge(_ edge: KnowledgeEdge) async throws {
        try await db.insertKnowledgeEdge(edge)
    }

    public func listKnowledgeEdges(fromCardId: String?, toCardId: String?) async throws -> [KnowledgeEdge] {
        try await db.listKnowledgeEdges(fromCardId: fromCardId, toCardId: toCardId)
    }

    public func deleteKnowledgeEdge(id: String) async throws {
        try await db.deleteKnowledgeEdge(id: id)
    }

    // MARK: - Clipboard Item Operations

    public func insertClipboardItem(_ item: ClipboardItem) async throws {
        try await db.insertClipboardItem(item)
    }

    public func listClipboardItems(limit: Int?) async throws -> [ClipboardItem] {
        try await db.listClipboardItems(limit: limit)
    }

    public func updateClipboardItem(_ item: ClipboardItem) async throws {
        try await db.updateClipboardItem(item)
    }

    public func deleteClipboardItem(id: String) async throws {
        try await db.deleteClipboardItem(id: id)
    }

    // MARK: - Settings Operations
    
    public func getSetting(key: String) async throws -> String? {
        try await db.getSetting(key: key)
    }
    
    public func setSetting(key: String, value: String) async throws {
        try await db.setSetting(key: key, value: value)
    }
    
    // MARK: - Migration
    
    /// Import data from legacy JSON file
    /// - Parameter items: Array of SourceItem from legacy JSON
    /// - Returns: Number of items successfully imported
    public func importFromJSON(_ items: [SourceItem]) async throws -> Int {
        try await db.importFromJSON(items)
    }
    
    /// Check if Electron database exists for migration
    /// - Returns: URL to Electron database if found, nil otherwise
    public func checkElectronDatabase() -> URL? {
        db.checkElectronDatabase()
    }
    
    // MARK: - Database Info
    
    public func getDatabasePath() -> String { db.path }
    public func getDatabaseVersion() async throws -> Int { db.version }

}

// MARK: - Model Extensions

extension ChatSessionRecord {
    init(from session: ChatSession) {
        self.id = session.id
        self.title = session.title
        self.providerId = session.providerId
        self.modelId = session.modelId
        self.status = session.status.rawValue
        self.metadata = Self.encodeDictionary(session.metadata)
        self.createdAt = Int(session.createdAt.timeIntervalSince1970)
        self.updatedAt = Int(session.updatedAt.timeIntervalSince1970)
    }
    
    func toChatSession() -> ChatSession {
        let parsedStatus = ChatSessionStatus(rawValue: status) ?? .active
        return ChatSession(
            id: id,
            title: title,
            providerId: providerId,
            modelId: modelId,
            status: parsedStatus,
            metadata: Self.decodeDictionary(metadata),
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedAt))
        )
    }

    private static func encodeDictionary(_ value: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func decodeDictionary(_ value: String) -> [String: String] {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: String] else {
            return [:]
        }
        return dict
    }
}

extension ChatMessageRecord {
    init(from message: ChatMessage) {
        self.id = message.id
        self.sessionId = message.sessionId
        self.role = message.role.rawValue
        self.content = message.content
        self.status = message.status.rawValue
        self.modelId = message.modelId
        self.providerId = message.providerId
        self.promptTokens = message.promptTokens
        self.completionTokens = message.completionTokens
        self.latencyMs = message.latencyMs
        self.error = message.error
        self.actionProposals = Self.encodeActionProposals(message.actionProposals)
        self.createdAt = Int(message.createdAt.timeIntervalSince1970)
    }
    
    func toChatMessage() -> ChatMessage {
        let parsedRole = ChatRole(rawValue: role) ?? .assistant
        let parsedStatus = ChatMessageStatus(rawValue: status) ?? .pending
        return ChatMessage(
            id: id,
            sessionId: sessionId,
            role: parsedRole,
            content: content,
            status: parsedStatus,
            modelId: modelId,
            providerId: providerId,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            latencyMs: latencyMs,
            error: error,
            actionProposals: Self.decodeActionProposals(actionProposals),
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt))
        )
    }

    private static func encodeActionProposals(_ value: [ActionProposal]) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func decodeActionProposals(_ value: String) -> [ActionProposal] {
        guard let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ActionProposal].self, from: data) else {
            return []
        }
        return decoded
    }
}
