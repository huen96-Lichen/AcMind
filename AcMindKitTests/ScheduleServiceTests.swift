import XCTest
@testable import AcMindKit

@MainActor
final class ScheduleServiceTests: XCTestCase {

    var storage: InMemoryScheduleStorage!
    var scheduleService: ScheduleService!

    override func setUp() async throws {
        try await super.setUp()
        storage = InMemoryScheduleStorage()
        try await storage.setup()
        scheduleService = ScheduleService(storage: storage)
        try await scheduleService.setup()
    }

    override func tearDown() async throws {
        scheduleService = nil
        storage = nil
        try await super.tearDown()
    }

    private func makeEvent(
        id: String = UUID().uuidString,
        title: String = "测试事件",
        categoryId: String = "work",
        startHour: Int? = nil,
        endHour: Int? = nil,
        status: ScheduleEvent.EventStatus = .todo,
        priority: ScheduleEvent.EventPriority = .medium,
        tag: String? = nil,
        description: String? = nil
    ) -> ScheduleEvent {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let derivedStartHour = startHour ?? (abs(id.hashValue) % 20)
        let derivedEndHour = endHour ?? min(23, derivedStartHour + 1)
        return ScheduleEvent(
            id: id,
            title: title,
            description: description,
            categoryId: categoryId,
            startAt: cal.date(byAdding: .hour, value: derivedStartHour, to: today)!,
            endAt: cal.date(byAdding: .hour, value: derivedEndHour, to: today)!,
            isAllDay: false,
            status: status,
            priority: priority,
            tag: tag
        )
    }

    func testCreateAndGetEvent() async throws {
        let expectation = expectation(forNotification: .scheduleDidChange, object: nil, handler: nil)
        let event = makeEvent(id: "test-create-\(UUID().uuidString)", title: "团队周会")
        try await scheduleService.createEvent(event)
        await fulfillment(of: [expectation], timeout: 1.0)

        let retrieved = try await scheduleService.getEvent(id: event.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "团队周会")
        XCTAssertEqual(retrieved?.categoryId, "work")
    }

    func testListEventsWithFilter() async throws {
        let uid = UUID().uuidString
        let id1 = "filter-a-\(uid)"
        let id2 = "filter-b-\(uid)"
        try await scheduleService.createEvent(makeEvent(id: id1, title: "事件A-\(uid)", categoryId: "cat-\(uid)", startHour: 4, endHour: 5, status: .todo))
        try await scheduleService.createEvent(makeEvent(id: id2, title: "事件B-\(uid)", categoryId: "cat-\(uid)", startHour: 6, endHour: 7, status: .done))

        let retrieved1 = try await scheduleService.getEvent(id: id1)
        XCTAssertNotNil(retrieved1, "Event id1 should exist")

        let filtered = try await scheduleService.listEvents(filter: ScheduleEventFilter(categoryId: "cat-\(uid)"))
        XCTAssertTrue(filtered.contains { $0.id == id1 })
        XCTAssertTrue(filtered.contains { $0.id == id2 })

        let todoOnly = try await scheduleService.listEvents(filter: ScheduleEventFilter(status: .todo))
        XCTAssertTrue(todoOnly.contains { $0.id == id1 })

        let doneOnly = try await scheduleService.listEvents(filter: ScheduleEventFilter(status: .done))
        XCTAssertTrue(doneOnly.contains { $0.id == id2 })
    }

    func testGetEventsForDate() async throws {
        let id = "today-\(UUID().uuidString)"
        try await scheduleService.createEvent(makeEvent(id: id, title: "今天事件"))

        let todayEvents = try await scheduleService.getEventsForDate(Date())
        XCTAssertTrue(todayEvents.contains { $0.id == id })
    }

    func testGetEventsForWeek() async throws {
        let id = "week-\(UUID().uuidString)"
        try await scheduleService.createEvent(makeEvent(id: id, title: "本周事件"))

        let weekEvents = try await scheduleService.getEventsForWeek(of: Date())
        XCTAssertTrue(weekEvents.contains { $0.id == id })
    }

    func testSearchEvents() async throws {
        let id1 = "search-\(UUID().uuidString)"
        let id2 = "search-\(UUID().uuidString)"
        try await scheduleService.createEvent(makeEvent(id: id1, title: "产品评审会议", startHour: 8, endHour: 9, tag: "产品", description: "讨论Q3规划"))
        try await scheduleService.createEvent(makeEvent(id: id2, title: "代码审查", startHour: 10, endHour: 11, tag: "工程", description: "Review PR #123"))

        let results = try await scheduleService.searchEvents(query: "评审")
        XCTAssertTrue(results.contains { $0.id == id1 })

        let tagResults = try await scheduleService.searchEvents(query: "工程")
        XCTAssertTrue(tagResults.contains { $0.id == id2 })

        let allResults = try await scheduleService.searchEvents(query: "")
        XCTAssertTrue(allResults.count >= 2)
    }

    func testDeleteEvent() async throws {
        let id = "delete-\(UUID().uuidString)"
        let event = makeEvent(id: id, title: "待删除")
        try await scheduleService.createEvent(event)

        let before = try await scheduleService.getEvent(id: id)
        XCTAssertNotNil(before)

        try await scheduleService.deleteEvent(id: id)

        let after = try await scheduleService.getEvent(id: id)
        XCTAssertNil(after)
    }

    func testDeleteNonexistentEventThrows() async throws {
        do {
            try await scheduleService.deleteEvent(id: "nonexistent-\(UUID().uuidString)")
            XCTFail("Should throw eventNotFound")
        } catch {
            XCTAssertTrue(error is ScheduleError)
        }
    }

    func testGetStats() async throws {
        let base = UUID().uuidString
        try await scheduleService.createEvent(makeEvent(id: "stats-todo-\(base)", title: "待办", startHour: 12, endHour: 13, status: .todo))
        try await scheduleService.createEvent(makeEvent(id: "stats-done-\(base)", title: "已完成", startHour: 14, endHour: 15, status: .done))

        let stats = try await scheduleService.getStats()
        XCTAssertGreaterThanOrEqual(stats.todayEvents, 2)
        XCTAssertGreaterThanOrEqual(stats.completedToday, 1)
    }

    func testUpdateEvent() async throws {
        let id = "update-\(UUID().uuidString)"
        let event = makeEvent(id: id, title: "原标题")
        try await scheduleService.createEvent(event)

        let expectation = expectation(forNotification: .scheduleDidChange, object: nil, handler: nil)
        let updated = ScheduleEvent(
            id: id,
            title: "新标题",
            categoryId: event.categoryId,
            startAt: event.startAt,
            endAt: event.endAt,
            isAllDay: event.isAllDay,
            status: .done,
            priority: .high
        )
        try await scheduleService.updateEvent(updated)
        await fulfillment(of: [expectation], timeout: 1.0)

        let retrieved = try await scheduleService.getEvent(id: id)
        XCTAssertEqual(retrieved?.title, "新标题")
        XCTAssertEqual(retrieved?.status, .done)
        XCTAssertEqual(retrieved?.priority, .high)
    }

    func testCreateEventRejectsInvalidDateRange() async throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let invalid = ScheduleEvent(
            id: "invalid-\(UUID().uuidString)",
            title: "无效时间",
            categoryId: "work",
            startAt: cal.date(byAdding: .hour, value: 11, to: today)!,
            endAt: cal.date(byAdding: .hour, value: 10, to: today)!,
            isAllDay: false,
            status: .todo,
            priority: .medium
        )

        do {
            try await scheduleService.createEvent(invalid)
            XCTFail("Should throw invalidDateRange")
        } catch let error as ScheduleError {
            if case .invalidDateRange = error {
                return
            }
            XCTFail("Expected invalidDateRange, got \(error)")
        }
    }

    func testCreateEventRejectsConflictingActiveEvent() async throws {
        let first = makeEvent(id: "conflict-first-\(UUID().uuidString)", title: "第一项", startHour: 21, endHour: 22)
        let second = makeEvent(id: "conflict-second-\(UUID().uuidString)", title: "第二项", startHour: 21, endHour: 23)

        try await scheduleService.createEvent(first)

        do {
            try await scheduleService.createEvent(second)
            XCTFail("Should throw conflict")
        } catch let error as ScheduleError {
            if case .conflict(let conflictEvent) = error {
                XCTAssertEqual(conflictEvent.id, first.id)
                return
            }
            XCTFail("Expected conflict, got \(error)")
        }
    }

    func testUpdateEventAllowsSelfButRejectsOtherConflict() async throws {
        let first = makeEvent(id: "update-conflict-first-\(UUID().uuidString)", title: "第一项", startHour: 18, endHour: 19)
        let second = makeEvent(id: "update-conflict-second-\(UUID().uuidString)", title: "第二项", startHour: 20, endHour: 21)
        try await scheduleService.createEvent(first)
        try await scheduleService.createEvent(second)

        let updatedSelf = ScheduleEvent(
            id: first.id,
            title: "第一项更新",
            categoryId: first.categoryId,
            startAt: first.startAt,
            endAt: first.endAt,
            isAllDay: first.isAllDay,
            status: .done,
            priority: .high
        )
        try await scheduleService.updateEvent(updatedSelf)
        let retrievedSelf = try await scheduleService.getEvent(id: first.id)
        XCTAssertEqual(retrievedSelf?.status, .done)

        let conflictingUpdate = ScheduleEvent(
            id: first.id,
            title: "第一项再次更新",
            categoryId: first.categoryId,
            startAt: second.startAt.addingTimeInterval(-30 * 60),
            endAt: second.endAt,
            isAllDay: false,
            status: .todo,
            priority: .high
        )

        do {
            try await scheduleService.updateEvent(conflictingUpdate)
            XCTFail("Should throw conflict")
        } catch let error as ScheduleError {
            if case .conflict(let conflictEvent) = error {
                XCTAssertEqual(conflictEvent.id, second.id)
                return
            }
            XCTFail("Expected conflict, got \(error)")
        }
    }
}

final class InMemoryScheduleStorage: StorageServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String: ScheduleEvent] = [:]

    func setup() async throws {}

    func insertSourceItem(_ item: SourceItem) async throws {}
    func getSourceItem(id: String) async throws -> SourceItem? { nil }
    func listSourceItems(filter: SourceItemFilter?) async throws -> [SourceItem] { [] }
    func updateSourceItem(_ item: SourceItem) async throws {}
    func deleteSourceItem(id: String) async throws {}

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

    func insertClipboardItem(_ item: ClipboardItem) async throws {}
    func listClipboardItems(limit: Int?) async throws -> [ClipboardItem] { [] }
    func updateClipboardItem(_ item: ClipboardItem) async throws {}
    func deleteClipboardItem(id: String) async throws {}

    func insertClipboardTag(_ tag: ClipboardTag) async throws {}
    func listClipboardTags() async throws -> [ClipboardTag] { [] }
    func deleteClipboardTag(id: String) async throws {}
    func listClipboardItemsByTag(_ tagName: String, limit: Int?) async throws -> [ClipboardItem] { [] }
    func addTagToClipboardItem(itemId: String, tagName: String) async throws {}
    func removeTagFromClipboardItem(itemId: String, tagName: String) async throws {}

    func insertScheduledAgentTask(_ task: ScheduledAgentTask) async throws {}
    func getScheduledAgentTask(id: String) async throws -> ScheduledAgentTask? { nil }
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask] { [] }
    func deleteScheduledAgentTask(id: String) async throws {}

    func listProviders() async throws -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}

    func insertScheduleEvent(_ event: ScheduleEvent) async throws {
        lock.withLock { events[event.id] = event }
    }

    func updateScheduleEvent(_ event: ScheduleEvent) async throws {
        lock.withLock { events[event.id] = event }
    }

    func deleteScheduleEvent(id: String) async throws {
        _ = lock.withLock { events.removeValue(forKey: id) }
    }

    func listScheduleEvents() async throws -> [ScheduleEvent] {
        lock.withLock { Array(events.values) }
    }

    func getScheduleEvent(id: String) async throws -> ScheduleEvent? {
        lock.withLock { events[id] }
    }

    func getSetting(key: String) async throws -> String? { nil }
    func setSetting(key: String, value: String) async throws {}
    func deleteSetting(key: String) async throws {}

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { "/tmp/in-memory-schedule.sqlite" }
    func getDatabaseVersion() async throws -> Int { 1 }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
