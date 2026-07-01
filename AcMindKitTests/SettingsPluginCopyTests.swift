import XCTest

final class SettingsPluginCopyTests: XCTestCase {
    func testSettingsViewContainsPluginOverviewCard() throws {
        let source = try readSource("Features/Native/Settings/SettingsView.swift")

        XCTAssertTrue(source.contains("插件扩展"))
        XCTAssertTrue(source.contains("PluginManager.shared"))
        XCTAssertTrue(source.contains("pluginSummaryHeadline"))
        XCTAssertTrue(source.contains("pluginSummaryRow"))
        XCTAssertTrue(source.contains("pluginPolicySummary"))
        XCTAssertTrue(source.contains(".pluginManagerDidChange"))
        XCTAssertTrue(source.contains("loadPluginSummaries()"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
