import Foundation

public enum SystemMonitorCadence: Sendable, Equatable {
    case collapsed
    case expanded

    var intervalSeconds: Double {
        switch self {
        case .collapsed:
            return 2.0
        case .expanded:
            return 1.0
        }
    }
}

@MainActor
public final class SystemMonitorService: ObservableObject {
    @Published public private(set) var snapshot: SystemMonitorSnapshot?
    @Published public private(set) var isMonitoring: Bool = false

    private let collector: SystemMonitorCollecting
    private let defaultCadence: SystemMonitorCadence
    private var cadence: SystemMonitorCadence
    private var monitoringTask: Task<Void, Never>?
    private let analyzer = SystemHealthAnalyzer()

    public init(
        defaultCadence: SystemMonitorCadence = .expanded,
        collector: SystemMonitorCollecting = SystemMonitorCollector()
    ) {
        self.defaultCadence = defaultCadence
        self.cadence = defaultCadence
        self.collector = collector
    }

    public func start() {
        start(cadence: cadence)
    }

    public func start(cadence: SystemMonitorCadence) {
        self.cadence = cadence
        guard monitoringTask == nil else {
            isMonitoring = true
            return
        }

        isMonitoring = true
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            await self.runLoop()
        }
    }

    public func setCadence(_ cadence: SystemMonitorCadence) {
        self.cadence = cadence
        if isMonitoring {
            Task { [weak self] in
                await self?.refreshNow()
            }
        }
    }

    public func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
    }

    public func refreshOnce() {
        Task { [weak self] in
            await self?.refreshNow()
        }
    }

    private func runLoop() async {
        defer {
            Task { @MainActor in
                self.monitoringTask = nil
                self.isMonitoring = false
            }
        }

        while !Task.isCancelled {
            await refreshNow()
            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .seconds(cadence.intervalSeconds))
        }
    }

    private func refreshNow() async {
        let collected = await collector.collectSnapshot()
        let health = analyzer.analyze(snapshot: collected.withHealth(.unknown))
        snapshot = collected.withHealth(health)
    }
}

public protocol SystemMonitorCollecting: Sendable {
    func collectSnapshot() async -> SystemMonitorSnapshot
}

public final class SystemMonitorCollector: SystemMonitorCollecting, @unchecked Sendable {
    private let cpuProvider = CPUStatsProvider()
    private let memoryProvider = MemoryStatsProvider()
    private let networkProvider = NetworkStatsProvider()
    private let storageProvider = StorageStatsProvider()
    private let batteryProvider = BatteryStatsProvider()
    private let thermalProvider = ThermalStatsProvider()
    private let gpuProvider = GPUStatsProvider()
    private let powerProvider = PowerStatsProvider()
    private let processProvider = ProcessStatsProvider()

    public init() {}

    public func collectSnapshot() async -> SystemMonitorSnapshot {
        async let cpu = cpuProvider.collect(previousSnapshot: nil)
        async let memory = memoryProvider.collect(previousSnapshot: nil)
        async let network = networkProvider.collect(previousSnapshot: nil)
        async let storage = storageProvider.collect(previousSnapshot: nil)
        async let battery = batteryProvider.collect(previousSnapshot: nil)
        async let thermal = thermalProvider.collect(previousSnapshot: nil)
        async let gpu = gpuProvider.collect(previousSnapshot: nil)
        async let power = powerProvider.collect(previousSnapshot: nil)
        async let uptime = uptimeSeconds()
        async let topProcesses = processProvider.collect(previousSnapshot: nil)

        let collected = SystemMonitorSnapshot(
            timestamp: Date(),
            cpu: await cpu,
            memory: await memory,
            network: await network,
            storage: await storage,
            battery: await battery,
            thermal: await thermal,
            gpu: await gpu,
            power: await power,
            uptime: await uptime,
            topProcesses: await topProcesses,
            health: .unknown
        )

        return collected
    }

    private func uptimeSeconds() async -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        let result = sysctlbyname("kern.boottime", &boottime, &size, nil, 0)
        guard result == 0 else { return 0 }

        let bootDate = Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec) + TimeInterval(boottime.tv_usec) / 1_000_000)
        return Date().timeIntervalSince(bootDate)
    }
}

private extension SystemMonitorSnapshot {
    func withHealth(_ health: SystemHealthSummary) -> SystemMonitorSnapshot {
        SystemMonitorSnapshot(
            timestamp: timestamp,
            cpu: cpu,
            memory: memory,
            network: network,
            storage: storage,
            battery: battery,
            thermal: thermal,
            gpu: gpu,
            power: power,
            uptime: uptime,
            topProcesses: topProcesses,
            health: health
        )
    }
}
