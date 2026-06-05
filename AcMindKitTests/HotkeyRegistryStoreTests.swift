import XCTest
@testable import AcMindKit

final class HotkeyRegistryStoreTests: XCTestCase {
    func testHotkeyRegistryRoundTripThroughDefaults() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let shortcuts = [
            KeyboardShortcut(key: "1", modifiers: [.command]),
            KeyboardShortcut(key: "C", modifiers: [.option]),
            KeyboardShortcut(key: ",", modifiers: [.command])
        ]

        HotkeyRegistryStore.save(shortcuts, to: defaults)

        let loaded = HotkeyRegistryStore.load(from: defaults)
        XCTAssertEqual(loaded, shortcuts)
    }

    func testHotkeyRegistryClearRemovesPersistedValue() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        HotkeyRegistryStore.save([KeyboardShortcut(key: "1", modifiers: [.command])], to: defaults)
        HotkeyRegistryStore.clear(from: defaults)

        XCTAssertTrue(HotkeyRegistryStore.load(from: defaults).isEmpty)
        XCTAssertNil(defaults.data(forKey: "hotkeys.registry.v1"))
    }

    func testHotkeyRegistrySaveWorksFromBackgroundTask() async throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let box = DefaultsBox(defaults: defaults)
        let shortcuts = [
            KeyboardShortcut(key: "1", modifiers: [.command]),
            KeyboardShortcut(key: "K", modifiers: [.option, .shift])
        ]

        await Task.detached(priority: .background) { [box] in
            HotkeyRegistryStore.save(shortcuts, to: box.defaults)
            let loaded = HotkeyRegistryStore.load(from: box.defaults)
            XCTAssertEqual(loaded, shortcuts)
        }.value
    }

    func testHotkeyRegistryOverwritesPreviousValue() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = [KeyboardShortcut(key: "1", modifiers: [.command])]
        HotkeyRegistryStore.save(first, to: defaults)

        let second = [KeyboardShortcut(key: "2", modifiers: [.option])]
        HotkeyRegistryStore.save(second, to: defaults)

        let loaded = HotkeyRegistryStore.load(from: defaults)
        XCTAssertEqual(loaded, second)
        XCTAssertNotEqual(loaded, first)
    }

    func testHotkeyRegistryLoadReturnsEmptyForMissingData() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let loaded = HotkeyRegistryStore.load(from: defaults)
        XCTAssertTrue(loaded.isEmpty)
    }

    private let suiteName = "HotkeyRegistryStoreTests.\(UUID().uuidString)"

    private func makeIsolatedDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated defaults")
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct DefaultsBox: @unchecked Sendable {
    let defaults: UserDefaults
}
