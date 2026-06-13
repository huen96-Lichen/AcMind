import Foundation

public enum UsageBurnSeverity: String, Sendable, Codable, CaseIterable {
    case none
    case info
    case warning
    case critical

    public var displayName: String {
        switch self {
        case .none: return "正常"
        case .info: return "关注"
        case .warning: return "预警"
        case .critical: return "危险"
        }
    }
}

public struct UsageBurnWindowConfig: Sendable, Codable, Equatable {
    public var name: String
    public var duration: TimeInterval
    public var tokenLimit: Int

    public init(name: String, duration: TimeInterval, tokenLimit: Int) {
        self.name = name
        self.duration = duration
        self.tokenLimit = tokenLimit
    }
}

public struct UsageBurnWindowSnapshot: Sendable, Codable, Equatable {
    public var name: String
    public var duration: TimeInterval
    public var tokenLimit: Int
    public var tokenCount: Int
    public var usagePercent: Double
    public var elapsedPercent: Double
    public var burnRatio: Double

    public init(
        name: String,
        duration: TimeInterval,
        tokenLimit: Int,
        tokenCount: Int,
        usagePercent: Double,
        elapsedPercent: Double,
        burnRatio: Double
    ) {
        self.name = name
        self.duration = duration
        self.tokenLimit = tokenLimit
        self.tokenCount = tokenCount
        self.usagePercent = usagePercent
        self.elapsedPercent = elapsedPercent
        self.burnRatio = burnRatio
    }
}

public struct UsageBurnSnapshot: Sendable, Codable, Equatable {
    public var severity: UsageBurnSeverity
    public var windows: [UsageBurnWindowSnapshot]
    public var totalTokens: Int
    public var totalCostCNY: Double
    public var totalRequests: Int
    public var totalLatencyMs: Int
    public var averageLatencyMs: Int
    public var lastUpdated: Date?
    public var note: String

    public init(
        severity: UsageBurnSeverity,
        windows: [UsageBurnWindowSnapshot],
        totalTokens: Int,
        totalCostCNY: Double,
        totalRequests: Int,
        totalLatencyMs: Int,
        averageLatencyMs: Int,
        lastUpdated: Date?,
        note: String
    ) {
        self.severity = severity
        self.windows = windows
        self.totalTokens = totalTokens
        self.totalCostCNY = totalCostCNY
        self.totalRequests = totalRequests
        self.totalLatencyMs = totalLatencyMs
        self.averageLatencyMs = averageLatencyMs
        self.lastUpdated = lastUpdated
        self.note = note
    }

    public static let empty = UsageBurnSnapshot(
        severity: .none,
        windows: [],
        totalTokens: 0,
        totalCostCNY: 0,
        totalRequests: 0,
        totalLatencyMs: 0,
        averageLatencyMs: 0,
        lastUpdated: nil,
        note: "暂无模型调用"
    )
}

public actor UsageBurnMonitor {
    public static let shared = UsageBurnMonitor()

    private struct Sample: Sendable {
        let usage: ModelUsage
    }

    private let windows: [UsageBurnWindowConfig]
    private let infoThreshold: Double
    private let warningThreshold: Double
    private let criticalThreshold: Double
    private let debounceSamples: Int
    private var samples: [Sample] = []
    private var lastEmittedSeverity: UsageBurnSeverity = .none
    private var pendingSeverity: UsageBurnSeverity = .none
    private var pendingCount: Int = 0
    private var lastUpdated: Date?

    public init(
        windows: [UsageBurnWindowConfig] = [
            UsageBurnWindowConfig(name: "5h", duration: 5 * 60 * 60, tokenLimit: 60_000),
            UsageBurnWindowConfig(name: "7d", duration: 7 * 24 * 60 * 60, tokenLimit: 400_000)
        ],
        infoThreshold: Double = 1.3,
        warningThreshold: Double = 2.0,
        criticalThreshold: Double = 3.0,
        debounceSamples: Int = 2
    ) {
        self.windows = windows
        self.infoThreshold = infoThreshold
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
        self.debounceSamples = max(debounceSamples, 1)
    }

    public func record(_ usage: ModelUsage) {
        let now = Date()
        samples.append(Sample(usage: usage))
        lastUpdated = usage.timestamp
        prune(now: now)
        updateDebounce(with: evaluate(at: now).severity)
    }

    public func snapshot(now: Date = Date()) -> UsageBurnSnapshot {
        prune(now: now)
        let evaluated = evaluate(at: now)
        let effectiveSeverity = effectiveSeverity(for: evaluated.severity)

        return UsageBurnSnapshot(
            severity: effectiveSeverity,
            windows: evaluated.windows,
            totalTokens: evaluated.totalTokens,
            totalCostCNY: evaluated.totalCostCNY,
            totalRequests: evaluated.totalRequests,
            totalLatencyMs: evaluated.totalLatencyMs,
            averageLatencyMs: evaluated.averageLatencyMs,
            lastUpdated: lastUpdated,
            note: evaluated.note
        )
    }

    public func reset() {
        samples.removeAll()
        lastUpdated = nil
        lastEmittedSeverity = .none
        pendingSeverity = .none
        pendingCount = 0
    }

    private func prune(now: Date) {
        guard let maxWindow = windows.map(\.duration).max() else { return }
        let cutoff = now.addingTimeInterval(-maxWindow)
        samples.removeAll { $0.usage.timestamp < cutoff }
    }

    private func evaluate(at now: Date) -> (severity: UsageBurnSeverity, windows: [UsageBurnWindowSnapshot], totalTokens: Int, totalCostCNY: Double, totalRequests: Int, totalLatencyMs: Int, averageLatencyMs: Int, note: String) {
        guard samples.isEmpty == false else {
            return (.none, [], 0, 0, 0, 0, 0, "暂无模型调用")
        }

        let usages = samples.map(\.usage)
        let totalTokens = usages.reduce(0) { $0 + $1.totalTokens }
        let totalCostCNY = usages.reduce(0) { $0 + $1.costCNY }
        let totalRequests = usages.count
        let totalLatencyMs = usages.reduce(0) { $0 + max($1.latencyMs, 0) }
        let averageLatencyMs = totalRequests > 0 ? Int(Double(totalLatencyMs) / Double(totalRequests)) : 0

        var snapshots: [UsageBurnWindowSnapshot] = []
        var candidateSeverity: UsageBurnSeverity = .none

        for window in windows {
            let windowStart = now.addingTimeInterval(-window.duration)
            let windowUsages = usages.filter { $0.timestamp >= windowStart }
            let windowTokens = windowUsages.reduce(0) { $0 + $1.totalTokens }
            let earliestTimestamp = windowUsages.map(\.timestamp).min() ?? now
            let elapsedSeconds = min(max(now.timeIntervalSince(earliestTimestamp), 0), window.duration)
            let usagePercent = window.tokenLimit > 0 ? Double(windowTokens) / Double(window.tokenLimit) : 0
            let elapsedPercent = window.duration > 0 ? elapsedSeconds / window.duration : 0
            let burnRatio = elapsedPercent > 0 ? usagePercent / elapsedPercent : 0

            snapshots.append(
                UsageBurnWindowSnapshot(
                    name: window.name,
                    duration: window.duration,
                    tokenLimit: window.tokenLimit,
                    tokenCount: windowTokens,
                    usagePercent: usagePercent,
                    elapsedPercent: elapsedPercent,
                    burnRatio: burnRatio
                )
            )

            let windowSeverity = severity(forBurnRatio: burnRatio)
            candidateSeverity = windowSeverity.rank > candidateSeverity.rank ? windowSeverity : candidateSeverity
        }

        let note: String
        switch candidateSeverity {
        case .none:
            note = "消耗处于正常速度"
        case .info:
            note = "消耗速度略快，建议留意"
        case .warning:
            note = "消耗速度偏快，可能提前超出预算"
        case .critical:
            note = "消耗速度过快，存在明显超预算风险"
        }

        return (candidateSeverity, snapshots, totalTokens, totalCostCNY, totalRequests, totalLatencyMs, averageLatencyMs, note)
    }

    private func severity(forBurnRatio ratio: Double) -> UsageBurnSeverity {
        if ratio >= criticalThreshold { return .critical }
        if ratio >= warningThreshold { return .warning }
        if ratio >= infoThreshold { return .info }
        return .none
    }

    private func updateDebounce(with severity: UsageBurnSeverity) {
        if severity == pendingSeverity {
            pendingCount += 1
        } else {
            pendingSeverity = severity
            pendingCount = 1
        }

        if pendingCount >= debounceSamples || severity.rank <= lastEmittedSeverity.rank {
            lastEmittedSeverity = severity
        }
    }

    private func effectiveSeverity(for severity: UsageBurnSeverity) -> UsageBurnSeverity {
        guard severity.rank > lastEmittedSeverity.rank else {
            lastEmittedSeverity = severity
            pendingSeverity = severity
            pendingCount = max(pendingCount, 1)
            return severity
        }

        if pendingSeverity == severity, samples.count >= debounceSamples {
            lastEmittedSeverity = severity
            return severity
        }

        return lastEmittedSeverity
    }
}

private extension UsageBurnSeverity {
    var rank: Int {
        switch self {
        case .none: return 0
        case .info: return 1
        case .warning: return 2
        case .critical: return 3
        }
    }
}
