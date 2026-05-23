import Foundation

public final class ThermalStatsProvider: SystemMetricProvider, @unchecked Sendable {
    public init() {}

    public func collect(previousSnapshot: SystemMonitorSnapshot? = nil) async -> ThermalStats? {
        // Phase 2 interface hook: most Mac models do not expose safe, non-privileged
        // thermal sensor access through a stable public API. We keep this provider
        // as a nil-returning entry point so the UI and analyzer can light up as soon
        // as a real source is wired in.
        nil
    }
}
