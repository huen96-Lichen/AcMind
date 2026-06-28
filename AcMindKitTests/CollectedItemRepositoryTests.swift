import Combine
import Combine
import XCTest
@testable import AcMindKit

@MainActor
final class CollectedItemRepositoryTests: XCTestCase {
    func testCollectedItemAIResultParsesStructuredResponseAndBuildsActionPrompt() throws {
        let start = "2026-06-16T01:00:00Z"
        let end = "2026-06-16T01:30:00Z"
        let response = """
        ```json
        {
          "title": "发布准备",
          "summary": "整理发布材料",
          "polishedText": null,
          "todos": ["补齐变更说明"],
          "schedule": [
            {"title":"发布检查","startAt":"\(start)","endAt":"\(end)","isAllDay":false}
          ]
        }
        ```
        """

        let result = try CollectedItemAIResult.parse(response)

        XCTAssertEqual(result.title, "发布准备")
        XCTAssertEqual(result.todos, ["补齐变更说明"])
        XCTAssertEqual(result.schedule.first?.title, "发布检查")

        let item = CollectedItem(
            id: CollectedItemID(origin: .sourceItem, rawID: "ai-prompt"),
            title: "原始标题",
            previewText: "需要整理的正文",
            content: .text("需要整理的正文"),
            contentType: .text,
            source: .manual,
            createdAt: Date(timeIntervalSince1970: 0),
            processingStatus: .pending
        )
        let messages = item.aiMessages(for: .extractTodos, referenceDate: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(messages.count, 2)
        XCTAssertTrue(messages[0].content.contains("提取明确可执行的待办事项"))
        XCTAssertTrue(messages[0].content.contains("\"todos\":[]"))
        XCTAssertTrue(messages[1].content.contains("需要整理的正文"))
    }

    func testRepositoryAppliesAIResultAndConvertsClipboardItemBeforeUpdating() async throws {
        let source = SourceItem(
            id: "source-ai",
            type: .text,
            source: .manual,
            status: .captured,
            title: "旧标题",
            previewText: "旧正文"
        )
        let clipboard = ClipboardItem(
            id: "clip-ai",
            type: .text,
            content: "剪贴板正文",
            textContent: "剪贴板正文"
        )
        let storage = CollectionStorageSpy()
        storage.sourceItems = [source]
        storage.clipboardItems = [clipboard]
        let repository = CollectedItemRepository(storage: storage)

        let sourceID = try await repository.applyAIResult(
            id: CollectedItemID(origin: .sourceItem, rawID: source.id),
            result: CollectedItemAIResult(title: "新标题", summary: "新的摘要")
        )
        XCTAssertEqual(sourceID, CollectedItemID(origin: .sourceItem, rawID: source.id))
        XCTAssertEqual(storage.updatedSourceItems.last?.title, "新标题")
        XCTAssertEqual(storage.updatedSourceItems.last?.previewText, "新的摘要")
        XCTAssertEqual(storage.updatedSourceItems.last?.status, .distilled)
        XCTAssertEqual(storage.updatedSourceItems.last?.metadata["preAISummaryPreview"], "旧正文")

        let convertedID = try await repository.applyAIResult(
            id: CollectedItemID(origin: .clipboardItem, rawID: clipboard.id),
            result: CollectedItemAIResult(polishedText: "润色后的剪贴板正文")
        )
        XCTAssertEqual(convertedID.origin, CollectedItemOrigin.sourceItem)
        XCTAssertEqual(storage.insertedSourceItems.last?.id, convertedID.rawID)
        XCTAssertEqual(storage.updatedSourceItems.last?.previewText, "润色后的剪贴板正文")
    }

    func testCollectedItemBuildsWorkflowDrafts() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 15,
            hour: 10,
            minute: 12
        )))
        let item = CollectedItem(
            id: CollectedItemID(origin: .sourceItem, rawID: "workflow-source"),
            title: "准备发布说明",
            previewText: "整理本轮重制的关键变更。",
            content: .text("整理本轮重制的关键变更。"),
            contentType: .text,
            source: .manual,
            originalURL: "https://example.com/release",
            createdAt: referenceDate,
            processingStatus: .captured,
            tags: ["发布", "AcWork"]
        )

        let task = item.makeAgentTask()
        XCTAssertEqual(task.title, "准备发布说明")
        XCTAssertEqual(task.sourceMessageId, "source:workflow-source")
        XCTAssertTrue(task.description.contains("整理本轮重制的关键变更。"))

        let event = item.makeScheduleEvent(referenceDate: referenceDate, calendar: calendar)
        XCTAssertEqual(event.categoryId, "acmind")
        XCTAssertEqual(event.startAt, calendar.date(bySettingHour: 10, minute: 30, second: 0, of: referenceDate))
        XCTAssertEqual(event.durationMinutes, 30)

        let note = item.makeDistilledNote()
        XCTAssertEqual(note.sourceItemId, "source:workflow-source")
        XCTAssertEqual(note.title, "准备发布说明")
        XCTAssertEqual(note.tags, ["发布", "AcWork"])
        XCTAssertTrue(note.contentMarkdown?.contains("# 准备发布说明") == true)
        XCTAssertTrue(item.workflowMarkdown.contains("[查看原始链接](https://example.com/release)"))
    }

    func testSourceItemMapsToCollectedItemWithoutLosingCompatibilityFields() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let source = SourceItem(
            id: "source-1",
            type: .screenshot,
            source: .screenshot,
            status: .distilled,
            title: "OCR 截图",
            previewText: "识别后的截图文本",
            ocrText: "识别后的截图文本",
            sourceApp: "Preview",
            tags: ["ocr", "design"],
            assetFileIds: ["asset-1"],
            metadata: [
                "isPinned": "true",
                "isFavorite": "true",
                "projectID": "project-1"
            ],
            createdAt: createdAt
        )

        let item = CollectedItem(sourceItem: source)

        XCTAssertEqual(item.id, CollectedItemID(origin: .sourceItem, rawID: "source-1"))
        XCTAssertEqual(item.id.stableValue, "source:source-1")
        XCTAssertEqual(CollectedItemID(stableValue: item.id.stableValue), item.id)
        XCTAssertEqual(item.contentType, .image)
        XCTAssertEqual(item.source, .screenshotOCR)
        XCTAssertEqual(item.processingStatus, .refined)
        XCTAssertTrue(item.isPinned)
        XCTAssertTrue(item.isFavorite)
        XCTAssertEqual(item.projectID, "project-1")
        XCTAssertEqual(item.assetFileIDs, ["asset-1"])
    }

    func testClipboardContentTypesMapToCollectedContentTypes() {
        let expectations: [(ClipboardContentType, CollectedContentType)] = [
            (.text, .text),
            (.image, .image),
            (.file, .file),
            (.url, .link),
            (.richText, .richText),
            (.code, .code),
            (.video, .video)
        ]

        for (clipboardType, expectedType) in expectations {
            let clipboard = ClipboardItem(
                id: "clip-\(clipboardType.rawValue)",
                type: clipboardType,
                content: clipboardType == .url ? "https://example.com" : "raw",
                textContent: "preview",
                sourceApp: "iPhone",
                codeLanguage: clipboardType == .code ? "swift" : nil
            )

            let item = CollectedItem(clipboardItem: clipboard)

            XCTAssertEqual(item.contentType, expectedType, "Unexpected mapping for \(clipboardType)")
            XCTAssertEqual(item.source, .phoneSync)
            XCTAssertEqual(item.sourceDevice, "iPhone")
            XCTAssertEqual(item.id.stableValue, "clipboard:clip-\(clipboardType.rawValue)")
        }
    }

    func testRepositoryMergesSourcesSortsAndFilters() async {
        let storage = CollectionStorageSpy()
        storage.sourceItems = [
            SourceItem(
                id: "source-old",
                type: .text,
                source: .voice,
                status: .pending,
                title: "语音待整理",
                previewText: "standup",
                createdAt: Date(timeIntervalSince1970: 100)
            )
        ]
        storage.clipboardItems = [
            ClipboardItem(
                id: "clip-new",
                type: .code,
                content: "let value = 1",
                textContent: "let value = 1",
                sourceApp: "Xcode",
                isPinned: true,
                createdAt: Date(timeIntervalSince1970: 200),
                codeLanguage: "swift",
                tags: ["code"]
            )
        ]

        let repository = CollectedItemRepository(storage: storage)
        let all = await repository.list(sort: .newestFirst)

        XCTAssertEqual(all.items.map(\.id.stableValue), ["clipboard:clip-new", "source:source-old"])
        XCTAssertTrue(all.partialErrors.isEmpty)

        let filtered = await repository.list(
            filter: CollectedItemFilter(searchQuery: "value", contentTypes: [.code], pinnedOnly: true),
            sort: .pinnedFirst
        )

        XCTAssertEqual(filtered.items.map(\.id.stableValue), ["clipboard:clip-new"])
    }

    func testRepositoryRoutesPinArchiveDeleteAndClipboardConversion() async throws {
        let storage = CollectionStorageSpy()
        let source = SourceItem(id: "source-1", type: .text, source: .manual, status: .pending, title: "Manual")
        let clipboard = ClipboardItem(id: "clip-1", type: .text, content: "clip", textContent: "clip")
        storage.sourceItems = [source]
        storage.clipboardItems = [clipboard]

        let repository = CollectedItemRepository(storage: storage)

        try await repository.pin(id: CollectedItemID(origin: .sourceItem, rawID: "source-1"))
        XCTAssertEqual(storage.updatedSourceItems.last?.metadata["isPinned"], "true")

        try await repository.archive(id: CollectedItemID(origin: .sourceItem, rawID: "source-1"))
        XCTAssertEqual(storage.updatedSourceItems.last?.status, .archived)

        let newID = try await repository.saveClipboardItemToInbox(id: CollectedItemID(origin: .clipboardItem, rawID: "clip-1"))
        XCTAssertEqual(newID.origin, .sourceItem)
        XCTAssertEqual(storage.insertedSourceItems.last?.metadata["originClipboardItemID"], "clip-1")

        try await repository.delete(id: CollectedItemID(origin: .clipboardItem, rawID: "clip-1"))
        XCTAssertEqual(storage.deletedClipboardIDs, ["clip-1"])
    }

    func testRepositoryUsesClipboardServiceForClipboardRoutesWhenAvailable() async throws {
        let storage = CollectionStorageSpy()
        let clipboard = CollectionClipboardSpy()
        clipboard.items = [
            ClipboardItem(id: "clip-1", type: .text, content: "clip", textContent: "clip")
        ]

        let repository = CollectedItemRepository(storage: storage, clipboardService: clipboard)
        let id = CollectedItemID(origin: .clipboardItem, rawID: "clip-1")

        try await repository.pin(id: id)
        try await repository.unpin(id: id)
        try await repository.delete(id: id)
        _ = try await repository.saveClipboardItemToInbox(id: id)
        repository.enqueueForPaste(ids: [id, CollectedItemID(origin: .sourceItem, rawID: "source-1")])

        XCTAssertEqual(clipboard.pinnedIDs, ["clip-1"])
        XCTAssertEqual(clipboard.unpinnedIDs, ["clip-1"])
        XCTAssertEqual(clipboard.deletedIDs, ["clip-1"])
        XCTAssertEqual(clipboard.savedInboxIDs, ["clip-1"])
        XCTAssertEqual(clipboard.enqueuedIDs, ["clip-1"])
    }

    func testRepositoryReturnsPartialResultsWhenOneSideFails() async {
        let storage = CollectionStorageSpy()
        storage.shouldFailSourceList = true
        storage.clipboardItems = [
            ClipboardItem(id: "clip-1", type: .text, content: "clip", textContent: "clip")
        ]

        let repository = CollectedItemRepository(storage: storage)
        let result = await repository.list()

        XCTAssertEqual(result.items.map(\.id.stableValue), ["clipboard:clip-1"])
        XCTAssertEqual(result.partialErrors.count, 1)
        XCTAssertTrue(result.partialErrors[0].contains("source_items"))
    }

}

private final class CollectionStorageSpy: StorageServiceProtocol, @unchecked Sendable {
    var sourceItems: [SourceItem] = []
    var clipboardItems: [ClipboardItem] = []
    var insertedSourceItems: [SourceItem] = []
    var updatedSourceItems: [SourceItem] = []
    var updatedClipboardItems: [ClipboardItem] = []
    var deletedSourceIDs: [String] = []
    var deletedClipboardIDs: [String] = []
    var shouldFailSourceList = false

    func insertSourceItem(_ item: SourceItem) async throws { insertedSourceItems.append(item) }
    func getSourceItem(id: String) async throws -> SourceItem? {
        updatedSourceItems.last(where: { $0.id == id })
            ?? insertedSourceItems.last(where: { $0.id == id })
            ?? sourceItems.first(where: { $0.id == id })
    }
    func listSourceItems(filter: SourceItemFilter?) async throws -> [SourceItem] {
        if shouldFailSourceList { throw NSError(domain: "CollectionStorageSpy", code: 1) }
        return sourceItems
    }
    func updateSourceItem(_ item: SourceItem) async throws { updatedSourceItems.append(item) }
    func deleteSourceItem(id: String) async throws { deletedSourceIDs.append(id) }

    func insertChatSession(_ session: ChatSession) async throws {}
    func getChatSession(id: String) async throws -> ChatSession? { nil }
    func listChatSessions(status: String?) async throws -> [ChatSession] { [] }
    func updateChatSession(_ session: ChatSession) async throws {}
    func deleteChatSession(id: String) async throws {}
    func insertChatMessage(_ message: ChatMessage) async throws {}
    func listChatMessages(sessionId: String) async throws -> [ChatMessage] { [] }

    func insertDistilledNote(_ note: DistilledNote) async throws {}
    func updateDistilledNote(_ note: DistilledNote) async throws {}
    func deleteDistilledNote(id: String) async throws {}
    func listDistilledNotes() async throws -> [DistilledNote] { [] }
    func insertExportRecord(_ record: ExportRecord) async throws {}
    func listExportRecords() async throws -> [ExportRecord] { [] }
    func insertKnowledgeCard(_ card: KnowledgeCard) async throws {}
    func updateKnowledgeCard(_ card: KnowledgeCard) async throws {}
    func listKnowledgeCards(status: KnowledgeCardStatus?) async throws -> [KnowledgeCard] { [] }
    func insertKnowledgeEdge(_ edge: KnowledgeEdge) async throws {}
    func listKnowledgeEdges(fromCardId: String?, toCardId: String?) async throws -> [KnowledgeEdge] { [] }
    func deleteKnowledgeEdge(id: String) async throws {}

    func insertClipboardItem(_ item: ClipboardItem) async throws { clipboardItems.append(item) }
    func listClipboardItems(limit: Int?) async throws -> [ClipboardItem] { clipboardItems }
    func updateClipboardItem(_ item: ClipboardItem) async throws { updatedClipboardItems.append(item) }
    func deleteClipboardItem(id: String) async throws { deletedClipboardIDs.append(id) }

    func insertScheduledAgentTask(_ task: ScheduledAgentTask) async throws {}
    func getScheduledAgentTask(id: String) async throws -> ScheduledAgentTask? { nil }
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask] { [] }
    func deleteScheduledAgentTask(id: String) async throws {}
    func listProviders() async throws -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}
    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }
    func getSetting(key: String) async throws -> String? { nil }
    func setSetting(key: String, value: String) async throws {}
    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { "/tmp/collection-spy.db" }
    func getDatabaseVersion() async throws -> Int { 1 }
}

@MainActor
private final class CollectionClipboardSpy: ClipboardServiceProtocol, @unchecked Sendable {
    var items: [ClipboardItem] = []
    var pinnedIDs: [String] = []
    var unpinnedIDs: [String] = []
    var deletedIDs: [String] = []
    var savedInboxIDs: [String] = []
    var enqueuedIDs: [String] = []

    var itemPublisher: AnyPublisher<ClipboardItem, Never> {
        Empty().eraseToAnyPublisher()
    }

    func startWatching() async {}
    func stopWatching() async {}
    func pauseWatching() async {}
    func resumeWatching() async {}
    func monitoringState() -> ClipboardMonitoringState { .stopped }
    func getStats() async -> ClipboardStats { ClipboardStats() }
    func listItems(filter: ClipboardFilter?) async throws -> [ClipboardItem] { items }
    func pinItem(id: String) async throws { pinnedIDs.append(id) }
    func unpinItem(id: String) async throws { unpinnedIDs.append(id) }
    func deleteItem(id: String) async throws { deletedIDs.append(id) }
    func saveToInbox(id: String) async throws -> SourceItem {
        savedInboxIDs.append(id)
        return SourceItem(id: "source-from-\(id)", type: .text, source: .clipboard, status: .captured)
    }
    func copyItem(id: String) async throws {}
    func copyText(_ text: String) async {}
    func clearHistory() async throws {}
    func pasteTransiently(id: String) async throws {}
    func enqueueForSequentialPaste(ids: [String]) { enqueuedIDs.append(contentsOf: ids) }
    func pasteNextInQueue() async throws -> ClipboardItem? { nil }
    func getQueueItems() -> [PasteQueue.QueueItem] { [] }
    func clearPasteQueue() {}
    func removeQueueItem(id: String) {}
    func reorderQueue(from source: Int, to destination: Int) {}
    func getCleaningRules() -> [CleaningRule] { [] }
    func addCleaningRule(_ rule: CleaningRule) async {}
    func updateCleaningRule(_ rule: CleaningRule) async {}
    func deleteCleaningRule(id: String) async {}
    func toggleCleaningRule(id: String) async {}
    func createTag(name: String, color: String) async throws -> ClipboardTag { ClipboardTag(name: name, color: color) }
    func listTags() async throws -> [ClipboardTag] { [] }
    func deleteTag(id: String) async throws {}
    func addTagToItem(itemId: String, tagName: String) async throws {}
    func removeTagFromItem(itemId: String, tagName: String) async throws {}
    func listItemsByTag(_ tagName: String) async throws -> [ClipboardItem] { [] }
}
