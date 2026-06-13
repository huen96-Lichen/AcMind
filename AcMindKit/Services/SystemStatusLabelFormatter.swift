import Foundation

public enum SystemStatusLabelFormatter {
    public static func availabilityState(
        isAvailable: Bool,
        availableText: String = "正常",
        unavailableText: String = "不可用"
    ) -> String {
        isAvailable ? availableText : unavailableText
    }

    public static func healthState(
        isHealthy: Bool,
        healthyText: String = "正常",
        unhealthyText: String = "异常"
    ) -> String {
        isHealthy ? healthyText : unhealthyText
    }

    public static func thermalThrottleSummary(_ throttle: SystemThermalThrottleInfo?) -> String {
        guard let throttle, throttle.isAvailable else { return "不可用" }

        let parts = [
            throttle.speedLimit.map { "\($0)%" },
            throttle.schedulerLimit.map { "\($0)%" }
        ].compactMap { $0 }

        guard parts.isEmpty == false else { return "已采样" }
        return parts.joined(separator: " · ")
    }

    public static func thermalThrottleDetail(_ throttle: SystemThermalThrottleInfo?) -> String {
        guard let throttle else { return "—" }
        if throttle.isAvailable == false {
            return throttle.unavailableReason ?? "不可用"
        }

        if let cpus = throttle.availableCPUs {
            return cpus == 1 ? "1 CPU" : "\(cpus) CPU"
        }

        return throttle.source
    }

    public static func thermalThrottleStatusText(_ throttle: SystemThermalThrottleInfo?) -> String {
        guard let throttle else { return "采样中" }
        if throttle.isAvailable == false {
            return throttle.unavailableReason ?? "不可用"
        }
        return thermalThrottleSummary(throttle)
    }

    public static func permissionStateLabel(for permission: SystemPermissionSnapshot) -> String {
        guard permission.isAvailable else {
            return "不可用"
        }

        let normalizedValue = permission.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard normalizedValue.isEmpty == false else { return "未知" }

        if normalizedValue.contains("已授权") || normalizedValue.contains("允许") {
            return "已授权"
        }

        if normalizedValue.contains("已拒绝") || normalizedValue.contains("拒绝") {
            return "已拒绝"
        }

        if normalizedValue.contains("未确定") {
            return "未知"
        }

        if normalizedValue.contains("受限") {
            return "受限"
        }

        return normalizedValue
    }

    public static func permissionOverviewSummary(_ permissions: [SystemPermissionSnapshot]) -> String {
        guard permissions.isEmpty == false else { return "暂无权限项" }

        let authorizedCount = permissions.filter { permissionStateLabel(for: $0) == "已授权" }.count
        let unknownCount = permissions.filter { permissionStateLabel(for: $0) == "未知" }.count
        let unavailableCount = permissions.filter { permissionStateLabel(for: $0) == "不可用" }.count

        return "已授权 \(authorizedCount) · 未知 \(unknownCount) · 不可用 \(unavailableCount)"
    }
}
