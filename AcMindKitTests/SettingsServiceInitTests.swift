import XCTest
@testable import AcMindKit

@MainActor
final class SettingsServiceInitTests: XCTestCase {
    func testInitWithoutPermissionManager() async throws {
        let storage = StorageService()
        try await storage.setup()
        let service = SettingsService(storage: storage, permissionManager: nil)
        XCTAssertNotNil(service)
    }

    func testModelManagementSummaryCountsRealItems() throws {
        let items = [
            ModelManagementItem(
                id: "ai1",
                displayName: "Provider A",
                domain: .ai,
                deploymentKind: .cloud,
                isDefault: true,
                isEnabled: true,
                isAvailable: true,
                isDownloaded: false,
                sizeLabel: "API",
                statusLabel: "可用",
                tags: []
            ),
            ModelManagementItem(
                id: "local1",
                displayName: "SenseVoice",
                domain: .speechRecognition,
                deploymentKind: .local,
                isDefault: false,
                isEnabled: true,
                isAvailable: true,
                isDownloaded: true,
                sizeLabel: "~350 MB",
                statusLabel: "已下载",
                tags: []
            )
        ]

        let summary = ModelManagementSummary(items: items)

        XCTAssertEqual(summary.totalCount, 2)
        XCTAssertEqual(summary.defaultCount, 1)
        XCTAssertEqual(summary.enabledCount, 2)
        XCTAssertEqual(summary.localCount, 1)
        XCTAssertEqual(summary.cloudCount, 1)
        XCTAssertEqual(summary.downloadedCount, 1)
    }
}
