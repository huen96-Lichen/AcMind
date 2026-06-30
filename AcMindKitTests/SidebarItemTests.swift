import XCTest
@testable import AcMindKit

final class SidebarItemTests: XCTestCase {
    func testPrimaryNavigationMatchesAcWorkInformationArchitecture() {
        XCTAssertEqual(SidebarItem.coreWorkflow, [.home, .agent, .inbox, .screenshot, .schedule, .workbench])
        XCTAssertEqual(SidebarItem.companionCapabilities, [.dynamicContinent, .voiceEntry])
        XCTAssertEqual(SidebarItem.systemItems, [.systemStatus, .modelManagement])
        XCTAssertEqual(SidebarItem.mainItems.count, 10)
        XCTAssertFalse(SidebarItem.mainItems.contains(.clipboard))
        XCTAssertFalse(SidebarItem.mainItems.contains(.screenshotHistory))
    }

    func testPrimaryNavigationShortcutsAreUnique() {
        XCTAssertFalse(SidebarItem.shortcutItems.contains(.clipboard))
        XCTAssertFalse(SidebarItem.shortcutItems.contains(.screenshotHistory))
        let shortcuts = SidebarItem.shortcutItems.compactMap(\.shortcut?.displayString)
        XCTAssertEqual(shortcuts.count, Set(shortcuts).count)
        XCTAssertEqual(SidebarItem.inbox.shortcut?.key, "3")
    }

    func testUserFacingNamesMatchAcWorkNavigation() {
        XCTAssertEqual(SidebarItem.home.displayName, "工作台")
        XCTAssertEqual(SidebarItem.home.commandTitle, "前往工作台")
        XCTAssertEqual(SidebarItem.screenshot.displayName, "截图")
        XCTAssertEqual(SidebarItem.screenshot.commandTitle, "打开截图工作区")
        XCTAssertEqual(SidebarItem.dynamicContinent.displayName, "灵动大陆")
        XCTAssertEqual(SidebarItem.dynamicContinent.commandTitle, "前往灵动大陆")
        XCTAssertEqual(SidebarItem.modelManagement.displayName, "模型")
        XCTAssertEqual(SidebarItem.modelManagement.commandTitle, "前往模型")
    }

    func testLegacyClipboardRouteHasNoPrimaryShortcut() {
        XCTAssertNil(SidebarItem.clipboard.shortcut)
    }

    func testResponsiveInspectorPresentationUsesAcWorkWindowThresholds() {
        XCTAssertEqual(
            AcWorkResponsiveLayout.inspectorPresentation(windowWidth: 1179, hasInspector: true),
            .sheet
        )
        XCTAssertEqual(
            AcWorkResponsiveLayout.inspectorPresentation(windowWidth: 1180, hasInspector: true),
            .sheet
        )
        XCTAssertEqual(
            AcWorkResponsiveLayout.inspectorPresentation(windowWidth: 1319, hasInspector: true),
            .sheet
        )
        XCTAssertEqual(
            AcWorkResponsiveLayout.inspectorPresentation(windowWidth: 1320, hasInspector: true),
            .fixed
        )
        XCTAssertEqual(
            AcWorkResponsiveLayout.inspectorPresentation(windowWidth: 1500, hasInspector: false),
            .hidden
        )
    }
}
