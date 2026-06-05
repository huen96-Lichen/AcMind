import XCTest
@testable import AcMindKit

@MainActor
final class PermissionManagerTests: XCTestCase {

    func testCheckPermission() {
        let manager = PermissionManager()

        for kind in AppPermissionKind.allCases {
            let status = manager.statuses[kind]
            XCTAssertNotNil(status, "Status for \(kind.rawValue) should not be nil")
            XCTAssertEqual(status, .unknown, "Initial status for \(kind.rawValue) should be unknown")
        }
    }

    func testPermissionKindCases() {
        let allCases = AppPermissionKind.allCases
        XCTAssertTrue(allCases.contains(.microphone))
        XCTAssertTrue(allCases.contains(.screenRecording))
        XCTAssertTrue(allCases.contains(.accessibility))
        XCTAssertTrue(allCases.contains(.fullDiskAccess))
    }

    func testPermissionStatusProperties() {
        XCTAssertTrue(AppPermissionStatus.unknown.isInteractive)
        XCTAssertTrue(AppPermissionStatus.denied.isInteractive)
        XCTAssertTrue(AppPermissionStatus.authorized.isInteractive)
        XCTAssertFalse(AppPermissionStatus.requesting.isInteractive)
    }
}
