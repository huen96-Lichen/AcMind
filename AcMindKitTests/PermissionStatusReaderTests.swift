import XCTest
import UserNotifications
@testable import AcMindKit

final class PermissionStatusReaderTests: XCTestCase {
    func testNotificationTextMapsKnownStatuses() {
        XCTAssertEqual(PermissionStatusReader.notificationText(for: .notDetermined), "未确定")
        XCTAssertEqual(PermissionStatusReader.notificationText(for: .denied), "已拒绝")
        XCTAssertEqual(PermissionStatusReader.notificationText(for: .authorized), "已授权")
        XCTAssertEqual(PermissionStatusReader.notificationText(for: .provisional), "已授权")
    }

    func testNotificationStatusUsesFetcherResult() {
        let status = PermissionStatusReader.notificationStatus { completion in
            completion(.denied)
        }

        XCTAssertEqual(status, "已拒绝")
    }
}
