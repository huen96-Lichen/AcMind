import XCTest
@testable import AcMindKit

final class SystemMonitorTests: XCTestCase {
    func testHealthAnalyzerReportsGoodWhenLoadIsLow() {
        let snapshot = makeSnapshot(
            cpuUsage: 18,
            memoryPressure: .low,
            storageUsedPercent: 62,
            batteryPercent: 82,
            isPluggedIn: true,
            isCharging: false
        )

        let summary = SystemHealthAnalyzer().analyze(snapshot: snapshot)

        XCTAssertEqual(summary.level, .good)
        XCTAssertTrue(summary.title.contains("良好"))
        XCTAssertTrue(summary.warnings.isEmpty)
    }

    func testHealthAnalyzerReportsAttentionWhenMemoryPressureIsModerate() {
        let snapshot = makeSnapshot(
            cpuUsage: 34,
            memoryPressure: .moderate,
            storageUsedPercent: 62,
            batteryPercent: 82,
            isPluggedIn: true,
            isCharging: false
        )

        let summary = SystemHealthAnalyzer().analyze(snapshot: snapshot)

        XCTAssertEqual(summary.level, .attention)
        XCTAssertTrue(summary.warnings.contains { $0.contains("内存") })
    }

    func testHealthAnalyzerReportsHighLoadWhenCpuAndStorageAreCritical() {
        let snapshot = makeSnapshot(
            cpuUsage: 94,
            memoryPressure: .high,
            storageUsedPercent: 96,
            batteryPercent: 12,
            isPluggedIn: false,
            isCharging: false
        )

        let summary = SystemHealthAnalyzer().analyze(snapshot: snapshot)

        XCTAssertEqual(summary.level, .highLoad)
        XCTAssertTrue(summary.warnings.contains { $0.contains("CPU") || $0.contains("CPU 负载") })
        XCTAssertTrue(summary.warnings.contains { $0.contains("硬盘") })
        XCTAssertTrue(summary.warnings.contains { $0.contains("电池") })
    }

    func testHealthAnalyzerReportsAttentionWhenThermalPressureIsSerious() {
        let snapshot = makeSnapshot(
            cpuUsage: 28,
            memoryPressure: .low,
            storageUsedPercent: 62,
            batteryPercent: 82,
            isPluggedIn: true,
            isCharging: false,
            thermal: ThermalStats(
                cpuTemperatureCelsius: 82,
                gpuTemperatureCelsius: 71,
                fanSpeedRPM: 3_600,
                pressureLevel: .serious
            )
        )

        let summary = SystemHealthAnalyzer().analyze(snapshot: snapshot)

        XCTAssertEqual(summary.level, .attention)
        XCTAssertTrue(summary.warnings.contains { $0.contains("温度") || $0.contains("风扇") })
    }

    func testHealthAnalyzerReportsHighLoadWhenThermalAndGpuAreCritical() {
        let snapshot = makeSnapshot(
            cpuUsage: 61,
            memoryPressure: .low,
            storageUsedPercent: 62,
            batteryPercent: 82,
            isPluggedIn: true,
            isCharging: false,
            thermal: ThermalStats(
                cpuTemperatureCelsius: 96,
                gpuTemperatureCelsius: 94,
                fanSpeedRPM: 5_200,
                pressureLevel: .critical
            ),
            gpu: GPUStats(
                name: "Apple M3 Max",
                usagePercent: 93,
                temperatureCelsius: 94
            ),
            power: PowerStats(
                consumptionWatts: 46.5
            )
        )

        let summary = SystemHealthAnalyzer().analyze(snapshot: snapshot)

        XCTAssertEqual(summary.level, .highLoad)
        XCTAssertTrue(summary.warnings.contains { $0.contains("温度") || $0.contains("风扇") })
        XCTAssertTrue(summary.warnings.contains { $0.contains("GPU") || $0.contains("显卡") })
        XCTAssertTrue(summary.warnings.contains { $0.contains("功耗") || $0.contains("电力") })
    }

    private func makeSnapshot(
        cpuUsage: Double,
        memoryPressure: MemoryPressureLevel,
        storageUsedPercent: Double,
        batteryPercent: Double,
        isPluggedIn: Bool,
        isCharging: Bool,
        thermal: ThermalStats? = nil,
        gpu: GPUStats? = nil,
        power: PowerStats? = nil
    ) -> SystemMonitorSnapshot {
        SystemMonitorSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            cpu: CPUStats(usagePercent: cpuUsage, loadAverage1m: 0.4, loadAverage5m: 0.5, loadAverage15m: 0.6),
            memory: MemoryStats(
                totalBytes: 32 * 1024 * 1024 * 1024,
                usedBytes: 12 * 1024 * 1024 * 1024,
                freeBytes: 20 * 1024 * 1024 * 1024,
                pressureLevel: memoryPressure,
                swapUsedBytes: 512 * 1024 * 1024
            ),
            network: NetworkStats(downloadBytesPerSecond: 0, uploadBytesPerSecond: 0, activeInterfaceName: "Wi-Fi"),
            storage: StorageStats(
                totalBytes: 1_000,
                usedBytes: UInt64(Double(1_000) * storageUsedPercent / 100.0),
                freeBytes: UInt64(Double(1_000) * (100.0 - storageUsedPercent) / 100.0),
                usedPercent: storageUsedPercent
            ),
            battery: BatteryStats(
                percentage: batteryPercent,
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                timeRemainingMinutes: 120
            ),
            thermal: thermal,
            gpu: gpu,
            power: power,
            uptime: 4 * 60 * 60,
            topProcesses: [
                ProcessStats(id: 1, name: "Xcode", cpuPercent: 22, memoryBytes: 1_000_000_000),
                ProcessStats(id: 2, name: "AcMind", cpuPercent: 8, memoryBytes: 300_000_000)
            ],
            health: SystemHealthSummary(level: .unknown, title: "", message: "", warnings: [])
        )
    }
}
