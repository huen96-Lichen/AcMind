import XCTest
@testable import AcMindKit

final class DiskStatusReaderTests: XCTestCase {
    func testDiskIOWarmupReasonIsReportedUntilBaselineExists() {
        let reason = DiskStatusReader.diskIOSamplingReason(hasBaseline: false, didReadIOBytes: true)

        XCTAssertEqual(reason?.id, "disk-io-warmup")
        XCTAssertEqual(reason?.category, "disk")
        XCTAssertEqual(reason?.message, "磁盘 I/O 等待基线")
        XCTAssertEqual(reason?.detail, "first sample requires a previous reading")
    }

    func testDiskIOUnavailableReasonIsReportedWhenSamplingFails() {
        let reason = DiskStatusReader.diskIOSamplingReason(hasBaseline: false, didReadIOBytes: false)

        XCTAssertEqual(reason?.id, "disk-io-unavailable")
        XCTAssertEqual(reason?.category, "disk")
        XCTAssertEqual(reason?.message, "磁盘 I/O 读取不可用")
        XCTAssertEqual(reason?.detail, "iostat failed")
    }

    func testDiskIOSamplingReasonIsOmittedOnceBaselineExists() {
        XCTAssertNil(DiskStatusReader.diskIOSamplingReason(hasBaseline: true, didReadIOBytes: true))
    }

    func testParseDiskIOBytesAggregatesAllDeviceRows() {
        let output = """
        disk0           KB/t tps  MB/s
        disk0           1.0 2.0 3.0
        disk1           9.0 8.0 7.0
        """

        let parsed = DiskStatusReader.parseDiskIOBytes(from: output)

        XCTAssertEqual(parsed?.totals.read, UInt64((1.0 + 9.0) * 1024))
        XCTAssertEqual(parsed?.totals.write, UInt64((2.0 + 8.0) * 1024))
        XCTAssertEqual(parsed?.devices.first?.name, "disk1")
    }

    func testParseDiskIOBytesRejectsNonDeviceRows() {
        let output = """
        KB/t tps MB/s
        total  1.0 2.0 3.0
        """

        XCTAssertNil(DiskStatusReader.parseDiskIOBytes(from: output))
    }

    func testParseDiskIOBytesIgnoresAggregateRowsWhileSummingDevices() {
        let output = """
        KB/t tps MB/s
        total  100.0 200.0 300.0
        disk0  1.0 2.0 3.0
        disk1  4.0 5.0 6.0
        """

        let parsed = DiskStatusReader.parseDiskIOBytes(from: output)

        XCTAssertEqual(parsed?.totals.read, UInt64((1.0 + 4.0) * 1024))
        XCTAssertEqual(parsed?.totals.write, UInt64((2.0 + 5.0) * 1024))
    }

    func testParseDiskIOBytesKeepsPerDeviceRows() {
        let output = """
        disk0           KB/t tps  MB/s
        disk0           1.0 2.0 3.0
        disk1           9.0 8.0 7.0
        """

        let parsed = DiskStatusReader.parseDiskIOBytes(from: output)

        XCTAssertEqual(parsed?.devices.count, 2)
        XCTAssertEqual(parsed?.devices.first?.name, "disk1")
        XCTAssertEqual(parsed?.devices.last?.name, "disk0")
    }

    func testDiskIOProcessSnapshotsComputePerProcessDeltasAndSortDescending() {
        let current: [Int32: (read: UInt64, write: UInt64)] = [
            101: (read: 5_242_880, write: 1_048_576),
            202: (read: 1_048_576, write: 8_388_608)
        ]
        let previous: [Int32: (read: UInt64, write: UInt64)] = [
            101: (read: 1_048_576, write: 0),
            202: (read: 1_048_576, write: 1_048_576)
        ]

        let snapshots = DiskStatusReader.diskIOProcessSnapshots(
            current: current,
            previous: previous,
            interval: 2.0,
            processNameProvider: { pid in pid == 101 ? "alpha" : "beta" }
        )

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots[0].name, "beta")
        XCTAssertEqual(snapshots[0].readMBps, 0)
        XCTAssertEqual(snapshots[0].writeMBps, 3.5)
        XCTAssertEqual(snapshots[1].name, "alpha")
        XCTAssertEqual(snapshots[1].readMBps, 2.0)
        XCTAssertEqual(snapshots[1].writeMBps, 0.5)
    }

    func testDiskIODeviceSnapshotsComputePerDeviceDeltasAndSortDescending() {
        let current: [String: DiskStatusReader.DiskIOBytes] = [
            "disk0": .init(read: 5_242_880, write: 1_048_576),
            "disk1": .init(read: 1_048_576, write: 8_388_608)
        ]
        let previous: [String: DiskStatusReader.DiskIOBytes] = [
            "disk0": .init(read: 1_048_576, write: 0),
            "disk1": .init(read: 1_048_576, write: 1_048_576)
        ]

        let snapshots = DiskStatusReader.diskIODeviceSnapshots(
            current: current,
            previous: previous,
            interval: 2.0
        )

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots[0].name, "disk1")
        XCTAssertEqual(snapshots[0].readMBps, 0)
        XCTAssertEqual(snapshots[0].writeMBps, 3.5)
        XCTAssertEqual(snapshots[1].name, "disk0")
        XCTAssertEqual(snapshots[1].readMBps, 2.0)
        XCTAssertEqual(snapshots[1].writeMBps, 0.5)
    }

    func testCollectMountedVolumesIncludesTheRootVolume() {
        let snapshots = DiskStatusReader.collectMountedVolumes(from: [URL(fileURLWithPath: "/")])

        XCTAssertTrue(snapshots.contains(where: { $0.mountPoint == "/" }))
        XCTAssertTrue(snapshots.first(where: { $0.mountPoint == "/" })?.totalGB ?? 0 > 0)
    }

    func testCollectMountedVolumesPrefersRootThenInternalVolumes() {
        let snapshots = DiskStatusReader.collectMountedVolumes(from: [
            URL(fileURLWithPath: "/Volumes/White Atlas"),
            URL(fileURLWithPath: "/")
        ])

        XCTAssertEqual(snapshots.first?.mountPoint, "/")
    }

    func testCollectMountedVolumesMarksTheCurrentVolume() {
        let snapshots = DiskStatusReader.collectMountedVolumes(from: [
            URL(fileURLWithPath: "/Volumes/White Atlas"),
            URL(fileURLWithPath: "/")
        ])

        XCTAssertTrue(snapshots.contains(where: { $0.mountPoint == "/" && $0.isCurrent }))
    }
}
