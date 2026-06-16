import XCTest
import UserNotifications
@testable import AcMindKit

final class PermissionStatusReaderTests: XCTestCase {
    func testPermissionSnapshotReflectsAuthorizationStateAndReason() {
        let authorized = PermissionStatusReader.permissionSnapshot(kind: .microphone, status: .authorized)
        let denied = PermissionStatusReader.permissionSnapshot(kind: .screenRecording, status: .denied)

        XCTAssertTrue(authorized.isAvailable)
        XCTAssertNil(authorized.unavailableReason)
        XCTAssertEqual(authorized.appPermissionKind, .microphone)
        XCTAssertFalse(denied.isAvailable)
        XCTAssertEqual(denied.value, "已拒绝")
        XCTAssertTrue(denied.unavailableReason?.contains("系统设置") == true)
    }

    func testEventPermissionSnapshotTreatsUndeterminedAsUnavailable() {
        let snapshot = PermissionStatusReader.eventPermissionSnapshot(
            id: "calendar",
            name: "日历",
            status: .notDetermined
        )

        XCTAssertFalse(snapshot.isAvailable)
        XCTAssertEqual(snapshot.value, "未确定")
        XCTAssertNotNil(snapshot.unavailableReason)
    }

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
