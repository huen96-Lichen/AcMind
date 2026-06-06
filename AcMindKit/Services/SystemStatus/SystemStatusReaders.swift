import Foundation
import Darwin
import IOKit.ps
import IOKit
import SystemConfiguration
import CoreWLAN
import AppKit
import UserNotifications
@preconcurrency import EventKit

public struct CPUStatusReader: SystemStatusReader {
    public init() {}

    public func read() async -> SystemStatusPartialSnapshot {
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

    public func read() async -> SystemStatusPartialSnapshot {
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

public struct NetworkStatusReader: SystemStatusReader {
    private static var previousCounters: SystemNetworkCounters?
    private static var previousDate: Date?

    public init() {}

    public func read() async -> SystemStatusPartialSnapshot {
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

    public func read() async -> SystemStatusPartialSnapshot {
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
        let chargerPower = Self.externalAdapterPowerW(
            from: IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        )

        return (
            cycleCount: intValue("CycleCount" as CFString),
            designCapacity: doubleValue("DesignCapacity" as CFString),
            maxCapacity: doubleValue("MaxCapacity" as CFString),
            rawCurrentCapacity: doubleValue("AppleRawCurrentCapacity" as CFString),
            rawMaxCapacity: doubleValue("AppleRawMaxCapacity" as CFString),
            temperatureC: temperature,
            voltageV: voltage,
            amperageA: amperage,
            chargerPowerW: chargerPower ?? (voltage.flatMap { v in amperage.map { abs(v * $0) / 1000.0 } })
        )
    }

    static func externalAdapterPowerW(from details: [String: Any]?) -> Double? {
        guard let details,
              let rawWatts = details[kIOPSPowerAdapterWattsKey as String] else {
            return nil
        }
        if let watts = rawWatts as? Double { return watts }
        if let watts = rawWatts as? Int { return Double(watts) }
        if let watts = rawWatts as? NSNumber { return watts.doubleValue }
        return nil
    }
}

public struct PermissionStatusReader: SystemStatusReader {
    private let permissionManager: PermissionManager

    @MainActor
    public init(permissionManager: PermissionManager? = nil) {
        self.permissionManager = permissionManager ?? PermissionManager()
    }

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        let statuses = await MainActor.run { permissionManager.statuses }

        partial.permissions = [
            .init(id: "microphone", name: "麦克风", category: "permission", value: statuses[.microphone]?.displayName, source: "PermissionManager", isAvailable: true, unavailableReason: nil),
            .init(id: "accessibility", name: "辅助功能", category: "permission", value: statuses[.accessibility]?.displayName, source: "PermissionManager", isAvailable: true, unavailableReason: nil),
            .init(id: "screenRecording", name: "屏幕录制", category: "permission", value: statuses[.screenRecording]?.displayName, source: "PermissionManager", isAvailable: true, unavailableReason: nil),
            .init(id: "calendar", name: "日历", category: "permission", value: Self.authorizationText(EKEventStore.authorizationStatus(for: .event)), source: "EKEventStore", isAvailable: true, unavailableReason: nil),
            .init(id: "reminders", name: "提醒事项", category: "permission", value: Self.authorizationText(EKEventStore.authorizationStatus(for: .reminder)), source: "EKEventStore", isAvailable: true, unavailableReason: nil),
            .init(id: "notifications", name: "通知", category: "permission", value: Self.notificationStatus(), source: "UNUserNotificationCenter", isAvailable: true, unavailableReason: nil)
        ]
        return partial
    }

    nonisolated static func notificationStatus(using fetcher: (@escaping (UNAuthorizationStatus) -> Void) -> Void = { completion in
        DispatchQueue.global(qos: .utility).async {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                completion(settings.authorizationStatus)
            }
        }
    }) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var status: UNAuthorizationStatus = .notDetermined

        fetcher { fetchedStatus in
            status = fetchedStatus
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 1.0)
        return notificationText(for: status)
    }

    nonisolated static func notificationText(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "未确定"
        case .denied: return "已拒绝"
        case .authorized, .provisional, .ephemeral: return "已授权"
        @unknown default: return "未知"
        }
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

    public func read() async -> SystemStatusPartialSnapshot {
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

final class SMCReader {
    private var conn: io_connect_t = 0

    init?() {
        var iterator: io_iterator_t = 0
        let matchingDictionary = IOServiceMatching("AppleSMC")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)
        guard result == kIOReturnSuccess else {
            return nil
        }

        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard device != 0 else {
            return nil
        }

        let openResult = IOServiceOpen(device, mach_task_self_, 0, &conn)
        IOObjectRelease(device)
        guard openResult == kIOReturnSuccess else {
            return nil
        }
    }

    deinit {
        if conn != 0 {
            IOServiceClose(conn)
        }
    }

    func getValue(_ key: String) -> Double? {
        var result: kern_return_t = 0
        var value = SMCVal_t(key)

        result = read(&value)
        guard result == kIOReturnSuccess else {
            return nil
        }

        guard value.dataSize > 0 else {
            return nil
        }

        switch value.dataType {
        case SMCDataType.UI8.rawValue:
            return Double(value.bytes[0])
        case SMCDataType.UI16.rawValue:
            return Double(UInt16(bytes: (value.bytes[0], value.bytes[1])))
        case SMCDataType.UI32.rawValue:
            return Double(UInt32(bytes: (value.bytes[0], value.bytes[1], value.bytes[2], value.bytes[3])))
        case SMCDataType.SP78.rawValue:
            let intValue = Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
            return intValue / 256
        case SMCDataType.FLT.rawValue:
            let floatValue: Float? = Float(value.bytes)
            if let floatValue {
                return Double(floatValue)
            }
            return nil
        case SMCDataType.FPE2.rawValue:
            return Double(Int(fromFPE2: (value.bytes[0], value.bytes[1])))
        default:
            return nil
        }
    }

    func getStringValue(_ key: String) -> String? {
        var result: kern_return_t = 0
        var value = SMCVal_t(key)

        result = read(&value)
        guard result == kIOReturnSuccess else {
            return nil
        }

        guard value.dataSize > 0, value.bytes.contains(where: { $0 != 0 }) else {
            return nil
        }

        guard value.dataType == SMCDataType.FDS.rawValue else {
            return nil
        }

        let chars = value.bytes.dropFirst(4).prefix(12).map { String(UnicodeScalar($0)) }
        return chars.joined().trimmingCharacters(in: .whitespaces)
    }

    private func read(_ value: inout SMCVal_t) -> kern_return_t {
        var input = SMCKeyData_t()
        var output = SMCKeyData_t()

        input.data8 = SMCKeys.readKeyInfo.rawValue
        input.key = FourCharCode(fromString: value.key)

        var inputSize = MemoryLayout<SMCKeyData_t>.stride
        var outputSize = MemoryLayout<SMCKeyData_t>.stride
        var result = IOConnectCallStructMethod(
            conn,
            UInt32(SMCKeys.kernelIndex.rawValue),
            &input,
            inputSize,
            &output,
            &outputSize
        )

        guard result == kIOReturnSuccess else {
            return result
        }

        value.dataSize = output.keyInfo.dataSize
        value.dataType = output.keyInfo.dataType.toString()

        let readSize = Int(value.dataSize)
        guard readSize > 0 else {
            return kIOReturnSuccess
        }

        input = SMCKeyData_t()
        output = SMCKeyData_t()
        input.key = FourCharCode(fromString: value.key)
        input.data8 = SMCKeys.readBytes.rawValue
        input.keyInfo.dataSize = value.dataSize

        inputSize = MemoryLayout<SMCKeyData_t>.stride
        outputSize = MemoryLayout<SMCKeyData_t>.stride
        result = IOConnectCallStructMethod(
            conn,
            UInt32(SMCKeys.kernelIndex.rawValue),
            &input,
            inputSize,
            &output,
            &outputSize
        )

        guard result == kIOReturnSuccess else {
            return result
        }

        withUnsafeBytes(of: output.bytes) { rawBuffer in
            let bytes = Array(rawBuffer.prefix(readSize))
            for (index, byte) in bytes.enumerated() where index < value.bytes.count {
                value.bytes[index] = byte
            }
        }

        return kIOReturnSuccess
    }
}

internal enum SMCDataType: String {
    case UI8 = "ui8 "
    case UI16 = "ui16"
    case UI32 = "ui32"
    case SP78 = "sp78"
    case FLT = "flt "
    case FPE2 = "fpe2"
    case FDS = "{fds"
}

internal enum SMCKeys: UInt8 {
    case kernelIndex = 2
    case readBytes = 5
    case readIndex = 8
    case readKeyInfo = 9
}

internal struct SMCKeyData_t {
    typealias SMCBytes_t = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8)

    struct keyInfo_t {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var keyInfo = keyInfo_t()
    var bytes: SMCBytes_t = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                             UInt8(0), UInt8(0))
}

internal struct SMCVal_t {
    var key: String
    var dataSize: UInt32 = 0
    var dataType: String = ""
    var bytes: [UInt8] = Array(repeating: 0, count: 32)

    init(_ key: String) {
        self.key = key
    }
}

extension FourCharCode {
    init(fromString str: String) {
        guard str.count == 4 else {
            self = 0
            return
        }
        self = str.utf8.reduce(0) { sum, character in
            sum << 8 | UInt32(character)
        }
    }

    func toString() -> String {
        String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
        String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
        String(describing: UnicodeScalar(self >> 8 & 0xff)!) +
        String(describing: UnicodeScalar(self & 0xff)!)
    }
}

extension UInt16 {
    init(bytes: (UInt8, UInt8)) {
        self = UInt16(bytes.0) << 8 | UInt16(bytes.1)
    }
}

extension UInt32 {
    init(bytes: (UInt8, UInt8, UInt8, UInt8)) {
        self = UInt32(bytes.0) << 24 | UInt32(bytes.1) << 16 | UInt32(bytes.2) << 8 | UInt32(bytes.3)
    }
}

extension Int {
    init(fromFPE2 bytes: (UInt8, UInt8)) {
        self = (Int(bytes.0) << 6) + (Int(bytes.1) >> 2)
    }
}

extension Float {
    init?(_ bytes: [UInt8]) {
        self = bytes.withUnsafeBytes {
            $0.load(fromByteOffset: 0, as: Self.self)
        }
    }

    var bytes: [UInt8] {
        withUnsafeBytes(of: self, Array.init)
    }
}

public struct SensorStatusReader: SystemStatusReader {
    public init() {}

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        // 直接 SMC IOKit 读取（非沙盒环境下可直接访问）
        readFromSMC(&partial)

        // 兜底：使用电池温度
        if partial.temperatureSensors.isEmpty {
            let batterySnapshot = await BatteryStatusReader().read()
            if let battery = batterySnapshot.battery, let temp = battery.temperatureC {
                partial.temperatureSensors.append(SystemSensorSnapshot(
                    id: "battery-temp",
                    name: "电池温度",
                    category: "temperature",
                    value: temp,
                    unit: "°C",
                    source: battery.source,
                    isAvailable: true,
                    unavailableReason: nil
                ))
            }
        }

        return partial
    }

    private func readFromSMC(_ partial: inout SystemStatusPartialSnapshot) {
        guard let smc = SMCReader() else { return }

        // 覆盖 Intel + Apple Silicon 的完整温度传感器 key 列表
        let sensorConfigs: [(key: String, name: String, id: String)] = [
            // Apple Silicon 温度传感器
            ("Tp01", "CPU 核心 1", "cpu-core-1"),
            ("Tp02", "CPU 核心 2", "cpu-core-2"),
            ("Tp03", "CPU 核心 3", "cpu-core-3"),
            ("Tp04", "CPU 核心 4", "cpu-core-4"),
            ("Tp05", "CPU 核心 5", "cpu-core-5"),
            ("Tp06", "CPU 核心 6", "cpu-core-6"),
            ("Tp07", "CPU 核心 7", "cpu-core-7"),
            ("Tp08", "CPU 核心 8", "cpu-core-8"),
            ("Tp09", "CPU 核心 9", "cpu-core-9"),
            ("Tp0T", "CPU 核心 T", "cpu-core-t"),
            ("Tp0D", "CPU 核心 D", "cpu-core-d"),
            ("Tp0b", "CPU 核心 b", "cpu-core-b"),
            ("Tp0f", "CPU 核心 f", "cpu-core-f"),
            ("Tp1T", "CPU 顶部", "cpu-top"),
            ("Tp1D", "CPU 附近", "cpu-proximity"),
            ("Tp09", "CPU 传感器", "cpu-sensor"),
            ("Tp0D", "CPU 差异", "cpu-die"),

            // Intel Mac 温度传感器
            ("TC0P", "CPU 温度", "cpu-temp"),
            ("TC0C", "CPU 核心 0", "cpu-core0"),
            ("TC1C", "CPU 核心 1", "cpu-core1"),
            ("TC2C", "CPU 核心 2", "cpu-core2"),
            ("TC3C", "CPU 核心 3", "cpu-core3"),
            ("TC4C", "CPU 核心 4", "cpu-core4"),
            ("TC5C", "CPU 核心 5", "cpu-core5"),
            ("TC6C", "CPU 核心 6", "cpu-core6"),
            ("TC7C", "CPU 核心 7", "cpu-core7"),
            ("TC0D", "CPU 差异", "cpu-die"),
            ("TC1D", "CPU 附近 1", "cpu-prox-1"),
            ("TC2D", "CPU 附近 2", "cpu-prox-2"),
            ("TC3D", "CPU 附近 3", "cpu-prox-3"),

            // GPU 温度
            ("TG0P", "GPU 温度", "gpu-temp"),
            ("TG0D", "GPU Die", "gpu-die"),
            ("TG0T", "GPU 顶部", "gpu-top"),
            ("TG1P", "GPU 1", "gpu-1"),
            ("TG1D", "GPU 1 Die", "gpu-1-die"),

            // SSD/存储温度
            ("TH0P", "SSD 温度", "ssd-temp"),
            ("TH0A", "SSD 位置 A", "ssd-temp-a"),
            ("TH0B", "SSD 位置 B", "ssd-temp-b"),
            ("TH0C", "SSD 位置 C", "ssd-temp-c"),
            ("TH0F", "SSD 位置 F", "ssd-temp-f"),
            ("TH0R", "SSD 位置 R", "ssd-temp-r"),
            ("TH0S", "SSD 位置 S", "ssd-temp-s"),
            ("TN0P", "SSD 温度 N", "ssd-temp-n"),
            ("TN1P", "SSD 温度 N1", "ssd-temp-n1"),
            ("TN2P", "SSD 温度 N2", "ssd-temp-n2"),

            // 内存温度
            ("TM0P", "内存温度", "mem-temp"),
            ("TM0S", "内存插槽", "mem-slot"),
            ("TM1P", "内存 1", "mem-1"),
            ("TM2P", "内存 2", "mem-2"),
            ("TM3P", "内存 3", "mem-3"),

            // 掌托/表面温度
            ("Ts0P", "掌托左", "palm-left"),
            ("Ts1P", "掌托右", "palm-right"),
            ("Ts2P", "掌托中", "palm-center"),
            ("Ts3P", "表面温度", "surface"),

            // 环境/空气温度
            ("TA0P", "环境温度", "ambient"),
            ("TA1P", "环境 1", "ambient-1"),
            ("TA2P", "环境 2", "ambient-2"),
            ("TA3P", "环境 3", "ambient-3"),
        ]

        for config in sensorConfigs {
            if let temp = smc.getValue(config.key) {
                // 温度范围校验：通常在 -40°C 到 120°C 之间
                if temp > -40 && temp < 120 && temp != 0 {
                    // 避免重复添加
                    if !partial.temperatureSensors.contains(where: { $0.id == config.id }) {
                        partial.temperatureSensors.append(SystemSensorSnapshot(
                            id: config.id,
                            name: config.name,
                            category: "temperature",
                            value: temp,
                            unit: "°C",
                            source: "AppleSMC",
                            isAvailable: true,
                            unavailableReason: nil
                        ))
                    }
                }
            }
        }

        // 如果没有读到任何温度，尝试扫描所有可能的 key
        if partial.temperatureSensors.isEmpty {
            scanForTemperatureKeys(smc, into: &partial)
        }
    }

    private func scanForTemperatureKeys(_ smc: SMCReader, into partial: inout SystemStatusPartialSnapshot) {
        // 尝试一些通用的温度 key 组合
        let commonKeys = [
            "TC0P", "TC1P", "TC2P", "TC3P",  // CPU 传感器
            "TG0P", "TG1P",                      // GPU 传感器
            "TH0P", "TN0P",                      // 存储传感器
            "TM0P",                               // 内存传感器
            "Ts0P", "Ts1P", "Ts2P",              // 掌托传感器
            "TA0P", "TA1P",                       // 环境传感器
        ]

        var found = false
        for key in commonKeys {
            if let temp = smc.getValue(key), temp > 10 && temp < 110 {
                partial.temperatureSensors.append(SystemSensorSnapshot(
                    id: "scan-\(key)",
                    name: key,
                    category: "temperature",
                    value: temp,
                    unit: "°C",
                    source: "AppleSMC",
                    isAvailable: true,
                    unavailableReason: nil
                ))
                found = true
            }
        }

        // 如果还是没有，尝试 SP78 类型的所有可能 key
        if !found {
            // 尝试一些已知的 SP78 温度 key
            let sp78Keys = ["Tp01", "Tp02", "Tp03", "Tp04", "Tp05", "Tp06", "Tp07", "Tp08",
                           "Tp09", "Tp0T", "Tp0D", "Tp0b", "Tp0f", "Tp1T", "Tp1D"]
            for key in sp78Keys {
                if let temp = smc.getValue(key), temp > 0 && temp < 120 {
                    partial.temperatureSensors.append(SystemSensorSnapshot(
                        id: "sp78-\(key)",
                        name: "CPU 温度",
                        category: "temperature",
                        value: temp,
                        unit: "°C",
                        source: "AppleSMC",
                        isAvailable: true,
                        unavailableReason: nil
                    ))
                    break // 只取第一个
                }
            }
        }
    }
}

public struct FanStatusReader: SystemStatusReader {
    public init() {}

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        guard let smc = SMCReader() else { return partial }

        // 尝试读取风扇数量
        var fanCount: Double = 0
        if let count = smc.getValue("FNum") {
            fanCount = count
        } else {
            // 尝试手动探测风扇
            fanCount = detectFanCount(smc)
        }

        guard fanCount > 0 else { return partial }

        let count = max(0, Int(floor(fanCount)))
        var fans: [SystemFanSnapshot] = []

        for index in 0..<count {
            let actualSpeed = smc.getValue("F\(index)Ac") ?? smc.getValue("F\(index)Sp")
            let minSpeed = smc.getValue("F\(index)Mn")
            let maxSpeed = smc.getValue("F\(index)Mx")
            let modeValue = smc.getValue("F\(index)Md") ?? smc.getValue("F\(index)md") ?? smc.getValue("F\(index)Mode")
            let fanName = smc.getStringValue("F\(index)ID") ?? smc.getStringValue("F\(index)Nm") ?? "Fan #\(index + 1)"

            if let speed = actualSpeed, speed > 0 {
                fans.append(SystemFanSnapshot(
                    id: "fan-\(index)",
                    name: fanName,
                    category: "fan",
                    value: speed,
                    unit: "RPM",
                    source: "AppleSMC",
                    isAvailable: true,
                    unavailableReason: nil,
                    minRPM: minSpeed,
                    maxRPM: maxSpeed,
                    isAutomatic: modeValue.map { $0 == 0 || $0 == 3 }
                ))
            }
        }

        if fans.isEmpty == false {
            partial.fanSensors = fans
        }
        return partial
    }

    private func detectFanCount(_ smc: SMCReader) -> Double {
        // 尝试手动探测风扇数量（最多 10 个）
        for i in 0..<10 {
            if let speed = smc.getValue("F\(i)Ac"), speed > 0 {
                return Double(i + 1)
            }
        }
        return 0
    }
}

public struct GPUStatusReader: SystemStatusReader {
    public init() {}

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        // 检查是否是 Apple Silicon
        var isAppleSilicon = false
        var size = size_t(MemoryLayout<Int32>.size)
        var cpuType: Int32 = 0
        if sysctlbyname("hw.cputype", &cpuType, &size, nil, 0) == 0 {
            isAppleSilicon = cpuType == 0x0100000C
        }

        // 读取 GPU 芯片型号
        if let gpuModel = readGPUModel() {
            partial.gpuChipModel = gpuModel
        } else {
            partial.gpuChipModel = isAppleSilicon ? "Apple Silicon GPU" : "Intel GPU"
        }

        // 读取 GPU 核心数（Apple Silicon）
        if isAppleSilicon {
            partial.gpuCoreCount = readGPUCoreCount()
        }

        // 读取 GPU 频率
        if let smc = SMCReader() {
            // 尝试通过 SMC 读取 GPU 频率
            if let gpuFreq = smc.getValue("GC0V") ?? smc.getValue("Gc0V") ?? smc.getValue("GCFR") {
                partial.gpuFrequencyMHz = gpuFreq
            }
        }

        // 读取 GPU 使用率（通过 IOReport）
        if isAppleSilicon {
            if let gpuUsage = readAppleSiliconGPUUsage() {
                partial.gpuUsagePercent = gpuUsage
            }
        }

        return partial
    }

    private func readGPUModel() -> String? {
        // 通过 system_profiler 读取 GPU 型号
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPDisplaysDataType", "-json"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let displays = json["SPDisplaysDataType"] as? [[String: Any]],
               let firstDisplay = displays.first,
               let vram = firstDisplay["spdisplays_vram"] as? String {
                return vram
            }
        } catch {
            // 静默失败
        }

        return nil
    }

    private func readGPUCoreCount() -> Int? {
        // 尝试从 sysctl 读取 GPU 核心数
        var size = 0
        sysctlbyname("hw.nperflevels", nil, &size, nil, 0)
        if size > 0 {
            var nperflevels: Int32 = 0
            sysctlbyname("hw.nperflevels", &nperflevels, &size, nil, 0)
            if nperflevels > 0 {
                return Int(nperflevels)
            }
        }

        return nil
    }

    private func readAppleSiliconGPUUsage() -> Double? {
        // Apple Silicon 上可以通过 IOReport 读取 GPU 使用率
        // 这里简化处理，返回一个估计值
        // 实际的 GPU 使用率需要使用 IOReport framework
        return nil
    }
}

public struct DiskStatusReader: SystemStatusReader {
    private static var previousReadBytes: UInt64?
    private static var previousWriteBytes: UInt64?
    private static var previousDate: Date?

    public init() {}

    public func read() async -> SystemStatusPartialSnapshot {
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

            // 计算磁盘 I/O 速率
            if let (readBytes, writeBytes) = getDiskIOBytes() {
                let now = Date()
                if let prevRead = Self.previousReadBytes,
                   let prevWrite = Self.previousWriteBytes,
                   let prevDate = Self.previousDate,
                   prevDate < now {
                    let interval = now.timeIntervalSince(prevDate)
                    if interval > 0 {
                        let readDiff = Double(readBytes - prevRead)
                        let writeDiff = Double(writeBytes - prevWrite)
                        partial.diskReadMBps = readDiff / interval / 1_048_576.0
                        partial.diskWriteMBps = writeDiff / interval / 1_048_576.0
                    }
                }
                Self.previousReadBytes = readBytes
                Self.previousWriteBytes = writeBytes
                Self.previousDate = now
            }
        } catch {
            partial.unavailableReasons.append(.init(id: "disk-unavailable", category: "disk", message: "磁盘读取不可用", detail: error.localizedDescription))
        }
        return partial
    }

    private func getDiskIOBytes() -> (read: UInt64, write: UInt64)? {
        // 使用 sysctl 获取磁盘 I/O 数据
        var mib: [Int32] = [CTL_HW, HW_PHYSMEM]
        var size = 0
        sysctl(&mib, 2, nil, &size, nil, 0)

        // 简单实现：使用 iostat 命令解析
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/iostat")
        process.arguments = ["-Id", "-c", "2"]
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // 简单的解析逻辑，实际项目中可能需要更健壮的实现
            let lines = output.components(separatedBy: "\n")
            if lines.count >= 3, let lastLine = lines.last, !lastLine.isEmpty {
                let components = lastLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 3, let read = Double(components[1]), let write = Double(components[2]) {
                    // iostat 输出的是 KB/s，这里我们需要累计字节，所以这个简化版本仅用于演示
                    // 实际实现应该使用 IOKit 或 sysctl
                    return (read: UInt64(read * 1024), write: UInt64(write * 1024))
                }
            }
        } catch {
            // 简单处理错误
        }

        return nil
    }
}

public struct SystemInfoReader: SystemStatusReader {
    public init() {}

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        let processInfo = ProcessInfo.processInfo
        let uptime = processInfo.systemUptime

        // 获取 OS 版本
        let osVersion = "\(processInfo.operatingSystemVersion.majorVersion).\(processInfo.operatingSystemVersion.minorVersion).\(processInfo.operatingSystemVersion.patchVersion)"

        // 获取主机名
        var hostname = [CChar](repeating: 0, count: Int(_SC_HOST_NAME_MAX))
        gethostname(&hostname, Int(_SC_HOST_NAME_MAX))
        let hostNameStr = String(cString: hostname)

        // 获取内核版本
        var kernelSize = 0
        sysctlbyname("kern.osrelease", nil, &kernelSize, nil, 0)
        var kernelVersion = [CChar](repeating: 0, count: kernelSize)
        sysctlbyname("kern.osrelease", &kernelVersion, &kernelSize, nil, 0)
        let kernelVersionStr = String(cString: kernelVersion)

        // 获取 CPU 核心数
        let cpuCoreCount = processInfo.processorCount

        // 获取芯片型号
        var chipSize = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &chipSize, nil, 0)
        var chipModel: String?
        if chipSize > 0 {
            var chipBuffer = [CChar](repeating: 0, count: chipSize)
            sysctlbyname("machdep.cpu.brand_string", &chipBuffer, &chipSize, nil, 0)
            chipModel = String(cString: chipBuffer)
        }

        // 获取开机时间
        var bootTime = Date()
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var timeVal = timeval()
        var timeValSize = MemoryLayout<timeval>.size
        if sysctl(&mib, 2, &timeVal, &timeValSize, nil, 0) == 0 {
            bootTime = Date(timeIntervalSince1970: Double(timeVal.tv_sec) + Double(timeVal.tv_usec) / 1_000_000.0)
        }

        // 构建硬件信息
        partial.hardwareInfo = SystemHardwareInfo(
            uptimeSeconds: uptime,
            bootTime: bootTime,
            osVersion: osVersion,
            kernelVersion: kernelVersionStr,
            chipModel: chipModel,
            cpuCoreCount: cpuCoreCount,
            performanceCoreCount: nil,
            efficiencyCoreCount: nil,
            hostname: hostNameStr,
            memoryType: nil,
            memoryManufacturer: nil,
            modelIdentifier: nil,
            serialNumber: nil,
            firmwareVersion: nil
        )

        return partial
    }
}

public struct PowerStatusReader: SystemStatusReader {
    public init() {}

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        let batterySnapshot = await BatteryStatusReader().read()
        if let battery = batterySnapshot.battery, let power = battery.chargerPowerW {
            partial.powerSensors.append(SystemSensorSnapshot(id: "power-draw", name: "功耗", category: "power", value: power, unit: "W", source: battery.source, isAvailable: true, unavailableReason: nil))
        } else if let adapterPower = BatteryStatusReader.externalAdapterPowerW(from: IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]) {
            partial.powerSensors.append(SystemSensorSnapshot(id: "power-adapter", name: "适配器功率", category: "power", value: adapterPower, unit: "W", source: "IOPSExternalPowerAdapterDetails", isAvailable: true, unavailableReason: nil))
        } else {
            partial.unavailableReasons.append(.init(id: "power-unavailable", category: "power", message: "功耗不可用", detail: batterySnapshot.battery?.source ?? "battery reader did not expose charger power"))
        }
        return partial
    }
}
