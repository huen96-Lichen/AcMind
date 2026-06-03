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
}
