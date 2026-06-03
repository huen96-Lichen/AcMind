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

    func testMonthViewCalendarDaysForDifferentMonthLengths() {
        let cal = Calendar.current

        let feb2026 = makeDate(year: 2026, month: 2, day: 1, hour: 0, minute: 0)
        let febInterval = cal.dateInterval(of: .month, for: feb2026)!
        let febDays = cal.dateComponents([.day], from: febInterval.start, to: febInterval.end).day!
        XCTAssertEqual(febDays, 28)

        let feb2024 = makeDate(year: 2024, month: 2, day: 1, hour: 0, minute: 0)
        let feb2024Interval = cal.dateInterval(of: .month, for: feb2024)!
        let feb2024Days = cal.dateComponents([.day], from: feb2024Interval.start, to: feb2024Interval.end).day!
        XCTAssertEqual(feb2024Days, 29)

        let apr2026 = makeDate(year: 2026, month: 4, day: 1, hour: 0, minute: 0)
        let aprInterval = cal.dateInterval(of: .month, for: apr2026)!
        let aprDays = cal.dateComponents([.day], from: aprInterval.start, to: aprInterval.end).day!
        XCTAssertEqual(aprDays, 30)

        let may2026 = makeDate(year: 2026, month: 5, day: 1, hour: 0, minute: 0)
        let mayInterval = cal.dateInterval(of: .month, for: may2026)!
        let mayDays = cal.dateComponents([.day], from: mayInterval.start, to: mayInterval.end).day!
        XCTAssertEqual(mayDays, 31)
    }

    func testMonthViewEventsMarkedCorrectly() {
        let viewModel = ScheduleViewModel(shouldLoadEvents: false)
        let june1 = makeDate(year: 2026, month: 6, day: 1, hour: 10, minute: 0)
        let june15 = makeDate(year: 2026, month: 6, day: 15, hour: 14, minute: 0)

        viewModel.selectedDate = june1
        viewModel.events = [
            ScheduleEvent(
                id: "evt-1",
                title: "会议",
                categoryId: "work",
                startAt: june1,
                endAt: june1.addingTimeInterval(3600),
                isAllDay: false,
                status: .todo,
                priority: .medium,
                tag: nil
            ),
            ScheduleEvent(
                id: "evt-2",
                title: "聚餐",
                categoryId: "life",
                startAt: june15,
                endAt: june15.addingTimeInterval(7200),
                isAllDay: false,
                status: .todo,
                priority: .medium,
                tag: nil
            )
        ]

        XCTAssertTrue(viewModel.hasEvents(on: june1))
        XCTAssertTrue(viewModel.hasEvents(on: june15))

        let june10 = makeDate(year: 2026, month: 6, day: 10, hour: 10, minute: 0)
        XCTAssertFalse(viewModel.hasEvents(on: june10))
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
