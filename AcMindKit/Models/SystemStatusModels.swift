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

public struct SystemMetricValue: Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: String
    public var value: Double?
    public var unit: String
    public var source: String
    public var isAvailable: Bool
    public var unavailableReason: String?

    public init(
        id: String,
        name: String,
        category: String,
        value: Double?,
        unit: String,
        source: String,
        isAvailable: Bool,
        unavailableReason: String?
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.value = value
        self.unit = unit
        self.source = source
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
    }
}

public struct SystemSensorSnapshot: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: String
    public var value: Double?
    public var unit: String
    public var source: String
    public var isAvailable: Bool
    public var unavailableReason: String?

    public init(
        id: String,
        name: String,
        category: String,
        value: Double?,
        unit: String,
        source: String,
        isAvailable: Bool,
        unavailableReason: String?
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.value = value
        self.unit = unit
        self.source = source
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
    }
}

public struct SystemFanSnapshot: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: String
    public var value: Double?
    public var unit: String
    public var source: String
    public var isAvailable: Bool
    public var unavailableReason: String?
    public var minRPM: Double?
    public var maxRPM: Double?
    public var isAutomatic: Bool?

    public init(
        id: String,
        name: String,
        category: String,
        value: Double?,
        unit: String,
        source: String,
        isAvailable: Bool,
        unavailableReason: String?,
        minRPM: Double? = nil,
        maxRPM: Double? = nil,
        isAutomatic: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.value = value
        self.unit = unit
        self.source = source
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.isAutomatic = isAutomatic
    }
}

public struct SystemBatteryDetails: Equatable, Sendable {
    public var percentage: Double?
    public var state: String
    public var cycleCount: Int?
    public var designCapacity: Double?
    public var maxCapacity: Double?
    public var rawCurrentCapacity: Double?
    public var rawMaxCapacity: Double?
    public var temperatureC: Double?
    public var voltageV: Double?
    public var amperageA: Double?
    public var chargerPowerW: Double?
    public var timeToFullChargeMinutes: Int?
    public var timeToEmptyMinutes: Int?
    public var source: String
    public var isAvailable: Bool
    public var unavailableReason: String?

    public init(
        percentage: Double? = nil,
        state: String = "未知",
        cycleCount: Int? = nil,
        designCapacity: Double? = nil,
        maxCapacity: Double? = nil,
        rawCurrentCapacity: Double? = nil,
        rawMaxCapacity: Double? = nil,
        temperatureC: Double? = nil,
        voltageV: Double? = nil,
        amperageA: Double? = nil,
        chargerPowerW: Double? = nil,
        timeToFullChargeMinutes: Int? = nil,
        timeToEmptyMinutes: Int? = nil,
        source: String = "",
        isAvailable: Bool = true,
        unavailableReason: String? = nil
    ) {
        self.percentage = percentage
        self.state = state
        self.cycleCount = cycleCount
        self.designCapacity = designCapacity
        self.maxCapacity = maxCapacity
        self.rawCurrentCapacity = rawCurrentCapacity
        self.rawMaxCapacity = rawMaxCapacity
        self.temperatureC = temperatureC
        self.voltageV = voltageV
        self.amperageA = amperageA
        self.chargerPowerW = chargerPowerW
        self.timeToFullChargeMinutes = timeToFullChargeMinutes
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.source = source
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
    }
}

public struct SystemNetworkInterfaceSnapshot: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: String
    public var value: Double?
    public var unit: String
    public var source: String
    public var isAvailable: Bool
    public var unavailableReason: String?
    public var interfaceName: String?
    public var ssid: String?
    public var bssid: String?
    public var rssi: Int?
    public var transmitRateMbps: Double?
    public var channel: String?
    public var isVPN: Bool

    public init(
        id: String,
        name: String,
        category: String,
        value: Double?,
        unit: String,
        source: String,
        isAvailable: Bool,
        unavailableReason: String?,
        interfaceName: String? = nil,
        ssid: String? = nil,
        bssid: String? = nil,
        rssi: Int? = nil,
        transmitRateMbps: Double? = nil,
        channel: String? = nil,
        isVPN: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.value = value
        self.unit = unit
        self.source = source
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
        self.interfaceName = interfaceName
        self.ssid = ssid
        self.bssid = bssid
        self.rssi = rssi
        self.transmitRateMbps = transmitRateMbps
        self.channel = channel
        self.isVPN = isVPN
    }
}

public struct SystemPermissionSnapshot: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var category: String
    public var value: String?
    public var unit: String
    public var source: String
    public var isAvailable: Bool
    public var unavailableReason: String?

    public init(
        id: String,
        name: String,
        category: String,
        value: String?,
        unit: String = "",
        source: String,
        isAvailable: Bool,
        unavailableReason: String?
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.value = value
        self.unit = unit
        self.source = source
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
    }
}

public struct SystemStatusUnavailableReason: Identifiable, Equatable, Sendable {
    public var id: String
    public var category: String
    public var message: String
    public var detail: String?

    public init(id: String, category: String, message: String, detail: String? = nil) {
        self.id = id
        self.category = category
        self.message = message
        self.detail = detail
    }
}

public struct SystemStatusPartialSnapshot: Equatable, Sendable {
    public var cpu: SystemMetricValue?
    public var memory: SystemMetricValue?
    public var disk: SystemMetricValue?
    public var network: SystemMetricValue?
    public var battery: SystemBatteryDetails?
    public var networkInterfaces: [SystemNetworkInterfaceSnapshot]
    public var permissions: [SystemPermissionSnapshot]
    public var topCPUProcesses: [SystemProcessSnapshot]
    public var topMemoryProcesses: [SystemProcessSnapshot]
    public var temperatureSensors: [SystemSensorSnapshot]
    public var fanSensors: [SystemFanSnapshot]
    public var powerSensors: [SystemSensorSnapshot]
    public var voltageSensors: [SystemSensorSnapshot]
    public var currentSensors: [SystemSensorSnapshot]
    public var thermalState: String?
    public var loadAverage1m: Double?
    public var loadAverage5m: Double?
    public var loadAverage15m: Double?
    public var diskUsedGB: Double?
    public var diskTotalGB: Double?
    public var networkDownloadMBps: Double?
    public var networkUploadMBps: Double?
    public var unavailableReasons: [SystemStatusUnavailableReason]

    public init(
        cpu: SystemMetricValue? = nil,
        memory: SystemMetricValue? = nil,
        disk: SystemMetricValue? = nil,
        network: SystemMetricValue? = nil,
        battery: SystemBatteryDetails? = nil,
        networkInterfaces: [SystemNetworkInterfaceSnapshot] = [],
        permissions: [SystemPermissionSnapshot] = [],
        topCPUProcesses: [SystemProcessSnapshot] = [],
        topMemoryProcesses: [SystemProcessSnapshot] = [],
        temperatureSensors: [SystemSensorSnapshot] = [],
        fanSensors: [SystemFanSnapshot] = [],
        powerSensors: [SystemSensorSnapshot] = [],
        voltageSensors: [SystemSensorSnapshot] = [],
        currentSensors: [SystemSensorSnapshot] = [],
        thermalState: String? = nil,
        loadAverage1m: Double? = nil,
        loadAverage5m: Double? = nil,
        loadAverage15m: Double? = nil,
        diskUsedGB: Double? = nil,
        diskTotalGB: Double? = nil,
        networkDownloadMBps: Double? = nil,
        networkUploadMBps: Double? = nil,
        unavailableReasons: [SystemStatusUnavailableReason] = []
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.battery = battery
        self.networkInterfaces = networkInterfaces
        self.permissions = permissions
        self.topCPUProcesses = topCPUProcesses
        self.topMemoryProcesses = topMemoryProcesses
        self.temperatureSensors = temperatureSensors
        self.fanSensors = fanSensors
        self.powerSensors = powerSensors
        self.voltageSensors = voltageSensors
        self.currentSensors = currentSensors
        self.thermalState = thermalState
        self.loadAverage1m = loadAverage1m
        self.loadAverage5m = loadAverage5m
        self.loadAverage15m = loadAverage15m
        self.diskUsedGB = diskUsedGB
        self.diskTotalGB = diskTotalGB
        self.networkDownloadMBps = networkDownloadMBps
        self.networkUploadMBps = networkUploadMBps
        self.unavailableReasons = unavailableReasons
    }
}

@MainActor
public protocol SystemStatusReader: Sendable {
    func read() -> SystemStatusPartialSnapshot
}

public struct SystemStatusSnapshot: Equatable, Sendable {
    public var cpu: SystemMetricValue?
    public var memory: SystemMetricValue?
    public var disk: SystemMetricValue?
    public var network: SystemMetricValue?
    public var battery: SystemBatteryDetails?
    public var networkInterfaces: [SystemNetworkInterfaceSnapshot]
    public var permissions: [SystemPermissionSnapshot]
    public var topCPUProcesses: [SystemProcessSnapshot]
    public var topMemoryProcesses: [SystemProcessSnapshot]
    public var temperatureSensors: [SystemSensorSnapshot]
    public var fanSensors: [SystemFanSnapshot]
    public var powerSensors: [SystemSensorSnapshot]
    public var voltageSensors: [SystemSensorSnapshot]
    public var currentSensors: [SystemSensorSnapshot]
    public var thermalState: String?
    public var loadAverage1m: Double?
    public var loadAverage5m: Double?
    public var loadAverage15m: Double?
    public var diskUsedGB: Double?
    public var diskTotalGB: Double?
    public var networkDownloadMBps: Double?
    public var networkUploadMBps: Double?
    public var unavailableReasons: [SystemStatusUnavailableReason]

    public var cpuUsage: Double
    public var memoryUsageGB: Double
    public var totalMemoryGB: Double
    public var memoryUsagePercent: Double
    public var diskUsagePercent: Double
    public var batteryLevel: Double
    public var batteryState: String
    public var topProcesses: [SystemProcessSnapshot]
    public var lastUpdated: Date

    public init(
        cpu: SystemMetricValue? = nil,
        memory: SystemMetricValue? = nil,
        disk: SystemMetricValue? = nil,
        network: SystemMetricValue? = nil,
        battery: SystemBatteryDetails? = nil,
        networkInterfaces: [SystemNetworkInterfaceSnapshot] = [],
        permissions: [SystemPermissionSnapshot] = [],
        topCPUProcesses: [SystemProcessSnapshot] = [],
        topMemoryProcesses: [SystemProcessSnapshot] = [],
        temperatureSensors: [SystemSensorSnapshot] = [],
        fanSensors: [SystemFanSnapshot] = [],
        powerSensors: [SystemSensorSnapshot] = [],
        voltageSensors: [SystemSensorSnapshot] = [],
        currentSensors: [SystemSensorSnapshot] = [],
        thermalState: String? = nil,
        loadAverage1m: Double? = nil,
        loadAverage5m: Double? = nil,
        loadAverage15m: Double? = nil,
        diskUsedGB: Double? = nil,
        diskTotalGB: Double? = nil,
        networkDownloadMBps: Double? = nil,
        networkUploadMBps: Double? = nil,
        unavailableReasons: [SystemStatusUnavailableReason] = [],
        cpuUsage: Double = 0,
        memoryUsageGB: Double = 0,
        totalMemoryGB: Double = 0,
        memoryUsagePercent: Double = 0,
        diskUsagePercent: Double = 0,
        batteryLevel: Double = 0,
        batteryState: String = "未知",
        topProcesses: [SystemProcessSnapshot] = [],
        lastUpdated: Date = .distantPast
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.battery = battery
        self.networkInterfaces = networkInterfaces
        self.permissions = permissions
        self.topCPUProcesses = topCPUProcesses
        self.topMemoryProcesses = topMemoryProcesses
        self.temperatureSensors = temperatureSensors
        self.fanSensors = fanSensors
        self.powerSensors = powerSensors
        self.voltageSensors = voltageSensors
        self.currentSensors = currentSensors
        self.thermalState = thermalState
        self.loadAverage1m = loadAverage1m
        self.loadAverage5m = loadAverage5m
        self.loadAverage15m = loadAverage15m
        self.diskUsedGB = diskUsedGB
        self.diskTotalGB = diskTotalGB
        self.networkDownloadMBps = networkDownloadMBps
        self.networkUploadMBps = networkUploadMBps
        self.unavailableReasons = unavailableReasons
        self.cpuUsage = cpuUsage
        self.memoryUsageGB = memoryUsageGB
        self.totalMemoryGB = totalMemoryGB
        self.memoryUsagePercent = memoryUsagePercent
        self.diskUsagePercent = diskUsagePercent
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
