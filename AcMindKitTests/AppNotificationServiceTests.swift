import XCTest
@testable import AcMindKit

final class AppNotificationServiceTests: XCTestCase {
    func testShouldNotifyTaskCompletedRespectsSettingsFlags() {
        XCTAssertTrue(AppNotificationService.shouldNotifyTaskCompleted(with: AppNotificationSettings()))
        XCTAssertFalse(AppNotificationService.shouldNotifyTaskCompleted(with: AppNotificationSettings(notificationsEnabled: false)))
        XCTAssertFalse(AppNotificationService.shouldNotifyTaskCompleted(with: AppNotificationSettings(taskCompletedNotificationsEnabled: false)))
        XCTAssertFalse(AppNotificationService.shouldNotifyTaskCompleted(with: AppNotificationSettings(notificationsEnabled: false, taskCompletedNotificationsEnabled: true)))
    }

    func testNotificationSettingsEquality() {
        let a = AppNotificationSettings(notificationsEnabled: true, taskCompletedNotificationsEnabled: true)
        let b = AppNotificationSettings(notificationsEnabled: true, taskCompletedNotificationsEnabled: true)
        let c = AppNotificationSettings(notificationsEnabled: false, taskCompletedNotificationsEnabled: true)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCaptureNotificationGating() {
        let enabled = AppNotificationSettings(notificationsEnabled: true, taskCompletedNotificationsEnabled: true)
        XCTAssertTrue(AppNotificationService.shouldNotifyTaskCompleted(with: enabled))

        let disabled = AppNotificationSettings(notificationsEnabled: false, taskCompletedNotificationsEnabled: false)
        XCTAssertFalse(AppNotificationService.shouldNotifyTaskCompleted(with: disabled))
    }
}
