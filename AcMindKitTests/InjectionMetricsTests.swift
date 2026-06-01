import XCTest
@testable import AcMindKit

@MainActor
final class InjectionMetricsTests: XCTestCase {

    func testRecordAddsEntry() async {
        let metrics = InjectionMetrics()

        await metrics.record(method: "clipboard", success: true)

        let stats = await metrics.getStats()
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats["clipboard"]?.attempts, 1)
        XCTAssertEqual(stats["clipboard"]?.successes, 1)
    }

    func testGetStatsAggregatesByMethod() async {
        let metrics = InjectionMetrics()

        await metrics.record(method: "clipboard", success: true)
        await metrics.record(method: "clipboard", success: false)
        await metrics.record(method: "clipboard", success: true)
        await metrics.record(method: "postToPid", success: true)

        let stats = await metrics.getStats()
        XCTAssertEqual(stats["clipboard"]?.attempts, 3)
        XCTAssertEqual(stats["clipboard"]?.successes, 2)
        XCTAssertEqual(stats["postToPid"]?.attempts, 1)
        XCTAssertEqual(stats["postToPid"]?.successes, 1)
    }

    func testGetStatsReturnsEmptyWhenNoRecords() async {
        let metrics = InjectionMetrics()

        let stats = await metrics.getStats()
        XCTAssertTrue(stats.isEmpty)
    }

    func testRecordsCappedAt1000() async {
        let metrics = InjectionMetrics()

        for i in 0..<1050 {
            await metrics.record(method: "method\(i % 2)", success: i % 3 != 0)
        }

        let stats = await metrics.getStats()
        let totalAttempts = stats.values.reduce(0) { $0 + $1.attempts }
        XCTAssertLessThanOrEqual(totalAttempts, 1000)
    }

    func testRecordFailedEntry() async {
        let metrics = InjectionMetrics()

        await metrics.record(method: "accessibility", success: false)

        let stats = await metrics.getStats()
        XCTAssertEqual(stats["accessibility"]?.attempts, 1)
        XCTAssertEqual(stats["accessibility"]?.successes, 0)
    }

    func testMultipleMethodsTrackedIndependently() async {
        let metrics = InjectionMetrics()

        await metrics.record(method: "clipboard", success: true)
        await metrics.record(method: "postToPid", success: true)
        await metrics.record(method: "accessibility", success: false)
        await metrics.record(method: "characterByCharacter", success: true)

        let stats = await metrics.getStats()
        XCTAssertEqual(stats.count, 4)
        XCTAssertEqual(stats["clipboard"]?.attempts, 1)
        XCTAssertEqual(stats["postToPid"]?.attempts, 1)
        XCTAssertEqual(stats["accessibility"]?.attempts, 1)
        XCTAssertEqual(stats["characterByCharacter"]?.attempts, 1)
    }
}
