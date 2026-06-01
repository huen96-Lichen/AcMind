import XCTest
@testable import AcMindKit

final class AppNotificationServiceTests: XCTestCase {
    func testShouldNotifyTaskCompletedRespectsSettingsFlags() {
        XCTAssertTrue(AppNotificationService.shouldNotifyTaskCompleted(with: AppNotificationSettings()))
        XCTAssertFalse(AppNotificationService.shouldNotifyTaskCompleted(with: AppNotificationSettings(notificationsEnabled: false)))
        XCTAssertFalse(AppNotificationService.shouldNotifyTaskCompleted(with: AppNotificationSettings(taskCompletedNotificationsEnabled: false)))
        XCTAssertFalse(AppNotificationService.shouldNotifyTaskCompleted(with: AppNotificationSettings(notificationsEnabled: false, taskCompletedNotificationsEnabled: true)))
    }
}
