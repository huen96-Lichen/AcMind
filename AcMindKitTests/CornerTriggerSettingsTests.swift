import XCTest
import AppKit
@testable import AcMindKit

final class CornerTriggerSettingsTests: XCTestCase {
    private var userDefaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        userDefaultsSuiteName = "AcMindKitTests.CornerTriggerSettingsTests.\(UUID().uuidString)"
        clearPersistedState()
    }

    override func tearDown() {
        clearPersistedState()
        userDefaultsSuiteName = nil
        super.tearDown()
    }

    func testCornerDetectionMatchesEachDisplayCorner() {
        let frame = CGRect(x: 100, y: 200, width: 1000, height: 700)
        let hotZoneSize: CGFloat = 28

        XCTAssertEqual(ScreenCorner.corner(for: CGPoint(x: 104, y: 894), in: frame, hotZoneSize: hotZoneSize), .topLeft)
        XCTAssertEqual(ScreenCorner.corner(for: CGPoint(x: 1096, y: 894), in: frame, hotZoneSize: hotZoneSize), .topRight)
        XCTAssertEqual(ScreenCorner.corner(for: CGPoint(x: 104, y: 204), in: frame, hotZoneSize: hotZoneSize), .bottomLeft)
        XCTAssertEqual(ScreenCorner.corner(for: CGPoint(x: 1096, y: 204), in: frame, hotZoneSize: hotZoneSize), .bottomRight)
        XCTAssertNil(ScreenCorner.corner(for: CGPoint(x: 600, y: 550), in: frame, hotZoneSize: hotZoneSize))
    }

    func testRoundedCornerDetectionUsesCircularHotZone() {
        let frame = CGRect(x: 100, y: 200, width: 1000, height: 700)
        let radius: CGFloat = 28

        XCTAssertEqual(ScreenCorner.roundedCorner(for: CGPoint(x: 108, y: 892), in: frame, radius: radius), .topLeft)
        XCTAssertEqual(ScreenCorner.roundedCorner(for: CGPoint(x: 1092, y: 892), in: frame, radius: radius), .topRight)
        XCTAssertEqual(ScreenCorner.roundedCorner(for: CGPoint(x: 108, y: 208), in: frame, radius: radius), .bottomLeft)
        XCTAssertEqual(ScreenCorner.roundedCorner(for: CGPoint(x: 1092, y: 208), in: frame, radius: radius), .bottomRight)

        XCTAssertNil(ScreenCorner.roundedCorner(for: CGPoint(x: 127, y: 873), in: frame, radius: radius))
    }

    func testCornerSettingsStoreRoundTripsThroughUserDefaults() {
        let suite = makeUserDefaults()
        let expected = CornerTriggerSettings(
            isEnabled: true,
            corners: [
                .topLeft: .init(isEnabled: true, target: .builtIn(.showAgent)),
                .topRight: .init(isEnabled: false, target: .builtIn(.showConfiguration)),
                .bottomLeft: .init(isEnabled: true, target: .application(name: "Safari", bundleIdentifier: "com.apple.Safari", url: URL(fileURLWithPath: "/Applications/Safari.app"))),
                .bottomRight: .init(isEnabled: false, target: .builtIn(.captureScreenshot))
            ],
            desktopHintDisplayIDs: ["111", "222"]
        )

        CornerTriggerSettingsStore.save(expected, userDefaults: suite)
        let loaded = CornerTriggerSettingsStore.load(userDefaults: suite)

        XCTAssertEqual(loaded, expected)
    }

    func testCornerSettingsDefaultsDesktopHintDisplaysToCurrentScreens() {
        let settings = CornerTriggerSettings()
        XCTAssertEqual(settings.desktopHintDisplayIDs, Set(NSScreen.screens.map(Self.displayIdentifier(for:))))
    }

    private func clearPersistedState() {
        guard let suite = userDefaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) else { return }
        suite.removePersistentDomain(forName: userDefaultsSuiteName)
        suite.synchronize()
    }

    private func makeUserDefaults() -> UserDefaults {
        guard let suite = userDefaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) else {
            return .standard
        }
        return suite
    }

    private static func displayIdentifier(for screen: NSScreen) -> String {
        if let raw = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return raw.stringValue
        }
        return screen.localizedName
    }
}
