import Foundation
import Darwin
import IOKit.ps
import Combine

@MainActor
public final class SystemStatusService: ObservableObject {
    @Published public private(set) var snapshot = SystemStatusSnapshot()

    private var timer: Timer?
    private var previousCPUTicks: SystemCPUTickTotals?
    private var previousNetworkCounters: SystemNetworkCounters?
    private var previousNetworkSampleDate: Date?
    private var isRunning = false

    public init() {}

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
        let cpuUsage = readCPUUsage()
        let memory = readMemory()
        let disk = readDisk()
        let network = readNetworkRate(sampleDate: now)
        let battery = readBattery()
        let processes = readProcesses()

        snapshot = SystemStatusSnapshot(
            cpuUsage: cpuUsage,
            memoryUsageGB: memory.usedGB,
            totalMemoryGB: memory.totalGB,
            memoryUsagePercent: memory.percent,
            diskUsagePercent: disk.percent,
            diskUsedGB: disk.usedGB,
            diskTotalGB: disk.totalGB,
            networkDownloadMBps: network.downloadMBps,
            networkUploadMBps: network.uploadMBps,
            batteryLevel: battery.level,
            batteryState: battery.state,
            topProcesses: processes,
            lastUpdated: now
        )
    }

    private func readCPUUsage() -> Double {
        guard let current = currentCPUTicks() else {
            return snapshot.cpuUsage
        }

        defer { previousCPUTicks = current }

        guard let previousCPUTicks else {
            return snapshot.cpuUsage
        }

        return SystemStatusMetrics.cpuUsage(previous: previousCPUTicks, current: current)
    }

    private func currentCPUTicks() -> SystemCPUTickTotals? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )
        guard result == KERN_SUCCESS, let info else {
            return nil
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        let buffer = UnsafeBufferPointer(start: info, count: Int(infoCount))
        let cpuStateMax = Int(CPU_STATE_MAX)
        guard buffer.count >= Int(cpuCount) * cpuStateMax else {
            return nil
        }

        var totals = SystemCPUTickTotals(user: 0, system: 0, idle: 0, nice: 0)
        for index in 0..<Int(cpuCount) {
            let base = index * cpuStateMax
            totals.user += UInt64(buffer[base + Int(CPU_STATE_USER)])
            totals.system += UInt64(buffer[base + Int(CPU_STATE_SYSTEM)])
            totals.idle += UInt64(buffer[base + Int(CPU_STATE_IDLE)])
            totals.nice += UInt64(buffer[base + Int(CPU_STATE_NICE)])
        }

        return totals
    }

    private func readMemory() -> (usedGB: Double, totalGB: Double, percent: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound -> kern_return_t in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        guard result == KERN_SUCCESS, totalBytes > 0 else {
            return (0, totalBytes / 1_073_741_824.0, 0)
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        let usedPages = Double(stats.active_count + stats.wire_count + stats.compressor_page_count)
        let usedBytes = usedPages * Double(pageSize)
        let percent = (usedBytes / totalBytes) * 100

        return (usedBytes / 1_073_741_824.0, totalBytes / 1_073_741_824.0, max(0, min(100, percent)))
    }

    private func readDisk() -> (usedGB: Double, totalGB: Double, percent: Double) {
        do {
            let values = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let totalBytes = (values[.systemSize] as? NSNumber)?.doubleValue ?? 0
            let freeBytes = (values[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
            let usedBytes = max(0, totalBytes - freeBytes)
            let percent = totalBytes > 0 ? (usedBytes / totalBytes) * 100 : 0

            return (usedBytes / 1_073_741_824.0, totalBytes / 1_073_741_824.0, max(0, min(100, percent)))
        } catch {
            return (0, 0, 0)
        }
    }

    private func readNetworkRate(sampleDate: Date) -> SystemNetworkRate {
        guard let current = currentNetworkCounters() else {
            return SystemNetworkRate(downloadMBps: 0, uploadMBps: 0)
        }

        defer {
            previousNetworkCounters = current
            previousNetworkSampleDate = sampleDate
        }

        guard let previousNetworkCounters, let previousNetworkSampleDate else {
            return SystemNetworkRate(downloadMBps: 0, uploadMBps: 0)
        }

        return SystemStatusMetrics.networkRate(
            previous: previousNetworkCounters,
            current: current,
            interval: sampleDate.timeIntervalSince(previousNetworkSampleDate)
        )
    }

    private func currentNetworkCounters() -> SystemNetworkCounters? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }

            let flags = Int32(current.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let address = current.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK) else { continue }
            guard let dataPointer = current.pointee.ifa_data else { continue }

            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            bytesIn += UInt64(data.ifi_ibytes)
            bytesOut += UInt64(data.ifi_obytes)
        }

        return SystemNetworkCounters(bytesIn: bytesIn, bytesOut: bytesOut)
    }

    private func readBattery() -> (level: Double, state: String) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return (0, "无电池")
        }

        let currentCapacity = description[kIOPSCurrentCapacityKey] as? Float ?? 0
        let maxCapacity = description[kIOPSMaxCapacityKey] as? Float ?? 100
        let powerSource = description[kIOPSPowerSourceStateKey] as? String ?? ""
        let isCharging = description["Is Charging"] as? Bool ?? false
        let level = maxCapacity > 0 ? Double(currentCapacity / maxCapacity * 100) : 0

        let state: String
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            state = "低电量模式"
        } else if isCharging || powerSource == kIOPSACPowerValue {
            state = "充电中"
        } else if powerSource.isEmpty {
            state = "无电池"
        } else {
            state = "电池供电"
        }

        return (level, state)
    }

    private func readProcesses(limit: Int = 5) -> [SystemProcessSnapshot] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,pcpu=,rss=,comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let processes = output.split(whereSeparator: \.isNewline).compactMap { line -> SystemProcessSnapshot? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let parts = trimmed.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            guard parts.count >= 4,
                  let pid = Int32(parts[0]),
                  let cpuUsage = Double(parts[1]),
                  let rssKB = Double(parts[2]) else {
                return nil
            }

            let command = String(parts[3])
            let name = URL(fileURLWithPath: command).lastPathComponent
            return SystemProcessSnapshot(
                pid: pid,
                name: name.isEmpty ? command : name,
                cpuUsage: cpuUsage,
                memoryUsageMB: rssKB / 1024.0
            )
        }

        return SystemStatusMetrics.sortedProcesses(processes, limit: limit)
    }
}
