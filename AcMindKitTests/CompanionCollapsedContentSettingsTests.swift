import XCTest
@testable import AcMindKit

final class CompanionCollapsedContentSettingsTests: XCTestCase {
    func testCollapsedContentSettingsDefaultsToCurrentStatus() {
        let settings = CompanionCollapsedContentSettings.default

        XCTAssertEqual(settings.source, .currentStatus)
        XCTAssertEqual(settings.customLabel, "当前状态")
        XCTAssertEqual(settings.customTitle, "待命")
        XCTAssertEqual(settings.customSubtitle, "可自定义展示内容")
        XCTAssertEqual(settings.customSymbol, "sparkles")
    }

    func testCollapsedContentSettingsRoundTripsThroughJSON() throws {
        let settings = CompanionCollapsedContentSettings(
            source: .custom,
            customLabel: "我的状态",
            customTitle: "专注中",
            customSubtitle: "正在工作",
            customSymbol: "bolt.fill"
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(CompanionCollapsedContentSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }
}
