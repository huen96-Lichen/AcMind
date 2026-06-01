import XCTest
@testable import AcMindKit

final class HotCornerSettingsTests: XCTestCase {
    func testDefaultHotCornerSettingsUsesEmptyBindings() {
        let settings = AppSettings()

        XCTAssertEqual(settings.hotCornerSettings.bindings.count, 4)
        XCTAssertEqual(settings.hotCornerSettings.cornerSize, 24)
        XCTAssertEqual(settings.hotCornerSettings.bindings[.topLeft]?.action, HotCornerAction.none)
        XCTAssertEqual(settings.hotCornerSettings.bindings[.topRight]?.action, HotCornerAction.none)
        XCTAssertEqual(settings.hotCornerSettings.bindings[.bottomLeft]?.action, HotCornerAction.none)
        XCTAssertEqual(settings.hotCornerSettings.bindings[.bottomRight]?.action, HotCornerAction.none)
    }

    func testHotCornerSettingsRoundTripsThroughJSON() throws {
        let original = HotCornerSettings(
            cornerSize: 72,
            bindings: [
                .topLeft: HotCornerBinding(action: .openApp(bundleIdentifier: "com.apple.Safari")),
                .topRight: HotCornerBinding(action: .toggleFeature(featureIdentifier: "dynamicContinent")),
                .bottomLeft: HotCornerBinding(action: .openURL(urlString: "https://example.com")),
                .bottomRight: HotCornerBinding(action: .none)
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotCornerSettings.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}
