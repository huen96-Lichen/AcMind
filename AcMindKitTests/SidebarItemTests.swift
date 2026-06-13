import XCTest
@testable import AcMindKit

final class SidebarItemTests: XCTestCase {
    func testCoreWorkflowUsesClipboardInsteadOfInbox() {
        XCTAssertEqual(SidebarItem.coreWorkflow, [.home, .agent, .clipboard, .schedule, .workbench])
        XCTAssertFalse(SidebarItem.coreWorkflow.contains(.inbox))
    }

    func testShortcutItemsUseClipboardAsPrimaryWorkspace() {
        XCTAssertTrue(SidebarItem.shortcutItems.contains(.clipboard))
        XCTAssertEqual(SidebarItem.clipboard.shortcut?.displayString, "⌘2")
    }

    func testCompanionCapabilitiesOrderIncludesStatusAfterVoiceEntry() {
        XCTAssertEqual(SidebarItem.companionCapabilities, [.dynamicContinent, .voiceEntry])
    }

    func testSystemItemsIncludeStatusFirst() {
        XCTAssertEqual(SidebarItem.systemItems, [.systemStatus, .settings, .modelManagement])
    }
}
