import XCTest
@testable import AcMindKit

final class UsageBurnMonitorTests: XCTestCase {
    func testEmptySnapshotUsesStableDefaultState() async {
        let monitor = UsageBurnMonitor(
            windows: [
                UsageBurnWindowConfig(name: "5h", duration: 5 * 60 * 60, tokenLimit: 60_000)
            ],
            debounceSamples: 2
        )

        let snapshot = await monitor.snapshot(now: Date(timeIntervalSince1970: 1_000_000))

        XCTAssertEqual(snapshot, .empty)
    }

    func testSeverityIsDebouncedBeforeEscalating() async {
        let monitor = UsageBurnMonitor(
            windows: [
                UsageBurnWindowConfig(name: "1h", duration: 60 * 60, tokenLimit: 100)
            ],
            infoThreshold: 1.3,
            warningThreshold: 2.0,
            criticalThreshold: 3.0,
            debounceSamples: 2
        )

        let now = Date()
        let usage = ModelUsage(
            providerId: "provider-a",
            modelId: "model-a",
            totalTokens: 40,
            costCNY: 1.5,
            latencyMs: 120,
            timestamp: now.addingTimeInterval(-1_000)
        )

        await monitor.record(usage)
        let firstSnapshot = await monitor.snapshot(now: now)
        guard firstSnapshot.severity == .none,
              firstSnapshot.totalTokens == 40,
              firstSnapshot.totalRequests == 1,
              firstSnapshot.totalLatencyMs == 120,
              firstSnapshot.averageLatencyMs == 120,
              abs(firstSnapshot.totalCostCNY - 1.5) < 0.0001 else {
            XCTFail("first snapshot mismatch: \(firstSnapshot)")
            return
        }

        await monitor.record(usage)
        let secondSnapshot = await monitor.snapshot(now: now)
        guard secondSnapshot.severity == .warning,
              secondSnapshot.totalTokens == 80,
              secondSnapshot.totalRequests == 2,
              secondSnapshot.totalLatencyMs == 240,
              secondSnapshot.averageLatencyMs == 120,
              abs(secondSnapshot.totalCostCNY - 3.0) < 0.0001,
              abs((secondSnapshot.windows.first?.burnRatio ?? 0) - 2.88) < 0.01 else {
            XCTFail("second snapshot mismatch: \(secondSnapshot)")
            return
        }
    }

    func testLabelFormatterProducesReadableCopy() {
        let window = UsageBurnWindowSnapshot(
            name: "5h",
            duration: 5 * 60 * 60,
            tokenLimit: 60_000,
            tokenCount: 30_000,
            usagePercent: 0.5,
            elapsedPercent: 0.25,
            burnRatio: 2.0
        )
        let snapshot = UsageBurnSnapshot(
            severity: .warning,
            windows: [window],
            totalTokens: 30_000,
            totalCostCNY: 12.34,
            totalRequests: 5,
            totalLatencyMs: 720,
            averageLatencyMs: 144,
            lastUpdated: Date(timeIntervalSince1970: 1_000_000),
            note: "消耗速度偏快，可能提前超出预算"
        )

        XCTAssertEqual(AIUsageBurnLabelFormatter.statusText(for: snapshot), "预警")
        XCTAssertEqual(AIUsageBurnLabelFormatter.summaryText(for: snapshot), "预警 · 5h 2.00x")
        XCTAssertEqual(
            AIUsageBurnLabelFormatter.detailText(for: snapshot),
            "30000 tokens · ¥12.34 · 144ms 平均 · 消耗速度偏快，可能提前超出预算"
        )
        XCTAssertEqual(AIUsageBurnLabelFormatter.windowText(for: window), "5h 50% / 25% · 2.00x")
        XCTAssertEqual(AIUsageBurnLabelFormatter.thresholdHintText(), "阈值：1.3x 关注 · 2.0x 预警 · 3.0x 危险")
    }
}
