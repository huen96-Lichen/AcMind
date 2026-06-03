import XCTest
@testable import AcMindKit

final class DesktopCapsuleConfigTests: XCTestCase {
    func testDefaultDesktopCapsuleIncludesScrollScreenshot() {
        let defaultTypes = DesktopCapsuleSettings.default.enabledActions.map(\.type)

        XCTAssertEqual(defaultTypes.first, .screenshot)
        XCTAssertTrue(defaultTypes.contains(.scrollScreenshot))
        XCTAssertEqual(defaultTypes[1], .scrollScreenshot)
        XCTAssertNil(DesktopCapsuleSettings.default.lastWebpageURL)
    }

    func testDesktopCapsuleSettingsRoundTripsLastWebpageURL() throws {
        let settings = DesktopCapsuleSettings(
            isEnabled: true,
            showOnLaunch: false,
            actions: [.default(type: .urlToText, order: 0)],
            position: CGPoint(x: 12, y: 34),
            lastWebpageURL: URL(string: "https://example.com/articles/123")!
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(DesktopCapsuleSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }
}
