import XCTest
@testable import AcMindKit

final class CompanionDisplaySettingsStoreTests: XCTestCase {
    func testCompanionDisplaySettingsRoundTripThroughDefaults() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = CompanionDisplaySettings(
            isEnabled: false,
            autoExpand: true,
            hoverExpandDelay: 2.75,
            showOnAllDisplays: true,
            autoSwitchDisplays: false,
            preferredDisplayID: "display-1",
            hideInFullscreen: false,
            hideWhenScreenRecording: false,
            enabledDynamicModules: [.music, .schedule],
            overviewVisibleModules: [.music],
            collapsedVisibleContents: [.voice, .agent],
            primarySurfaceContents: [.systemStatus],
            nonNotchCollapsedWidth: 248,
            notchHeightMode: .custom,
            notchCustomHeight: 36,
            nonNotchHeightMode: .custom,
            nonNotchCustomHeight: 42,
            showCollapsedSubtitle: false,
            showCollapsedStatusDots: false,
            showSystemEventHUD: false,
            enabledSystemEventKinds: [.volume, .microphone]
        )

        CompanionDisplaySettingsStore.save(settings, to: defaults)

        let loaded = CompanionDisplaySettingsStore.load(from: defaults)

        XCTAssertEqual(loaded, settings)
    }

    func testCompanionDisplaySettingsDefaultsWhenUnset() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let loaded = CompanionDisplaySettingsStore.load(from: defaults)

        XCTAssertTrue(loaded.isEnabled)
        XCTAssertFalse(loaded.autoExpand)
        XCTAssertEqual(loaded.hoverExpandDelay, 1.5)
        XCTAssertEqual(loaded.enabledDynamicModules, Set(DynamicContinentModuleID.allCases))
    }

    private let suiteName = "CompanionDisplaySettingsStoreTests.\(UUID().uuidString)"

    private func makeIsolatedDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated defaults")
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
