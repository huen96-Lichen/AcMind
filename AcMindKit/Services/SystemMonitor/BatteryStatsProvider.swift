import Foundation
import IOKit.ps

public final class BatteryStatsProvider: SystemMetricProvider, @unchecked Sendable {
    public init() {}

    public func collect(previousSnapshot: SystemMonitorSnapshot? = nil) async -> BatteryStats? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }

        guard let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
              let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
              maxCapacity > 0 else {
            return nil
        }

        let percentage = Double(currentCapacity) / Double(maxCapacity) * 100.0
        let isCharging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false
        let isPluggedIn = (description[kIOPSPowerSourceStateKey as String] as? String) == kIOPSACPowerValue

        let timeRemainingMinutes: Int? = {
            if let minutes = description[kIOPSTimeToEmptyKey as String] as? Int, minutes >= 0 {
                return minutes
            }
            return nil
        }()

        return BatteryStats(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            timeRemainingMinutes: timeRemainingMinutes
        )
    }
}
