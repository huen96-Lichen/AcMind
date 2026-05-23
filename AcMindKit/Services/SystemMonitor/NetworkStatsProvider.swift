import Foundation
import Darwin

public final class NetworkStatsProvider: SystemMetricProvider, @unchecked Sendable {
    private struct NetworkCounterSample {
        let timestamp: Date
        let bytesReceived: UInt64
        let bytesSent: UInt64
        let interfaceName: String?
    }

    private let lock = NSLock()
    private var lastSample: NetworkCounterSample?

    public init() {}

    public func collect(previousSnapshot: SystemMonitorSnapshot? = nil) async -> NetworkStats {
        let current = readCurrentCounters()
        let (downloadRate, uploadRate) = networkRates(for: current)

        return NetworkStats(
            downloadBytesPerSecond: downloadRate,
            uploadBytesPerSecond: uploadRate,
            activeInterfaceName: current.interfaceName
        )
    }

    private func networkRates(for current: NetworkCounterSample) -> (UInt64, UInt64) {
        lock.lock()
        defer { lock.unlock() }
        defer { lastSample = current }

        guard let lastSample else {
            return (0, 0)
        }

        let elapsed = current.timestamp.timeIntervalSince(lastSample.timestamp)
        guard elapsed > 0 else { return (0, 0) }

        let bytesReceived = current.bytesReceived >= lastSample.bytesReceived ? current.bytesReceived - lastSample.bytesReceived : 0
        let bytesSent = current.bytesSent >= lastSample.bytesSent ? current.bytesSent - lastSample.bytesSent : 0

        let download = UInt64(Double(bytesReceived) / elapsed)
        let upload = UInt64(Double(bytesSent) / elapsed)
        return (download, upload)
    }

    private func readCurrentCounters() -> NetworkCounterSample {
        var interfaceName: String?
        var bytesReceived: UInt64 = 0
        var bytesSent: UInt64 = 0

        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let head = ifaddrPointer else {
            return NetworkCounterSample(timestamp: Date(), bytesReceived: 0, bytesSent: 0, interfaceName: nil)
        }
        defer { freeifaddrs(ifaddrPointer) }

        var bestScore: UInt64 = 0
        var bestName: String?

        var pointer = head
        while true {
            let flags = UInt32(pointer.pointee.ifa_flags)
            guard (flags & UInt32(IFF_UP)) != 0, (flags & UInt32(IFF_LOOPBACK)) == 0 else {
                if let next = pointer.pointee.ifa_next {
                    pointer = next
                    continue
                }
                break
            }

            guard let dataPointer = pointer.pointee.ifa_data else {
                if let next = pointer.pointee.ifa_next {
                    pointer = next
                    continue
                }
                break
            }
            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee

            let name = String(cString: pointer.pointee.ifa_name)
            let received = UInt64(data.ifi_ibytes)
            let sent = UInt64(data.ifi_obytes)
            let score = received + sent

            bytesReceived += received
            bytesSent += sent

            if score > bestScore || bestName == nil {
                bestScore = score
                bestName = name
            }

            if let next = pointer.pointee.ifa_next {
                pointer = next
            } else {
                break
            }
        }

        interfaceName = bestName
        return NetworkCounterSample(
            timestamp: Date(),
            bytesReceived: bytesReceived,
            bytesSent: bytesSent,
            interfaceName: interfaceName
        )
    }
}
