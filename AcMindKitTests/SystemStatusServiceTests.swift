import XCTest
@testable import AcMindKit

@MainActor
final class SystemStatusServiceTests: XCTestCase {
    func testRefreshMergesReaderSnapshotsAndUnavailableReasons() {
        let service = SystemStatusService(
            readers: [
                FakeStatusReader { partial in
                    var output = partial
                    output.cpu = SystemMetricValue(
                        id: "cpu",
                        name: "CPU",
                        category: "cpu",
                        value: 42,
                        unit: "%",
                        source: "fake",
                        isAvailable: true,
                        unavailableReason: nil
                    )
                    output.topCPUProcesses = [
                        SystemProcessSnapshot(pid: 100, name: "AcMind", cpuUsage: 7, memoryUsageMB: 120)
                    ]
                    return output
                },
                FakeStatusReader { partial in
                    var output = partial
                    output.unavailableReasons = [
                        SystemStatusUnavailableReason(
                            id: "sensor-unavailable",
                            category: "sensor",
                            message: "传感器不可用",
                            detail: "IOReport unavailable"
                        )
                    ]
                    return output
                }
            ]
        )

        service.refresh()

        XCTAssertEqual(service.snapshot.cpu?.value, 42)
        XCTAssertEqual(service.snapshot.topCPUProcesses.map(\.name), ["AcMind"])
        XCTAssertEqual(service.snapshot.unavailableReasons.count, 1)
        XCTAssertEqual(service.snapshot.unavailableReasons.first?.id, "sensor-unavailable")
    }

    func testRefreshKeepsOtherReaderValuesWhenOneReaderIsUnavailable() {
        let service = SystemStatusService(
            readers: [
                FakeStatusReader { partial in
                    var output = partial
                    output.cpu = SystemMetricValue(
                        id: "cpu",
                        name: "CPU",
                        category: "cpu",
                        value: 18,
                        unit: "%",
                        source: "fake",
                        isAvailable: true,
                        unavailableReason: nil
                    )
                    return output
                },
                FakeStatusReader { partial in
                    var output = partial
                    output.memory = SystemMetricValue(
                        id: "memory",
                        name: "内存",
                        category: "memory",
                        value: nil,
                        unit: "GB",
                        source: "fake",
                        isAvailable: false,
                        unavailableReason: "reader failed"
                    )
                    output.unavailableReasons = [
                        SystemStatusUnavailableReason(
                            id: "memory-unavailable",
                            category: "memory",
                            message: "内存读取失败",
                            detail: "simulated reader failure"
                        )
                    ]
                    return output
                }
            ]
        )

        service.refresh()

        XCTAssertEqual(service.snapshot.cpu?.value, 18)
        XCTAssertEqual(service.snapshot.memory?.isAvailable, false)
        XCTAssertEqual(service.snapshot.memory?.unavailableReason, "reader failed")
        XCTAssertEqual(service.snapshot.unavailableReasons.count, 1)
    }
}

private struct FakeStatusReader: SystemStatusReader {
    let makePartial: @Sendable (SystemStatusPartialSnapshot) -> SystemStatusPartialSnapshot

    func read() -> SystemStatusPartialSnapshot {
        makePartial(SystemStatusPartialSnapshot())
    }
}
