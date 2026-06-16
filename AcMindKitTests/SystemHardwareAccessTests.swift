import XCTest
@testable import AcMindKit

final class SystemHardwareAccessTests: XCTestCase {
    func testHelperTransportWinsWhenAvailable() {
        let helper = MockHardwareTransport(isAvailable: true)
        let local = MockHardwareTransport(isAvailable: true)
        let access = SystemHardwareAccess(
            helperProvider: { helper },
            localProvider: { local }
        )

        let transport = access.makeDefaultTransport()

        XCTAssertTrue(transport === helper)
    }

    func testLocalTransportIsUsedWhenHelperMissing() {
        let local = MockHardwareTransport(isAvailable: true)
        let access = SystemHardwareAccess(
            helperProvider: { nil },
            localProvider: { local }
        )

        let transport = access.makeDefaultTransport()

        XCTAssertTrue(transport === local)
    }
}

private final class MockHardwareTransport: SystemHardwareTransport {
    let isAvailable: Bool

    init(isAvailable: Bool) {
        self.isAvailable = isAvailable
    }

    func refreshFanControlStates() -> [SystemFanControlState] {
        []
    }

    func setFanPercentage(fanIndex: Int, percentage: Double) -> Bool {
        true
    }

    func setFanAutomatic(fanIndex: Int) -> Bool {
        true
    }

    func resetFanControl() -> Bool {
        true
    }
}

