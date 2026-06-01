import Foundation

public actor InjectionMetrics {
    public static let shared = InjectionMetrics()
    private var records: [InjectionRecord] = []

    public struct InjectionRecord: Sendable {
        public let method: String
        public let success: Bool
        public let timestamp: Date
    }

    public func record(method: String, success: Bool) {
        records.append(InjectionRecord(method: method, success: success, timestamp: Date()))
        if records.count > 1000 { records.removeFirst(500) }
    }

    public func getStats() -> [String: (attempts: Int, successes: Int)] {
        var stats: [String: (attempts: Int, successes: Int)] = [:]
        for record in records {
            var entry = stats[record.method] ?? (0, 0)
            entry.attempts += 1
            if record.success { entry.successes += 1 }
            stats[record.method] = entry
        }
        return stats
    }
}
