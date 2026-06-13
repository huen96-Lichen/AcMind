import XCTest

final class SettingsStatusCopyTests: XCTestCase {
    func testSettingsViewsUseSharedStatusFormatter() throws {
        let settingsView = try readSource("Features/Native/Settings/SettingsView.swift")
        let settingsSuiteView = try readSource("Features/Native/Settings/SettingsSuiteView.swift")
        let voiceEntryView = try readSource("Features/Native/VoiceEntry/VoiceEntryView.swift")

        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.binaryState"))
        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.configuredState"))
        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.localStorageText"))
        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.unconfiguredProviderText"))
        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.backupSectionDescription"))
        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.createBackupText"))
        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.restoreBackupText"))
        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.autoBackupText"))
        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.backupLastRunText"))
        XCTAssertTrue(settingsView.contains("SettingsStatusLabelFormatter.backupTriggerText"))
        XCTAssertTrue(settingsView.contains("AIUsageBurnLabelFormatter.thresholdHintText"))
        XCTAssertTrue(settingsView.contains("AIUsageBurnLabelFormatter.detailText"))
        XCTAssertTrue(settingsSuiteView.contains("SettingsStatusLabelFormatter.binaryState"))
        XCTAssertTrue(settingsSuiteView.contains("SettingsStatusLabelFormatter.permissionSummary"))
        XCTAssertTrue(settingsSuiteView.contains("SettingsStatusLabelFormatter.fallbackText"))
        XCTAssertTrue(settingsSuiteView.contains("SettingsStatusLabelFormatter.binaryState("))
        XCTAssertTrue(voiceEntryView.contains("SettingsStatusLabelFormatter.binaryState"))
        XCTAssertTrue(voiceEntryView.contains("outputSummaryText"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
