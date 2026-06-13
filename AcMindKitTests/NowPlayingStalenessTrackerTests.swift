import XCTest
@testable import AcMindKit

final class NowPlayingStalenessTrackerTests: XCTestCase {
    func testTrackerWaitsForConsecutiveMissesBeforeClearing() {
        var tracker = NowPlayingStalenessTracker(clearThreshold: 2)

        XCTAssertFalse(tracker.recordSourceMissing())
        XCTAssertTrue(tracker.recordSourceMissing())
        XCTAssertTrue(tracker.recordSourceMissing())
    }

    func testTrackerResetsAfterSourceFound() {
        var tracker = NowPlayingStalenessTracker(clearThreshold: 2)

        XCTAssertFalse(tracker.recordSourceMissing())
        tracker.recordSourceFound()
        XCTAssertFalse(tracker.recordSourceMissing())
        XCTAssertEqual(tracker.consecutiveMisses, 1)
    }
}
