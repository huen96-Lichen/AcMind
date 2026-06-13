import XCTest
@testable import AcMindKit

final class SystemThermalThrottleTests: XCTestCase {
    func testParseThermalThrottleOutputExtractsQuantifiedValues() {
        let output = """
        Machine models: MacBookPro18,3
        CPU_Speed_Limit = 72
        CPU_Scheduler_Limit = 54
        CPU_Available_CPUs = 6
        """

        let throttle = ThermalStatusReader.parseThermalThrottleOutput(output)

        XCTAssertNotNil(throttle)
        XCTAssertEqual(throttle?.speedLimit, 72)
        XCTAssertEqual(throttle?.schedulerLimit, 54)
        XCTAssertEqual(throttle?.availableCPUs, 6)
        XCTAssertEqual(throttle?.isAvailable, true)
    }

    func testReaderProducesThermalThrottleSnapshot() async {
        let reader = ThermalStatusReader(outputProvider: {
            """
            CPU_Speed_Limit = 88
            CPU_Scheduler_Limit = 66
            CPU_Available_CPUs = 8
            """
        })

        let partial = await reader.read()

        XCTAssertEqual(partial.thermalThrottle?.speedLimit, 88)
        XCTAssertEqual(partial.thermalThrottle?.schedulerLimit, 66)
        XCTAssertEqual(partial.thermalThrottle?.availableCPUs, 8)
    }

    func testThermalThrottleFormatterUsesQuantifiedValues() {
        let throttle = SystemThermalThrottleInfo(
            speedLimit: 82,
            schedulerLimit: 61,
            availableCPUs: 6,
            source: "pmset",
            isAvailable: true,
            unavailableReason: nil
        )

        XCTAssertEqual(SystemStatusLabelFormatter.thermalThrottleSummary(throttle), "82% · 61%")
        XCTAssertEqual(SystemStatusLabelFormatter.thermalThrottleDetail(throttle), "6 CPU")
    }

    func testThermalThrottleFormatterFallsBackWhenUnavailable() {
        let throttle = SystemThermalThrottleInfo(
            speedLimit: nil,
            schedulerLimit: nil,
            availableCPUs: nil,
            source: "pmset",
            isAvailable: false,
            unavailableReason: "pmset failed"
        )

        XCTAssertEqual(SystemStatusLabelFormatter.thermalThrottleSummary(throttle), "不可用")
        XCTAssertEqual(SystemStatusLabelFormatter.thermalThrottleDetail(throttle), "pmset failed")
    }
}
