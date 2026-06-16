import XCTest
@testable import AcMindKit

final class SystemSMCBridgeTests: XCTestCase {
    func testFanPercentageMapsIntoRPMRange() {
        XCTAssertEqual(SystemSMCBridge.percentageToFanRPM(0, minRPM: 1200, maxRPM: 4800), 1200)
        XCTAssertEqual(SystemSMCBridge.percentageToFanRPM(50, minRPM: 1200, maxRPM: 4800), 3000)
        XCTAssertEqual(SystemSMCBridge.percentageToFanRPM(100, minRPM: 1200, maxRPM: 4800), 4800)
    }

    func testFanRPMMapsBackIntoPercentage() {
        XCTAssertEqual(SystemSMCBridge.rpmToPercentage(1200, minRPM: 1200, maxRPM: 4800) ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(SystemSMCBridge.rpmToPercentage(3000, minRPM: 1200, maxRPM: 4800) ?? -1, 50, accuracy: 0.001)
        XCTAssertEqual(SystemSMCBridge.rpmToPercentage(4800, minRPM: 1200, maxRPM: 4800) ?? -1, 100, accuracy: 0.001)
    }
}
