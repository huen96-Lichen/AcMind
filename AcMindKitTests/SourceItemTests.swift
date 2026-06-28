import XCTest
@testable import AcMindKit

final class SourceItemTests: XCTestCase {
    func testAgentGeneratedHelperReflectsSourceOrigin() {
        let agentItem = SourceItem(source: .agent)
        let manualItem = SourceItem(source: .manual)

        XCTAssertTrue(agentItem.isAgentGenerated)
        XCTAssertFalse(manualItem.isAgentGenerated)
    }

    func testSourceOriginKeepsScreenshotOcrAsDistinctOrigin() {
        XCTAssertEqual(SourceOrigin(collectionSource: .screenshotOCR), .screenshotOCR)
        XCTAssertEqual(SourceOrigin.screenshotOCR.displayName, "截图 OCR")
        XCTAssertTrue(SourceOrigin.allCases.contains(.screenshotOCR))
    }
}
