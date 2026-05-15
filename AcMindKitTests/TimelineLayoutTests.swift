import XCTest
@testable import AcMindKit

final class TimelineLayoutTests: XCTestCase {
    func testCompanionSettingsDesignTokensArePinnedToProductLayout() {
        XCTAssertEqual(CompanionControlLayout.contentMaxWidth, 1240, accuracy: 0.1)
        XCTAssertEqual(CompanionControlLayout.contentHeight, 740, accuracy: 0.1)
        XCTAssertEqual(CompanionControlLayout.previewSectionHeight, 218, accuracy: 0.1)
        XCTAssertEqual(CompanionControlLayout.widgetItemWidth, 76, accuracy: 0.1)
        XCTAssertEqual(CompanionControlLayout.featureCardHeight, 92, accuracy: 0.1)
    }

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

    func testCompanionMenuBarLayoutUsesUnifiedExpandedFrame() {
        XCTAssertEqual(CompanionMenuBarLayout.expandedWidth, 880, accuracy: 0.1)
        XCTAssertEqual(CompanionMenuBarLayout.expandedHeight, 440, accuracy: 0.1)
    }

    func testCompanionMenuBarLayoutKeepsLeadingEdgeStableWhenExpandingAndCollapsing() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        let collapsed = CompanionScreenPositioning.collapsedFrame(on: screen)
        let expanded = CompanionScreenPositioning.expandedFrame(anchoredTo: collapsed)
        let collapsedAgain = CompanionScreenPositioning.collapsedFrame(anchoredTo: expanded)

        XCTAssertEqual(expanded.minX, collapsed.minX, accuracy: 0.5)
        XCTAssertEqual(collapsedAgain.minX, collapsed.minX, accuracy: 0.5)
    }

    func testCompanionMenuBarLayoutKeepsTopCenterStableWhenExpandingAndCollapsing() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        let collapsed = CompanionScreenPositioning.collapsedFrame(on: screen)
        let expanded = CompanionScreenPositioning.expandedFrame(centeredOnX: collapsed.midX, on: screen)
        let collapsedAgain = CompanionScreenPositioning.collapsedFrame(centeredOnX: expanded.midX, on: screen)

        XCTAssertEqual(expanded.midX, collapsed.midX, accuracy: 0.5)
        XCTAssertEqual(collapsedAgain.midX, collapsed.midX, accuracy: 0.5)
    }
}
