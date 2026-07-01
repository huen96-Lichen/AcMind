import Foundation
import Combine
import AppKit

@MainActor
public final class SleepAwareRepeatingTimer {
    public private(set) var isRunning = false
    public private(set) var isSuspended = false

    private let interval: TimeInterval
    private let timerQueue: DispatchQueue
    private let notificationCenter: NotificationCenter
    private let sleepNotificationName: Notification.Name
    private let wakeNotificationName: Notification.Name
    private let handler: @MainActor () -> Void
    private var timer: DispatchSourceTimer?
    private var observers: [NSObjectProtocol] = []

    public init(
        interval: TimeInterval,
        timerQueue: DispatchQueue = DispatchQueue(label: "com.acmind.system-status.sleep-aware-timer", qos: .utility),
        notificationCenter: NotificationCenter = .default,
        sleepNotificationName: Notification.Name = NSWorkspace.willSleepNotification,
        wakeNotificationName: Notification.Name = NSWorkspace.didWakeNotification,
        handler: @escaping @MainActor () -> Void
    ) {
        self.interval = interval
        self.timerQueue = timerQueue
        self.notificationCenter = notificationCenter
        self.sleepNotificationName = sleepNotificationName
        self.wakeNotificationName = wakeNotificationName
        self.handler = handler
    }

    deinit {
        if let timer {
            if isSuspended {
                timer.resume()
            }
            timer.cancel()
        }

        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }

    public func start() {
        guard isRunning == false else { return }
        isRunning = true
        isSuspended = false
        installObservers()
        scheduleTimer()
    }

    public func stop() {
        if let timer {
            if isSuspended {
                timer.resume()
            }
            timer.cancel()
        }
        timer = nil
        isRunning = false
        isSuspended = false
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func suspend() {
        guard isRunning, isSuspended == false else { return }
        timer?.suspend()
        isSuspended = true
    }

    public func resume() {
        guard isRunning, isSuspended else { return }
        isSuspended = false
        timer?.resume()
    }

    public func fireForTesting() {
        guard isRunning, isSuspended == false else { return }
        handler()
    }

    private func installObservers() {
        guard observers.isEmpty else { return }

        observers = [
            notificationCenter.addObserver(
                forName: sleepNotificationName,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self else { return }

                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self.suspend()
                    }
                } else {
                    Task { @MainActor in
                        self.suspend()
                    }
                }
            },
            notificationCenter.addObserver(
                forName: wakeNotificationName,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self else { return }

                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self.resume()
                    }
                } else {
                    Task { @MainActor in
                        self.resume()
                    }
                }
            }
        ]
    }

    private func scheduleTimer() {
        timer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: .milliseconds(200)
        )
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.fireForTesting()
            }
        }
        timer.resume()
        self.timer = timer
    }
}

@MainActor
public final class SystemStatusService: ObservableObject {
    @Published public private(set) var snapshot = SystemStatusSnapshot()

    private var timer: SleepAwareRepeatingTimer?
    private var isRunning = false
    private let readers: [any SystemStatusReader]

    public init() {
        self.readers = Self.defaultReaders()
    }

    public init(permissionManager: PermissionManager) {
        self.readers = Self.defaultReaders(permissionManager: permissionManager)
    }

    public init(readers: [any SystemStatusReader]) {
        self.readers = readers
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        refresh()

        let timer = SleepAwareRepeatingTimer(interval: 2.0) { [weak self] in
            self?.refresh()
        }
        timer.start()
        self.timer = timer
    }

    public func stop() {
        timer?.stop()
        timer = nil
        isRunning = false
    }

    public func refresh() {
        let readers = self.readers

        Task.detached(priority: .utility) {
            var merged = SystemStatusPartialSnapshot()
            let corePublishCount = min(readers.count, 6)

            for (index, reader) in readers.enumerated() {
                let partial = await reader.read()
                merged = Self.merge(merged, with: partial)

                let isCoreCheckpoint = (index + 1) == corePublishCount && corePublishCount < readers.count
                let isFinalReader = (index + 1) == readers.count

                if isCoreCheckpoint || isFinalReader {
                    let snapshot = Self.makeSnapshot(from: merged, updatedAt: Date())
                    await MainActor.run {
                        self.snapshot = snapshot
                    }
                }
            }
        }
    }

    private nonisolated static func makeSnapshot(from merged: SystemStatusPartialSnapshot, updatedAt now: Date) -> SystemStatusSnapshot {
        let totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        let memoryUsageGB = merged.memory?.value ?? 0
        let memoryUsagePercent = totalMemoryGB > 0 ? (memoryUsageGB / totalMemoryGB) * 100 : 0
        let diskUsagePercent = merged.disk?.value ?? 0
        let batteryLevel = merged.battery?.percentage ?? 0
        let batteryState = merged.battery?.state ?? "未知"

        return SystemStatusSnapshot(
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
            fanControlStates: merged.fanControlStates,
            bluetoothDevices: merged.bluetoothDevices,
            powerSensors: merged.powerSensors,
            voltageSensors: merged.voltageSensors,
            currentSensors: merged.currentSensors,
            thermalThrottle: merged.thermalThrottle,
            thermalState: merged.thermalState,
            loadAverage1m: merged.loadAverage1m,
            loadAverage5m: merged.loadAverage5m,
            loadAverage15m: merged.loadAverage15m,
            diskMountPoint: merged.diskMountPoint,
            diskUsedGB: merged.diskUsedGB,
            diskTotalGB: merged.diskTotalGB,
            diskVolumes: merged.diskVolumes,
            networkDownloadMBps: merged.networkDownloadMBps,
            networkUploadMBps: merged.networkUploadMBps,
            gpuUsagePercent: merged.gpuUsagePercent,
            gpuFrequencyMHz: merged.gpuFrequencyMHz,
            gpuCoreCount: merged.gpuCoreCount,
            gpuChipModel: merged.gpuChipModel,
            diskReadMBps: merged.diskReadMBps,
            diskWriteMBps: merged.diskWriteMBps,
            topDiskIOProcesses: merged.topDiskIOProcesses,
            diskIODevices: merged.diskIODevices,
            diskIODeviceSource: merged.diskIODeviceSource,
            networkLatencyMs: merged.networkLatencyMs,
            networkDNSLookupMs: merged.networkDNSLookupMs,
            publicIPAddress: merged.publicIPAddress,
            hardwareInfo: merged.hardwareInfo,
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

    private nonisolated static func merge(_ lhs: SystemStatusPartialSnapshot, with rhs: SystemStatusPartialSnapshot) -> SystemStatusPartialSnapshot {
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
        if rhs.fanControlStates.isEmpty == false { result.fanControlStates = rhs.fanControlStates }
        if rhs.bluetoothDevices.isEmpty == false { result.bluetoothDevices = rhs.bluetoothDevices }
        if rhs.powerSensors.isEmpty == false { result.powerSensors = rhs.powerSensors }
        if rhs.voltageSensors.isEmpty == false { result.voltageSensors = rhs.voltageSensors }
        if rhs.currentSensors.isEmpty == false { result.currentSensors = rhs.currentSensors }
        if let thermalThrottle = rhs.thermalThrottle { result.thermalThrottle = thermalThrottle }
        if let thermalState = rhs.thermalState { result.thermalState = thermalState }
        if let loadAverage1m = rhs.loadAverage1m { result.loadAverage1m = loadAverage1m }
        if let loadAverage5m = rhs.loadAverage5m { result.loadAverage5m = loadAverage5m }
        if let loadAverage15m = rhs.loadAverage15m { result.loadAverage15m = loadAverage15m }
        if let diskUsedGB = rhs.diskUsedGB { result.diskUsedGB = diskUsedGB }
        if let diskTotalGB = rhs.diskTotalGB { result.diskTotalGB = diskTotalGB }
        if rhs.diskVolumes.isEmpty == false { result.diskVolumes = rhs.diskVolumes }
        if let networkDownloadMBps = rhs.networkDownloadMBps { result.networkDownloadMBps = networkDownloadMBps }
        if let networkUploadMBps = rhs.networkUploadMBps { result.networkUploadMBps = networkUploadMBps }
        if let gpuUsagePercent = rhs.gpuUsagePercent { result.gpuUsagePercent = gpuUsagePercent }
        if let gpuFrequencyMHz = rhs.gpuFrequencyMHz { result.gpuFrequencyMHz = gpuFrequencyMHz }
        if let gpuCoreCount = rhs.gpuCoreCount { result.gpuCoreCount = gpuCoreCount }
        if let gpuChipModel = rhs.gpuChipModel { result.gpuChipModel = gpuChipModel }
        if let diskReadMBps = rhs.diskReadMBps { result.diskReadMBps = diskReadMBps }
        if let diskWriteMBps = rhs.diskWriteMBps { result.diskWriteMBps = diskWriteMBps }
        if rhs.topDiskIOProcesses.isEmpty == false { result.topDiskIOProcesses = rhs.topDiskIOProcesses }
        if rhs.diskIODevices.isEmpty == false { result.diskIODevices = rhs.diskIODevices }
        if let diskIODeviceSource = rhs.diskIODeviceSource { result.diskIODeviceSource = diskIODeviceSource }
        if let networkLatencyMs = rhs.networkLatencyMs { result.networkLatencyMs = networkLatencyMs }
        if let networkDNSLookupMs = rhs.networkDNSLookupMs { result.networkDNSLookupMs = networkDNSLookupMs }
        if let publicIPAddress = rhs.publicIPAddress { result.publicIPAddress = publicIPAddress }
        if let hardwareInfo = rhs.hardwareInfo { result.hardwareInfo = hardwareInfo }
        if rhs.unavailableReasons.isEmpty == false { result.unavailableReasons.append(contentsOf: rhs.unavailableReasons) }

        return result
    }

    private static func defaultReaders(permissionManager: PermissionManager? = nil) -> [any SystemStatusReader] {
        [
            CPUStatusReader(),
            ThermalStatusReader(),
            MemoryStatusReader(),
            DiskStatusReader(),
            NetworkStatusReader(),
            BatteryStatusReader(),
            BluetoothStatusReader(),
            PermissionStatusReader(permissionManager: permissionManager),
            ProcessStatusReader(),
            SensorStatusReader(),
            FanStatusReader(),
            PowerStatusReader(),
            GPUStatusReader(),
            SystemInfoReader()
        ]
    }
}
