import Foundation

public struct SystemCPUTickTotals: Equatable, Sendable {
    public var user: UInt64
    public var system: UInt64
    public var idle: UInt64
    public var nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    var activeTotal: UInt64 { user + system + nice }
    var total: UInt64 { activeTotal + idle }
}

public struct SystemNetworkCounters: Equatable, Sendable {
    public var bytesIn: UInt64
    public var bytesOut: UInt64

    public init(bytesIn: UInt64, bytesOut: UInt64) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }
}

public struct SystemNetworkRate: Equatable, Sendable {
    public var downloadMBps: Double
    public var uploadMBps: Double

    public init(downloadMBps: Double, uploadMBps: Double) {
        self.downloadMBps = downloadMBps
        self.uploadMBps = uploadMBps
    }
}

public struct SystemProcessSnapshot: Identifiable, Equatable, Sendable {
    public let pid: Int32
    public let name: String
    public let cpuUsage: Double
    public let memoryUsageMB: Double

    public init(pid: Int32 = 0, name: String, cpuUsage: Double, memoryUsageMB: Double) {
        self.pid = pid
        self.name = name
        self.cpuUsage = cpuUsage
        self.memoryUsageMB = memoryUsageMB
    }

    public var id: Int32 { pid }
}

public struct SystemStatusSnapshot: Equatable, Sendable {
    public var cpuUsage: Double
    public var memoryUsageGB: Double
    public var totalMemoryGB: Double
    public var memoryUsagePercent: Double
    public var diskUsagePercent: Double
    public var diskUsedGB: Double
    public var diskTotalGB: Double
    public var networkDownloadMBps: Double
    public var networkUploadMBps: Double
    public var batteryLevel: Double
    public var batteryState: String
    public var topProcesses: [SystemProcessSnapshot]
    public var lastUpdated: Date

    public init(
        cpuUsage: Double = 0,
        memoryUsageGB: Double = 0,
        totalMemoryGB: Double = 0,
        memoryUsagePercent: Double = 0,
        diskUsagePercent: Double = 0,
        diskUsedGB: Double = 0,
        diskTotalGB: Double = 0,
        networkDownloadMBps: Double = 0,
        networkUploadMBps: Double = 0,
        batteryLevel: Double = 0,
        batteryState: String = "未知",
        topProcesses: [SystemProcessSnapshot] = [],
        lastUpdated: Date = .distantPast
    ) {
        self.cpuUsage = cpuUsage
        self.memoryUsageGB = memoryUsageGB
        self.totalMemoryGB = totalMemoryGB
        self.memoryUsagePercent = memoryUsagePercent
        self.diskUsagePercent = diskUsagePercent
        self.diskUsedGB = diskUsedGB
        self.diskTotalGB = diskTotalGB
        self.networkDownloadMBps = networkDownloadMBps
        self.networkUploadMBps = networkUploadMBps
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
        self.topProcesses = topProcesses
        self.lastUpdated = lastUpdated
    }
}

public enum SystemStatusMetrics {
    public static func cpuUsage(previous: SystemCPUTickTotals, current: SystemCPUTickTotals) -> Double {
        let totalDelta = Double(current.total - previous.total)
        guard totalDelta > 0 else { return 0 }

        let activeDelta = Double(current.activeTotal - previous.activeTotal)
        return max(0, min(100, (activeDelta / totalDelta) * 100))
    }

    public static func networkRate(previous: SystemNetworkCounters, current: SystemNetworkCounters, interval: TimeInterval) -> SystemNetworkRate {
        guard interval > 0 else {
            return SystemNetworkRate(downloadMBps: 0, uploadMBps: 0)
        }

        let downDelta = max(0, Double(current.bytesIn &- previous.bytesIn))
        let upDelta = max(0, Double(current.bytesOut &- previous.bytesOut))
        let bytesPerSecondFactor = 1.0 / interval / 1_000_000.0

        return SystemNetworkRate(
            downloadMBps: downDelta * bytesPerSecondFactor,
            uploadMBps: upDelta * bytesPerSecondFactor
        )
    }

    public static func sortedProcesses(_ processes: [SystemProcessSnapshot], limit: Int = 5) -> [SystemProcessSnapshot] {
        processes
            .sorted { lhs, rhs in
                if lhs.cpuUsage == rhs.cpuUsage {
                    return lhs.memoryUsageMB > rhs.memoryUsageMB
                }
                return lhs.cpuUsage > rhs.cpuUsage
            }
            .prefix(limit)
            .map { $0 }
    }
}
