import Foundation

public final class PowerStatsProvider: SystemMetricProvider, @unchecked Sendable {
    public init() {}

    public func collect(previousSnapshot: SystemMonitorSnapshot? = nil) async -> PowerStats? {
        // Phase 2 hook for system power consumption. A stable, non-privileged
        // public API is not available here yet, so we keep the endpoint in place
        // and return nil until a safe source is chosen.
        nil
    }
}
