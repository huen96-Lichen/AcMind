import XCTest
@testable import AcMindKit

@MainActor
final class SchedulePlanningTests: XCTestCase {
    func testPlanningSnapshotHighlightsCurrentNextConflictAndFreeWindow() {
        let viewModel = ScheduleViewModel(shouldLoadEvents: false)
        let now = makeDate(year: 2026, month: 6, day: 14, hour: 9, minute: 45)

        viewModel.selectedDate = now
        viewModel.events = [
            makeEvent(
                id: "morning",
                title: "晨会",
                startHour: 9,
                startMinute: 0,
                durationMinutes: 60,
                status: .todo
            ),
            makeEvent(
                id: "sync",
                title: "冲刺同步",
                startHour: 9,
                startMinute: 30,
                durationMinutes: 60,
                status: .todo
            ),
            makeEvent(
                id: "review",
                title: "评审",
                startHour: 11,
                startMinute: 0,
                durationMinutes: 60,
                status: .done
            ),
            makeEvent(
                id: "afternoon",
                title: "下午整理",
                startHour: 14,
                startMinute: 0,
                durationMinutes: 60,
                status: .todo
            )
        ]

        let snapshot = viewModel.planningSnapshot(for: now, referenceDate: now)

        XCTAssertEqual(snapshot.currentEvent?.id, "morning")
        XCTAssertEqual(snapshot.nextEvent?.id, "review")
        XCTAssertEqual(snapshot.conflict?.first.id, "morning")
        XCTAssertEqual(snapshot.conflict?.second.id, "sync")
        XCTAssertEqual(snapshot.freeWindow?.start, makeDate(year: 2026, month: 6, day: 14, hour: 10, minute: 30))
        XCTAssertEqual(snapshot.freeWindow?.end, makeDate(year: 2026, month: 6, day: 14, hour: 11, minute: 0))
        XCTAssertEqual(snapshot.totalEventCount, 4)
        XCTAssertEqual(snapshot.activeEventCount, 4)
        XCTAssertEqual(snapshot.completedEventCount, 1)
        XCTAssertEqual(snapshot.allDayEventCount, 0)
        XCTAssertEqual(snapshot.overdueEventCount, 0)
    }

    func testPlanningSnapshotSeparatesAllDayAndOverdueStates() {
        let viewModel = ScheduleViewModel(shouldLoadEvents: false)
        let now = makeDate(year: 2026, month: 6, day: 14, hour: 18, minute: 0)

        viewModel.selectedDate = now
        viewModel.events = [
            makeEvent(
                id: "all-day",
                title: "全天待命",
                startHour: 0,
                startMinute: 0,
                durationMinutes: 24 * 60,
                isAllDay: true,
                status: .todo
            ),
            makeEvent(
                id: "overdue",
                title: "午间回顾",
                startHour: 8,
                startMinute: 0,
                durationMinutes: 60,
                status: .todo
            ),
            makeEvent(
                id: "done",
                title: "午前复盘",
                startHour: 10,
                startMinute: 0,
                durationMinutes: 60,
                status: .done
            )
        ]

        let snapshot = viewModel.planningSnapshot(for: now, referenceDate: now)

        XCTAssertEqual(snapshot.currentEvent?.id, "all-day")
        XCTAssertNil(snapshot.nextEvent)
        XCTAssertEqual(snapshot.allDayEventCount, 1)
        XCTAssertEqual(snapshot.overdueEventCount, 1)
        XCTAssertEqual(viewModel.events[0].timingState(referenceDate: now), .allDay)
        XCTAssertEqual(viewModel.events[1].timingState(referenceDate: now), .overdue)
        XCTAssertEqual(viewModel.events[2].timingState(referenceDate: now), .done)
    }

    private func makeEvent(
        id: String,
        title: String,
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int,
        isAllDay: Bool = false,
        status: ScheduleEvent.EventStatus = .todo
    ) -> ScheduleEvent {
        let start = makeDate(year: 2026, month: 6, day: 14, hour: startHour, minute: startMinute)
        return ScheduleEvent(
            id: id,
            title: title,
            categoryId: "work",
            startAt: start,
            endAt: isAllDay ? makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0) : start.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            isAllDay: isAllDay,
            status: status,
            priority: .medium,
            tag: nil
        )
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
