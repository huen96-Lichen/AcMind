import XCTest
@testable import AcMindKit

final class SystemStatusMetricsTests: XCTestCase {
    func testCPUUsageIsCalculatedFromTickDelta() {
        let previous = SystemCPUTickTotals(user: 100, system: 50, idle: 850, nice: 0)
        let current = SystemCPUTickTotals(user: 110, system: 55, idle: 935, nice: 0)

        let usage = SystemStatusMetrics.cpuUsage(previous: previous, current: current)

        XCTAssertEqual(usage, 15, accuracy: 0.001)
    }

    func testNetworkRateIsCalculatedFromByteDelta() {
        let previous = SystemNetworkCounters(bytesIn: 1_000_000, bytesOut: 2_000_000)
        let current = SystemNetworkCounters(bytesIn: 1_500_000, bytesOut: 2_500_000)

        let rate = SystemStatusMetrics.networkRate(previous: previous, current: current, interval: 2)

        XCTAssertEqual(rate.downloadMBps, 0.25, accuracy: 0.0001)
        XCTAssertEqual(rate.uploadMBps, 0.25, accuracy: 0.0001)
    }

    func testProcessSnapshotsAreSortedByDescendingCPU() {
        let processes = [
            SystemProcessSnapshot(name: "Finder", cpuUsage: 2.0, memoryUsageMB: 100),
            SystemProcessSnapshot(name: "AcMind", cpuUsage: 7.0, memoryUsageMB: 480),
            SystemProcessSnapshot(name: "Safari", cpuUsage: 3.0, memoryUsageMB: 880)
        ]

        let sorted = SystemStatusMetrics.sortedProcesses(processes, limit: 3)

        XCTAssertEqual(sorted.map(\.name), ["AcMind", "Safari", "Finder"])
    }
}
