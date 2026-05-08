import XCTest
@testable import AcMindKit

final class TimelineLayoutTests: XCTestCase {
    func testVisualOverlapSplitsTouchingEventsIntoDifferentLanes() throws {
        let placements = layoutTimelineEvents(
            [
                TimelineEventSlice(id: "a", startMinute: 14 * 60, endMinute: 14 * 60 + 30),
                TimelineEventSlice(id: "b", startMinute: 14 * 60 + 30, endMinute: 15 * 60),
                TimelineEventSlice(id: "c", startMinute: 16 * 60, endMinute: 17 * 60),
            ],
            visibleStartHour: 6,
            hourHeight: 56,
            minimumHeight: 54,
            overlapPadding: 4
        )

        let a = try XCTUnwrap(placements.first { $0.id == "a" })
        let b = try XCTUnwrap(placements.first { $0.id == "b" })
        let c = try XCTUnwrap(placements.first { $0.id == "c" })

        XCTAssertEqual(a.laneCount, 2)
        XCTAssertEqual(b.laneCount, 2)
        XCTAssertNotEqual(a.lane, b.lane)
        XCTAssertEqual(c.laneCount, 1)
        XCTAssertEqual(c.lane, 0)
    }
}
