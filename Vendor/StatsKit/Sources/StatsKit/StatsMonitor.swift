import Foundation
import Darwin
import IOKit.ps

public final class StatsMonitor: @unchecked Sendable {
    public static let shared = StatsMonitor()
    
    public private(set) var cpu: CPUStats = CPUStats()
    public private(set) var memory: MemoryStats = MemoryStats()
    public private(set) var disk: DiskStats = DiskStats()
    public private(set) var network: NetworkStats = NetworkStats()
    public private(set) var battery: BatteryStats = BatteryStats()
    
    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.acmind.statsmonitor", qos: .userInitiated)
    private var previousNetwork: (upload: Int64, download: Int64)?
    private var previousSampleTime: Date?
    
    public struct CPUStats {
        public var total: Double = 0
        public var perCore: [Double] = []
        public var system: Double = 0
        public var user: Double = 0
        public var idle: Double = 0
    }
    
    public struct MemoryStats {
        public var total: UInt64 = 0
        public var used: UInt64 = 0
        public var free: UInt64 = 0
        public var active: UInt64 = 0
        public var inactive: UInt64 = 0
        public var wired: UInt64 = 0
        public var compressed: UInt64 = 0
    }
    
    public struct DiskStats {
        public var total: Int64 = 0
        public var used: Int64 = 0
        public var free: Int64 = 0
    }
    
    public struct NetworkStats {
        public var upload: Int64 = 0
        public var download: Int64 = 0
        public var interfaceName: String = ""
        public var status: Bool = false
    }
    
    public struct BatteryStats {
        public var level: Double = 0
        public var isCharging: Bool = false
        public var isPluggedIn: Bool = false
        public var timeRemaining: Int = -1
        public var health: Int = 100
    }
    
    private var numCPUs: natural_t = 0
    private var cpuInfo: processor_info_array_t?
    private var prevCpuInfo: processor_info_array_t?
    private var numCpuInfo: mach_msg_type_number_t = 0
    private var numPrevCpuInfo: mach_msg_type_number_t = 0
    private var previousCPUInfo = host_cpu_load_info()
    
    private init() {
        readCPUInitial()
        readMemory()
        readDisk()
        readNetwork()
        readBattery()
    }
    
    public func start(interval: TimeInterval = 2.0) {
        stop()
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.refresh()
            }
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    public func refresh() {
        queue.async { [weak self] in
            self?.readCPU()
            self?.readMemory()
            self?.readDisk()
            self?.readNetwork()
            self?.readBattery()
        }
    }
    
    private func readCPUInitial() {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numPrevCpuInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCpuInfo)
        if result == KERN_SUCCESS, let cpuInfo = cpuInfo {
            self.numCPUs = numCPUs
            self.cpuInfo = cpuInfo
            self.numCpuInfo = numCpuInfo
            self.previousCPUInfo = hostCPULoadInfo() ?? host_cpu_load_info()
        }
    }
    
    private func readCPU() {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCpuInfo)
        if result == KERN_SUCCESS {
            var perCore: [Double] = []
            
            for i in 0..<Int(numCPUs) {
                var inUse: Int32 = 0
                var total: Int32 = 0
                
                if let prevCpuInfo = prevCpuInfo {
                    inUse = cpuInfo?[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_USER)] ?? 0
                        - prevCpuInfo[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_USER)]
                    inUse += cpuInfo?[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_SYSTEM)] ?? 0
                        - prevCpuInfo[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_SYSTEM)]
                    inUse += cpuInfo?[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_NICE)] ?? 0
                        - prevCpuInfo[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_NICE)]
                    total = inUse + ((cpuInfo?[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_IDLE)] ?? 0) - (prevCpuInfo[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_IDLE)]))
                } else {
                    inUse = (cpuInfo?[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_USER)] ?? 0)
                        + (cpuInfo?[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_SYSTEM)] ?? 0)
                        + (cpuInfo?[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_NICE)] ?? 0)
                    total = inUse + (cpuInfo?[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_IDLE)] ?? 0)
                }
                
                if total != 0 {
                    perCore.append(Double(inUse) / Double(total))
                }
            }
            
            if let prevCpuInfo = prevCpuInfo {
                let size = MemoryLayout<integer_t>.stride * Int(numPrevCpuInfo)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevCpuInfo), vm_size_t(size))
            }
            
            self.prevCpuInfo = cpuInfo
            self.numPrevCpuInfo = numCpuInfo
            
            var newStats = CPUStats()
            newStats.perCore = perCore
            newStats.total = perCore.isEmpty ? 0 : perCore.reduce(0, +) / Double(perCore.count)
            
            if let currentInfo = hostCPULoadInfo() {
                let userDiff = Double(currentInfo.cpu_ticks.0 &- previousCPUInfo.cpu_ticks.0)
                let sysDiff = Double(currentInfo.cpu_ticks.1 &- previousCPUInfo.cpu_ticks.1)
                let idleDiff = Double(currentInfo.cpu_ticks.2 &- previousCPUInfo.cpu_ticks.2)
                let niceDiff = Double(currentInfo.cpu_ticks.3 &- previousCPUInfo.cpu_ticks.3)
                let totalTicks = sysDiff + userDiff + niceDiff + idleDiff
                
                if totalTicks > 0 {
                    newStats.system = sysDiff / totalTicks
                    newStats.user = userDiff / totalTicks
                    newStats.idle = idleDiff / totalTicks
                    newStats.total = newStats.system + newStats.user
                }
                previousCPUInfo = currentInfo
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.cpu = newStats
            }
        }
    }
    
    private func hostCPULoadInfo() -> host_cpu_load_info? {
        let count = MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        var size = mach_msg_type_number_t(count)
        var cpuLoadInfo = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: count) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        return result == KERN_SUCCESS ? cpuLoadInfo : nil
    }
    
    private func readMemory() {
        var stats = vm_statistics64()
        var count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            var hostBasicInfo = host_basic_info()
            var count = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
            _ = withUnsafeMutablePointer(to: &hostBasicInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
                }
            }
            
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(stats.active_count) * pageSize
            let inactive = UInt64(stats.inactive_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize
            let total = hostBasicInfo.max_mem
            let used = active + inactive + wired + compressed
            let free = total > used ? total - used : 0
            
            var newStats = MemoryStats()
            newStats.total = total
            newStats.used = used
            newStats.free = free
            newStats.active = active
            newStats.inactive = inactive
            newStats.wired = wired
            newStats.compressed = compressed
            
            DispatchQueue.main.async { [weak self] in
                self?.memory = newStats
            }
        }
    }
    
    private func readDisk() {
        let count = Darwin.getfsstat(nil, 0, MNT_NOWAIT)
        if count > 0 {
            var disks = [Darwin.statfs](repeating: Darwin.statfs(), count: Int(count))
            let result = Darwin.getfsstat(&disks, Int32(MemoryLayout<Darwin.statfs>.size * Int(count)), MNT_NOWAIT)
            if result > 0 {
                var total: Int64 = 0
                var used: Int64 = 0
                
                for i in 0..<Int(result) {
                    let blockSize = Int64(disks[i].f_bsize)
                    total += Int64(disks[i].f_blocks) * blockSize
                    used += Int64(disks[i].f_blocks - disks[i].f_bavail) * blockSize
                }
                
                var newStats = DiskStats()
                newStats.total = total
                newStats.used = used
                newStats.free = total - used
                
                DispatchQueue.main.async { [weak self] in
                    self?.disk = newStats
                }
            }
        }
    }
    
    private func readNetwork() {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddr = interfaceAddresses else { return }
        
        defer { freeifaddrs(interfaceAddresses) }
        
        var primaryInterface = ""
        var totalUpload: Int64 = 0
        var totalDownload: Int64 = 0
        var isUp = false
        
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = pointer {
            let name = String(cString: addr.pointee.ifa_name)
            if name.hasPrefix("en") || name.hasPrefix("lo") {
                if name.hasPrefix("en") && primaryInterface.isEmpty {
                    primaryInterface = name
                }
                
                if let data = addr.pointee.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    totalUpload += Int64(networkData.ifi_obytes)
                    totalDownload += Int64(networkData.ifi_ibytes)
                }
                
                if name == primaryInterface {
                    isUp = (addr.pointee.ifa_flags & UInt32(IFF_UP)) != 0
                }
            }
            pointer = addr.pointee.ifa_next
        }
        
        let now = Date()
        var uploadRate: Int64 = 0
        var downloadRate: Int64 = 0
        
        if let prev = previousNetwork, let prevTime = previousSampleTime {
            let interval = now.timeIntervalSince(prevTime)
            if interval > 0 {
                uploadRate = max(0, totalUpload - prev.upload)
                downloadRate = max(0, totalDownload - prev.download)
            }
        }
        
        previousNetwork = (totalUpload, totalDownload)
        previousSampleTime = now
        
        var newStats = NetworkStats()
        newStats.upload = uploadRate
        newStats.download = downloadRate
        newStats.interfaceName = primaryInterface
        newStats.status = isUp
        
        DispatchQueue.main.async { [weak self] in
            self?.network = newStats
        }
    }
    
    private func readBattery() {
        let psInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let psList = IOPSCopyPowerSourcesList(psInfo).takeRetainedValue() as [CFTypeRef]
        
        guard let ps = psList.first,
              let desc = IOPSGetPowerSourceDescription(psInfo, ps).takeUnretainedValue() as? [String: Any] else {
            return
        }
        
        var newStats = BatteryStats()
        
        let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        newStats.level = maxCapacity > 0 ? Double(currentCapacity) / Double(maxCapacity) : 0
        
        let powerSource = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        newStats.isPluggedIn = powerSource != "Battery Power"
        newStats.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        
        if let time = desc[kIOPSTimeToEmptyKey] as? Int, time > 0 {
            newStats.timeRemaining = time
        } else if let time = desc[kIOPSTimeToFullChargeKey] as? Int, time > 0 {
            newStats.timeRemaining = time
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.battery = newStats
        }
    }
}
