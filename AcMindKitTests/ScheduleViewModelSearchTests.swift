import XCTest
@testable import AcMindKit

@MainActor
final class ScheduleViewModelSearchTests: XCTestCase {
    func testSearchFiltersEventsByTitleDescriptionTagCategoryAndStatus() {
        let viewModel = ScheduleViewModel(shouldLoadEvents: false)
        let date = makeDate(year: 2026, month: 6, day: 1, hour: 10, minute: 0)

        viewModel.selectedDate = date
        viewModel.events = [
            ScheduleEvent(
                id: "work-1",
                title: "项目评审",
                description: "讨论产品路线",
                categoryId: "work",
                startAt: date,
                endAt: date.addingTimeInterval(3600),
                isAllDay: false,
                status: .todo,
                priority: .medium,
                tag: "会议"
            ),
            ScheduleEvent(
                id: "study-1",
                title: "读书",
                description: "整理笔记",
                categoryId: "study",
                startAt: date,
                endAt: date.addingTimeInterval(3600),
                isAllDay: false,
                status: .done,
                priority: .medium,
                tag: "复盘"
            )
        ]

        viewModel.searchText = "项目"
        XCTAssertEqual(viewModel.events(for: date).map(\.id), ["work-1"])
        XCTAssertTrue(viewModel.hasEvents(on: date))

        viewModel.searchText = "整理"
        XCTAssertEqual(viewModel.events(for: date).map(\.id), ["study-1"])

        viewModel.searchText = "会议"
        XCTAssertEqual(viewModel.events(for: date).map(\.id), ["work-1"])

        viewModel.searchText = "工作"
        XCTAssertEqual(viewModel.events(for: date).map(\.id), ["work-1"])

        viewModel.searchText = "完成"
        XCTAssertEqual(viewModel.events(for: date).map(\.id), ["study-1"])

        viewModel.searchText = "不存在"
        XCTAssertTrue(viewModel.events(for: date).isEmpty)
        XCTAssertFalse(viewModel.hasEvents(on: date))
    }

    func testClearingSearchRestoresVisibleEvents() {
        let viewModel = ScheduleViewModel(shouldLoadEvents: false)
        let date = makeDate(year: 2026, month: 6, day: 1, hour: 9, minute: 0)

        viewModel.selectedDate = date
        viewModel.events = [
            ScheduleEvent(
                id: "event-1",
                title: "晨会",
                categoryId: "work",
                startAt: date,
                endAt: date.addingTimeInterval(1800),
                isAllDay: false,
                status: .todo,
                priority: .medium,
                tag: nil
            ),
            ScheduleEvent(
                id: "event-2",
                title: "午餐",
                categoryId: "life",
                startAt: date.addingTimeInterval(3600),
                endAt: date.addingTimeInterval(5400),
                isAllDay: false,
                status: .todo,
                priority: .medium,
                tag: nil
            )
        ]

        viewModel.searchText = "晨会"
        XCTAssertEqual(viewModel.events(for: date).map(\.id), ["event-1"])

        viewModel.searchText = ""
        XCTAssertEqual(viewModel.events(for: date).map(\.id), ["event-1", "event-2"])
        XCTAssertTrue(viewModel.hasEvents(on: date))
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components)!
    }
}
