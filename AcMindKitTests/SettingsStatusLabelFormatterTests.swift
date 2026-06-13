import XCTest
@testable import AcMindKit

final class SettingsStatusLabelFormatterTests: XCTestCase {
    func testBinaryStateCoversCommonSettingsCopy() {
        XCTAssertEqual(
            SettingsStatusLabelFormatter.binaryState(
                isEnabled: true,
                enabledText: "已启用",
                disabledText: "未启用"
            ),
            "已启用"
        )
        XCTAssertEqual(
            SettingsStatusLabelFormatter.binaryState(
                isEnabled: false,
                enabledText: "已开启",
                disabledText: "已关闭"
            ),
            "已关闭"
        )
    }

    func testConfiguredAndPermissionSummariesReadNaturally() {
        XCTAssertEqual(SettingsStatusLabelFormatter.configuredState(isConfigured: true), "已配置")
        XCTAssertEqual(SettingsStatusLabelFormatter.configuredState(isConfigured: false), "未配置")
        XCTAssertEqual(SettingsStatusLabelFormatter.fallbackText(value: ""), "未设置")
        XCTAssertEqual(SettingsStatusLabelFormatter.fallbackText(value: "⌘⇧Space"), "⌘⇧Space")
        XCTAssertEqual(SettingsStatusLabelFormatter.permissionSummary(grantedCount: 2, totalCount: 3), "2/3 已授权")
    }

    func testUnconfiguredLabelsStayStable() {
        XCTAssertEqual(SettingsStatusLabelFormatter.unconfiguredModelText, "未配置模型")
        XCTAssertEqual(SettingsStatusLabelFormatter.unconfiguredProviderText, "未配置")
    }
}
