import Foundation
import CoreGraphics

// MARK: - StorageServiceProtocol

public protocol StorageServiceProtocol: Sendable {
    // SourceItem
    func insertSourceItem(_ item: SourceItem) async throws
    func getSourceItem(id: String) async throws -> SourceItem?
    func listSourceItems(filter: SourceItemFilter?) async throws -> [SourceItem]
    func updateSourceItem(_ item: SourceItem) async throws
    func deleteSourceItem(id: String) async throws

    // Chat
    func insertChatSession(_ session: ChatSession) async throws
    func getChatSession(id: String) async throws -> ChatSession?
    func listChatSessions(status: String?) async throws -> [ChatSession]
    func updateChatSession(_ session: ChatSession) async throws
    func deleteChatSession(id: String) async throws
    func insertChatMessage(_ message: ChatMessage) async throws
    func listChatMessages(sessionId: String) async throws -> [ChatMessage]

    // Distilled notes
    func insertDistilledNote(_ note: DistilledNote) async throws
    func updateDistilledNote(_ note: DistilledNote) async throws
    func listDistilledNotes() async throws -> [DistilledNote]

    // Export records
    func insertExportRecord(_ record: ExportRecord) async throws
    func listExportRecords() async throws -> [ExportRecord]

    // Knowledge cards
    func insertKnowledgeCard(_ card: KnowledgeCard) async throws
    func updateKnowledgeCard(_ card: KnowledgeCard) async throws
    func listKnowledgeCards(status: KnowledgeCardStatus?) async throws -> [KnowledgeCard]

    // Knowledge edges
    func insertKnowledgeEdge(_ edge: KnowledgeEdge) async throws
    func listKnowledgeEdges(fromCardId: String?, toCardId: String?) async throws -> [KnowledgeEdge]
    func deleteKnowledgeEdge(id: String) async throws

    // Clipboard items
    func insertClipboardItem(_ item: ClipboardItem) async throws
    func listClipboardItems(limit: Int?) async throws -> [ClipboardItem]
    func updateClipboardItem(_ item: ClipboardItem) async throws
    func deleteClipboardItem(id: String) async throws

    // Settings
    func getSetting(key: String) async throws -> String?
    func setSetting(key: String, value: String) async throws

    // Migration
    func importFromJSON(_ items: [SourceItem]) async throws -> Int
    func checkElectronDatabase() -> URL?

    // Info
    func getDatabasePath() -> String
    func getDatabaseVersion() async throws -> Int
}

public struct SourceItemFilter: Sendable, Equatable {
    public let status: SourceItemStatus?
    public let type: SourceType?
    public let searchQuery: String?
    public let limit: Int?

    public init(status: SourceItemStatus? = nil, type: SourceType? = nil, searchQuery: String? = nil, limit: Int? = nil) {
        self.status = status
        self.type = type
        self.searchQuery = searchQuery
        self.limit = limit
    }
}

// MARK: - CaptureServiceProtocol

public protocol CaptureServiceProtocol: Sendable {
    func captureScreenshot(mode: ScreenshotMode) async throws -> CaptureResult
    func captureFromClipboard() async throws -> CaptureResult?
    func captureFromFile(url: URL) async throws -> CaptureResult
    func captureFromWebpage(url: URL) async throws -> CaptureResult
    func captureFromManualText(_ text: String) async throws -> CaptureResult
    func captureFromVoice() async throws -> CaptureResult
}

// MARK: - ClipboardServiceProtocol

public protocol ClipboardServiceProtocol: Sendable {
    func startWatching() async
    func stopWatching() async
    func listItems(filter: ClipboardFilter?) async throws -> [ClipboardItem]
    func pinItem(id: String) async throws
    func unpinItem(id: String) async throws
    func deleteItem(id: String) async throws
    func saveToInbox(id: String) async throws -> SourceItem
    func copyItem(id: String) async throws
    func clearHistory() async throws
}

// MARK: - DistillServiceProtocol

public protocol DistillServiceProtocol: Sendable {
    func distill(sourceItem: SourceItem) async throws -> DistilledNote
    func batchDistill(sourceItems: [SourceItem]) async throws -> [DistilledNote]
    func review(noteId: String, action: ReviewAction) async throws -> DistilledNote?
}

// MARK: - ExportServiceProtocol

public protocol ExportServiceProtocol: Sendable {
    func export(note: DistilledNote, config: ExportConfig) async throws -> ExportRecord
    func exportBatch(notes: [DistilledNote], config: ExportConfig) async throws -> [ExportRecord]
    func preview(note: DistilledNote, config: ExportConfig) async throws -> String
    func listExportRecords() async throws -> [ExportRecord]
    func resolveConflict(path: String, strategy: ConflictStrategy) async throws -> String
}

// MARK: - AIRuntimeProtocol

public protocol AIRuntimeProtocol: Sendable {
    func listProviders() async -> [ProviderConfig]
    func addProvider(_ config: ProviderConfig) async throws
    func updateProvider(_ config: ProviderConfig) async throws
    func removeProvider(id: String) async throws
    func healthCheck(providerId: String) async throws -> Bool
    func listJobs() async throws -> [ProcessJob]
    func cancelJob(id: String) async throws
    func runDistillation(sourceItem: SourceItem) async throws -> DistilledNote
    func chat(messages: [ChatMessage]) async throws -> ChatResponse
    func chat(messages: [ChatMessage], providerId: String, model: String?) async throws -> ChatResponse
    func chatStream(messages: [ChatMessage]) -> AsyncThrowingStream<ChatResponse, Error>
}

// MARK: - AIProvider

public protocol AIProvider: Sendable {
    func chat(messages: [ChatMessage], config: ChatConfig) async throws -> ChatResponse
    func chatStream(messages: [ChatMessage], config: ChatConfig) -> AsyncThrowingStream<ChatResponse, Error>
    func listModels() async throws -> [String]
    func healthCheck() async throws -> Bool
}

// MARK: - KnowledgeServiceProtocol

public protocol KnowledgeServiceProtocol: Sendable {
    func listCards(filter: KnowledgeCardFilter?) async throws -> [KnowledgeCard]
    func getCard(id: String) async throws -> KnowledgeCard?
    func searchCards(query: String) async throws -> [KnowledgeCard]
    func searchVault(query: String) async throws -> [VaultSearchResult]
    func createCard(from note: DistilledNote) async throws -> KnowledgeCard
    func updateCard(_ card: KnowledgeCard) async throws
    func deleteCard(id: String) async throws

    // Knowledge Edges
    func addEdge(_ edge: KnowledgeEdge) async throws
    func listEdges(fromCardId: String?, toCardId: String?) async throws -> [KnowledgeEdge]
    func deleteEdge(id: String) async throws
}

public struct KnowledgeCardFilter: Sendable, Equatable {
    public let status: KnowledgeCardStatus?
    public let category: String?
    public let tags: [String]?

    public init(status: KnowledgeCardStatus? = nil, category: String? = nil, tags: [String]? = nil) {
        self.status = status
        self.category = category
        self.tags = tags
    }
}

// MARK: - AssetStoreProtocol

public protocol AssetStoreProtocol: Sendable {
    func setup() async throws
    func getAsset(id: String) async throws -> AssetFile?
    func getAssetsForSourceItem(sourceItemId: String) async throws -> [AssetFile]
    func listAssets(kind: AssetFileKind?) async throws -> [AssetFile]
    func deleteAsset(id: String) async throws
    func deleteAssetsForSourceItem(sourceItemId: String) async throws
    func assetExists(asset: AssetFile) -> Bool
    func getTotalSize() async throws -> Int64
}
