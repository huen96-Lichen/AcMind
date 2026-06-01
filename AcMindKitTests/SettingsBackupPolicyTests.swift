import XCTest
@testable import AcMindKit

final class SettingsBackupPolicyTests: XCTestCase {
    func testAutomaticBackupRunsWhenEnabledAndNeverBackedUp() {
        XCTAssertTrue(SettingsBackupPolicy.shouldPerformAutomaticBackup(enabled: true, lastAutoBackupAt: nil, now: Date()))
    }

    func testAutomaticBackupSkipsWhenDisabled() {
        let now = Date()
        XCTAssertFalse(SettingsBackupPolicy.shouldPerformAutomaticBackup(enabled: false, lastAutoBackupAt: nil, now: now))
        XCTAssertFalse(SettingsBackupPolicy.shouldPerformAutomaticBackup(enabled: false, lastAutoBackupAt: now.addingTimeInterval(-8 * 24 * 60 * 60), now: now))
    }

    func testAutomaticBackupRunsOnlyAfterSevenDays() {
        let now = Date()
        let recent = now.addingTimeInterval(-6 * 24 * 60 * 60)
        let stale = now.addingTimeInterval(-8 * 24 * 60 * 60)

        XCTAssertFalse(SettingsBackupPolicy.shouldPerformAutomaticBackup(enabled: true, lastAutoBackupAt: recent, now: now))
        XCTAssertTrue(SettingsBackupPolicy.shouldPerformAutomaticBackup(enabled: true, lastAutoBackupAt: stale, now: now))
    }
}
