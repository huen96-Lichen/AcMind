import XCTest
@testable import AcMindKit

final class SystemFanControlServiceTests: XCTestCase {
    func testFanControlStateCarriesPercentAndMode() {
        let state = SystemFanControlState(
            id: 0,
            fanIndex: 0,
            name: "Main Fan",
            rpm: 1400,
            minRPM: 1200,
            maxRPM: 4800,
            isAutomatic: false,
            controlPercent: 25,
            source: "AppleSMC",
            isAvailable: true,
            unavailableReason: nil
        )

        XCTAssertEqual(state.displayPercent, 25)
        XCTAssertEqual(state.displayRPM, 1400)
        XCTAssertEqual(state.isAutomatic, false)
        XCTAssertEqual(state.name, "Main Fan")
    }
}
