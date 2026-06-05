import XCTest
@testable import AcMindKit

final class KeyboardShortcutParsingTests: XCTestCase {
    func testParsesCommonSymbolShortcuts() throws {
        let shortcut = try XCTUnwrap(KeyboardShortcut(displayString: "⌥ C"))
        XCTAssertEqual(shortcut.key, "C")
        XCTAssertEqual(shortcut.modifiers, [.option])
        XCTAssertEqual(shortcut.displayString, "⌥+C")

        let commandShift = try XCTUnwrap(KeyboardShortcut(displayString: "⌘⇧4"))
        XCTAssertEqual(commandShift.key, "4")
        XCTAssertEqual(commandShift.modifiers, [.command, .shift])
        XCTAssertEqual(commandShift.displayString, "⌘+⇧+4")

        let commandComma = try XCTUnwrap(KeyboardShortcut(displayString: "⌘,"))
        XCTAssertEqual(commandComma.key, ",")
        XCTAssertEqual(commandComma.modifiers, [.command])
    }

    func testDoesNotParseFnOnlyShortcut() throws {
        XCTAssertNil(KeyboardShortcut(displayString: "Fn"))
        XCTAssertNil(KeyboardShortcut(displayString: "  "))
    }
}
