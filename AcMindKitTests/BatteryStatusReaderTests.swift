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

    func testExternalAdapterPowerParsingAcceptsNumericValues() {
        let wattsKey = kIOPSPowerAdapterWattsKey as String

        XCTAssertEqual(BatteryStatusReader.externalAdapterPowerW(from: [wattsKey: 87]), 87)
        XCTAssertEqual(BatteryStatusReader.externalAdapterPowerW(from: [wattsKey: NSNumber(value: 65.5)]) ?? -1, 65.5, accuracy: 0.0001)
        XCTAssertNil(BatteryStatusReader.externalAdapterPowerW(from: [:]))
    }
}
