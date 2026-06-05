import Foundation
import Darwin
import IOKit.ps
import IOKit
import SystemConfiguration
import CoreWLAN
import AppKit
@preconcurrency import EventKit

public struct CPUStatusReader: SystemStatusReader {
    public init() {}

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        if let usage = currentCPUTicks() {
            let loadAverage = systemLoadAverage()
            let cpuValue = SystemMetricValue(
                id: "cpu",
                name: "CPU",
                category: "cpu",
                value: usage,
                unit: "%",
                source: "host_processor_info",
                isAvailable: true,
                unavailableReason: nil
            )
            partial.cpu = cpuValue
            partial.topCPUProcesses = []
            partial.loadAverage1m = loadAverage?.0
            partial.loadAverage5m = loadAverage?.1
            partial.loadAverage15m = loadAverage?.2
        } else {
            partial.unavailableReasons.append(.init(id: "cpu-unavailable", category: "cpu", message: "CPU 读取不可用", detail: "host_processor_info failed"))
        }

        return partial
    }

    private func currentCPUTicks() -> Double? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        let buffer = UnsafeBufferPointer(start: info, count: Int(infoCount))
        let cpuStateMax = Int(CPU_STATE_MAX)
        guard buffer.count >= Int(cpuCount) * cpuStateMax else { return nil }

        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        var nice: UInt64 = 0
        for index in 0..<Int(cpuCount) {
            let base = index * cpuStateMax
            user += UInt64(buffer[base + Int(CPU_STATE_USER)])
            system += UInt64(buffer[base + Int(CPU_STATE_SYSTEM)])
            idle += UInt64(buffer[base + Int(CPU_STATE_IDLE)])
            nice += UInt64(buffer[base + Int(CPU_STATE_NICE)])
        }

        let total = Double(user + system + idle + nice)
        guard total > 0 else { return nil }
        return (Double(user + system + nice) / total) * 100.0
    }

    private func systemLoadAverage() -> (Double, Double, Double)? {
        var loads = [Double](repeating: 0, count: 3)
        let result = loads.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return -1 }
            return getloadavg(base, Int32(buffer.count))
        }
        guard result > 0 else { return nil }
        return (loads[0], loads[1], loads[2])
    }
}

public struct MemoryStatusReader: SystemStatusReader {
    public init() {}

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound -> kern_return_t in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        guard result == KERN_SUCCESS, totalBytes > 0 else {
            partial.unavailableReasons.append(.init(id: "memory-unavailable", category: "memory", message: "内存读取不可用", detail: "host_statistics64 failed"))
            return partial
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let usedPages = Double(stats.active_count + stats.wire_count + stats.compressor_page_count)
        let usedBytes = usedPages * Double(pageSize)
        let percent = (usedBytes / totalBytes) * 100
        let swap = swapUsage()
        let pressure = memoryPressure()

        partial.memory = SystemMetricValue(
            id: "memory",
            name: "内存",
            category: "memory",
            value: usedBytes / 1_073_741_824.0,
            unit: "GB",
            source: "vm_statistics64",
            isAvailable: true,
            unavailableReason: nil
        )
        if let pressure {
            partial.unavailableReasons.append(.init(id: "memory-pressure-\(pressure.lowercased())", category: "memory", message: "内存压力：\(pressure)", detail: nil))
        }
        if let swap {
            partial.currentSensors.append(SystemSensorSnapshot(
                id: "swap-used",
                name: "Swap 使用",
                category: "memory",
                value: swap,
                unit: "GB",
                source: "vm.swapusage",
                isAvailable: true,
                unavailableReason: nil
            ))
        }
        _ = percent
        return partial
    }

    private func memoryPressure() -> String? {
        var pressureLevel: Int32 = 0
        var size = MemoryLayout.size(ofValue: pressureLevel)
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &size, nil, 0)
        guard result == 0 else { return nil }
        switch pressureLevel {
        case 2: return "warning"
        case 4: return "critical"
        default: return "normal"
        }
    }

    private func swapUsage() -> Double? {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swap, &size, nil, 0)
        guard result == 0 else { return nil }
        return Double(swap.xsu_used) / 1_073_741_824.0
    }
}

public struct DiskStatusReader: SystemStatusReader {
    public init() {}

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        do {
            let values = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let totalBytes = (values[.systemSize] as? NSNumber)?.doubleValue ?? 0
            let freeBytes = (values[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
            let usedBytes = max(0, totalBytes - freeBytes)
            let percent = totalBytes > 0 ? (usedBytes / totalBytes) * 100 : 0
            partial.disk = SystemMetricValue(
                id: "disk",
                name: "磁盘",
                category: "disk",
                value: percent,
                unit: "%",
                source: "attributesOfFileSystem",
                isAvailable: true,
                unavailableReason: nil
            )
            partial.diskUsedGB = usedBytes / 1_073_741_824.0
            partial.diskTotalGB = totalBytes / 1_073_741_824.0
        } catch {
            partial.unavailableReasons.append(.init(id: "disk-unavailable", category: "disk", message: "磁盘读取不可用", detail: error.localizedDescription))
        }
        return partial
    }
}

public struct NetworkStatusReader: SystemStatusReader {
    private static var previousCounters: SystemNetworkCounters?
    private static var previousDate: Date?

    public init() {}

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        guard let current = currentNetworkCounters() else {
            partial.unavailableReasons.append(.init(id: "network-unavailable", category: "network", message: "网络计数读取不可用", detail: "getifaddrs failed"))
            return partial
        }

        let now = Date()
        defer {
            Self.previousCounters = current
            Self.previousDate = now
        }

        guard let previous = Self.previousCounters, let previousDate = Self.previousDate else {
            partial.unavailableReasons.append(.init(id: "network-warmup", category: "network", message: "网络速率不可用", detail: "等待下一次采样建立基线"))
            partial.networkInterfaces = interfaceDetails()
            return partial
        }

        let rate = SystemStatusMetrics.networkRate(previous: previous, current: current, interval: now.timeIntervalSince(previousDate))
        partial.network = SystemMetricValue(
            id: "network",
            name: "网络",
            category: "network",
            value: rate.downloadMBps + rate.uploadMBps,
            unit: "MB/s",
            source: "getifaddrs",
            isAvailable: true,
            unavailableReason: nil
        )
        partial.networkInterfaces = interfaceDetails()
        partial.networkDownloadMBps = rate.downloadMBps
        partial.networkUploadMBps = rate.uploadMBps
        return partial
    }

    private func currentNetworkCounters() -> SystemNetworkCounters? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
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

    private func interfaceDetails() -> [SystemNetworkInterfaceSnapshot] {
        var snapshots: [SystemNetworkInterfaceSnapshot] = []
        let scopedInterfaces = vpnScopedInterfaces()
        let primaryInterfaceName = primaryInterface()

        if let wifi = CWWiFiClient.shared().interface() {
            let ssid = wifi.ssid()
            let bssid = wifi.bssid()
            let rssi = wifi.rssiValue()
            let transmitRate = wifi.transmitRate()
            let channel = wifi.wlanChannel()?.description
            snapshots.append(SystemNetworkInterfaceSnapshot(
                id: "wifi-\(wifi.interfaceName ?? "unknown")",
                name: "Wi-Fi",
                category: "network",
                value: nil,
                unit: "",
                source: "CoreWLAN",
                isAvailable: ssid != nil,
                unavailableReason: ssid == nil ? "未连接 Wi‑Fi" : nil,
                interfaceName: wifi.interfaceName,
                ssid: ssid,
                bssid: bssid,
                rssi: rssi,
                transmitRateMbps: transmitRate,
                channel: channel,
                isVPN: false
            ))
        }

        if let primaryInterfaceName {
            snapshots.append(SystemNetworkInterfaceSnapshot(
                id: "primary-\(primaryInterfaceName)",
                name: "主接口",
                category: "network",
                value: nil,
                unit: "",
                source: "SCDynamicStoreCopyValue",
                isAvailable: true,
                unavailableReason: nil,
                interfaceName: primaryInterfaceName,
                ssid: nil,
                bssid: nil,
                rssi: nil,
                transmitRateMbps: nil,
                channel: nil,
                isVPN: scopedInterfaces.contains(primaryInterfaceName)
            ))
        } else {
            snapshots.append(SystemNetworkInterfaceSnapshot(
                id: "primary-interface-unavailable",
                name: "主接口",
                category: "network",
                value: nil,
                unit: "",
                source: "SCDynamicStoreCopyValue",
                isAvailable: false,
                unavailableReason: "无法读取主接口",
                interfaceName: nil,
                ssid: nil,
                bssid: nil,
                rssi: nil,
                transmitRateMbps: nil,
                channel: nil,
                isVPN: false
            ))
        }

        if snapshots.isEmpty {
            snapshots.append(SystemNetworkInterfaceSnapshot(
                id: "network-interface-unavailable",
                name: "网络接口",
                category: "network",
                value: nil,
                unit: "",
                source: "SCDynamicStoreCopyValue",
                isAvailable: false,
                unavailableReason: "未能读取网络接口",
                interfaceName: nil,
                ssid: nil,
                bssid: nil,
                rssi: nil,
                transmitRateMbps: nil,
                channel: nil,
                isVPN: false
            ))
        }

        return snapshots
    }

    private func primaryInterface() -> String? {
        guard let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) else { return nil }
        return (global as? [String: Any])?["PrimaryInterface"] as? String
    }

    private func vpnScopedInterfaces() -> Set<String> {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = settings["__SCOPED__"] as? [String: Any] else {
            return []
        }
        return Set(scoped.keys)
    }
}

public struct BatteryStatusReader: SystemStatusReader {
    public init() {}

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            partial.battery = Self.noBatterySnapshot(source: "IOPSCopyPowerSourcesInfo")
            partial.unavailableReasons.append(.init(id: "battery-unavailable", category: "battery", message: "无电池", detail: "IOPSCopyPowerSourcesList empty"))
            return partial
        }

        let currentCapacity = description[kIOPSCurrentCapacityKey] as? Float ?? 0
        let maxCapacity = description[kIOPSMaxCapacityKey] as? Float ?? 100
        let powerSource = description[kIOPSPowerSourceStateKey] as? String ?? ""
        let isCharging = description["Is Charging"] as? Bool ?? false
        let level = maxCapacity > 0 ? Double(currentCapacity / maxCapacity * 100) : nil

        let smart = smartBatteryDetails()
        let battery = SystemBatteryDetails(
            percentage: level,
            state: batteryState(isCharging: isCharging, powerSource: powerSource),
            cycleCount: smart?.cycleCount,
            designCapacity: smart?.designCapacity,
            maxCapacity: smart?.maxCapacity,
            rawCurrentCapacity: smart?.rawCurrentCapacity,
            rawMaxCapacity: smart?.rawMaxCapacity,
            temperatureC: smart?.temperatureC,
            voltageV: smart?.voltageV,
            amperageA: smart?.amperageA,
            chargerPowerW: smart?.chargerPowerW,
            timeToFullChargeMinutes: description[kIOPSTimeToFullChargeKey] as? Int,
            timeToEmptyMinutes: description[kIOPSTimeToEmptyKey] as? Int,
            source: "IOPS + AppleSmartBattery",
            isAvailable: true,
            unavailableReason: nil
        )
        partial.battery = battery

        if let temperatureC = battery.temperatureC {
                partial.temperatureSensors.append(SystemSensorSnapshot(id: "battery-temperature", name: "电池温度", category: "temperature", value: temperatureC, unit: "°C", source: battery.source, isAvailable: true, unavailableReason: nil))
        }
        if let voltageV = battery.voltageV {
                partial.voltageSensors.append(SystemSensorSnapshot(id: "battery-voltage", name: "电池电压", category: "voltage", value: voltageV, unit: "V", source: battery.source, isAvailable: true, unavailableReason: nil))
        }
        if let amperageA = battery.amperageA {
                partial.currentSensors.append(SystemSensorSnapshot(id: "battery-current", name: "电池电流", category: "current", value: amperageA, unit: "A", source: battery.source, isAvailable: true, unavailableReason: nil))
        }
        if let chargerPowerW = battery.chargerPowerW {
                partial.powerSensors.append(SystemSensorSnapshot(id: "battery-charger-power", name: "充电功率", category: "power", value: chargerPowerW, unit: "W", source: battery.source, isAvailable: true, unavailableReason: nil))
        }

        return partial
    }

    static func noBatterySnapshot(source: String = "IOPSCopyPowerSourcesInfo") -> SystemBatteryDetails {
        SystemBatteryDetails(
            percentage: nil,
            state: "无电池",
            source: source,
            isAvailable: false,
            unavailableReason: "无可用电池"
        )
    }

    private func batteryState(isCharging: Bool, powerSource: String) -> String {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return "低电量模式"
        }
        if isCharging || powerSource == kIOPSACPowerValue {
            return "充电中"
        }
        if powerSource.isEmpty {
            return "无电池"
        }
        return "电池供电"
    }

    private func smartBatteryDetails() -> (cycleCount: Int?, designCapacity: Double?, maxCapacity: Double?, rawCurrentCapacity: Double?, rawMaxCapacity: Double?, temperatureC: Double?, voltageV: Double?, amperageA: Double?, chargerPowerW: Double?)? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        func intValue(_ key: CFString) -> Int? {
            guard let value = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
            return value as? Int
        }

        func doubleValue(_ key: CFString, scale: Double = 1) -> Double? {
            guard let value = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
            if let double = value as? Double { return double / scale }
            if let int = value as? Int { return Double(int) / scale }
            if let number = value as? NSNumber { return number.doubleValue / scale }
            return nil
        }

        let voltage = doubleValue("Voltage" as CFString, scale: 1000.0)
        let amperage = doubleValue("Amperage" as CFString)
        let temperature = doubleValue("Temperature" as CFString, scale: 100.0)
        let chargerPower = (IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any])?[kIOPSPowerAdapterWattsKey] as? Int

        return (
            cycleCount: intValue("CycleCount" as CFString),
            designCapacity: doubleValue("DesignCapacity" as CFString),
            maxCapacity: doubleValue("MaxCapacity" as CFString),
            rawCurrentCapacity: doubleValue("AppleRawCurrentCapacity" as CFString),
            rawMaxCapacity: doubleValue("AppleRawMaxCapacity" as CFString),
            temperatureC: temperature,
            voltageV: voltage,
            amperageA: amperage,
            chargerPowerW: chargerPower.map(Double.init) ?? (voltage.flatMap { v in amperage.map { abs(v * $0) / 1000.0 } })
        )
    }
}

@MainActor
public struct PermissionStatusReader: SystemStatusReader {
    private let permissionManager: PermissionManager

    public init(permissionManager: PermissionManager? = nil) {
        self.permissionManager = permissionManager ?? PermissionManager()
    }

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        let statuses = permissionManager.statuses

        partial.permissions = [
            .init(id: "microphone", name: "麦克风", category: "permission", value: statuses[.microphone]?.displayName, source: "PermissionManager", isAvailable: true, unavailableReason: nil),
            .init(id: "accessibility", name: "辅助功能", category: "permission", value: statuses[.accessibility]?.displayName, source: "PermissionManager", isAvailable: true, unavailableReason: nil),
            .init(id: "screenRecording", name: "屏幕录制", category: "permission", value: statuses[.screenRecording]?.displayName, source: "PermissionManager", isAvailable: true, unavailableReason: nil),
            .init(id: "calendar", name: "日历", category: "permission", value: Self.authorizationText(EKEventStore.authorizationStatus(for: .event)), source: "EKEventStore", isAvailable: true, unavailableReason: nil),
            .init(id: "reminders", name: "提醒事项", category: "permission", value: Self.authorizationText(EKEventStore.authorizationStatus(for: .reminder)), source: "EKEventStore", isAvailable: true, unavailableReason: nil),
            .init(id: "notifications", name: "通知", category: "permission", value: notificationStatus(), source: "UNUserNotificationCenter", isAvailable: true, unavailableReason: nil)
        ]
        return partial
    }

    private func notificationStatus() -> String {
        "待检查"
    }

    private static func authorizationText(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "已授权"
        case .fullAccess: return "已授权"
        case .writeOnly: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限"
        case .notDetermined: return "未确定"
        @unknown default: return "未知"
        }
    }
}

public struct ProcessStatusReader: SystemStatusReader {
    public init() {}

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        partial.topCPUProcesses = readProcesses(limit: 5)
        partial.topMemoryProcesses = partial.topCPUProcesses.sorted { $0.memoryUsageMB > $1.memoryUsageMB }
        return partial
    }

    private func readProcesses(limit: Int) -> [SystemProcessSnapshot] {
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

public struct SensorStatusReader: SystemStatusReader {
    public init() {}

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        partial.unavailableReasons.append(.init(id: "sensor-unavailable", category: "sensor", message: "传感器只读不可用", detail: "SMC/IOReport readers not wired yet"))
        return partial
    }
}

public struct FanStatusReader: SystemStatusReader {
    public init() {}

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        partial.unavailableReasons.append(.init(id: "fan-unavailable", category: "fan", message: "风扇控制未开放", detail: "read-only fan snapshot not yet wired"))
        return partial
    }
}

public struct PowerStatusReader: SystemStatusReader {
    public init() {}

    public func read() -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        if let battery = BatteryStatusReader().read().battery, let power = battery.chargerPowerW {
            partial.powerSensors.append(SystemSensorSnapshot(id: "power-draw", name: "功耗", category: "power", value: power, unit: "W", source: battery.source, isAvailable: true, unavailableReason: nil))
        } else {
            partial.unavailableReasons.append(.init(id: "power-unavailable", category: "power", message: "功耗不可用", detail: "battery reader did not expose charger power"))
        }
        return partial
    }
}
