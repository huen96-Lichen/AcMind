import Foundation
import Darwin

public final class MemoryStatsProvider: SystemMetricProvider, @unchecked Sendable {
    public init() {}

    public func collect(previousSnapshot: SystemMonitorSnapshot? = nil) async -> MemoryStats {
        let totalBytes = UInt64(ProcessInfo.processInfo.physicalMemory)
        var pageSizeValue: vm_size_t = 0
        let pageSizeResult = host_page_size(mach_host_self(), &pageSizeValue)
        let pageSize = pageSizeResult == KERN_SUCCESS ? UInt64(pageSizeValue) : 4096
        let info = readVMStatistics()

        let freePages = UInt64(info.free_count)
        let activePages = UInt64(info.active_count)
        let inactivePages = UInt64(info.inactive_count)
        let wiredPages = UInt64(info.wire_count)
        let speculativePages = UInt64(info.speculative_count)
        let compressedPages = UInt64(info.compressor_page_count)

        let usedPages = activePages + wiredPages + compressedPages
        let availablePages = freePages + inactivePages + speculativePages
        let usedBytes = Swift.min(totalBytes, usedPages * pageSize)
        let freeBytes = Swift.min(totalBytes.saturatingSubtract(usedBytes), availablePages * pageSize)

        let usedPercent = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100.0 : 0
        let pressureLevel = determinePressureLevel(usedPercent: usedPercent, swapBytes: nil)

        return MemoryStats(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            freeBytes: freeBytes,
            pressureLevel: pressureLevel,
            swapUsedBytes: nil
        )
    }

    private func readVMStatistics() -> vm_statistics64_data_t {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var info = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return vm_statistics64_data_t()
        }

        return info
    }

    private func determinePressureLevel(usedPercent: Double, swapBytes: UInt64?) -> MemoryPressureLevel {
        let swapInUseGB = Double(swapBytes ?? 0) / 1_073_741_824.0

        if usedPercent >= 85 || swapInUseGB >= 2.0 {
            return .high
        }

        if usedPercent >= 70 || swapInUseGB >= 0.5 {
            return .moderate
        }

        return .low
    }
}

private extension UInt64 {
    func saturatingSubtract(_ other: UInt64) -> UInt64 {
        if self < other { return 0 }
        return self - other
    }
}
