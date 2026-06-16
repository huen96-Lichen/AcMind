import Foundation
import Darwin
import DiskArbitration
import IOKit.ps
import IOKit
import SystemConfiguration
import CoreWLAN
import AppKit
import UserNotifications
@preconcurrency import EventKit

#if arch(arm64)
private typealias IOHIDEventSystemClientRef = OpaquePointer
private typealias IOHIDServiceClientRef = OpaquePointer
private typealias IOHIDEventRef = OpaquePointer

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> IOHIDEventSystemClientRef?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: IOHIDEventSystemClientRef, _ match: CFDictionary) -> Int32

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: IOHIDEventSystemClientRef) -> CFArray?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: IOHIDServiceClientRef, _ property: CFString) -> CFTypeRef?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: IOHIDServiceClientRef, _ type: Int64, _ field: Int32, _ options: Int64) -> IOHIDEventRef?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: IOHIDEventRef, _ field: Int32) -> Double
#endif

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

public struct ThermalStatusReader: SystemStatusReader {
    private let outputProvider: @Sendable () async -> String?

    public init(outputProvider: (@Sendable () async -> String?)? = nil) {
        self.outputProvider = outputProvider ?? { await Self.defaultOutputProvider() }
    }

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        guard let output = await outputProvider(),
              let throttle = Self.parseThermalThrottleOutput(output) else {
            partial.thermalThrottle = SystemThermalThrottleInfo(
                source: "pmset -g therm",
                isAvailable: false,
                unavailableReason: "pmset -g therm 无输出"
            )
            partial.unavailableReasons.append(.init(
                id: "thermal-throttle-unavailable",
                category: "thermal",
                message: "热节流信息不可用",
                detail: "pmset -g therm 读取失败或无数据"
            ))
            partial.thermalState = "不可用"
            return partial
        }

        partial.thermalThrottle = throttle
        partial.thermalState = Self.thermalStateText(for: throttle)
        return partial
    }

    public static func parseThermalThrottleOutput(_ output: String) -> SystemThermalThrottleInfo? {
        let lines = output.split(whereSeparator: \.isNewline)
        var speedLimit: Int?
        var schedulerLimit: Int?
        var availableCPUs: Int?
        var sawValue = false

        for lineSubsequence in lines {
            let line = String(lineSubsequence)
            if let value = intValue(from: line, keys: ["CPU_Speed_Limit", "CPU Speed Limit"]) {
                speedLimit = value
                sawValue = true
            }
            if let value = intValue(from: line, keys: ["CPU_Scheduler_Limit", "CPU Scheduler Limit"]) {
                schedulerLimit = value
                sawValue = true
            }
            if let value = intValue(from: line, keys: ["CPU_Available_CPUs", "CPU Available CPUs"]) {
                availableCPUs = value
                sawValue = true
            }
        }

        guard sawValue else { return nil }
        return SystemThermalThrottleInfo(
            speedLimit: speedLimit,
            schedulerLimit: schedulerLimit,
            availableCPUs: availableCPUs,
            source: "pmset -g therm",
            isAvailable: true,
            unavailableReason: nil
        )
    }

    private static func defaultOutputProvider() async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
                process.arguments = ["-g", "therm"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func thermalStateText(for throttle: SystemThermalThrottleInfo) -> String {
        guard throttle.isAvailable else { return "不可用" }

        if let speed = throttle.speedLimit {
            if speed >= 90 { return "正常" }
            if speed >= 70 { return "轻度节流" }
            if speed >= 40 { return "中度节流" }
            return "严重节流"
        }

        return "已采样"
    }

    private static func intValue(from line: String, keys: [String]) -> Int? {
        for key in keys {
            guard line.contains(key) else { continue }
            let separators = CharacterSet(charactersIn: "=:")
            let parts = line.components(separatedBy: separators)
            guard parts.count >= 2 else { continue }
            let rawValue = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Int(rawValue) {
                return value
            }
        }
        return nil
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
    private let latencyProvider: @Sendable () async -> Double?
    private let dnsLookupProvider: @Sendable () async -> Double?
    private let publicIPAddressProvider: @Sendable () async -> String?

    public init(
        latencyProvider: (@Sendable () async -> Double?)? = nil,
        dnsLookupProvider: (@Sendable () async -> Double?)? = nil,
        publicIPAddressProvider: (@Sendable () async -> String?)? = nil
    ) {
        self.latencyProvider = latencyProvider ?? { await Self.defaultLatencyProvider() }
        self.dnsLookupProvider = dnsLookupProvider ?? { await Self.defaultDNSLookupProvider() }
        self.publicIPAddressProvider = publicIPAddressProvider ?? { await Self.defaultPublicIPAddressProvider() }
    }

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        async let latencyResult = latencyProvider()
        async let dnsLookupResult = dnsLookupProvider()
        async let publicIPResult = publicIPAddressProvider()

        if let latency = await latencyResult {
            partial.networkLatencyMs = latency
        } else {
            partial.unavailableReasons.append(.init(id: "network-ping-unavailable", category: "network", message: "网络延迟不可用", detail: "ping failed"))
        }

        if let dnsLookup = await dnsLookupResult {
            partial.networkDNSLookupMs = dnsLookup
        } else {
            partial.unavailableReasons.append(.init(id: "network-dns-unavailable", category: "network", message: "DNS 解析不可用", detail: "DNS lookup failed"))
        }

        if let publicIPAddress = await publicIPResult {
            partial.publicIPAddress = publicIPAddress
        } else {
            partial.unavailableReasons.append(.init(id: "network-public-ip-unavailable", category: "network", message: "公网 IP 不可用", detail: "public IP lookup failed"))
        }

        guard let current = currentNetworkCounters() else {
            partial.unavailableReasons.append(.init(id: "network-unavailable", category: "network", message: "网络计数读取不可用", detail: "getifaddrs failed"))
            partial.networkInterfaces = interfaceDetails()
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

    private static func defaultLatencyProvider() async -> Double? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                process.arguments = ["-c", "1", "-n", "-W", "1000", "1.1.1.1"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: Self.parsePingLatency(output))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func defaultDNSLookupProvider() async -> Double? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let start = DispatchTime.now()
                var hints = addrinfo(
                    ai_flags: 0,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: 0,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )

                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo("apple.com", nil, &hints, &result)
                if let result {
                    freeaddrinfo(result)
                }

                guard status == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let elapsedNs = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                continuation.resume(returning: Double(elapsedNs) / 1_000_000.0)
            }
        }
    }

    private static func defaultPublicIPAddressProvider() async -> String? {
        guard let url = URL(string: "https://api.ipify.org?format=text") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let text = String(data: data, encoding: .utf8)
            return parsePublicIPAddress(text)
        } catch {
            return nil
        }
    }

    static func parsePingLatency(_ output: String) -> Double? {
        let patterns = [
            #"time[=<]([0-9]+(?:\.[0-9]+)?)\s*ms"#,
            #"avg[=/]([0-9]+(?:\.[0-9]+)?)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            guard let match = regex.firstMatch(in: output, options: [], range: range), match.numberOfRanges >= 2,
                  let valueRange = Range(match.range(at: 1), in: output),
                  let value = Double(output[valueRange]) else { continue }
            return value
        }

        return nil
    }

    static func parsePublicIPAddress(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

public struct BluetoothStatusReader: SystemStatusReader {
    private let devicesProvider: @Sendable () async -> [SystemBluetoothDeviceSnapshot]?

    public init(devicesProvider: (@Sendable () async -> [SystemBluetoothDeviceSnapshot]?)? = nil) {
        self.devicesProvider = devicesProvider ?? { await Self.defaultDevicesProvider() }
    }

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        guard let devices = await devicesProvider() else {
            partial.unavailableReasons.append(.init(
                id: "bluetooth-unavailable",
                category: "bluetooth",
                message: "蓝牙状态不可用",
                detail: "system_profiler SPBluetoothDataType failed"
            ))
            return partial
        }

        partial.bluetoothDevices = devices
        if devices.isEmpty {
            partial.unavailableReasons.append(.init(
                id: "bluetooth-empty",
                category: "bluetooth",
                message: "没有可用的蓝牙设备",
                detail: "system_profiler returned no paired or connected devices"
            ))
        }
        return partial
    }

    public static func parseSystemProfilerBluetoothData(_ output: String) -> [SystemBluetoothDeviceSnapshot]? {
        guard let data = output.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let reports = json["SPBluetoothDataType"] as? [[String: Any]], let report = reports.first else { return [] }

        var devices: [SystemBluetoothDeviceSnapshot] = []

        if let connected = report["device_connected"] as? [[String: [String: Any]]] {
            devices.append(contentsOf: connected.compactMap { entry in
                guard let device = entry.first else { return nil }
                let name = device.key
                let info = device.value
                return Self.snapshot(
                    name: name,
                    info: info,
                    isConnected: true,
                    isPaired: true
                )
            })
        }

        if let paired = report["device_not_connected"] as? [[String: [String: String]]] {
            devices.append(contentsOf: paired.flatMap { entry in
                entry.compactMap { deviceEntry in
                    let name = deviceEntry.key
                    let info = deviceEntry.value
                    return Self.snapshot(
                        name: name,
                        info: info,
                        isConnected: false,
                        isPaired: true
                    )
                }
            })
        }

        if devices.isEmpty {
            return []
        }

        return devices
    }

    private static func defaultDevicesProvider() async -> [SystemBluetoothDeviceSnapshot]? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                process.arguments = ["SPBluetoothDataType", "-json"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: Self.parseSystemProfilerBluetoothData(output))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func snapshot(
        name: String,
        info: [String: Any],
        isConnected: Bool,
        isPaired: Bool
    ) -> SystemBluetoothDeviceSnapshot {
        let address = Self.deviceAddress(from: info)
        let batteryInfo = Self.batteryInfo(from: info)
        let source = "system_profiler SPBluetoothDataType"

        return SystemBluetoothDeviceSnapshot(
            id: address.isEmpty ? name : address,
            name: name.isEmpty ? address : name,
            address: address.isEmpty ? name : address,
            isConnected: isConnected,
            isPaired: isPaired,
            batteryLevel: batteryInfo.level,
            batteryDetail: batteryInfo.detail,
            source: source,
            isAvailable: true,
            unavailableReason: nil
        )
    }

    private static func snapshot(
        name: String,
        info: [String: String],
        isConnected: Bool,
        isPaired: Bool
    ) -> SystemBluetoothDeviceSnapshot {
        let address = Self.deviceAddress(from: info)
        let batteryInfo = Self.batteryInfo(from: info)
        let source = "system_profiler SPBluetoothDataType"

        return SystemBluetoothDeviceSnapshot(
            id: address.isEmpty ? name : address,
            name: name.isEmpty ? address : name,
            address: address.isEmpty ? name : address,
            isConnected: isConnected,
            isPaired: isPaired,
            batteryLevel: batteryInfo.level,
            batteryDetail: batteryInfo.detail,
            source: source,
            isAvailable: true,
            unavailableReason: nil
        )
    }

    private static func deviceAddress(from info: [String: Any]) -> String {
        for key in ["device_address", "deviceAddress", "BD_ADDR", "Address", "address"] {
            if let raw = info[key] {
                if let text = raw as? String, text.isEmpty == false {
                    return normalizedBluetoothAddress(text)
                }
            }
        }
        return ""
    }

    private static func deviceAddress(from info: [String: String]) -> String {
        for key in ["device_address", "deviceAddress", "BD_ADDR", "Address", "address"] {
            if let text = info[key], text.isEmpty == false {
                return normalizedBluetoothAddress(text)
            }
        }
        return ""
    }

    private static func normalizedBluetoothAddress(_ raw: String) -> String {
        raw.replacingOccurrences(of: ":", with: "-").lowercased()
    }

    private static func batteryInfo(from info: [String: Any]) -> (level: Double?, detail: String?) {
        let keys = [
            ("Main", "device_batteryLevelMain"),
            ("Case", "device_batteryLevelCase"),
            ("Left", "device_batteryLevelLeft"),
            ("Right", "device_batteryLevelRight"),
            ("Battery", "device_batteryLevel"),
            ("Battery", "Left Battery Level"),
            ("Battery", "Right Battery Level")
        ]

        var details: [(String, Double)] = []

        for (label, key) in keys {
            guard let value = Self.percentageValue(info[key]) else { continue }
            details.append((label, value))
        }

        let level = details.first?.1
        let detail = details.isEmpty ? nil : details.map { "\($0.0) \(Int($0.1.rounded()))%" }.joined(separator: " · ")
        return (level, detail)
    }

    private static func batteryInfo(from info: [String: String]) -> (level: Double?, detail: String?) {
        let keys = [
            ("Main", "device_batteryLevelMain"),
            ("Case", "device_batteryLevelCase"),
            ("Left", "device_batteryLevelLeft"),
            ("Right", "device_batteryLevelRight"),
            ("Battery", "device_batteryLevel"),
            ("Battery", "Left Battery Level"),
            ("Battery", "Right Battery Level")
        ]

        var details: [(String, Double)] = []

        for (label, key) in keys {
            guard let value = Self.percentageValue(info[key]) else { continue }
            details.append((label, value))
        }

        let level = details.first?.1
        let detail = details.isEmpty ? nil : details.map { "\($0.0) \(Int($0.1.rounded()))%" }.joined(separator: " · ")
        return (level, detail)
    }

    private static func percentageValue(_ value: Any?) -> Double? {
        guard let value else { return nil }
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            if raw <= 1, raw >= 0 { return raw * 100 }
            return raw
        }
        if let int = value as? Int {
            return int == 1 ? 100 : Double(int)
        }
        if let double = value as? Double {
            return double <= 1 && double >= 0 ? double * 100 : double
        }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: "")
            if let double = Double(trimmed) {
                return double <= 1 && double >= 0 ? double * 100 : double
            }
        }
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
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        let remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
        let notificationValue = Self.notificationStatus()

        partial.permissions = [
            Self.permissionSnapshot(kind: .microphone, status: statuses[.microphone] ?? .unknown),
            Self.permissionSnapshot(kind: .accessibility, status: statuses[.accessibility] ?? .unknown),
            Self.permissionSnapshot(kind: .screenRecording, status: statuses[.screenRecording] ?? .unknown),
            Self.eventPermissionSnapshot(id: "calendar", name: "日历", status: calendarStatus),
            Self.eventPermissionSnapshot(id: "reminders", name: "提醒事项", status: remindersStatus),
            .init(
                id: AppPermissionKind.notifications.rawValue,
                name: AppPermissionKind.notifications.displayName,
                category: "permission",
                value: notificationValue,
                source: "UNUserNotificationCenter",
                isAvailable: notificationValue == "已授权",
                unavailableReason: notificationValue == "已授权" ? nil : "通知权限\(notificationValue)"
            )
        ]
        partial.unavailableReasons = partial.permissions.compactMap { permission -> SystemStatusUnavailableReason? in
            guard permission.isAvailable == false else { return nil }
            return SystemStatusUnavailableReason(
                id: "permission-\(permission.id)",
                category: "permission",
                message: "\(permission.name)：\(permission.unavailableReason ?? permission.value ?? "不可用")",
                detail: permission.source
            )
        }
        return partial
    }

    nonisolated static func permissionSnapshot(
        kind: AppPermissionKind,
        status: AppPermissionStatus
    ) -> SystemPermissionSnapshot {
        SystemPermissionSnapshot(
            id: kind.rawValue,
            name: kind.displayName,
            category: "permission",
            value: status.displayName,
            source: "PermissionManager",
            isAvailable: status.isAuthorized,
            unavailableReason: status.unavailableReason
        )
    }

    nonisolated static func eventPermissionSnapshot(
        id: String,
        name: String,
        status: EKAuthorizationStatus
    ) -> SystemPermissionSnapshot {
        let value = authorizationText(status)
        return SystemPermissionSnapshot(
            id: id,
            name: name,
            category: "permission",
            value: value,
            source: "EKEventStore",
            isAvailable: value == "已授权",
            unavailableReason: value == "已授权" ? nil : "\(name)权限\(value)"
        )
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

    nonisolated static func authorizationText(_ status: EKAuthorizationStatus) -> String {
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
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary, &iterator)
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

        // Apple Silicon 机型会把温度传感器暴露为 HID event services，
        // 这条路径和 AppleSMC 的旧 key 不是一回事。
        #if arch(arm64)
        if partial.temperatureSensors.isEmpty {
            readFromAppleSiliconHIDSensors(&partial)
        }
        #endif

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

    #if arch(arm64)
    private func readFromAppleSiliconHIDSensors(_ partial: inout SystemStatusPartialSnapshot) {
        let sensors = readAppleSiliconTemperatureSensors()
        for (key, value) in sensors {
            guard value > -40, value < 160 else { continue }

            let normalizedName = Self.appleSiliconSensorName(for: key)
            let id = "hid-\(key.lowercased())"
            if !partial.temperatureSensors.contains(where: { $0.id == id }) {
                partial.temperatureSensors.append(SystemSensorSnapshot(
                    id: id,
                    name: normalizedName,
                    category: "temperature",
                    value: value,
                    unit: "°C",
                    source: "AppleHIDEventSystem",
                    isAvailable: true,
                    unavailableReason: nil
                ))
            }
        }
    }

    private func readAppleSiliconTemperatureSensors() -> [String: Double] {
        guard let system = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return [:] }
        let matching: CFDictionary = [
            "PrimaryUsagePage": 0xff00,
            "PrimaryUsage": 0x0005
        ] as CFDictionary
        _ = IOHIDEventSystemClientSetMatching(system, matching)
        guard let services = IOHIDEventSystemClientCopyServices(system) as? [AnyObject] else {
            return [:]
        }

        var results: [String: Double] = [:]
        results.reserveCapacity(services.count)

        for service in services {
            let serviceRef = unsafeBitCast(service, to: IOHIDServiceClientRef.self)
            let product = IOHIDServiceClientCopyProperty(serviceRef, "Product" as CFString)
                .flatMap { $0 as? String } ?? ""
            guard let event = IOHIDServiceClientCopyEvent(serviceRef, 15, 0, 0) else { continue }
            let value = IOHIDEventGetFloatValue(event, 15 << 16)
            results[product] = value
        }

        return results
    }
    #else
    private func readFromAppleSiliconHIDSensors(_ partial: inout SystemStatusPartialSnapshot) {}
    #endif

    private static func appleSiliconSensorName(for product: String) -> String {
        let normalized = product.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalized.lowercased()
        if lower.contains("tcal") { return "当前设备温度" }
        if lower.contains("tdev") { return normalized.replacingOccurrences(of: "PMU ", with: "") }
        if lower.contains("temp") { return normalized }
        return normalized.isEmpty ? "Apple Silicon 传感器" : normalized
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
    private let transportProvider: @Sendable () -> any SystemHardwareTransport

    public init(transportProvider: @escaping @Sendable () -> any SystemHardwareTransport = { SystemHardwareAccess.shared.makeDefaultTransport() }) {
        self.transportProvider = transportProvider
    }

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()

        let transport = transportProvider()
        guard transport.isAvailable else {
            return partial
        }

        let controlStates = transport.refreshFanControlStates()
        guard controlStates.isEmpty == false else { return partial }

        partial.fanControlStates = controlStates
        partial.fanSensors = controlStates.compactMap { state in
            guard let rpm = state.rpm, rpm > 0 else { return nil }
            return SystemFanSnapshot(
                id: "fan-\(state.fanIndex)",
                name: state.name,
                category: "fan",
                value: rpm,
                unit: "RPM",
                source: state.source,
                isAvailable: state.isAvailable,
                unavailableReason: state.unavailableReason,
                minRPM: state.minRPM,
                maxRPM: state.maxRPM,
                isAutomatic: state.isAutomatic
            )
        }
        return partial
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
            let gpuUsage = readAppleSiliconGPUUsage()
            if let gpuUsage {
                partial.gpuUsagePercent = gpuUsage
            }
            if let reason = Self.gpuUsageUnavailableReason(isAppleSilicon: isAppleSilicon, gpuUsage: gpuUsage) {
                partial.unavailableReasons.append(reason)
            }
        } else {
            partial.unavailableReasons.append(.init(
                id: "gpu-usage-unsupported",
                category: "gpu",
                message: "GPU 使用率不可用",
                detail: "No stable GPU usage source for this hardware class"
            ))
        }

        return partial
    }

    static func gpuUsageUnavailableReason(isAppleSilicon: Bool, gpuUsage: Double?) -> SystemStatusUnavailableReason? {
        guard isAppleSilicon, gpuUsage == nil else { return nil }
        return .init(
            id: "gpu-usage-unavailable",
            category: "gpu",
            message: "GPU 使用率不可用",
            detail: "Apple Silicon GPU usage source unavailable"
        )
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
    struct DiskIOBytes {
        var read: UInt64
        var write: UInt64
    }

    struct DiskIODeviceBytes {
        let name: String
        let read: Double
        let write: Double
    }

    struct ParsedDiskIO {
        let totals: DiskIOBytes
        let devices: [DiskIODeviceBytes]
    }

    private static var previousProcessDiskIO: [Int32: DiskIOBytes]?
    private static var previousProcessDate: Date?
    private static var previousReadBytes: UInt64?
    private static var previousWriteBytes: UInt64?
    private static var previousDate: Date?
    private static var previousDeviceDiskIO: [String: DiskIOBytes]?
    private static var previousDeviceDate: Date?
    private let mountedVolumeURLsProvider: @Sendable () -> [URL]?

    public init(mountedVolumeURLsProvider: (@Sendable () -> [URL]?)? = nil) {
        self.mountedVolumeURLsProvider = mountedVolumeURLsProvider ?? {
            FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: [
                    .volumeNameKey,
                    .volumeAvailableCapacityForImportantUsageKey,
                    .volumeTotalCapacityKey,
                    .volumeIsRemovableKey,
                    .volumeIsInternalKey
                ],
                options: [.skipHiddenVolumes]
            )
        }
    }

    public func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot()
        do {
            let diskMountPoint = "/"
            let values = try FileManager.default.attributesOfFileSystem(forPath: diskMountPoint)
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
            partial.diskMountPoint = diskMountPoint
            partial.diskUsedGB = usedBytes / 1_073_741_824.0
            partial.diskTotalGB = totalBytes / 1_073_741_824.0
            partial.diskVolumes = Self.collectMountedVolumes(from: mountedVolumeURLsProvider() ?? [])

            if let currentProcessIO = getProcessDiskIOBytes() {
                let hasBaseline = Self.previousProcessDiskIO != nil && Self.previousProcessDate != nil
                if let reason = Self.diskIOSamplingReason(hasBaseline: hasBaseline, didReadIOBytes: true) {
                    partial.unavailableReasons.append(reason)
                }
                let now = Date()
                if let previousProcessIO = Self.previousProcessDiskIO,
                   let previousDate = Self.previousProcessDate,
                   previousDate < now {
                    let interval = now.timeIntervalSince(previousDate)
                    if interval > 0 {
                        let processSnapshots = Self.diskIOProcessSnapshots(
                            current: currentProcessIO.mapValues { (read: $0.read, write: $0.write) },
                            previous: previousProcessIO.mapValues { (read: $0.read, write: $0.write) },
                            interval: interval,
                            processNameProvider: Self.processName(for:)
                        )
                        partial.topDiskIOProcesses = processSnapshots
                        partial.diskReadMBps = processSnapshots.reduce(0) { $0 + $1.readMBps }
                        partial.diskWriteMBps = processSnapshots.reduce(0) { $0 + $1.writeMBps }
                    }
                }
                Self.previousProcessDiskIO = currentProcessIO
                Self.previousProcessDate = now
            } else if let deviceIO = getNativeDiskIODeviceBytes() {
                partial.diskIODeviceSource = "IORegistry / IOBlockStorageDriver"
                let hasBaseline = Self.previousDeviceDiskIO != nil && Self.previousDeviceDate != nil
                if let reason = Self.diskIOSamplingReason(hasBaseline: hasBaseline, didReadIOBytes: true) {
                    partial.unavailableReasons.append(reason)
                }
                let now = Date()
                if let previousDeviceIO = Self.previousDeviceDiskIO,
                   let previousDate = Self.previousDeviceDate,
                   previousDate < now {
                    let interval = now.timeIntervalSince(previousDate)
                    if interval > 0 {
                        let deviceSnapshots = Self.diskIODeviceSnapshots(
                            current: deviceIO,
                            previous: previousDeviceIO,
                            interval: interval
                        )
                        partial.diskIODevices = deviceSnapshots
                        partial.diskReadMBps = deviceSnapshots.reduce(0) { $0 + $1.readMBps }
                        partial.diskWriteMBps = deviceSnapshots.reduce(0) { $0 + $1.writeMBps }
                    }
                }
                Self.previousDeviceDiskIO = deviceIO
                Self.previousDeviceDate = now
            } else if let diskIO = getDiskIOBytes() {
                partial.diskIODeviceSource = "iostat -Id -c 2"
                let hasBaseline = Self.previousReadBytes != nil && Self.previousWriteBytes != nil && Self.previousDate != nil
                if let reason = Self.diskIOSamplingReason(hasBaseline: hasBaseline, didReadIOBytes: true) {
                    partial.unavailableReasons.append(reason)
                }
                let now = Date()
                if let prevRead = Self.previousReadBytes,
                   let prevWrite = Self.previousWriteBytes,
                   let prevDate = Self.previousDate,
                   prevDate < now {
                    let interval = now.timeIntervalSince(prevDate)
                    if interval > 0 {
                        let readDiff = Double(diskIO.totals.read - prevRead)
                        let writeDiff = Double(diskIO.totals.write - prevWrite)
                        partial.diskReadMBps = readDiff / interval / 1_048_576.0
                        partial.diskWriteMBps = writeDiff / interval / 1_048_576.0
                    }
                }
                partial.diskIODevices = diskIO.devices.map {
                    DiskIODeviceSnapshot(name: $0.name, readMBps: $0.read / 1_048_576.0, writeMBps: $0.write / 1_048_576.0)
                }
                Self.previousReadBytes = diskIO.totals.read
                Self.previousWriteBytes = diskIO.totals.write
                Self.previousDate = now
            } else if let reason = Self.diskIOSamplingReason(hasBaseline: false, didReadIOBytes: false) {
                partial.unavailableReasons.append(reason)
            }
        } catch {
            partial.unavailableReasons.append(.init(id: "disk-unavailable", category: "disk", message: "磁盘读取不可用", detail: error.localizedDescription))
        }
        return partial
    }

    static func diskIOSamplingReason(hasBaseline: Bool, didReadIOBytes: Bool) -> SystemStatusUnavailableReason? {
        if didReadIOBytes == false {
            return .init(
                id: "disk-io-unavailable",
                category: "disk",
                message: "磁盘 I/O 读取不可用",
                detail: "iostat failed"
            )
        }

        guard hasBaseline == false else { return nil }
        return .init(
            id: "disk-io-warmup",
            category: "disk",
            message: "磁盘 I/O 等待基线",
            detail: "first sample requires a previous reading"
        )
    }

    private func getProcessDiskIOBytes() -> [Int32: DiskIOBytes]? {
        var pidBuffer = [Int32](repeating: 0, count: 4096)
        let bytesWritten = proc_listallpids(&pidBuffer, Int32(pidBuffer.count * MemoryLayout<Int32>.size))
        guard bytesWritten > 0 else { return nil }

        let pidCount = Int(bytesWritten) / MemoryLayout<Int32>.size
        guard pidCount > 0 else { return nil }

        var samples: [Int32: DiskIOBytes] = [:]
        samples.reserveCapacity(pidCount)
        for pid in pidBuffer.prefix(pidCount) where pid > 0 {
            var usage = rusage_info_v4()
            let result: Int32 = withUnsafeMutablePointer(to: &usage) { usagePtr in
                let rawPtr = UnsafeMutableRawPointer(usagePtr)
                let procPtr = UnsafeMutablePointer<rusage_info_t?>(OpaquePointer(rawPtr))
                return proc_pid_rusage(pid, RUSAGE_INFO_V4, procPtr)
            }
            guard result == 0 else { continue }
            let read = usage.ri_diskio_bytesread
            let write = usage.ri_diskio_byteswritten
            guard read > 0 || write > 0 else { continue }
            samples[pid] = DiskIOBytes(read: read, write: write)
        }

        return samples.isEmpty ? nil : samples
    }

    static func collectMountedVolumes(from urls: [URL], currentMountPoint: String = "/") -> [DiskVolumeSnapshot] {
        let snapshots = urls.compactMap { url -> DiskVolumeSnapshot? in
            let keys: Set<URLResourceKey> = [
                .volumeNameKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
                .volumeTotalCapacityKey,
                .volumeIsRemovableKey,
                .volumeIsInternalKey
            ]

            guard let values = try? url.resourceValues(forKeys: keys),
                  let volumeName = values.volumeName else {
                return nil
            }

            let totalBytes = Double(values.volumeTotalCapacity ?? 0)
            guard totalBytes > 0 else { return nil }

            let availableBytes: Double
            if let important = values.volumeAvailableCapacityForImportantUsage {
                availableBytes = Double(important)
            } else if let available = values.volumeAvailableCapacity {
                availableBytes = Double(available)
            } else {
                return nil
            }

            let usedBytes = max(0, totalBytes - availableBytes)
            return DiskVolumeSnapshot(
                mountPoint: url.path,
                name: volumeName,
                usedGB: usedBytes / 1_073_741_824.0,
                totalGB: totalBytes / 1_073_741_824.0,
                isRemovable: values.volumeIsRemovable ?? false,
                isInternal: values.volumeIsInternal ?? false,
                isCurrent: url.path == currentMountPoint
            )
        }

        return snapshots.sorted {
            let lhsIsRoot = $0.mountPoint == "/"
            let rhsIsRoot = $1.mountPoint == "/"
            if lhsIsRoot != rhsIsRoot { return lhsIsRoot }
            if $0.isInternal != $1.isInternal { return $0.isInternal && !$1.isInternal }
            return $0.usedGB > $1.usedGB
        }
    }

    private func getDiskIOBytes() -> ParsedDiskIO? {
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
            return Self.parseDiskIOBytes(from: output)
        } catch {
            return nil
        }
    }

    private func getNativeDiskIODeviceBytes() -> [String: DiskIOBytes]? {
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return nil }

        let urls = mountedVolumeURLsProvider() ?? []
        var samples: [String: DiskIOBytes] = [:]
        samples.reserveCapacity(urls.count)

        for url in urls {
            guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL) else {
                continue
            }

            guard let bsdName = DADiskGetBSDName(disk) else { continue }
            let media = DADiskCopyIOMedia(disk)
            guard media != 0 else { continue }
            defer { IOObjectRelease(media) }

            guard let stats = IORegistryEntrySearchCFProperty(
                media,
                kIOServicePlane,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
            ) as? [String: Any] else {
                continue
            }

            guard let read = Self.doubleValue(
                in: stats,
                keys: [
                    "Bytes read from block device",
                    "Bytes (Read)"
                ]
            ),
                  let write = Self.doubleValue(
                    in: stats,
                    keys: [
                        "Bytes written to block device",
                        "Bytes (Write)"
                    ]
                  ) else {
                continue
            }

            samples[String(cString: bsdName)] = DiskIOBytes(
                read: UInt64(max(0, read)),
                write: UInt64(max(0, write))
            )
        }

        return samples.isEmpty ? nil : samples
    }

    private static func processName(for pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 512)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func doubleValue(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dictionary[key] as? Double { return value }
            if let value = dictionary[key] as? Int { return Double(value) }
            if let value = dictionary[key] as? UInt64 { return Double(value) }
            if let value = dictionary[key] as? NSNumber { return value.doubleValue }
        }
        return nil
    }

    static func diskIOProcessSnapshots(
        current: [Int32: (read: UInt64, write: UInt64)],
        previous: [Int32: (read: UInt64, write: UInt64)],
        interval: TimeInterval,
        processNameProvider: (Int32) -> String?
    ) -> [DiskIOProcessSnapshot] {
        guard interval > 0 else { return [] }

        let snapshots = current.compactMap { pid, currentBytes -> DiskIOProcessSnapshot? in
            let previousBytes = previous[pid] ?? (read: 0, write: 0)
            let readDelta = currentBytes.read >= previousBytes.read ? currentBytes.read - previousBytes.read : 0
            let writeDelta = currentBytes.write >= previousBytes.write ? currentBytes.write - previousBytes.write : 0
            guard readDelta > 0 || writeDelta > 0 else { return nil }

            let readMBps = Double(readDelta) / interval / 1_048_576.0
            let writeMBps = Double(writeDelta) / interval / 1_048_576.0
            let name = processNameProvider(pid) ?? "pid \(pid)"
            return DiskIOProcessSnapshot(pid: pid, name: name, readMBps: readMBps, writeMBps: writeMBps)
        }

        return snapshots
            .sorted { ($0.readMBps + $0.writeMBps) > ($1.readMBps + $1.writeMBps) }
    }

    static func diskIODeviceSnapshots(
        current: [String: DiskIOBytes],
        previous: [String: DiskIOBytes],
        interval: TimeInterval
    ) -> [DiskIODeviceSnapshot] {
        guard interval > 0 else { return [] }

        let snapshots = current.compactMap { name, currentBytes -> DiskIODeviceSnapshot? in
            let previousBytes = previous[name] ?? .init(read: 0, write: 0)
            let readDelta = currentBytes.read >= previousBytes.read ? currentBytes.read - previousBytes.read : 0
            let writeDelta = currentBytes.write >= previousBytes.write ? currentBytes.write - previousBytes.write : 0
            guard readDelta > 0 || writeDelta > 0 else { return nil }

            let readMBps = Double(readDelta) / interval / 1_048_576.0
            let writeMBps = Double(writeDelta) / interval / 1_048_576.0
            return DiskIODeviceSnapshot(name: name, readMBps: readMBps, writeMBps: writeMBps)
        }

        return snapshots.sorted { ($0.readMBps + $0.writeMBps) > ($1.readMBps + $1.writeMBps) }
    }

    static func parseDiskIOBytes(from output: String) -> ParsedDiskIO? {
        let lines = output.split(whereSeparator: \.isNewline).reversed()
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var foundDeviceRow = false
        var devices: [DiskIODeviceBytes] = []

        for lineSubsequence in lines {
            let line = String(lineSubsequence)
            let components = line
                .split(whereSeparator: { $0.isWhitespace || $0 == "," })
                .map(String.init)
            guard components.count >= 3 else { continue }
            guard isDiskDeviceRow(components[0]),
                  let read = Double(components[1]),
                  let write = Double(components[2]) else { continue }
            foundDeviceRow = true
            let normalizedRead = max(0, read) * 1024
            let normalizedWrite = max(0, write) * 1024
            devices.append(DiskIODeviceBytes(name: components[0], read: normalizedRead, write: normalizedWrite))
            totalRead += UInt64(normalizedRead)
            totalWrite += UInt64(normalizedWrite)
        }

        guard foundDeviceRow else { return nil }
        return ParsedDiskIO(
            totals: DiskIOBytes(read: totalRead, write: totalWrite),
            devices: devices.sorted { ($0.read + $0.write) > ($1.read + $1.write) }
        )
    }

    private static func isDiskDeviceRow(_ token: String) -> Bool {
        let prefixes = ["disk", "rdisk", "sd", "md", "nvme"]
        return prefixes.contains(where: { token.hasPrefix($0) }) || token.contains(where: { $0.isNumber })
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
