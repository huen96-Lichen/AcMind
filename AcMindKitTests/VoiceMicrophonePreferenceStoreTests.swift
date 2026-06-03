import XCTest
@testable import AcMindKit

final class VoiceMicrophonePreferenceStoreTests: XCTestCase {
    func testVoiceMicrophonePreferenceRoundTripThroughDefaults() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        VoiceMicrophonePreferenceStore.save("Built-in Microphone", to: defaults)

        XCTAssertEqual(VoiceMicrophonePreferenceStore.load(from: defaults), "Built-in Microphone")
    }

    func testVoiceMicrophonePreferenceDefaultsToAutomaticSelection() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(VoiceMicrophonePreferenceStore.load(from: defaults), VoiceMicrophonePreferenceStore.defaultName)
    }

    private let suiteName = "VoiceMicrophonePreferenceStoreTests.\(UUID().uuidString)"

    private func makeIsolatedDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated defaults")
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
