import Foundation
import Combine

@MainActor
public final class SystemStatusService: ObservableObject {
    public static let shared = SystemStatusService()

    @Published public private(set) var snapshot = SystemStatusSnapshot()

    private var timer: Timer?
    private var isRunning = false
    private let readers: [any SystemStatusReader]

    public init() {
        self.readers = Self.defaultReaders()
    }

    public init(readers: [any SystemStatusReader]) {
        self.readers = readers
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        refresh()

        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    public func refresh() {
        let now = Date()
        var merged = SystemStatusPartialSnapshot()

        for reader in readers {
            let partial = reader.read()
            merged = Self.merge(merged, with: partial)
        }

        let totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        let memoryUsageGB = merged.memory?.value ?? 0
        let memoryUsagePercent = totalMemoryGB > 0 ? (memoryUsageGB / totalMemoryGB) * 100 : 0
        let diskUsagePercent = merged.disk?.value ?? 0
        let batteryLevel = merged.battery?.percentage ?? 0
        let batteryState = merged.battery?.state ?? "未知"

        snapshot = SystemStatusSnapshot(
            cpu: merged.cpu,
            memory: merged.memory,
            disk: merged.disk,
            network: merged.network,
            battery: merged.battery,
            networkInterfaces: merged.networkInterfaces,
            permissions: merged.permissions,
            topCPUProcesses: merged.topCPUProcesses,
            topMemoryProcesses: merged.topMemoryProcesses,
            temperatureSensors: merged.temperatureSensors,
            fanSensors: merged.fanSensors,
            powerSensors: merged.powerSensors,
            voltageSensors: merged.voltageSensors,
            currentSensors: merged.currentSensors,
            thermalState: merged.thermalState,
            loadAverage1m: merged.loadAverage1m,
            loadAverage5m: merged.loadAverage5m,
            loadAverage15m: merged.loadAverage15m,
            diskUsedGB: merged.diskUsedGB,
            diskTotalGB: merged.diskTotalGB,
            networkDownloadMBps: merged.networkDownloadMBps,
            networkUploadMBps: merged.networkUploadMBps,
            unavailableReasons: merged.unavailableReasons,
            cpuUsage: merged.cpu?.value ?? 0,
            memoryUsageGB: memoryUsageGB,
            totalMemoryGB: totalMemoryGB,
            memoryUsagePercent: memoryUsagePercent,
            diskUsagePercent: diskUsagePercent,
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            topProcesses: merged.topCPUProcesses,
            lastUpdated: now
        )
    }

    private static func merge(_ lhs: SystemStatusPartialSnapshot, with rhs: SystemStatusPartialSnapshot) -> SystemStatusPartialSnapshot {
        var result = lhs

        if let cpu = rhs.cpu { result.cpu = cpu }
        if let memory = rhs.memory { result.memory = memory }
        if let disk = rhs.disk { result.disk = disk }
        if let network = rhs.network { result.network = network }
        if let battery = rhs.battery { result.battery = battery }
        if rhs.networkInterfaces.isEmpty == false { result.networkInterfaces = rhs.networkInterfaces }
        if rhs.permissions.isEmpty == false { result.permissions.append(contentsOf: rhs.permissions) }
        if rhs.topCPUProcesses.isEmpty == false { result.topCPUProcesses = rhs.topCPUProcesses }
        if rhs.topMemoryProcesses.isEmpty == false { result.topMemoryProcesses = rhs.topMemoryProcesses }
        if rhs.temperatureSensors.isEmpty == false { result.temperatureSensors = rhs.temperatureSensors }
        if rhs.fanSensors.isEmpty == false { result.fanSensors = rhs.fanSensors }
        if rhs.powerSensors.isEmpty == false { result.powerSensors = rhs.powerSensors }
        if rhs.voltageSensors.isEmpty == false { result.voltageSensors = rhs.voltageSensors }
        if rhs.currentSensors.isEmpty == false { result.currentSensors = rhs.currentSensors }
        if let thermalState = rhs.thermalState { result.thermalState = thermalState }
        if let loadAverage1m = rhs.loadAverage1m { result.loadAverage1m = loadAverage1m }
        if let loadAverage5m = rhs.loadAverage5m { result.loadAverage5m = loadAverage5m }
        if let loadAverage15m = rhs.loadAverage15m { result.loadAverage15m = loadAverage15m }
        if let diskUsedGB = rhs.diskUsedGB { result.diskUsedGB = diskUsedGB }
        if let diskTotalGB = rhs.diskTotalGB { result.diskTotalGB = diskTotalGB }
        if let networkDownloadMBps = rhs.networkDownloadMBps { result.networkDownloadMBps = networkDownloadMBps }
        if let networkUploadMBps = rhs.networkUploadMBps { result.networkUploadMBps = networkUploadMBps }
        if rhs.unavailableReasons.isEmpty == false { result.unavailableReasons.append(contentsOf: rhs.unavailableReasons) }

        return result
    }

    private static func defaultReaders() -> [any SystemStatusReader] {
        [
            CPUStatusReader(),
            MemoryStatusReader(),
            DiskStatusReader(),
            NetworkStatusReader(),
            BatteryStatusReader(),
            PermissionStatusReader(),
            ProcessStatusReader(),
            SensorStatusReader(),
            FanStatusReader(),
            PowerStatusReader()
        ]
    }
}
