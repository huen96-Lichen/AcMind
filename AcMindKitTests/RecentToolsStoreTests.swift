import XCTest
@testable import AcMindKit

final class RecentToolsStoreTests: XCTestCase {
    func testRecentToolsRoundTripThroughDefaults() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let records = [
            RecentToolRecord(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                toolId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "Markdown 整理",
                description: "自动整理和格式化 Markdown 文档",
                icon: "text.quote",
                category: "text",
                route: "markdownCleaner",
                lastUsedDate: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            RecentToolRecord(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                toolId: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                name: "JSON 格式化",
                description: "格式化 JSON",
                icon: "curlybraces",
                category: "developer",
                route: "jsonFormatter",
                lastUsedDate: Date(timeIntervalSince1970: 1_700_000_100)
            )
        ]

        RecentToolsStore.save(records, to: defaults)

        let loaded = RecentToolsStore.load(from: defaults)

        XCTAssertEqual(loaded, records)
    }

    func testRecentToolsClearRemovesPersistedValue() throws {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        RecentToolsStore.save([
            RecentToolRecord(
                id: UUID(),
                toolId: UUID(),
                name: "临时工具",
                description: "临时描述",
                icon: "wrench",
                category: "utility",
                route: "apiTest",
                lastUsedDate: Date()
            )
        ], to: defaults)

        RecentToolsStore.clear(from: defaults)

        XCTAssertTrue(RecentToolsStore.load(from: defaults).isEmpty)
        XCTAssertNil(defaults.data(forKey: "tools.recentTools.v1"))
    }

    private let suiteName = "RecentToolsStoreTests.\(UUID().uuidString)"

    private func makeIsolatedDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated defaults")
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
