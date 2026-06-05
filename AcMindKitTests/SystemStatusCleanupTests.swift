import XCTest

final class SystemStatusCleanupTests: XCTestCase {
    func testDynamicContinentNoLegacyStatusPanels() throws {
        let source = try readSource("Features/Native/DynamicContinent/DynamicContinentConfigView.swift")
        XCTAssertFalse(source.contains("采样通道"))
        XCTAssertFalse(source.contains("权限状态"))
        XCTAssertFalse(source.contains("系统事件"))
    }

    func testVoiceEntryOnlyKeepsStatusEntry() throws {
        let source = try readSource("Features/Native/VoiceEntry/VoiceEntryView.swift")
        XCTAssertFalse(source.contains("权限状态"))
        XCTAssertTrue(source.contains("查看状态"))
    }

    func testSettingsViewsOnlyKeepStatusJump() throws {
        let suiteSource = try readSource("Features/Native/Settings/SettingsSuiteView.swift")
        let viewSource = try readSource("Features/Native/Settings/SettingsView.swift")

        XCTAssertFalse(suiteSource.contains("诊断信息"))
        XCTAssertTrue(suiteSource.contains("查看状态"))
        XCTAssertFalse(viewSource.contains("诊断信息"))
        XCTAssertTrue(viewSource.contains("查看状态"))
    }

    func testNotchSummaryRailIsLightweight() throws {
        let source = try readSource("Features/Companion/NotchV2SystemStatusRail.swift")
        XCTAssertTrue(source.contains("查看状态"))
        XCTAssertFalse(source.contains("BatteryService"))
        XCTAssertFalse(source.contains("PermissionManager"))
    }

    func testSystemStatusViewIsWhiteBackgroundAndSnapshotDriven() throws {
        let source = try readSource("Features/Native/SystemStatus/SystemStatusView.swift")
        XCTAssertTrue(source.contains("Color.white.ignoresSafeArea()"))
        XCTAssertFalse(source.contains("BatteryService.shared"))
        XCTAssertFalse(source.contains("PermissionManager"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
