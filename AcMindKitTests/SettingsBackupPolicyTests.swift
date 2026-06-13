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

    func testBackupStatusCopyUsesSharedFormatter() {
        let now = Date()
        let recent = now.addingTimeInterval(-6 * 24 * 60 * 60)

        XCTAssertEqual(
            SettingsStatusLabelFormatter.backupSectionDescription(autoBackupEnabled: true),
            "自动备份已开启，每 7 天保存一次本地快照。"
        )
        XCTAssertEqual(
            SettingsStatusLabelFormatter.backupSectionDescription(autoBackupEnabled: false),
            "自动备份已关闭，仍可手动创建备份。"
        )
        XCTAssertEqual(
            SettingsStatusLabelFormatter.backupLastRunText(lastAutoBackupAt: nil),
            "尚未备份"
        )
        XCTAssertEqual(
            SettingsStatusLabelFormatter.backupTriggerText(enabled: true, lastAutoBackupAt: recent, now: now),
            "下次自动备份尚未到期"
        )
        XCTAssertEqual(
            SettingsStatusLabelFormatter.backupTriggerText(enabled: false, lastAutoBackupAt: nil, now: now),
            "自动备份已关闭"
        )
    }
}
