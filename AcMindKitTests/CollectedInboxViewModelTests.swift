import XCTest
@testable import AcMindKit

@MainActor
final class CollectedInboxViewModelTests: XCTestCase {
    func testFilterStateBuildsTypeSafeRepositoryFilter() {
        let state = InboxFilterState(
            quickFilter: .pending,
            searchQuery: "ocr",
            sources: [.screenshotOCR],
            contentTypes: [.image],
            statuses: [.refined],
            sort: .oldestFirst
        )

        let filter = state.repositoryFilter

        XCTAssertEqual(filter.searchQuery, "ocr")
        XCTAssertEqual(filter.sources, [.screenshotOCR])
        XCTAssertEqual(filter.contentTypes, [.image])
        XCTAssertEqual(filter.statuses, [.pending, .captured, .refined])
        XCTAssertFalse(filter.pinnedOnly)
        XCTAssertFalse(filter.favoriteOnly)
        XCTAssertEqual(state.resolvedSort, .oldestFirst)

        let recent = InboxFilterState(quickFilter: .recent, sort: .oldestFirst)
        XCTAssertEqual(recent.resolvedSort, .recentlyUpdated)

        let pinned = InboxFilterState(quickFilter: .pinned)
        XCTAssertTrue(pinned.repositoryFilter.pinnedOnly)

        let favorites = InboxFilterState(quickFilter: .favorites)
        XCTAssertTrue(favorites.repositoryFilter.favoriteOnly)

        let screenshotHistory = InboxFilterState(quickFilter: .screenshotHistory)
        XCTAssertEqual(screenshotHistory.repositoryFilter.sources, [.screenshot, .screenshotOCR])
    }

    func testViewModePersistsToDefaults() {
        let defaults = UserDefaults(suiteName: "CollectedInboxViewModelTests.\(UUID().uuidString)")!
        let key = "view-mode"
        let viewModel = CollectedInboxViewModel(repository: CollectedInboxRepositorySpy(), defaults: defaults, viewModeKey: key)

        XCTAssertEqual(viewModel.viewMode, .grid)

        viewModel.setViewMode(.list)

        XCTAssertEqual(defaults.string(forKey: key), "list")
        let restored = CollectedInboxViewModel(repository: CollectedInboxRepositorySpy(), defaults: defaults, viewModeKey: key)
        XCTAssertEqual(restored.viewMode, .list)
    }

    func testDensityPersistsAndUsesSpecifiedRowHeights() {
        let defaults = UserDefaults(suiteName: "CollectedInboxDensityTests.\(UUID().uuidString)")!
        let key = "density"
        let viewModel = CollectedInboxViewModel(
            repository: CollectedInboxRepositorySpy(),
            defaults: defaults,
            densityKey: key
        )

        XCTAssertEqual(viewModel.density, .standard)
        XCTAssertEqual(CollectedInboxDensity.standard.rowHeight, 84)
        XCTAssertEqual(CollectedInboxDensity.compact.rowHeight, 64)

        viewModel.setDensity(.compact)

        XCTAssertEqual(defaults.string(forKey: key), "compact")
        let restored = CollectedInboxViewModel(
            repository: CollectedInboxRepositorySpy(),
            defaults: defaults,
            densityKey: key
        )
        XCTAssertEqual(restored.density, .compact)
    }

    func testSingleSelectionAndBatchSelectionAreMutuallyExclusive() async {
        let repository = CollectedInboxRepositorySpy()
        repository.items = [.sample("one"), .sample("two")]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        viewModel.select(repository.items[0].id)

        XCTAssertEqual(viewModel.selectedItemID, repository.items[0].id)
        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)

        viewModel.toggleBatchSelection(repository.items[1].id)

        XCTAssertNil(viewModel.selectedItemID)
        XCTAssertEqual(viewModel.selectedItemIDs, [repository.items[1].id])

        viewModel.select(repository.items[0].id)

        XCTAssertEqual(viewModel.selectedItemID, repository.items[0].id)
        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)
    }

    func testKeyboardSelectionMovesThroughItemsAndWraps() async {
        let repository = CollectedInboxRepositorySpy()
        let first = CollectedItem.sample("first")
        let second = CollectedItem.sample("second")
        let third = CollectedItem.sample("third")
        repository.items = [first, second, third]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        viewModel.moveSelection(.next)
        XCTAssertEqual(viewModel.selectedItemID, first.id)

        viewModel.moveSelection(.next)
        XCTAssertEqual(viewModel.selectedItemID, second.id)

        viewModel.moveSelection(.previous)
        XCTAssertEqual(viewModel.selectedItemID, first.id)

        viewModel.moveSelection(.previous)
        XCTAssertEqual(viewModel.selectedItemID, third.id)

        viewModel.moveSelection(.next)
        XCTAssertEqual(viewModel.selectedItemID, first.id)
    }

    func testRefreshKeepsValidSelectionAndDropsInvalidSelection() async {
        let repository = CollectedInboxRepositorySpy()
        let first = CollectedItem.sample("first")
        let second = CollectedItem.sample("second")
        repository.items = [first, second]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        viewModel.select(second.id)
        await viewModel.refresh()

        XCTAssertEqual(viewModel.selectedItemID, second.id)

        repository.items = [first]
        await viewModel.refresh()

        XCTAssertNil(viewModel.selectedItemID)
    }

    func testFacetCountsUseUnfilteredCollection() async {
        let repository = CollectedInboxRepositorySpy()
        var pinnedVoice = CollectedItem.sample("voice")
        pinnedVoice.source = .voice
        pinnedVoice.contentType = .audio
        pinnedVoice.processingStatus = .captured
        pinnedVoice.isPinned = true
        var favoriteLink = CollectedItem.sample("link")
        favoriteLink.source = .phoneSync
        favoriteLink.contentType = .link
        favoriteLink.processingStatus = .refined
        favoriteLink.isFavorite = true
        repository.items = [pinnedVoice, favoriteLink]
        let viewModel = CollectedInboxViewModel(
            repository: repository,
            filterState: InboxFilterState(sources: [.voice])
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.items.map(\.id), [pinnedVoice.id])
        XCTAssertEqual(viewModel.allItems.count, 2)
        XCTAssertEqual(viewModel.count(for: InboxQuickFilter.pending), 1)
        XCTAssertEqual(viewModel.count(for: InboxQuickFilter.screenshotHistory), 0)
        XCTAssertEqual(viewModel.count(for: InboxQuickFilter.pinned), 1)
        XCTAssertEqual(viewModel.count(for: InboxQuickFilter.favorites), 1)
        XCTAssertEqual(viewModel.count(for: CollectionSource.phoneSync), 1)
        XCTAssertEqual(viewModel.count(for: CollectedContentType.link), 1)
        XCTAssertEqual(viewModel.count(for: ProcessingStatus.refined), 1)
    }

    func testScreenshotHistoryQuickFilterIncludesScreenshotAndOCRSources() async {
        let repository = CollectedInboxRepositorySpy()
        var screenshot = CollectedItem.sample("screenshot")
        screenshot.source = .screenshot
        screenshot.contentType = .image
        var screenshotOCR = CollectedItem.sample("screenshot-ocr")
        screenshotOCR.source = .screenshotOCR
        screenshotOCR.contentType = .image
        var voice = CollectedItem.sample("voice")
        voice.source = .voice
        voice.contentType = .audio
        repository.items = [screenshot, screenshotOCR, voice]
        let viewModel = CollectedInboxViewModel(
            repository: repository,
            filterState: InboxFilterState(quickFilter: .screenshotHistory)
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.items.map(\.id), [screenshot.id, screenshotOCR.id])
        XCTAssertEqual(viewModel.count(for: InboxQuickFilter.screenshotHistory), 2)
        XCTAssertEqual(repository.receivedFilters.first?.sources, [.screenshot, .screenshotOCR])
    }

    func testDeleteSelectedItemChoosesAdjacentItem() async {
        let repository = CollectedInboxRepositorySpy()
        let first = CollectedItem.sample("first")
        let second = CollectedItem.sample("second")
        let third = CollectedItem.sample("third")
        repository.items = [first, second, third]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        viewModel.select(second.id)
        await viewModel.deleteSelectedItem()

        XCTAssertEqual(repository.deletedIDs, [second.id])
        XCTAssertEqual(viewModel.items.map(\.id), [first.id, third.id])
        XCTAssertEqual(viewModel.selectedItemID, third.id)

        viewModel.select(third.id)
        await viewModel.deleteSelectedItem()

        XCTAssertEqual(viewModel.items.map(\.id), [first.id])
        XCTAssertEqual(viewModel.selectedItemID, first.id)
    }

    func testSearchDebounceCancelsOlderRequests() async throws {
        let repository = CollectedInboxRepositorySpy()
        repository.items = [.sample("alpha"), .sample("beta")]
        let viewModel = CollectedInboxViewModel(repository: repository)

        viewModel.updateSearchQuery("a", debounceNanoseconds: 80_000_000)
        viewModel.updateSearchQuery("beta", debounceNanoseconds: 5_000_000)
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(repository.receivedFilters.compactMap(\.searchQuery), ["beta"])
        XCTAssertEqual(repository.receivedFilters.filter { $0.searchQuery == nil }.count, 1)
        XCTAssertEqual(viewModel.filterState.searchQuery, "beta")
    }

    func testCancelPendingTasksStopsDebouncedSearch() async throws {
        let repository = CollectedInboxRepositorySpy()
        repository.items = [.sample("alpha")]
        let viewModel = CollectedInboxViewModel(repository: repository)

        viewModel.updateSearchQuery("alpha", debounceNanoseconds: 80_000_000)
        viewModel.cancelPendingTasks()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(repository.receivedFilters.isEmpty)
    }

    func testSlowerRefreshCannotOverwriteNewerFilterResults() async throws {
        let repository = CollectedInboxRepositorySpy()
        repository.items = [.sample("slow"), .sample("fast")]
        repository.delayNanosecondsByQuery["slow"] = 80_000_000
        let viewModel = CollectedInboxViewModel(repository: repository)

        let slowTask = Task {
            await viewModel.updateFilter(InboxFilterState(searchQuery: "slow"))
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        let fastTask = Task {
            await viewModel.updateFilter(InboxFilterState(searchQuery: "fast"))
        }

        await fastTask.value
        await slowTask.value

        XCTAssertEqual(viewModel.filterState.searchQuery, "fast")
        XCTAssertEqual(viewModel.items.map(\.id.rawID), ["fast"])
    }

    func testErrorStateKeepsPreviouslyLoadedItems() async {
        let repository = CollectedInboxRepositorySpy()
        repository.items = [.sample("survivor")]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        repository.partialErrors = ["source_items failed"]
        repository.items = []
        await viewModel.refresh()

        XCTAssertEqual(viewModel.items.map(\.id.rawID), ["survivor"])
        XCTAssertEqual(viewModel.phase, .failed("source_items failed"))
    }

    func testItemActionsRouteThroughRepositoryAndRefresh() async {
        let repository = CollectedInboxRepositorySpy()
        let sourceItem = CollectedItem.sample("source")
        let clipboardItem = CollectedItem.sample("clip", origin: .clipboardItem)
        repository.items = [sourceItem, clipboardItem]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        await viewModel.pin(sourceItem.id)
        await viewModel.unpin(sourceItem.id)
        await viewModel.setFavorite(sourceItem.id, isFavorite: true)
        await viewModel.archive(sourceItem.id)
        await viewModel.saveClipboardItemToInbox(clipboardItem.id)
        viewModel.enqueueForPaste([clipboardItem.id])

        XCTAssertEqual(repository.pinnedIDs, [sourceItem.id])
        XCTAssertEqual(repository.unpinnedIDs, [sourceItem.id])
        XCTAssertEqual(repository.favoriteRequests.map(\.id), [sourceItem.id])
        XCTAssertEqual(repository.favoriteRequests.map(\.isFavorite), [true])
        XCTAssertEqual(repository.archivedIDs, [sourceItem.id])
        XCTAssertEqual(repository.savedClipboardIDs, [clipboardItem.id])
        XCTAssertEqual(repository.enqueuedIDs, [clipboardItem.id])
        XCTAssertGreaterThanOrEqual(repository.receivedFilters.count, 6)
    }

    func testApplyingAIResultRoutesThroughRepositoryAndKeepsResolvedSelection() async throws {
        let repository = CollectedInboxRepositorySpy()
        let item = CollectedItem.sample("ai-result")
        repository.items = [item]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        viewModel.select(item.id)
        let result = CollectedItemAIResult(title: "AI 标题")

        let resolvedID = try await viewModel.applyAIResult(result, to: item.id)

        XCTAssertEqual(resolvedID, item.id)
        XCTAssertEqual(viewModel.selectedItemID, item.id)
        XCTAssertEqual(repository.appliedAIResults.first?.id, item.id)
        XCTAssertEqual(repository.appliedAIResults.first?.result, result)
    }

    func testBatchActionsRouteThroughRepository() async {
        let repository = CollectedInboxRepositorySpy()
        let first = CollectedItem.sample("batch-one", origin: .clipboardItem)
        let second = CollectedItem.sample("batch-two", origin: .clipboardItem)
        repository.items = [first, second]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        viewModel.toggleBatchSelection(first.id)
        viewModel.toggleBatchSelection(second.id)
        viewModel.enqueueBatchSelectionForPaste()
        await viewModel.archiveBatchSelection()

        XCTAssertEqual(Set(repository.enqueuedIDs), [first.id, second.id])
        XCTAssertEqual(Set(repository.archivedIDs), [first.id, second.id])
        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)
    }

    func testBatchActionsKeepFailedItemsSelectedAndReportCounts() async {
        let repository = CollectedInboxRepositorySpy()
        let first = CollectedItem.sample("batch-success")
        let second = CollectedItem.sample("batch-failure")
        repository.items = [first, second]
        repository.archiveFailureIDs = [second.id]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        viewModel.toggleBatchSelection(first.id)
        viewModel.toggleBatchSelection(second.id)
        await viewModel.archiveBatchSelection()

        XCTAssertEqual(repository.archivedIDs, [first.id])
        XCTAssertEqual(viewModel.selectedItemIDs, [second.id])
        XCTAssertEqual(viewModel.lastBatchOperationResult?.actionTitle, "批量归档")
        XCTAssertEqual(viewModel.lastBatchOperationResult?.successCount, 1)
        XCTAssertEqual(viewModel.lastBatchOperationResult?.failureCount, 1)
        XCTAssertEqual(viewModel.lastBatchOperationResult?.failedIDs, [second.id])
        XCTAssertTrue(viewModel.lastBatchOperationResult?.failureMessages.first?.contains("batch-failure") == true)

        viewModel.clearBatchOperationResult()
        XCTAssertNil(viewModel.lastBatchOperationResult)
    }

    func testBatchTaggingMergesExistingTagsAndClearsSuccessfulSelection() async {
        let repository = CollectedInboxRepositorySpy()
        var first = CollectedItem.sample("tag-one")
        first.tags = ["existing"]
        let second = CollectedItem.sample("tag-two")
        repository.items = [first, second]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        viewModel.toggleBatchSelection(first.id)
        viewModel.toggleBatchSelection(second.id)
        await viewModel.applyTagsToBatchSelection(["project", "existing"])

        XCTAssertEqual(repository.tagRequests.count, 2)
        XCTAssertEqual(
            repository.tagRequests.first(where: { $0.id == first.id })?.tags,
            ["existing", "project"]
        )
        XCTAssertEqual(
            repository.tagRequests.first(where: { $0.id == second.id })?.tags,
            ["existing", "project"]
        )
        XCTAssertEqual(viewModel.lastBatchOperationResult?.actionTitle, "批量添加标签")
        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)
    }

    func testPasteQueueOperationsRefreshPublishedQueueState() async {
        let repository = CollectedInboxRepositorySpy()
        let first = PasteQueue.QueueItem(clipboardItemId: "clip-one")
        let second = PasteQueue.QueueItem(clipboardItemId: "clip-two")
        repository.queueItems = [first, second]
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        XCTAssertEqual(viewModel.pasteQueueItems.map(\.id), [first.id, second.id])

        viewModel.reorderPasteQueue(from: 0, to: 1)
        XCTAssertEqual(viewModel.pasteQueueItems.map(\.id), [second.id, first.id])

        viewModel.removePasteQueueItem(id: first.id)
        XCTAssertEqual(viewModel.pasteQueueItems.map(\.id), [second.id])
        XCTAssertEqual(repository.removedQueueIDs, [first.id])

        await viewModel.pasteNextInQueue()
        XCTAssertTrue(viewModel.pasteQueueItems.isEmpty)

        repository.queueItems = [first]
        await viewModel.refresh()
        viewModel.clearPasteQueue()
        XCTAssertTrue(viewModel.pasteQueueItems.isEmpty)
        XCTAssertEqual(repository.clearedQueueCount, 1)
    }

    func testClipboardMonitoringToggleUsesRepositoryState() async {
        let repository = CollectedInboxRepositorySpy()
        repository.monitoringStateValue = .active
        let viewModel = CollectedInboxViewModel(repository: repository)

        await viewModel.refresh()
        XCTAssertEqual(viewModel.clipboardMonitoringState, .active)

        await viewModel.toggleClipboardMonitoring()
        XCTAssertEqual(repository.pauseMonitoringCount, 1)
        XCTAssertEqual(viewModel.clipboardMonitoringState, .paused)

        await viewModel.toggleClipboardMonitoring()
        XCTAssertEqual(repository.resumeMonitoringCount, 1)
        XCTAssertEqual(viewModel.clipboardMonitoringState, .active)
    }
}

@MainActor
private final class CollectedInboxRepositorySpy: CollectedItemRepositoryProtocol, @unchecked Sendable {
    var items: [CollectedItem] = []
    var partialErrors: [String] = []
    var receivedFilters: [CollectedItemFilter] = []
    var receivedSorts: [CollectedItemSort] = []
    var deletedIDs: [CollectedItemID] = []
    var pinnedIDs: [CollectedItemID] = []
    var unpinnedIDs: [CollectedItemID] = []
    var favoriteRequests: [(id: CollectedItemID, isFavorite: Bool)] = []
    var tagRequests: [(id: CollectedItemID, tags: [String])] = []
    var appliedAIResults: [(id: CollectedItemID, result: CollectedItemAIResult)] = []
    var archivedIDs: [CollectedItemID] = []
    var savedClipboardIDs: [CollectedItemID] = []
    var enqueuedIDs: [CollectedItemID] = []
    var queueItems: [PasteQueue.QueueItem] = []
    var clearedQueueCount = 0
    var removedQueueIDs: [String] = []
    var queueMoves: [(source: Int, destination: Int)] = []
    var monitoringStateValue: ClipboardMonitoringState = .active
    var delayNanosecondsByQuery: [String: UInt64] = [:]
    var pauseMonitoringCount = 0
    var resumeMonitoringCount = 0
    var archiveFailureIDs: Set<CollectedItemID> = []
    var deleteFailureIDs: Set<CollectedItemID> = []

    func list(filter: CollectedItemFilter, sort: CollectedItemSort) async -> CollectedItemListResult {
        receivedFilters.append(filter)
        receivedSorts.append(sort)
        if let query = filter.searchQuery, let delay = delayNanosecondsByQuery[query] {
            try? await Task.sleep(nanoseconds: delay)
        }
        var result = items

        if let query = filter.searchQuery, query.isEmpty == false {
            result = result.filter {
                ($0.title?.localizedCaseInsensitiveContains(query) ?? false) ||
                ($0.previewText?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        if filter.sources.isEmpty == false {
            result = result.filter { filter.sources.contains($0.source) }
        }
        if filter.contentTypes.isEmpty == false {
            result = result.filter { filter.contentTypes.contains($0.contentType) }
        }
        if filter.statuses.isEmpty == false {
            result = result.filter { filter.statuses.contains($0.processingStatus) }
        }
        if filter.pinnedOnly {
            result = result.filter(\.isPinned)
        }
        if filter.favoriteOnly {
            result = result.filter(\.isFavorite)
        }

        return CollectedItemListResult(items: result, partialErrors: partialErrors)
    }

    func pin(id: CollectedItemID) async throws { pinnedIDs.append(id) }
    func unpin(id: CollectedItemID) async throws { unpinnedIDs.append(id) }
    func favorite(id: CollectedItemID, isFavorite: Bool) async throws {
        favoriteRequests.append((id, isFavorite))
    }
    func updateTags(id: CollectedItemID, tags: [String]) async throws {
        tagRequests.append((id, tags))
    }
    func applyAIResult(id: CollectedItemID, result: CollectedItemAIResult) async throws -> CollectedItemID {
        appliedAIResults.append((id, result))
        return id
    }
    func archive(id: CollectedItemID) async throws {
        if archiveFailureIDs.contains(id) {
            throw NSError(domain: "CollectedInboxRepositorySpy", code: 1, userInfo: [NSLocalizedDescriptionKey: "归档失败 \(id.rawID)"])
        }
        archivedIDs.append(id)
    }
    func delete(id: CollectedItemID) async throws {
        if deleteFailureIDs.contains(id) {
            throw NSError(domain: "CollectedInboxRepositorySpy", code: 2, userInfo: [NSLocalizedDescriptionKey: "删除失败 \(id.rawID)"])
        }
        deletedIDs.append(id)
        items.removeAll { $0.id == id }
    }
    func saveClipboardItemToInbox(id: CollectedItemID) async throws -> CollectedItemID {
        savedClipboardIDs.append(id)
        return id
    }
    func enqueueForPaste(ids: [CollectedItemID]) {
        enqueuedIDs.append(contentsOf: ids)
    }
    func getPasteQueueItems() -> [PasteQueue.QueueItem] { queueItems }
    func pasteNextInQueue() async throws -> ClipboardItem? {
        guard queueItems.isEmpty == false else { return nil }
        queueItems.removeFirst()
        return nil
    }
    func clearPasteQueue() {
        clearedQueueCount += 1
        queueItems.removeAll()
    }
    func removePasteQueueItem(id: String) {
        removedQueueIDs.append(id)
        queueItems.removeAll { $0.id == id }
    }
    func reorderPasteQueue(from source: Int, to destination: Int) {
        queueMoves.append((source, destination))
        guard queueItems.indices.contains(source), queueItems.indices.contains(destination) else { return }
        let item = queueItems.remove(at: source)
        queueItems.insert(item, at: destination)
    }
    func clipboardMonitoringState() -> ClipboardMonitoringState { monitoringStateValue }
    func pauseClipboardMonitoring() async {
        pauseMonitoringCount += 1
        monitoringStateValue = .paused
    }
    func resumeClipboardMonitoring() async {
        resumeMonitoringCount += 1
        monitoringStateValue = .active
    }
}

private extension CollectedItem {
    static func sample(_ rawID: String, origin: CollectedItemOrigin = .sourceItem) -> CollectedItem {
        CollectedItem(
            id: CollectedItemID(origin: origin, rawID: rawID),
            title: rawID,
            previewText: "preview \(rawID)",
            content: .text("preview \(rawID)"),
            contentType: .text,
            source: .manual,
            createdAt: Date(timeIntervalSince1970: TimeInterval(rawID.count)),
            processingStatus: .pending
        )
    }
}
