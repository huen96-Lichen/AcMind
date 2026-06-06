import XCTest
@testable import AcMindKit

final class CloudSyncServicePrivacyTests: XCTestCase {
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
