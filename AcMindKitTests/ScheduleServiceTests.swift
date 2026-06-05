import XCTest
@testable import AcMindKit

@MainActor
final class ScheduleServiceTests: XCTestCase {

    var storage: StorageService!
    var scheduleService: ScheduleService!

    override func setUp() async throws {
        try await super.setUp()
        storage = StorageService()
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
        startHour: Int = 10,
        endHour: Int = 11,
        status: ScheduleEvent.EventStatus = .todo,
        priority: ScheduleEvent.EventPriority = .medium,
        tag: String? = nil,
        description: String? = nil
    ) -> ScheduleEvent {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return ScheduleEvent(
            id: id,
            title: title,
            description: description,
            categoryId: categoryId,
            startAt: cal.date(byAdding: .hour, value: startHour, to: today)!,
            endAt: cal.date(byAdding: .hour, value: endHour, to: today)!,
            isAllDay: false,
            status: status,
            priority: priority,
            tag: tag
        )
    }

    func testCreateAndGetEvent() async throws {
        let event = makeEvent(id: "test-create-\(UUID().uuidString)", title: "团队周会")
        try await scheduleService.createEvent(event)

        let retrieved = try await scheduleService.getEvent(id: event.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, "团队周会")
        XCTAssertEqual(retrieved?.categoryId, "work")
    }

    func testListEventsWithFilter() async throws {
        let uid = UUID().uuidString
        let id1 = "filter-a-\(uid)"
        let id2 = "filter-b-\(uid)"
        try await scheduleService.createEvent(makeEvent(id: id1, title: "事件A-\(uid)", categoryId: "cat-\(uid)", status: .todo))
        try await scheduleService.createEvent(makeEvent(id: id2, title: "事件B-\(uid)", categoryId: "cat-\(uid)", status: .done))

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
        try await scheduleService.createEvent(makeEvent(id: id1, title: "产品评审会议", tag: "产品", description: "讨论Q3规划"))
        try await scheduleService.createEvent(makeEvent(id: id2, title: "代码审查", tag: "工程", description: "Review PR #123"))

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
        try await scheduleService.createEvent(makeEvent(id: "stats-todo-\(base)", title: "待办", status: .todo))
        try await scheduleService.createEvent(makeEvent(id: "stats-done-\(base)", title: "已完成", status: .done))

        let stats = try await scheduleService.getStats()
        XCTAssertGreaterThanOrEqual(stats.todayEvents, 2)
        XCTAssertGreaterThanOrEqual(stats.completedToday, 1)
    }

    func testUpdateEvent() async throws {
        let id = "update-\(UUID().uuidString)"
        let event = makeEvent(id: id, title: "原标题")
        try await scheduleService.createEvent(event)

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

        let retrieved = try await scheduleService.getEvent(id: id)
        XCTAssertEqual(retrieved?.title, "新标题")
        XCTAssertEqual(retrieved?.status, .done)
        XCTAssertEqual(retrieved?.priority, .high)
    }
}
