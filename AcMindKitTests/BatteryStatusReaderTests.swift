import XCTest
@testable import AcMindKit

@MainActor
final class BatteryStatusReaderTests: XCTestCase {
    func testNoBatterySnapshotUsesUnavailableStateInsteadOfZeroPercent() {
        let snapshot = BatteryStatusReader.noBatterySnapshot()
        XCTAssertFalse(snapshot.isAvailable)
        XCTAssertEqual(snapshot.state, "无电池")
        XCTAssertNil(snapshot.percentage)
        XCTAssertEqual(snapshot.unavailableReason, "无可用电池")
    }
}
