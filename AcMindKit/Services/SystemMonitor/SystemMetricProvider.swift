import Foundation

public protocol SystemMetricProvider {
    associatedtype Metric

    func collect(previousSnapshot: SystemMonitorSnapshot?) async -> Metric
}
