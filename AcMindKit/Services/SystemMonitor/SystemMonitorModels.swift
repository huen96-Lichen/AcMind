import Foundation

public enum MemoryPressureLevel: String, Codable, CaseIterable, Sendable, Equatable {
    case unknown
    case low
    case moderate
    case high
}

public enum SystemHealthLevel: String, Codable, CaseIterable, Sendable, Equatable {
    case unknown
    case good
    case attention
    case highLoad
}

public enum ThermalPressureLevel: String, Codable, CaseIterable, Sendable, Equatable {
    case unknown
    case nominal
    case fair
    case serious
    case critical
}

public struct CPUStats: Equatable, Sendable {
    public let usagePercent: Double
    public let loadAverage1m: Double
    public let loadAverage5m: Double
    public let loadAverage15m: Double

    public init(
        usagePercent: Double,
        loadAverage1m: Double,
        loadAverage5m: Double,
        loadAverage15m: Double
    ) {
        self.usagePercent = usagePercent
        self.loadAverage1m = loadAverage1m
        self.loadAverage5m = loadAverage5m
        self.loadAverage15m = loadAverage15m
    }
}

public struct MemoryStats: Equatable, Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64
    public let pressureLevel: MemoryPressureLevel
    public let swapUsedBytes: UInt64?

    public init(
        totalBytes: UInt64,
        usedBytes: UInt64,
        freeBytes: UInt64,
        pressureLevel: MemoryPressureLevel,
        swapUsedBytes: UInt64?
    ) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.pressureLevel = pressureLevel
        self.swapUsedBytes = swapUsedBytes
    }
}

public struct NetworkStats: Equatable, Sendable {
    public let downloadBytesPerSecond: UInt64
    public let uploadBytesPerSecond: UInt64
    public let activeInterfaceName: String?

    public init(
        downloadBytesPerSecond: UInt64,
        uploadBytesPerSecond: UInt64,
        activeInterfaceName: String?
    ) {
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.activeInterfaceName = activeInterfaceName
    }
}

public struct StorageStats: Equatable, Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64
    public let usedPercent: Double

    public init(
        totalBytes: UInt64,
        usedBytes: UInt64,
        freeBytes: UInt64,
        usedPercent: Double
    ) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.usedPercent = usedPercent
    }
}

public struct BatteryStats: Equatable, Sendable {
    public let percentage: Double
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let timeRemainingMinutes: Int?

    public init(
        percentage: Double,
        isCharging: Bool,
        isPluggedIn: Bool,
        timeRemainingMinutes: Int?
    ) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.timeRemainingMinutes = timeRemainingMinutes
    }
}

public struct ThermalStats: Equatable, Sendable {
    public let cpuTemperatureCelsius: Double?
    public let gpuTemperatureCelsius: Double?
    public let fanSpeedRPM: Int?
    public let pressureLevel: ThermalPressureLevel

    public init(
        cpuTemperatureCelsius: Double?,
        gpuTemperatureCelsius: Double?,
        fanSpeedRPM: Int?,
        pressureLevel: ThermalPressureLevel
    ) {
        self.cpuTemperatureCelsius = cpuTemperatureCelsius
        self.gpuTemperatureCelsius = gpuTemperatureCelsius
        self.fanSpeedRPM = fanSpeedRPM
        self.pressureLevel = pressureLevel
    }
}

public struct GPUStats: Equatable, Sendable {
    public let name: String?
    public let usagePercent: Double?
    public let temperatureCelsius: Double?

    public init(
        name: String?,
        usagePercent: Double?,
        temperatureCelsius: Double?
    ) {
        self.name = name
        self.usagePercent = usagePercent
        self.temperatureCelsius = temperatureCelsius
    }
}

public struct PowerStats: Equatable, Sendable {
    public let consumptionWatts: Double?

    public init(consumptionWatts: Double?) {
        self.consumptionWatts = consumptionWatts
    }
}

public struct ProcessStats: Equatable, Identifiable, Sendable {
    public let id: Int32
    public let name: String
    public let cpuPercent: Double
    public let memoryBytes: UInt64?

    public init(
        id: Int32,
        name: String,
        cpuPercent: Double,
        memoryBytes: UInt64?
    ) {
        self.id = id
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}

public struct SystemHealthSummary: Equatable, Sendable {
    public let level: SystemHealthLevel
    public let title: String
    public let message: String
    public let warnings: [String]

    public init(
        level: SystemHealthLevel,
        title: String,
        message: String,
        warnings: [String]
    ) {
        self.level = level
        self.title = title
        self.message = message
        self.warnings = warnings
    }

    public static let unknown = SystemHealthSummary(
        level: .unknown,
        title: "状态未知",
        message: "系统监控数据尚未完成采样。",
        warnings: []
    )
}

public struct SystemMonitorSnapshot: Equatable, Sendable {
    public let timestamp: Date
    public let cpu: CPUStats
    public let memory: MemoryStats
    public let network: NetworkStats
    public let storage: StorageStats
    public let battery: BatteryStats?
    public let thermal: ThermalStats?
    public let gpu: GPUStats?
    public let power: PowerStats?
    public let uptime: TimeInterval
    public let topProcesses: [ProcessStats]
    public let health: SystemHealthSummary

    public init(
        timestamp: Date,
        cpu: CPUStats,
        memory: MemoryStats,
        network: NetworkStats,
        storage: StorageStats,
        battery: BatteryStats?,
        thermal: ThermalStats? = nil,
        gpu: GPUStats? = nil,
        power: PowerStats? = nil,
        uptime: TimeInterval,
        topProcesses: [ProcessStats],
        health: SystemHealthSummary
    ) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.memory = memory
        self.network = network
        self.storage = storage
        self.battery = battery
        self.thermal = thermal
        self.gpu = gpu
        self.power = power
        self.uptime = uptime
        self.topProcesses = topProcesses
        self.health = health
    }
}
