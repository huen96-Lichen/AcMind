import Foundation
import Combine
import CoreGraphics
import AppKit

public struct UnsupportedServiceCapabilityError: LocalizedError, Sendable, Equatable {
    public let service: String
    public let operation: String

    public init(service: String, operation: String) {
        self.service = service
        self.operation = operation
    }

    public var errorDescription: String? {
        "\(service) 未实现 \(operation) 能力"
    }
}

// MARK: - StorageServiceProtocol

public protocol StorageServiceProtocol: Sendable {
    func setup() async throws

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
    func deleteDistilledNote(id: String) async throws
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

    // Clipboard Tags
    func insertClipboardTag(_ tag: ClipboardTag) async throws
    func listClipboardTags() async throws -> [ClipboardTag]
    func deleteClipboardTag(id: String) async throws
    func listClipboardItemsByTag(_ tagName: String, limit: Int?) async throws -> [ClipboardItem]
    func addTagToClipboardItem(itemId: String, tagName: String) async throws
    func removeTagFromClipboardItem(itemId: String, tagName: String) async throws

    // Scheduled agent tasks
    func insertScheduledAgentTask(_ task: ScheduledAgentTask) async throws
    func getScheduledAgentTask(id: String) async throws -> ScheduledAgentTask?
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask]
    func deleteScheduledAgentTask(id: String) async throws

    // Provider configs
    func listProviders() async throws -> [ProviderConfig]
    func addProvider(_ config: ProviderConfig) async throws
    func updateProvider(_ config: ProviderConfig) async throws
    func removeProvider(id: String) async throws

    // Schedule Events
    func insertScheduleEvent(_ event: ScheduleEvent) async throws
    func updateScheduleEvent(_ event: ScheduleEvent) async throws
    func deleteScheduleEvent(id: String) async throws
    func listScheduleEvents() async throws -> [ScheduleEvent]
    func getScheduleEvent(id: String) async throws -> ScheduleEvent?

    // Settings
    func getSetting(key: String) async throws -> String?
    func setSetting(key: String, value: String) async throws
    func deleteSetting(key: String) async throws

    // Migration
    func importFromJSON(_ items: [SourceItem]) async throws -> Int
    func checkLegacyDatabase() -> URL?

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

// MARK: - Collected Item Repository

public struct CollectedItemFilter: Sendable, Equatable {
    public var searchQuery: String?
    public var sources: Set<CollectionSource>
    public var contentTypes: Set<CollectedContentType>
    public var statuses: Set<ProcessingStatus>
    public var pinnedOnly: Bool
    public var favoriteOnly: Bool
    public var limit: Int?

    public init(
        searchQuery: String? = nil,
        sources: Set<CollectionSource> = [],
        contentTypes: Set<CollectedContentType> = [],
        statuses: Set<ProcessingStatus> = [],
        pinnedOnly: Bool = false,
        favoriteOnly: Bool = false,
        limit: Int? = nil
    ) {
        self.searchQuery = searchQuery
        self.sources = sources
        self.contentTypes = contentTypes
        self.statuses = statuses
        self.pinnedOnly = pinnedOnly
        self.favoriteOnly = favoriteOnly
        self.limit = limit
    }
}

public enum CollectedItemSort: Sendable, Equatable {
    case newestFirst
    case oldestFirst
    case pinnedFirst
    case recentlyUpdated
}

public struct CollectedItemListResult: Sendable, Equatable {
    public var items: [CollectedItem]
    public var partialErrors: [String]

    public init(items: [CollectedItem], partialErrors: [String] = []) {
        self.items = items
        self.partialErrors = partialErrors
    }
}

@MainActor
public protocol CollectedItemRepositoryProtocol: Sendable {
    func list(filter: CollectedItemFilter, sort: CollectedItemSort) async -> CollectedItemListResult
    func pin(id: CollectedItemID) async throws
    func unpin(id: CollectedItemID) async throws
    func favorite(id: CollectedItemID, isFavorite: Bool) async throws
    func updateTags(id: CollectedItemID, tags: [String]) async throws
    func applyAIResult(id: CollectedItemID, result: CollectedItemAIResult) async throws -> CollectedItemID
    func archive(id: CollectedItemID) async throws
    func delete(id: CollectedItemID) async throws
    func saveClipboardItemToInbox(id: CollectedItemID) async throws -> CollectedItemID
    func enqueueForPaste(ids: [CollectedItemID])
    func getPasteQueueItems() -> [PasteQueue.QueueItem]
    func pasteNextInQueue() async throws -> ClipboardItem?
    func clearPasteQueue()
    func removePasteQueueItem(id: String)
    func reorderPasteQueue(from source: Int, to destination: Int)
    func clipboardMonitoringState() -> ClipboardMonitoringState
    func pauseClipboardMonitoring() async
    func resumeClipboardMonitoring() async
}

@MainActor
public final class CollectedItemRepository: CollectedItemRepositoryProtocol {
    private let storage: StorageServiceProtocol
    private let clipboardService: (any ClipboardServiceProtocol)?

    public init(
        storage: StorageServiceProtocol = StorageService(),
        clipboardService: (any ClipboardServiceProtocol)? = nil
    ) {
        self.storage = storage
        self.clipboardService = clipboardService
    }

    public func list(filter: CollectedItemFilter = CollectedItemFilter(), sort: CollectedItemSort = .newestFirst) async -> CollectedItemListResult {
        var items: [CollectedItem] = []
        var partialErrors: [String] = []

        do {
            let sourceItems = try await storage.listSourceItems(filter: nil)
            items.append(contentsOf: sourceItems.map(CollectedItem.init(sourceItem:)))
        } catch {
            partialErrors.append("source_items: \(error.localizedDescription)")
        }

        do {
            let clipboardItems: [ClipboardItem]
            if let clipboardService {
                clipboardItems = try await clipboardService.listItems(filter: nil)
            } else {
                clipboardItems = try await storage.listClipboardItems(limit: nil)
            }
            items.append(contentsOf: clipboardItems.map(CollectedItem.init(clipboardItem:)))
        } catch {
            partialErrors.append("clipboard_items: \(error.localizedDescription)")
        }

        let filtered = apply(filter: filter, to: items)
        let sorted = apply(sort: sort, to: filtered)
        let limited = filter.limit.map { Array(sorted.prefix($0)) } ?? sorted
        return CollectedItemListResult(items: limited, partialErrors: partialErrors)
    }

    public func pin(id: CollectedItemID) async throws {
        switch id.origin {
        case .sourceItem:
            try await mutateSourceItem(id.rawID) { item in
                item.metadata["isPinned"] = "true"
            }
        case .clipboardItem:
            if let clipboardService {
                try await clipboardService.pinItem(id: id.rawID)
            } else {
                try await mutateClipboardItem(id.rawID) { item in
                    item.isPinned = true
                }
            }
        }
    }

    public func unpin(id: CollectedItemID) async throws {
        switch id.origin {
        case .sourceItem:
            try await mutateSourceItem(id.rawID) { item in
                item.metadata["isPinned"] = "false"
            }
        case .clipboardItem:
            if let clipboardService {
                try await clipboardService.unpinItem(id: id.rawID)
            } else {
                try await mutateClipboardItem(id.rawID) { item in
                    item.isPinned = false
                }
            }
        }
    }

    public func favorite(id: CollectedItemID, isFavorite: Bool) async throws {
        switch id.origin {
        case .sourceItem:
            try await mutateSourceItem(id.rawID) { item in
                item.metadata["isFavorite"] = isFavorite ? "true" : "false"
            }
        case .clipboardItem:
            let newID = try await saveClipboardItemToInbox(id: id)
            try await favorite(id: newID, isFavorite: isFavorite)
        }
    }

    public func updateTags(id: CollectedItemID, tags: [String]) async throws {
        switch id.origin {
        case .sourceItem:
            try await mutateSourceItem(id.rawID) { item in
                item.tags = tags
            }
        case .clipboardItem:
            try await mutateClipboardItem(id.rawID) { item in
                item.tags = tags
            }
        }
    }

    public func applyAIResult(id: CollectedItemID, result: CollectedItemAIResult) async throws -> CollectedItemID {
        let resolvedID: CollectedItemID
        switch id.origin {
        case .sourceItem:
            resolvedID = id
        case .clipboardItem:
            resolvedID = try await saveClipboardItemToInbox(id: id)
        }

        try await mutateSourceItem(resolvedID.rawID) { item in
            if let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines), title.isEmpty == false {
                item.title = title
            }
            if let polishedText = result.polishedText?.trimmingCharacters(in: .whitespacesAndNewlines), polishedText.isEmpty == false {
                item.previewText = polishedText
                item.polishedTranscript = polishedText
            } else if let summary = result.summary?.trimmingCharacters(in: .whitespacesAndNewlines), summary.isEmpty == false {
                if let previewText = item.previewText, previewText.isEmpty == false {
                    item.metadata["preAISummaryPreview"] = previewText
                }
                item.previewText = summary
                item.metadata["aiSummary"] = summary
            }
            item.metadata["lastAIProcessedAt"] = ISO8601DateFormatter().string(from: Date())
            item.status = .distilled
        }
        return resolvedID
    }

    public func archive(id: CollectedItemID) async throws {
        switch id.origin {
        case .sourceItem:
            try await mutateSourceItem(id.rawID) { item in
                item.status = .archived
            }
        case .clipboardItem:
            let newID = try await saveClipboardItemToInbox(id: id)
            try await archive(id: newID)
        }
    }

    public func delete(id: CollectedItemID) async throws {
        switch id.origin {
        case .sourceItem:
            try await storage.deleteSourceItem(id: id.rawID)
        case .clipboardItem:
            if let clipboardService {
                try await clipboardService.deleteItem(id: id.rawID)
            } else {
                try await storage.deleteClipboardItem(id: id.rawID)
            }
        }
    }

    public func saveClipboardItemToInbox(id: CollectedItemID) async throws -> CollectedItemID {
        guard id.origin == .clipboardItem else { return id }
        if let clipboardService {
            let sourceItem = try await clipboardService.saveToInbox(id: id.rawID)
            return CollectedItemID(origin: .sourceItem, rawID: sourceItem.id)
        }

        let clipboardItems = try await storage.listClipboardItems(limit: nil)
        guard let item = clipboardItems.first(where: { $0.id == id.rawID }) else {
            throw CollectedItemRepositoryError.itemNotFound(id.stableValue)
        }
        let sourceItem = SourceItem(clipboardItem: item)
        try await storage.insertSourceItem(sourceItem)
        return CollectedItemID(origin: .sourceItem, rawID: sourceItem.id)
    }

    public func enqueueForPaste(ids: [CollectedItemID]) {
        let clipboardIDs = ids.filter { $0.origin == .clipboardItem }.map(\.rawID)
        clipboardService?.enqueueForSequentialPaste(ids: clipboardIDs)
    }

    public func getPasteQueueItems() -> [PasteQueue.QueueItem] {
        clipboardService?.getQueueItems() ?? []
    }

    public func pasteNextInQueue() async throws -> ClipboardItem? {
        try await clipboardService?.pasteNextInQueue()
    }

    public func clearPasteQueue() {
        clipboardService?.clearPasteQueue()
    }

    public func removePasteQueueItem(id: String) {
        clipboardService?.removeQueueItem(id: id)
    }

    public func reorderPasteQueue(from source: Int, to destination: Int) {
        clipboardService?.reorderQueue(from: source, to: destination)
    }

    public func clipboardMonitoringState() -> ClipboardMonitoringState {
        clipboardService?.monitoringState() ?? .unavailable
    }

    public func pauseClipboardMonitoring() async {
        await clipboardService?.pauseWatching()
    }

    public func resumeClipboardMonitoring() async {
        await clipboardService?.resumeWatching()
    }

    private func apply(filter: CollectedItemFilter, to items: [CollectedItem]) -> [CollectedItem] {
        items.filter { item in
            if filter.sources.isEmpty == false, filter.sources.contains(item.source) == false { return false }
            if filter.contentTypes.isEmpty == false, filter.contentTypes.contains(item.contentType) == false { return false }
            if filter.statuses.isEmpty == false, filter.statuses.contains(item.processingStatus) == false { return false }
            if filter.pinnedOnly, item.isPinned == false { return false }
            if filter.favoriteOnly, item.isFavorite == false { return false }
            if let query = filter.searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), query.isEmpty == false {
                let haystack = [
                    item.title,
                    item.previewText,
                    item.sourceApplication,
                    item.sourceDevice,
                    item.originalURL,
                    item.tags.joined(separator: " ")
                ]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
                return haystack.contains(query)
            }
            return true
        }
    }

    private func apply(sort: CollectedItemSort, to items: [CollectedItem]) -> [CollectedItem] {
        switch sort {
        case .newestFirst:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .pinnedFirst:
            return items.sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                return $0.createdAt > $1.createdAt
            }
        case .recentlyUpdated:
            return items.sorted { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }
        }
    }

    private func mutateSourceItem(_ rawID: String, mutate: (inout SourceItem) -> Void) async throws {
        guard var item = try await storage.getSourceItem(id: rawID) else {
            throw CollectedItemRepositoryError.itemNotFound("source:\(rawID)")
        }
        mutate(&item)
        item.updatedAt = Date()
        try await storage.updateSourceItem(item)
    }

    private func mutateClipboardItem(_ rawID: String, mutate: (inout ClipboardItem) -> Void) async throws {
        let items = try await storage.listClipboardItems(limit: nil)
        guard var item = items.first(where: { $0.id == rawID }) else {
            throw CollectedItemRepositoryError.itemNotFound("clipboard:\(rawID)")
        }
        mutate(&item)
        try await storage.updateClipboardItem(item)
    }
}

public enum CollectedItemRepositoryError: LocalizedError, Equatable {
    case itemNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .itemNotFound(let id):
            return "未找到收集项: \(id)"
        }
    }
}

// MARK: - Collected Inbox View Model

public enum InboxQuickFilter: String, Codable, Sendable, Hashable, CaseIterable {
    case all
    case pending
    case screenshotHistory
    case pinned
    case favorites
    case recent
}

public enum CollectedInboxViewMode: String, Codable, Sendable, Hashable, CaseIterable {
    case grid
    case list
}

public enum CollectedInboxDensity: String, Codable, Sendable, Hashable, CaseIterable {
    case standard
    case compact

    public var rowHeight: CGFloat {
        switch self {
        case .standard: return 84
        case .compact: return 64
        }
    }
}

public enum CollectedInboxSelectionMovement: Sendable, Equatable {
    case previous
    case next
}

public enum CollectedInboxPhase: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)
}

public struct CollectedInboxBatchOperationResult: Sendable, Equatable {
    public var actionTitle: String
    public var successCount: Int
    public var failureMessages: [String]
    public var failedIDs: [CollectedItemID]

    public var failureCount: Int { failedIDs.count }
    public var isPartialFailure: Bool { successCount > 0 && failureCount > 0 }
    public var isFailure: Bool { successCount == 0 && failureCount > 0 }

    public init(
        actionTitle: String,
        successCount: Int,
        failureMessages: [String] = [],
        failedIDs: [CollectedItemID] = []
    ) {
        self.actionTitle = actionTitle
        self.successCount = successCount
        self.failureMessages = failureMessages
        self.failedIDs = failedIDs
    }
}

public struct InboxFilterState: Sendable, Equatable {
    public var quickFilter: InboxQuickFilter
    public var searchQuery: String
    public var sources: Set<CollectionSource>
    public var contentTypes: Set<CollectedContentType>
    public var statuses: Set<ProcessingStatus>
    public var sort: CollectedItemSort

    public init(
        quickFilter: InboxQuickFilter = .all,
        searchQuery: String = "",
        sources: Set<CollectionSource> = [],
        contentTypes: Set<CollectedContentType> = [],
        statuses: Set<ProcessingStatus> = [],
        sort: CollectedItemSort = .newestFirst
    ) {
        self.quickFilter = quickFilter
        self.searchQuery = searchQuery
        self.sources = sources
        self.contentTypes = contentTypes
        self.statuses = statuses
        self.sort = sort
    }

    public var repositoryFilter: CollectedItemFilter {
        var resolvedStatuses = statuses
        var resolvedSources = sources
        var pinnedOnly = false
        var favoriteOnly = false

        switch quickFilter {
        case .all:
            break
        case .pending:
            resolvedStatuses.insert(.pending)
            resolvedStatuses.insert(.captured)
        case .screenshotHistory:
            resolvedSources.insert(.screenshot)
            resolvedSources.insert(.screenshotOCR)
        case .pinned:
            pinnedOnly = true
        case .favorites:
            favoriteOnly = true
        case .recent:
            break
        }

        return CollectedItemFilter(
            searchQuery: searchQuery,
            sources: resolvedSources,
            contentTypes: contentTypes,
            statuses: resolvedStatuses,
            pinnedOnly: pinnedOnly,
            favoriteOnly: favoriteOnly
        )
    }

    public var resolvedSort: CollectedItemSort {
        quickFilter == .recent ? .recentlyUpdated : sort
    }
}

@MainActor
public final class CollectedInboxViewModel: ObservableObject {
    private let repository: any CollectedItemRepositoryProtocol
    private let defaults: UserDefaults
    private let viewModeKey: String
    private let densityKey: String
    private var searchTask: Task<Void, Never>?
    private var refreshRevision: UInt = 0

    @Published public private(set) var items: [CollectedItem] = []
    @Published public private(set) var allItems: [CollectedItem] = []
    @Published public private(set) var phase: CollectedInboxPhase = .idle
    @Published public private(set) var partialErrors: [String] = []
    @Published public var filterState: InboxFilterState
    @Published public private(set) var selectedItemID: CollectedItemID?
    @Published public private(set) var selectedItemIDs: Set<CollectedItemID> = []
    @Published public private(set) var viewMode: CollectedInboxViewMode
    @Published public private(set) var density: CollectedInboxDensity
    @Published public private(set) var lastBatchOperationResult: CollectedInboxBatchOperationResult?
    @Published public private(set) var pasteQueueItems: [PasteQueue.QueueItem] = []
    @Published public private(set) var clipboardMonitoringState: ClipboardMonitoringState = .unavailable

    public var isBatchSelecting: Bool { selectedItemIDs.isEmpty == false }
    public var selectedItem: CollectedItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    public init(
        repository: any CollectedItemRepositoryProtocol,
        defaults: UserDefaults = .standard,
        viewModeKey: String = "acwork.inbox.viewMode",
        densityKey: String = "acwork.inbox.density",
        filterState: InboxFilterState = InboxFilterState()
    ) {
        self.repository = repository
        self.defaults = defaults
        self.viewModeKey = viewModeKey
        self.densityKey = densityKey
        self.filterState = filterState
        self.viewMode = defaults.string(forKey: viewModeKey).flatMap(CollectedInboxViewMode.init(rawValue:)) ?? .grid
        self.density = defaults.string(forKey: densityKey).flatMap(CollectedInboxDensity.init(rawValue:)) ?? .standard
    }

    public convenience init(
        defaults: UserDefaults = .standard,
        viewModeKey: String = "acwork.inbox.viewMode",
        densityKey: String = "acwork.inbox.density",
        filterState: InboxFilterState = InboxFilterState()
    ) {
        self.init(
            repository: CollectedItemRepository(),
            defaults: defaults,
            viewModeKey: viewModeKey,
            densityKey: densityKey,
            filterState: filterState
        )
    }

    deinit {
        searchTask?.cancel()
    }

    public func refresh() async {
        refreshRevision &+= 1
        let revision = refreshRevision
        phase = items.isEmpty ? .loading : .loaded
        let previousSelection = selectedItemID
        let result = await repository.list(filter: filterState.repositoryFilter, sort: filterState.resolvedSort)
        guard Task.isCancelled == false, revision == refreshRevision else { return }
        let completeResult = await repository.list(filter: CollectedItemFilter(), sort: .newestFirst)
        guard Task.isCancelled == false, revision == refreshRevision else { return }
        if result.items.isEmpty, result.partialErrors.isEmpty == false, items.isEmpty == false {
            partialErrors = result.partialErrors
            phase = .failed(result.partialErrors.joined(separator: "\n"))
            restoreSelection(previousSelection)
            return
        }

        items = result.items
        allItems = completeResult.items
        partialErrors = result.partialErrors
        pasteQueueItems = repository.getPasteQueueItems()
        clipboardMonitoringState = repository.clipboardMonitoringState()
        restoreSelection(previousSelection)

        if items.isEmpty {
            phase = result.partialErrors.isEmpty ? .empty : .failed(result.partialErrors.joined(separator: "\n"))
        } else {
            phase = .loaded
        }
    }

    public func updateFilter(_ next: InboxFilterState) async {
        filterState = next
        selectedItemIDs.removeAll()
        await refresh()
    }

    public func updateSearchQuery(_ query: String, debounceNanoseconds: UInt64 = 250_000_000) {
        filterState.searchQuery = query
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }
            await self?.refresh()
        }
    }

    public func cancelPendingTasks() {
        searchTask?.cancel()
        searchTask = nil
        refreshRevision &+= 1
    }

    public func select(_ id: CollectedItemID?) {
        selectedItemID = id
        selectedItemIDs.removeAll()
    }

    public func moveSelection(_ movement: CollectedInboxSelectionMovement) {
        guard items.isEmpty == false else {
            selectedItemID = nil
            return
        }

        selectedItemIDs.removeAll()
        guard let selectedItemID, let index = items.firstIndex(where: { $0.id == selectedItemID }) else {
            self.selectedItemID = movement == .next ? items.first?.id : items.last?.id
            return
        }

        switch movement {
        case .previous:
            self.selectedItemID = index == items.startIndex ? items.last?.id : items[items.index(before: index)].id
        case .next:
            let nextIndex = items.index(after: index)
            self.selectedItemID = nextIndex == items.endIndex ? items.first?.id : items[nextIndex].id
        }
    }

    public func toggleBatchSelection(_ id: CollectedItemID) {
        selectedItemID = nil
        lastBatchOperationResult = nil
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    public func clearSelection() {
        selectedItemID = nil
        selectedItemIDs.removeAll()
        lastBatchOperationResult = nil
    }

    public func clearBatchOperationResult() {
        lastBatchOperationResult = nil
    }

    public func setViewMode(_ mode: CollectedInboxViewMode) {
        viewMode = mode
        defaults.set(mode.rawValue, forKey: viewModeKey)
    }

    public func setDensity(_ nextDensity: CollectedInboxDensity) {
        density = nextDensity
        defaults.set(nextDensity.rawValue, forKey: densityKey)
    }

    public func count(for quickFilter: InboxQuickFilter) -> Int {
        switch quickFilter {
        case .all: return allItems.count
        case .pending: return allItems.filter { $0.processingStatus == .pending || $0.processingStatus == .captured }.count
        case .screenshotHistory: return allItems.filter { $0.source == .screenshot || $0.source == .screenshotOCR }.count
        case .pinned: return allItems.filter(\.isPinned).count
        case .favorites: return allItems.filter(\.isFavorite).count
        case .recent:
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
            return allItems.filter { ($0.updatedAt ?? $0.createdAt) >= cutoff }.count
        }
    }

    public func count(for source: CollectionSource) -> Int {
        allItems.filter { $0.source == source }.count
    }

    public func count(for contentType: CollectedContentType) -> Int {
        allItems.filter { $0.contentType == contentType }.count
    }

    public func count(for status: ProcessingStatus) -> Int {
        allItems.filter { $0.processingStatus == status }.count
    }

    public func pin(_ id: CollectedItemID) async {
        await performItemMutation {
            try await repository.pin(id: id)
        }
    }

    public func unpin(_ id: CollectedItemID) async {
        await performItemMutation {
            try await repository.unpin(id: id)
        }
    }

    public func setFavorite(_ id: CollectedItemID, isFavorite: Bool) async {
        await performItemMutation {
            try await repository.favorite(id: id, isFavorite: isFavorite)
        }
    }

    public func archive(_ id: CollectedItemID) async {
        await performItemMutation {
            try await repository.archive(id: id)
        }
    }

    public func saveClipboardItemToInbox(_ id: CollectedItemID) async {
        await performItemMutation {
            _ = try await repository.saveClipboardItemToInbox(id: id)
        }
    }

    @discardableResult
    public func applyAIResult(_ result: CollectedItemAIResult, to id: CollectedItemID) async throws -> CollectedItemID {
        let resolvedID = try await repository.applyAIResult(id: id, result: result)
        selectedItemID = resolvedID
        selectedItemIDs.removeAll()
        await refresh()
        return resolvedID
    }

    public func enqueueForPaste(_ ids: [CollectedItemID]) {
        repository.enqueueForPaste(ids: ids)
        refreshPasteQueue()
    }

    public func enqueueBatchSelectionForPaste() {
        repository.enqueueForPaste(ids: Array(selectedItemIDs))
        refreshPasteQueue()
    }

    public func applyTagsToBatchSelection(_ tags: [String]) async {
        let normalizedTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard normalizedTags.isEmpty == false, selectedItemIDs.isEmpty == false else { return }

        let selectedItems = items.filter { selectedItemIDs.contains($0.id) }
        let result = await performBatchOperation(title: "批量添加标签", ids: selectedItemIDs) { id in
            guard let item = selectedItems.first(where: { $0.id == id }) else {
                throw CollectedItemRepositoryError.itemNotFound(id.stableValue)
            }
            let mergedTags = Array(Set(item.tags + normalizedTags)).sorted()
            try await repository.updateTags(id: id, tags: mergedTags)
        }
        selectedItemIDs = Set(result.failedIDs)
        await refresh()
    }

    public func pasteNextInQueue() async {
        do {
            _ = try await repository.pasteNextInQueue()
            refreshPasteQueue()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    public func clearPasteQueue() {
        repository.clearPasteQueue()
        refreshPasteQueue()
    }

    public func removePasteQueueItem(id: String) {
        repository.removePasteQueueItem(id: id)
        refreshPasteQueue()
    }

    public func reorderPasteQueue(from source: Int, to destination: Int) {
        repository.reorderPasteQueue(from: source, to: destination)
        refreshPasteQueue()
    }

    public func toggleClipboardMonitoring() async {
        switch clipboardMonitoringState {
        case .active:
            await repository.pauseClipboardMonitoring()
        case .paused:
            await repository.resumeClipboardMonitoring()
        case .stopped, .unavailable:
            return
        }
        clipboardMonitoringState = repository.clipboardMonitoringState()
    }

    public func delete(_ id: CollectedItemID) async {
        let fallbackID = adjacentSelection(afterDeleting: id)
        do {
            try await repository.delete(id: id)
            if selectedItemID == id {
                selectedItemID = fallbackID
            }
            selectedItemIDs.remove(id)
            await refresh()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    public func deleteSelectedItem() async {
        guard let selectedItemID else { return }
        await delete(selectedItemID)
    }

    public func deleteBatchSelection() async {
        let ids = selectedItemIDs
        guard ids.isEmpty == false else { return }
        let result = await performBatchOperation(title: "批量删除", ids: ids) { id in
            try await repository.delete(id: id)
        }
        selectedItemIDs = Set(result.failedIDs)
        await refresh()
    }

    public func archiveBatchSelection() async {
        let ids = selectedItemIDs
        guard ids.isEmpty == false else { return }
        let result = await performBatchOperation(title: "批量归档", ids: ids) { id in
            try await repository.archive(id: id)
        }
        selectedItemIDs = Set(result.failedIDs)
        await refresh()
    }

    private func performBatchOperation(
        title: String,
        ids: Set<CollectedItemID>,
        operation: (CollectedItemID) async throws -> Void
    ) async -> CollectedInboxBatchOperationResult {
        var successCount = 0
        var failedIDs: [CollectedItemID] = []
        var failureMessages: [String] = []

        for id in ids {
            do {
                try await operation(id)
                successCount += 1
            } catch {
                failedIDs.append(id)
                failureMessages.append("\(id.stableValue): \(error.localizedDescription)")
            }
        }

        let result = CollectedInboxBatchOperationResult(
            actionTitle: title,
            successCount: successCount,
            failureMessages: failureMessages,
            failedIDs: failedIDs
        )
        lastBatchOperationResult = result

        if result.isFailure {
            phase = .failed(result.failureMessages.joined(separator: "\n"))
        }

        return result
    }

    private func performItemMutation(_ mutation: () async throws -> Void) async {
        do {
            try await mutation()
            await refresh()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func restoreSelection(_ previousSelection: CollectedItemID?) {
        if let previousSelection, items.contains(where: { $0.id == previousSelection }) {
            selectedItemID = previousSelection
        } else if selectedItemID != nil {
            selectedItemID = nil
        }
        selectedItemIDs = selectedItemIDs.filter { id in
            items.contains { $0.id == id }
        }
    }

    private func adjacentSelection(afterDeleting id: CollectedItemID) -> CollectedItemID? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let nextIndex = items.index(after: index)
        if nextIndex < items.endIndex {
            return items[nextIndex].id
        }
        if index != items.startIndex {
            let previousIndex = items.index(before: index)
            return items[previousIndex].id
        }
        return nil
    }

    private func refreshPasteQueue() {
        pasteQueueItems = repository.getPasteQueueItems()
    }
}

public extension StorageServiceProtocol {
    func setup() async throws {}

    func insertScheduledAgentTask(_ task: ScheduledAgentTask) async throws { throw unsupportedStorageCapability("insertScheduledAgentTask") }
    func getScheduledAgentTask(id: String) async throws -> ScheduledAgentTask? { throw unsupportedStorageCapability("getScheduledAgentTask") }
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask] { throw unsupportedStorageCapability("listScheduledAgentTasks") }
    func deleteScheduledAgentTask(id: String) async throws { throw unsupportedStorageCapability("deleteScheduledAgentTask") }

    func insertClipboardTag(_ tag: ClipboardTag) async throws { throw unsupportedStorageCapability("insertClipboardTag") }
    func listClipboardTags() async throws -> [ClipboardTag] { throw unsupportedStorageCapability("listClipboardTags") }
    func deleteClipboardTag(id: String) async throws { throw unsupportedStorageCapability("deleteClipboardTag") }
    func listClipboardItemsByTag(_ tagName: String, limit: Int?) async throws -> [ClipboardItem] { throw unsupportedStorageCapability("listClipboardItemsByTag") }
    func addTagToClipboardItem(itemId: String, tagName: String) async throws { throw unsupportedStorageCapability("addTagToClipboardItem") }
    func removeTagFromClipboardItem(itemId: String, tagName: String) async throws { throw unsupportedStorageCapability("removeTagFromClipboardItem") }
    func deleteSetting(key: String) async throws { throw unsupportedStorageCapability("deleteSetting") }

    private func unsupportedStorageCapability(_ operation: String) -> UnsupportedServiceCapabilityError {
        UnsupportedServiceCapabilityError(service: "StorageServiceProtocol", operation: operation)
    }
}

// MARK: - CaptureServiceProtocol

public protocol CaptureServiceProtocol: Sendable {
    func captureScreenshot(mode: ScreenshotMode) async throws -> CaptureResult
    func captureScrollingScreenshot() async throws -> CaptureResult
    func captureFromClipboard() async throws -> CaptureResult?
    func captureFromFile(url: URL) async throws -> CaptureResult
    func captureFromWebpage(url: URL) async throws -> CaptureResult
    func captureFromManualText(_ text: String) async throws -> CaptureResult
    func captureFromVoice() async throws -> CaptureResult
}

// MARK: - ClipboardServiceProtocol

@MainActor
public protocol ClipboardServiceProtocol: Sendable {
    var itemPublisher: AnyPublisher<ClipboardItem, Never> { get }
    func startWatching() async
    func stopWatching() async
    func pauseWatching() async
    func resumeWatching() async
    func monitoringState() -> ClipboardMonitoringState
    func getStats() async -> ClipboardStats
    func listItems(filter: ClipboardFilter?) async throws -> [ClipboardItem]
    func pinItem(id: String) async throws
    func unpinItem(id: String) async throws
    func deleteItem(id: String) async throws
    func saveToInbox(id: String) async throws -> SourceItem
    func copyItem(id: String) async throws
    func copyText(_ text: String) async
    func clearHistory() async throws
    func pasteTransiently(id: String) async throws
    func enqueueForSequentialPaste(ids: [String])
    func pasteNextInQueue() async throws -> ClipboardItem?
    func getQueueItems() -> [PasteQueue.QueueItem]
    func clearPasteQueue()
    func removeQueueItem(id: String)
    func reorderQueue(from source: Int, to destination: Int)
    func getCleaningRules() -> [CleaningRule]
    func addCleaningRule(_ rule: CleaningRule) async
    func updateCleaningRule(_ rule: CleaningRule) async
    func deleteCleaningRule(id: String) async
    func toggleCleaningRule(id: String) async

    // Tags
    func createTag(name: String, color: String) async throws -> ClipboardTag
    func listTags() async throws -> [ClipboardTag]
    func deleteTag(id: String) async throws
    func addTagToItem(itemId: String, tagName: String) async throws
    func removeTagFromItem(itemId: String, tagName: String) async throws
    func listItemsByTag(_ tagName: String) async throws -> [ClipboardItem]
}

public enum ClipboardMonitoringState: String, Sendable, Equatable {
    case active
    case paused
    case stopped
    case unavailable
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
    func setDefaultProvider(id: String) throws
    func healthCheck(providerId: String) async throws -> Bool
    func listModels(providerId: String) async throws -> [String]
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
    func setup() async throws

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
    func loadImage(asset: AssetFile) -> NSImage?
    func loadImage(asset: AssetFile, maxPixelSize: CGFloat) -> NSImage?
}
