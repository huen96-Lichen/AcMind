# AcMind 本机系统监控技术指南

> 基于 iStat Menus 逆向分析 + AcMind 现有架构，提供完整的系统监控实现方案。

---

## 目录

1. [架构总览](#1-架构总览)
2. [CPU 监控](#2-cpu-监控)
3. [内存监控](#3-内存监控)
4. [磁盘监控](#4-磁盘监控)
5. [网络监控](#5-网络监控)
6. [电池监控](#6-电池监控)
7. [温度传感器监控](#7-温度传感器监控)
8. [风扇监控](#8-风扇监控)
9. [GPU 监控](#9-gpu-监控)
10. [进程监控](#10-进程监控)
11. [权限要求总结](#11-权限要求总结)
12. [性能优化策略](#12-性能优化策略)
13. [AcMind 现状与待办](#13-acmind-现状与待办)

---

## 1. 架构总览

### 1.1 三层架构

```
┌─────────────────────────────────────────────────┐
│                  View Layer                      │
│    NotchV2 · SystemStatusPage · Companion        │
├─────────────────────────────────────────────────┤
│              SystemStatusService                  │
│    定时轮询 (2s) · 合并快照 · 发布更新            │
├─────────────────────────────────────────────────┤
│              Reader Layer (×10)                   │
│  CPU · Memory · Disk · Network · Battery         │
│  Sensor · Fan · Power · Process · Permission     │
└─────────────────────────────────────────────────┘
```

### 1.2 核心协议

```swift
protocol SystemStatusReader: Sendable {
    func read() async -> SystemStatusPartialSnapshot
}
```

每个 Reader 独立采集，输出 `SystemStatusPartialSnapshot`，由 `SystemStatusService.merge()` 合并为 `SystemStatusSnapshot`。

### 1.3 数据流

```
Timer (2s) → Reader.read() × N → merge() → SystemStatusSnapshot → @Published → View
```

---

## 2. CPU 监控

### 2.1 技术方案

| API | 权限 | 用途 |
|-----|------|------|
| `host_processor_info()` | 无 | 每核 CPU 使用率（tick 级） |
| `getloadavg()` | 无 | 1/5/15 分钟负载均值 |
| `sysctl hw.ncpu` | 无 | CPU 核心数 |
| `IOReport` | 无 | Apple Silicon P/E 核心频率 |

### 2.2 实现代码

```swift
import MachO

struct CPUStatusReader: SystemStatusReader {
    func read() async -> SystemStatusPartialSnapshot {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t!
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )

        guard result == KERN_SUCCESS else {
            return SystemStatusPartialSnapshot(readerID: "cpu")
        }

        defer { vm_deallocate(mach_host_self(), vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * Int(MemoryLayout<integer_t>.size))) }

        var perCoreUsage: [Double] = []
        for i in 0..<Int(cpuCount) {
            let offset = Int(CPU_STATE_MAX) * i
            let user   = Double(info[offset + Int(CPU_STATE_USER)])
            let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle   = Double(info[offset + Int(CPU_STATE_IDLE)])
            let nice   = Double(info[offset + Int(CPU_STATE_NICE)])
            let total = user + system + idle + nice
            if total > 0 {
                perCoreUsage.append((user + system + nice) / total * 100.0)
            }
        }

        // 负载均值
        var loadAvg = [Double](repeating: 0, count: 3)
        getloadavg(&loadAvg, 3)

        var partial = SystemStatusPartialSnapshot(readerID: "cpu")
        partial.cpuUsagePercent = perCoreUsage.reduce(0, +) / Double(perCoreUsage.count)
        partial.topProcesses = []  // 需要 ProcessStatusReader 补充
        return partial
    }
}
```

### 2.3 Apple Silicon P/E 核心频率（进阶）

```swift
import IOKit

func readCPUFrequency() -> (pCoreMHz: Int, eCoreMHz: Int)? {
    // IOReport 读取 Apple Silicon 的 CPU 频率
    // 需要解析 IOReportCopyChannelsInGroup("CPU Stats")
    // 这部分需要自行封装 IOKit 桥接
    return nil
}
```

---

## 3. 内存监控

### 3.1 技术方案

| API | 权限 | 用途 |
|-----|------|------|
| `host_statistics64()` | 无 | 物理内存使用详情 |
| `sysctl hw.memsize` | 无 | 物理内存总量 |
| `sysctl kern.memorystatus_vm_pressure_level` | 无 | 内存压力等级 |
| `vm_stat64` | 无 | Swap 用量 |

### 3.2 实现代码

```swift
struct MemoryStatusReader: SystemStatusReader {
    func read() async -> SystemStatusPartialSnapshot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return SystemStatusPartialSnapshot(readerID: "memory")
        }

        let pageSize = Double(vm_kernel_page_size)
        let active     = Double(stats.active_count) * pageSize
        let inactive   = Double(stats.inactive_count) * pageSize
        let free       = Double(stats.free_count) * pageSize
        let wired      = Double(stats.internal_page_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let purgeable  = Double(stats.purgeable_count) * pageSize
        let speculative = Double(stats.speculative_count) * pageSize

        // 总物理内存
        var totalMem: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMem, &size, nil, 0)

        let used = active + wired + compressed
        let total = Double(totalMem)

        // 内存压力
        var pressureLevel: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &pressureSize, nil, 0)

        var partial = SystemStatusPartialSnapshot(readerID: "memory")
        partial.memoryUsedGB = used / 1_073_741_824
        partial.memoryTotalGB = total / 1_073_741_824
        partial.memoryPressureLevel = Int(pressureLevel)
        return partial
    }
}
```

### 3.3 内存压力等级

| Level | 含义 | 颜色建议 |
|-------|------|----------|
| 0 | 正常 | 绿色 |
| 1 | 警告 | 黄色 |
| 2 | 严重 | 红色 |

---

## 4. 磁盘监控

### 4.1 技术方案

| API | 权限 | 用途 |
|-----|------|------|
| `FileManager.attributesOfFileSystem` | 无 | 卷容量/可用空间 |
| `statfs()` / `getfsstat()` | 无 | 详细挂载点信息 |
| `IOReport` | 无 | Apple Silicon 磁盘 I/O 吞吐量 |

### 4.2 实现代码（简单方案）

```swift
struct DiskStatusReader: SystemStatusReader {
    func read() async -> SystemStatusPartialSnapshot {
        let home = NSHomeDirectory()
        guard let values = try? FileManager.default.attributesOfFileSystem(forPath: home) else {
            return SystemStatusPartialSnapshot(readerID: "disk")
        }

        let totalBytes = (values[.systemSize] as? NSNumber)?.doubleValue ?? 0
        let freeBytes  = (values[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
        let usedBytes  = totalBytes - freeBytes

        var partial = SystemStatusPartialSnapshot(readerID: "disk")
        partial.diskUsedGB = usedBytes / 1_073_741_824
        partial.diskTotalGB = totalBytes / 1_073_741_824
        partial.diskFreeGB = freeBytes / 1_073_741_824
        return partial
    }
}
```

### 4.3 实现代码（statfs 详细方案）

```swift
import Darwin

func getAllMounts() -> [(mountPoint: String, total: UInt64, free: UInt64, used: UInt64)] {
    var results: [(String, UInt64, UInt64, UInt64)] = []

    let count = getfsstat(nil, 0, MNT_NOWAIT)
    guard count > 0 else { return results }

    var statBuffer = [statfs](repeating: statfs(), count: Int(count))
    let actual = getfsstat(&statBuffer, Int32(count * MemoryLayout<statfs>.size), MNT_NOWAIT)

    for i in 0..<Int(actual) {
        let fs = statBuffer[i]
        let mountPoint = withUnsafePointer(to: fs.f_mntonname) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }

        let total = fs.f_blocks * UInt64(fs.f_bsize)
        let free  = fs.f_bavail * UInt64(fs.f_bsize)
        let used  = total - free

        // 过滤掉系统卷的只读快照等
        if total > 0 {
            results.append((mountPoint, total, free, used))
        }
    }

    return results
}
```

---

## 5. 网络监控

### 5.1 技术方案

| API | 权限 | 用途 |
|-----|------|------|
| `getifaddrs()` | 无 | 接口收发字节数、包数 |
| `SCDynamicStore` | 无 | 主接口 IP、DNS、代理 |
| `NWPathMonitor` | 无 | 网络路径变化监听 |
| `CoreWLAN` | 无 | WiFi SSID、RSSI、速率 |
| `CFNetworkCopySystemProxySettings` | 无 | VPN 检测 |

### 5.2 实现代码

```swift
import Darwin

struct NetworkStatusReader: SystemStatusReader {
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private var lastTimestamp: Date = Date()

    func read() async -> SystemStatusPartialSnapshot {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return SystemStatusPartialSnapshot(readerID: "network")
        }
        defer { freeifaddrs(first) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var activeInterfaces: [String] = []

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let iface = ptr?.pointee {
            let name = String(cString: iface.ifa_name)

            // 跳过 lo0 和 utun
            guard !name.hasPrefix("lo") && !name.hasPrefix("utun") else {
                ptr = iface.ifa_next
                continue
            }

            if iface.ifa_flags & UInt32(IFF_UP) != 0 {
                if !activeInterfaces.contains(name) {
                    activeInterfaces.append(name)
                }
            }

            if let data = iface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                bytesIn  += UInt64(data.ifi_ibytes)
                bytesOut += UInt64(data.ifi_obytes)
            }

            ptr = iface.ifa_next
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastTimestamp)
        let downloadSpeed = elapsed > 0 ? Double(bytesIn - lastBytesIn) / elapsed : 0
        let uploadSpeed   = elapsed > 0 ? Double(bytesOut - lastBytesOut) / elapsed : 0

        lastBytesIn = bytesIn
        lastBytesOut = bytesOut
        lastTimestamp = now

        var partial = SystemStatusPartialSnapshot(readerID: "network")
        partial.networkBytesIn = bytesIn
        partial.networkBytesOut = bytesOut
        partial.networkDownloadSpeed = downloadSpeed
        partial.networkUploadSpeed = uploadSpeed
        partial.activeInterfaces = activeInterfaces
        return partial
    }
}
```

### 5.3 WiFi 详情（进阶）

```swift
import CoreWLAN

func getWiFiInfo() -> (ssid: String, rssi: Int, txRate: Double)? {
    guard let iface = CWWiFiClient.shared().interface() else { return nil }
    let ssid = iface.ssid() ?? "Unknown"
    let rssi = iface.rssiValue()
    let txRate = iface.transmitRate()
    return (ssid, rssi, txRate)
}
```

---

## 6. 电池监控

### 6.1 技术方案

| API | 权限 | 用途 |
|-----|------|------|
| `IOPSCopyPowerSourcesInfo()` | 无 | 基本电池信息（电量、充电状态） |
| `IOPSCopyPowerSourcesList()` | 无 | 电源源列表 |
| `IOServiceMatching("AppleSmartBattery")` | 无 | 详细 SMART 数据（循环次数、健康度） |
| `IOPSNotificationCreateRunLoopSource` | 无 | 电池变化事件监听 |

### 6.2 实现代码

```swift
import IOKit.ps

struct BatteryStatusReader: SystemStatusReader {
    func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot(readerID: "battery")

        // 基本信息
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any]
        else {
            return partial
        }

        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let timeRemaining = desc[kIOPSTimeToEmptyKey] as? Int ?? -1

        // SMART 详情
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        if service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, nil, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                partial.batteryCycleCount = dict["CycleCount"] as? Int
                partial.batteryDesignCapacity = dict["DesignCapacity"] as? Int
                partial.batteryMaxCapacity = dict["AppleRawMaxCapacity"] as? Int ?? dict["MaxCapacity"] as? Int
                partial.batteryTemperatureC = (dict["Temperature"] as? Double).map { $0 / 100.0 }
                partial.batteryVoltageMv = dict["Voltage"] as? Int
                partial.batteryAmperageMa = dict["Amperage"] as? Int
                partial.batteryWattageMw = dict["InstantAmperage"] as? Int
            }
        }

        partial.batteryPercent = Double(capacity) / Double(maxCapacity) * 100.0
        partial.batteryIsCharging = isCharging
        partial.batteryTimeRemainingMin = timeRemaining >= 0 ? timeRemaining : nil
        return partial
    }
}
```

### 6.3 蓝牙设备电量（进阶）

```swift
import IOBluetooth

func getBluetoothBatteryLevels() -> [(name: String, level: Int)] {
    // IOBluetoothDevice 读取已连接设备的电池等级
    // AirPods、键盘、触控板等
    // 需要遍历 IOBluetoothDevice.pairedDevices()
    return []
}
```

---

## 7. 温度传感器监控

### 7.1 技术方案

| API | 权限 | 用途 |
|-----|------|------|
| `IOKit / AppleSMC` | 无（用户态） | CPU/GPU/SSD 温度 |
| `IOReport` | 无 | Apple Silicon SoC 温度 |

### 7.2 SMC 读取核心实现

```swift
import IOKit

class SMCReader {
    private var connection: io_connect_t = IO_OBJECT_NULL

    init() {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }
        IOServiceOpen(service, mach_task_self_, 0, &connection)
    }

    deinit {
        if connection != IO_OBJECT_NULL {
            IOServiceClose(connection)
        }
    }

    // SMC 数据类型
    enum SMCDataType: UInt32 {
        case flt  = 0x666C7420  // "flt " - float
        case fp1f = 0x66703166  // "fp1f" - 1.5 fixed point
        case fp2e = 0x66703265  // "fp2e" - 2.4 fixed point (温度常用)
        case fp4c = 0x66703463  // "fp4c" - 4.12 fixed point
        case sp78 = 0x73703738  // "sp78" - signed 7.8 fixed point (温度)
        case ui8  = 0x75693820  // "ui8 " - unsigned 8-bit
        case ui16 = 0x75693136  // "ui16" - unsigned 16-bit
        case ui32 = 0x75693332  // "ui32" - unsigned 32-bit
    }

    func readFloat(key: String) -> Double? {
        guard connection != IO_OBJECT_NULL else { return nil }

        var input = SMCKeyData_t()
        var output = SMCKeyData_t()

        // 读取 key 信息
        input.key = FourCharCode(from: key)
        input.data8 = SMC_CMD_READ_KEYINFO

        let result = IOConnectCallStructMethod(
            connection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            MemoryLayout<SMCKeyData_t>.size,
            &output,
            &MemoryLayout<SMCKeyData_t>.size
        )

        guard result == KERN_SUCCESS else { return nil }

        // 读取值
        input.key8 = output.key
        input.data8 = SMC_CMD_READ_BYTES

        let readResult = IOConnectCallStructMethod(
            connection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            MemoryLayout<SMCKeyData_t>.size,
            &output,
            &MemoryLayout<SMCKeyData_t>.size
        )

        guard readResult == KERN_SUCCESS else { return nil }

        // 根据类型解析
        let dataType = output.dataType
        if dataType == SMCDataType.sp78.rawValue {
            // signed 7.8 fixed point（温度）
            let raw = Int16(output.bytes.0) << 8 | Int16(output.bytes.1)
            return Double(raw) / 256.0
        } else if dataType == SMCDataType.flt.rawValue {
            // float
            var value: Float = 0
            withUnsafeMutableBytes(of: &value) { ptr in
                ptr.storeBytes(of: output.bytes.0.bigEndian, toByteOffset: 0, as: UInt8.self)
                ptr.storeBytes(of: output.bytes.1.bigEndian, toByteOffset: 1, as: UInt8.self)
                ptr.storeBytes(of: output.bytes.2.bigEndian, toByteOffset: 2, as: UInt8.self)
                ptr.storeBytes(of: output.bytes.3.bigEndian, toByteOffset: 3, as: UInt8.self)
            }
            return Double(value)
        }
        return nil
    }
}
```

### 7.3 常用温度 SMC 密钥

```swift
struct SMCKeys {
    // CPU 温度
    static let cpuProximity    = "TC0P"
    static let cpuCore0        = "TC0C"
    static let cpuCore1        = "TC1C"

    // GPU 温度
    static let gpuProximity    = "TG0P"
    static let gpuDie          = "TG0D"

    // 内存温度
    static let memProximity    = "TM0P"

    // SSD 温度
    static let ssd             = "TH0P"

    // 机箱温度
    static let palmrest        = "Ts0P"
    static let ambient         = "TA0P"
}
```

### 7.4 AcMind 现状

`SensorStatusReader` 目前是**桩实现**，未接入 SMC/IOReport。需要：
1. 复用已有的 `SMCReader` 类（SystemStatusReaders.swift L609）
2. 在 `SensorStatusReader.read()` 中调用 `smc.readFloat(key:)`
3. 将结果填入 `partial.temperatureSensors`

---

## 8. 风扇监控

### 8.1 技术方案

| API | 权限 | 用途 |
|-----|------|------|
| `IOKit / AppleSMC` | 无 | 风扇数量、转速、最小/最大转速 |

### 8.2 实现代码

```swift
struct FanStatusReader: SystemStatusReader {
    private let smc: SMCReader

    init(smc: SMCReader) {
        self.smc = smc
    }

    func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot(readerID: "fan")

        // 读取风扇数量
        guard let fanCount = smc.readFloat(key: "FNum").map({ Int($0) }),
              fanCount > 0 else {
            return partial
        }

        var fans: [SystemFanSnapshot] = []
        for i in 0..<fanCount {
            let actualSpeed = smc.readFloat(key: "F\(i)Ac")
            let minSpeed = smc.readFloat(key: "F\(i)Mn")
            let maxSpeed = smc.readFloat(key: "F\(i)Mx")
            let name = smc.readString(key: "F\(i)ID") ?? "Fan #\(i + 1)"

            fans.append(SystemFanSnapshot(
                id: "fan-\(i)",
                name: name,
                currentRPM: actualSpeed.map { Int($0) },
                minRPM: minSpeed.map { Int($0) },
                maxRPM: maxSpeed.map { Int($0) }
            ))
        }

        partial.fanSensors = fans
        return partial
    }
}
```

### 8.3 AcMind 现状

`FanStatusReader` 已实现并接入 SMC，可正常工作。

---

## 9. GPU 监控

### 9.1 技术方案

| API | 权限 | 用途 |
|-----|------|------|
| `IOReport` | 无 | Apple Silicon GPU 使用率、频率 |
| `IOKit / AGXEngine` | 无 | Intel/AMD GPU 状态 |
| `powermetrics` | root | GPU 引擎利用率（最准确） |

### 9.2 Apple Silicon GPU 使用率（IOReport）

```swift
import IOKit

func readGPUUsage() -> Double? {
    // IOReport 方式读取 GPU 使用率
    // 需要解析 IOReportCopyChannelsInGroup("GPU Stats")
    //
    // 关键键名（Apple Silicon）:
    // - "GPU Active"     - GPU 活跃时间占比
    // - "GPU Frequency"  - GPU 当前频率

    return nil // 需要完整 IOReport 桥接实现
}
```

### 9.3 GPU 温度（SMC）

```swift
// Apple Silicon GPU 温度 SMC 密钥
let gpuTempKeys = [
    "TG0P",  // GPU proximity
    "TG0D",  // GPU die
    "TG1P",  // GPU 1 proximity (M1 Max/Ultra)
]
```

### 9.4 AcMind 现状

AcMindKit 中**完全没有 GPU 监控代码**。Vendor 目录有第三方实现（exelban/Stats）但未集成。需要：
1. 创建 `GPUStatusReader`
2. 使用 IOReport 读取 GPU 使用率和频率
3. 使用 SMC 读取 GPU 温度

---

## 10. 进程监控

### 10.1 技术方案

| API | 权限 | 用途 |
|-----|------|------|
| `ps` 命令 | 无 | 进程列表、CPU%、内存 |
| `libproc.h` | 无 | 进程详细信息 |
| `proc_pidinfo()` | 无 | 进程 CPU 时间、内存 |

### 10.2 实现代码（ps 方式）

```swift
struct ProcessStatusReader: SystemStatusReader {
    func read() async -> SystemStatusPartialSnapshot {
        var partial = SystemStatusPartialSnapshot(readerID: "process")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid,pcpu,pmem,rss,comm", "-r"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            let lines = output.split(separator: "\n").dropFirst() // 跳过 header
            var processes: [SystemProcessSnapshot] = []

            for line in lines.prefix(10) { // Top 10
                let parts = line.split(separator: " ", maxSplits: 4)
                guard parts.count >= 5 else { continue }

                let pid = Int(parts[0]) ?? 0
                let cpuPercent = Double(parts[1]) ?? 0
                let memPercent = Double(parts[2]) ?? 0
                let rssKB = Int(parts[3]) ?? 0
                let name = String(parts[4]).components(separatedBy: "/").last ?? String(parts[4])

                processes.append(SystemProcessSnapshot(
                    pid: pid,
                    name: name,
                    cpuPercent: cpuPercent,
                    memoryMB: Double(rssKB) / 1024.0
                ))
            }

            partial.topProcesses = processes
        } catch {
            // ps 失败
        }

        return partial
    }
}
```

---

## 11. 权限要求总结

| 功能 | 所需权限 | 特权助手 |
|------|----------|----------|
| CPU 使用率 | 无 | 否 |
| CPU 频率 | 无 | 否 |
| 内存使用 | 无 | 否 |
| 磁盘空间 | 无 | 否 |
| 磁盘 I/O | 无 | 否 |
| 网络流量 | 无 | 否 |
| WiFi 详情 | 无 | 否 |
| 电池信息 | 无 | 否 |
| 温度传感器 | 无（用户态 IOKit） | 否 |
| 风扇转速 | 无（用户态 IOKit） | 否 |
| GPU 使用率 | 无（IOReport） | 否 |
| GPU 详细功耗 | root（powermetrics） | 是 |
| 进程列表 | 无 | 否 |

**关键结论**：macOS 上读取 SMC（温度/风扇）**不需要 root 权限**，用户态即可通过 `IOServiceOpen("AppleSMC")` 访问。只有 `powermetrics`（GPU 详细功耗）需要 root。

---

## 12. 性能优化策略

### 12.1 采样频率

| 数据类型 | 建议频率 | 原因 |
|----------|----------|------|
| CPU 使用率 | 2s | tick 级差值计算需要间隔 |
| 内存 | 5s | 变化缓慢 |
| 磁盘空间 | 30s | 变化极慢 |
| 网络速率 | 1s | 需要高频计算差值 |
| 电池 | 10s | 变化极慢 |
| 温度 | 5s | 变化缓慢 |
| 风扇 | 3s | 转速变化较慢 |
| GPU | 2s | 变化较快 |
| 进程 | 5s | ps 命令开销较大 |

### 12.2 节能策略

```swift
// 应用失去焦点时降低采样频率
NotificationCenter.default.addObserver(
    forName: NSApplication.didResignActiveNotification,
    object: nil, queue: .main
) { _ in
    // 降低频率到 10s
}

NotificationCenter.default.addObserver(
    forName: NSApplication.didBecomeActiveNotification,
    object: nil, queue: .main
) { _ in
    // 恢复正常频率 2s
}
```

### 12.3 内存管理

- SMC 连接保持长连接，避免每次读取都 `IOServiceOpen`/`IOServiceClose`
- Reader 实例在 `SystemStatusService` 中复用
- 快照使用值类型（struct），避免不必要的堆分配

---

## 13. AcMind 现状与待办

### 13.1 已实现 ✅

| 功能 | 文件 | 状态 |
|------|------|------|
| CPU 使用率 | CPUStatusReader | ✅ 完整 |
| 内存使用 | MemoryStatusReader | ✅ 完整 |
| 磁盘空间 | DiskStatusReader | ✅ 基本 |
| 网络流量 | NetworkStatusReader | ✅ 完整 |
| 电池信息 | BatteryStatusReader | ✅ 完整 |
| 风扇转速 | FanStatusReader | ✅ 完整 |
| 进程列表 | ProcessStatusReader | ✅ 基本 |
| SMC 读取器 | SMCReader | ✅ 核心已实现 |

### 13.2 待实现 ❌

| 功能 | 优先级 | 工作量 | 说明 |
|------|--------|--------|------|
| 温度传感器 | 🔴 高 | 小 | `SensorStatusReader` 是桩实现，需要接入 `SMCReader` |
| GPU 监控 | 🔴 高 | 中 | 需要新建 `GPUStatusReader`，使用 IOReport |
| 磁盘 I/O | 🟡 中 | 小 | 需要 IOReport 或 `iostat` 命令 |
| CPU 频率 | 🟡 中 | 小 | 需要 IOReport（Apple Silicon） |
| WiFi 详情 | 🟢 低 | 小 | 已有 CoreWLAN 代码，需接入 Reader |
| 蓝牙设备电量 | 🟢 低 | 中 | IOBluetooth 扫描 |
| 电池变化监听 | 🟢 低 | 小 | `IOPSNotificationCreateRunLoopSource` |

### 13.3 推荐实现顺序

```
第一步（立即可用）:
  接入 SensorStatusReader → 读取 CPU/GPU/SSD 温度

第二步（核心能力）:
  新建 GPUStatusReader → 读取 GPU 使用率和温度

第三步（完善）:
  DiskIOStatusReader → 磁盘读写速率
  CPUFreqStatusReader → P/E 核心频率
```
