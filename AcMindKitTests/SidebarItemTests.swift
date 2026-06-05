import XCTest
@testable import AcMindKit

final class SidebarItemTests: XCTestCase {
    func testCompanionCapabilitiesOrderIncludesStatusAfterVoiceEntry() {
        XCTAssertEqual(SidebarItem.companionCapabilities, [.dynamicContinent, .voiceEntry])
    }
}
