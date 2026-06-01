import XCTest
@testable import AcMindKit

@MainActor
final class CompanionDockingRulesTests: XCTestCase {
    func testDesktopCapsuleSnapsWhenDraggedIntoTopDockZone() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let snappedFrame = CGRect(x: 280, y: 860, width: 240, height: 40)
        let outsideSnapFrame = CGRect(x: 280, y: 840, width: 240, height: 40)

        XCTAssertTrue(CompanionDockingRules.shouldDockDesktopCapsuleToNotch(frame: snappedFrame, screenFrame: screenFrame))
        XCTAssertFalse(CompanionDockingRules.shouldDockDesktopCapsuleToNotch(frame: outsideSnapFrame, screenFrame: screenFrame))
    }

    func testPreferredScreenFramePicksTheScreenContainingTheFrameCenter() {
        let leftScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let rightScreen = CGRect(x: 1440, y: 0, width: 1440, height: 900)
        let frameOnRightScreen = CGRect(x: 1760, y: 850, width: 240, height: 33)

        let selected = CompanionScreenPositioning.preferredScreenFrame(
            for: frameOnRightScreen,
            screenFrames: [leftScreen, rightScreen]
        )

        XCTAssertEqual(selected, rightScreen)
    }

    func testCollapsedFrameIsCenteredOnTheChosenScreen() {
        let chosenScreen = CGRect(x: 1440, y: 0, width: 1440, height: 900)
        let frame = CompanionScreenPositioning.collapsedFrame(on: chosenScreen)

        XCTAssertEqual(frame.midX, chosenScreen.midX, accuracy: 0.001)
        XCTAssertEqual(frame.minY, chosenScreen.maxY - frame.height, accuracy: 0.001)
    }
}
