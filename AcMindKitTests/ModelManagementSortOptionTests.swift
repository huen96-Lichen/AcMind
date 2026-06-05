import XCTest
@testable import AcMindKit

final class ModelManagementSortOptionTests: XCTestCase {
    func testRecommendedSortKeepsDefaultThenLocalThenAlphabetical() throws {
        let items = [
            ModelManagementItem(
                id: "cloud",
                displayName: "Cloud Alpha",
                domain: .ai,
                deploymentKind: .cloud,
                isDefault: false,
                isEnabled: true,
                isAvailable: true,
                isDownloaded: false,
                sizeLabel: "API",
                statusLabel: "可用",
                tags: []
            ),
            ModelManagementItem(
                id: "local",
                displayName: "Local Beta",
                domain: .speechRecognition,
                deploymentKind: .local,
                isDefault: false,
                isEnabled: true,
                isAvailable: true,
                isDownloaded: true,
                sizeLabel: "~350 MB",
                statusLabel: "已下载",
                tags: []
            ),
            ModelManagementItem(
                id: "default",
                displayName: "Default Omega",
                domain: .ai,
                deploymentKind: .api,
                isDefault: true,
                isEnabled: true,
                isAvailable: true,
                isDownloaded: false,
                sizeLabel: "API",
                statusLabel: "可用",
                tags: []
            )
        ]

        let recommended = ModelManagementSortOption.recommended.sort(items)
        XCTAssertEqual(recommended.map(\.id), ["default", "local", "cloud"])
    }

    func testLocalFirstSortMovesLocalItemsAheadOfOthers() throws {
        let items = [
            ModelManagementItem(
                id: "cloud",
                displayName: "Cloud Alpha",
                domain: .ai,
                deploymentKind: .cloud,
                isDefault: false,
                isEnabled: true,
                isAvailable: true,
                isDownloaded: false,
                sizeLabel: "API",
                statusLabel: "可用",
                tags: []
            ),
            ModelManagementItem(
                id: "local",
                displayName: "Local Beta",
                domain: .speechRecognition,
                deploymentKind: .local,
                isDefault: false,
                isEnabled: true,
                isAvailable: true,
                isDownloaded: true,
                sizeLabel: "~350 MB",
                statusLabel: "已下载",
                tags: []
            ),
            ModelManagementItem(
                id: "default",
                displayName: "Default Omega",
                domain: .ai,
                deploymentKind: .api,
                isDefault: true,
                isEnabled: true,
                isAvailable: true,
                isDownloaded: false,
                sizeLabel: "API",
                statusLabel: "可用",
                tags: []
            )
        ]

        let localFirst = ModelManagementSortOption.localFirst.sort(items)
        XCTAssertEqual(localFirst.map(\.id), ["local", "default", "cloud"])
    }
}
