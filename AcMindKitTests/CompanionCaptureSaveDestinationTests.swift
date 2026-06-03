import XCTest
@testable import AcMindKit

final class CompanionCaptureSaveDestinationTests: XCTestCase {
    func testSaveDestinationDisplayNamesAreStable() {
        XCTAssertEqual(CompanionCaptureSaveDestination.inbox.displayName, "收集箱")
        XCTAssertEqual(CompanionCaptureSaveDestination.clipboard.displayName, "剪贴板")
        XCTAssertEqual(CompanionCaptureSaveDestination.ask.displayName, "询问")
    }

    func testSaveDestinationDescriptionsMatchUserFacingBehavior() {
        XCTAssertEqual(CompanionCaptureSaveDestination.inbox.description, "捕获后默认进入收集箱")
        XCTAssertEqual(CompanionCaptureSaveDestination.clipboard.description, "捕获后复制结果到剪贴板")
        XCTAssertEqual(CompanionCaptureSaveDestination.ask.description, "每次捕获后询问下一步")
    }

    func testSaveDestinationRawValuesStayAlignedWithStoredIndex() {
        XCTAssertEqual(CompanionCaptureSaveDestination(rawValue: 0), .inbox)
        XCTAssertEqual(CompanionCaptureSaveDestination(rawValue: 1), .clipboard)
        XCTAssertEqual(CompanionCaptureSaveDestination(rawValue: 2), .ask)
    }
}
