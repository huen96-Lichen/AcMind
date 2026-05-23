import Foundation

public final class StorageStatsProvider: SystemMetricProvider, @unchecked Sendable {
    public init() {}

    public func collect(previousSnapshot: SystemMonitorSnapshot? = nil) async -> StorageStats {
        let url = FileManager.default.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]

        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity else {
            return StorageStats(totalBytes: 0, usedBytes: 0, freeBytes: 0, usedPercent: 0)
        }

        let available: Int64
        if let directAvailable = values.volumeAvailableCapacity {
            available = Int64(directAvailable)
        } else if let importantAvailable = values.volumeAvailableCapacityForImportantUsage {
            available = Int64(importantAvailable)
        } else {
            available = 0
        }

        let totalBytes = UInt64(max(Int64(total), 0))
        let freeBytes = UInt64(max(available, 0))
        let usedBytes = totalBytes > freeBytes ? totalBytes - freeBytes : 0
        let usedPercent = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100.0 : 0

        return StorageStats(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            freeBytes: freeBytes,
            usedPercent: usedPercent
        )
    }
}
