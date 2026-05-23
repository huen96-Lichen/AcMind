import Foundation
import Darwin

public final class CPUStatsProvider: SystemMetricProvider, @unchecked Sendable {
    private struct CPUCounterSample {
        let user: UInt32
        let system: UInt32
        let idle: UInt32
        let nice: UInt32
    }

    private let lock = NSLock()
    private var lastSample: CPUCounterSample?

    public init() {}

    public func collect(previousSnapshot: SystemMonitorSnapshot? = nil) async -> CPUStats {
        let currentSample = readCurrentSample()
        let usagePercent = cpuUsagePercent(for: currentSample)

        let loadAverage = readLoadAverage()
        return CPUStats(
            usagePercent: usagePercent,
            loadAverage1m: loadAverage.0,
            loadAverage5m: loadAverage.1,
            loadAverage15m: loadAverage.2
        )
    }

    private func cpuUsagePercent(for currentSample: CPUCounterSample) -> Double {
        lock.lock()
        defer { lock.unlock() }

        defer { lastSample = currentSample }

        guard let lastSample else {
            return 0
        }

        let previousTotal = Double(lastSample.user + lastSample.system + lastSample.idle + lastSample.nice)
        let currentTotal = Double(currentSample.user + currentSample.system + currentSample.idle + currentSample.nice)
        let totalDelta = max(currentTotal - previousTotal, 0)

        guard totalDelta > 0 else {
            return 0
        }

        let activeDelta = Double(
            (currentSample.user - lastSample.user) +
            (currentSample.system - lastSample.system) +
            (currentSample.nice - lastSample.nice)
        )
        return Swift.max(0, Swift.min(100, (activeDelta / totalDelta) * 100))
    }

    private func readCurrentSample() -> CPUCounterSample {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { pointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, pointer, &size)
            }
        }

        guard result == KERN_SUCCESS else {
            return CPUCounterSample(user: 0, system: 0, idle: 0, nice: 0)
        }

        return CPUCounterSample(
            user: info.cpu_ticks.0,
            system: info.cpu_ticks.1,
            idle: info.cpu_ticks.2,
            nice: info.cpu_ticks.3
        )
    }

    private func readLoadAverage() -> (Double, Double, Double) {
        var loads = [Double](repeating: 0, count: 3)
        let count = getloadavg(&loads, Int32(loads.count))
        guard count > 0 else {
            return (0, 0, 0)
        }

        return (
            loads.indices.contains(0) ? loads[0] : 0,
            loads.indices.contains(1) ? loads[1] : 0,
            loads.indices.contains(2) ? loads[2] : 0
        )
    }
}
