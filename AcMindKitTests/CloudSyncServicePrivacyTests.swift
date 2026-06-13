import XCTest
@testable import AcMindKit

final class CloudSyncServicePrivacyTests: XCTestCase {
    func testCloudSyncStatusSummaryExplainsDisabledState() {
        let summary = CloudSyncStatusSummary.make(
            from: SyncStatus(isEnabled: false),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(summary.title, "云同步未开启")
        XCTAssertEqual(summary.detail, "开启后会同步个人词典、知识卡片、蒸馏笔记、Agent 任务和设置。")
        XCTAssertFalse(summary.canRetry)
        XCTAssertNil(summary.retryTitle)
    }

    func testCloudSyncStatusSummaryExplainsFailureAndRetry() {
        let summary = CloudSyncStatusSummary.make(
            from: SyncStatus(
                isEnabled: true,
                lastSyncDate: Date(timeIntervalSince1970: 1_699_999_900),
                lastErrorMessage: "知识卡片超过 iCloud 同步大小限制"
            ),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(summary.title, "云同步需要重试")
        XCTAssertEqual(summary.detail, "知识卡片超过 iCloud 同步大小限制")
        XCTAssertTrue(summary.canRetry)
        XCTAssertEqual(summary.retryTitle, "重试同步")
    }

    func testCloudSyncStatusSummaryExplainsFreshSuccess() {
        let summary = CloudSyncStatusSummary.make(
            from: SyncStatus(
                isEnabled: true,
                lastSyncDate: Date(timeIntervalSince1970: 1_699_999_940),
                lastSyncByType: [.settings: Date(timeIntervalSince1970: 1_699_999_940)]
            ),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(summary.title, "云同步正常")
        XCTAssertEqual(summary.detail, "最近同步于 1 分钟前 · 已覆盖 1 类数据")
        XCTAssertFalse(summary.canRetry)
    }

    func testCloudSyncSettingsScreenUsesSharedSummaryLanguage() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Features/Native/Settings/SettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("cloudSyncSummary.title"))
        XCTAssertTrue(source.contains("cloudSyncSummary.detail"))
        XCTAssertTrue(source.contains("Button(\"刷新状态\")"))
        XCTAssertTrue(source.contains("await refreshCloudSyncSummary()"))
    }

    func testSanitizedSettingsBackupRedactsSensitiveFieldsWhenUploadIsDisabled() throws {
        let settings = AppSettings(
            theme: .dark,
            language: "zh-CN",
            defaultProviderId: "anthropic",
            defaultModelId: "gpt-4o",
            modelRoutingStrategy: .automatic,
            vaultPath: "/Users/test/PrivateVault",
            autoCaptureClipboard: false,
            captureScreenshotHotkey: "⌘⇧4",
            defaultExportTarget: .obsidian,
            autoFrontmatter: true
        )
        let preferences = SettingsLocalPreferences(sensitiveContentNotUpload: true)

        let sanitized = CloudSyncService.sanitizedSettingsBackup(settings, preferences: preferences)

        XCTAssertEqual(sanitized.theme, .dark)
        XCTAssertEqual(sanitized.language, "zh-CN")
        XCTAssertNil(sanitized.defaultProviderId)
        XCTAssertNil(sanitized.defaultModelId)
        XCTAssertEqual(sanitized.vaultPath, "")
        XCTAssertNil(sanitized.captureScreenshotHotkey)
        XCTAssertEqual(sanitized.autoCaptureClipboard, false)
        XCTAssertEqual(sanitized.defaultExportTarget, .obsidian)
    }

    func testSanitizedSettingsBackupLeavesFieldsUntouchedWhenUploadIsAllowed() throws {
        let settings = AppSettings(
            theme: .light,
            language: "en-US",
            defaultProviderId: "openai",
            defaultModelId: "gpt-4.1",
            modelRoutingStrategy: .privacyPriority,
            vaultPath: "/Users/test/Vault",
            autoCaptureClipboard: true,
            captureScreenshotHotkey: "⌥⌘4",
            defaultExportTarget: .local,
            autoFrontmatter: false
        )
        let preferences = SettingsLocalPreferences(sensitiveContentNotUpload: false)

        let sanitized = CloudSyncService.sanitizedSettingsBackup(settings, preferences: preferences)

        XCTAssertEqual(sanitized, settings)
    }
}
