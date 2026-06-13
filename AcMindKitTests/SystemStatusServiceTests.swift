import XCTest
import Combine
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

        let snapshotUpdated = expectation(description: "snapshot updated")
        var cancellable: AnyCancellable?
        cancellable = service.$snapshot
            .dropFirst()
            .sink { snapshot in
                if snapshot.cpu?.value == 42 {
                    snapshotUpdated.fulfill()
                    cancellable?.cancel()
                }
            }

        service.refresh()
        wait(for: [snapshotUpdated], timeout: 2.0)

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

        let snapshotUpdated = expectation(description: "snapshot updated")
        var cancellable: AnyCancellable?
        cancellable = service.$snapshot
            .dropFirst()
            .sink { snapshot in
                if snapshot.cpu?.value == 18 {
                    snapshotUpdated.fulfill()
                    cancellable?.cancel()
                }
            }

        service.refresh()
        wait(for: [snapshotUpdated], timeout: 2.0)

        XCTAssertEqual(service.snapshot.cpu?.value, 18)
        XCTAssertEqual(service.snapshot.memory?.isAvailable, false)
        XCTAssertEqual(service.snapshot.memory?.unavailableReason, "reader failed")
        XCTAssertEqual(service.snapshot.unavailableReasons.count, 1)
    }

    func testStartDoesNotBlockWhenAReaderIsSlow() {
        let service = SystemStatusService(
            readers: [
                SlowStatusReader(delay: 0.5)
            ]
        )

        let snapshotUpdated = expectation(description: "snapshot updated asynchronously")
        let startTime = Date()
        var cancellable: AnyCancellable?

        cancellable = service.$snapshot
            .dropFirst()
            .sink { snapshot in
                if snapshot.cpu?.value == 17 {
                    snapshotUpdated.fulfill()
                    cancellable?.cancel()
                }
            }

        service.start()

        XCTAssertLessThan(Date().timeIntervalSince(startTime), 0.1)
        wait(for: [snapshotUpdated], timeout: 2.0)

        service.stop()
        _ = cancellable
    }

    func testSamplingTimerSuspendsOnSleepAndResumesOnWake() {
        let center = NotificationCenter()
        let sleepName = Notification.Name("SystemStatusServiceTests.sleep")
        let wakeName = Notification.Name("SystemStatusServiceTests.wake")
        var fireCount = 0
        let timer = SleepAwareRepeatingTimer(
            interval: 1.0,
            notificationCenter: center,
            sleepNotificationName: sleepName,
            wakeNotificationName: wakeName
        ) {
            fireCount += 1
        }

        timer.start()
        XCTAssertTrue(timer.isRunning)
        XCTAssertFalse(timer.isSuspended)

        center.post(name: sleepName, object: nil)
        XCTAssertTrue(timer.isRunning)
        XCTAssertTrue(timer.isSuspended)

        timer.fireForTesting()
        XCTAssertEqual(fireCount, 0)

        center.post(name: wakeName, object: nil)
        XCTAssertTrue(timer.isRunning)
        XCTAssertFalse(timer.isSuspended)

        timer.fireForTesting()
        XCTAssertEqual(fireCount, 1)

        timer.stop()
        XCTAssertFalse(timer.isRunning)
    }

    func testFourCharCodeInitializerFallsBackForInvalidSMCKeys() {
        let valid = FourCharCode(fromString: "FNum")
        XCTAssertEqual(valid.toString(), "FNum")

        let invalid = FourCharCode(fromString: "FNumber")
        XCTAssertEqual(invalid, 0)
    }
}

private struct FakeStatusReader: SystemStatusReader {
    let makePartial: @Sendable (SystemStatusPartialSnapshot) -> SystemStatusPartialSnapshot

    func read() async -> SystemStatusPartialSnapshot {
        makePartial(SystemStatusPartialSnapshot())
    }
}

    private struct SlowStatusReader: SystemStatusReader {
        let delay: TimeInterval

        func read() async -> SystemStatusPartialSnapshot {
        let duration = UInt64(delay * 1_000_000_000)
        try? await Task.sleep(nanoseconds: duration)

        var partial = SystemStatusPartialSnapshot()
        partial.cpu = SystemMetricValue(
            id: "cpu",
            name: "CPU",
            category: "cpu",
            value: 17,
            unit: "%",
            source: "slow",
            isAvailable: true,
            unavailableReason: nil
        )
        return partial
    }
}
