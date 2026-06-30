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
        guard permissions.isEmpty == false else { return "无权限项" }

        let authorizedCount = permissions.filter { permissionStateLabel(for: $0) == "已授权" }.count
        let unknownCount = permissions.filter { permissionStateLabel(for: $0) == "未知" }.count
        let unavailableCount = permissions.filter { permissionStateLabel(for: $0) == "不可用" }.count

        return "已授权 \(authorizedCount) · 未知 \(unknownCount) · 不可用 \(unavailableCount)"
    }

    public static func networkInterfaceSummary(for interface: SystemNetworkInterfaceSnapshot?) -> String {
        guard let interface else { return "—" }

        if let ssid = interface.ssid, let name = interface.interfaceName {
            return "Wi‑Fi · \(ssid) · \(name)"
        }

        if let interfaceName = interface.interfaceName {
            return interface.isVPN ? "主接口 · \(interfaceName) · VPN" : "主接口 · \(interfaceName)"
        }

        return interface.name
    }

    public static func networkQualitySummary(for interface: SystemNetworkInterfaceSnapshot?) -> String {
        guard let interface else { return "—" }

        var parts: [String] = []
        if let rssi = interface.rssi {
            parts.append("RSSI \(rssi)")
        }
        if let transmitRateMbps = interface.transmitRateMbps {
            parts.append("\(String(format: "%.0f", transmitRateMbps)) Mbps")
        }
        if let channel = interface.channel {
            parts.append(channel)
        }

        if parts.isEmpty {
            if interface.ssid != nil {
                return "已连接"
            }
            if interface.interfaceName != nil {
                return interface.isVPN ? "VPN / scoped" : "活动接口"
            }
            return interface.unavailableReason ?? "—"
        }

        return parts.joined(separator: " · ")
    }

    public static func networkLinkQualityLabel(for interface: SystemNetworkInterfaceSnapshot?) -> String {
        guard let interface else { return "—" }

        let rssi = interface.rssi ?? -100
        switch rssi {
        case let value where value >= -55:
            return "信号优秀"
        case let value where value >= -67:
            return "信号良好"
        case let value where value >= -75:
            return "信号一般"
        case let value where value > -100:
            return "信号较弱"
        default:
            if interface.ssid != nil {
                return "已连接"
            }
            if interface.interfaceName != nil {
                return interface.isVPN ? "VPN 已启用" : "活动接口"
            }
            return interface.unavailableReason ?? "—"
        }
    }

    public static func networkLatencySummary(_ latencyMs: Double?) -> String {
        guard let latencyMs else { return "—" }
        return "\(String(format: "%.0f", latencyMs)) ms"
    }

    public static func networkLatencyQualityLabel(_ latencyMs: Double?) -> String {
        guard let latencyMs else { return "等待采样" }
        switch latencyMs {
        case ..<30:
            return "延迟优秀"
        case ..<80:
            return "延迟良好"
        case ..<150:
            return "延迟一般"
        default:
            return "延迟偏高"
        }
    }

    public static func networkDNSLookupSummary(_ lookupMs: Double?) -> String {
        guard let lookupMs else { return "—" }
        return "\(String(format: "%.0f", lookupMs)) ms"
    }

    public static func networkDNSLookupQualityLabel(_ lookupMs: Double?) -> String {
        guard let lookupMs else { return "等待采样" }
        switch lookupMs {
        case ..<20:
            return "DNS 很快"
        case ..<80:
            return "DNS 正常"
        case ..<150:
            return "DNS 偏慢"
        default:
            return "DNS 很慢"
        }
    }

    public static func networkServiceQualitySummary(
        latencyMs: Double?,
        dnsLookupMs: Double?,
        publicIPAddress: String?
    ) -> String {
        guard latencyMs != nil || dnsLookupMs != nil || publicIPAddress != nil else {
            return "等待采样"
        }

        if let latencyQualityScore = latencyScore(for: latencyMs),
           let dnsQualityScore = latencyScore(for: dnsLookupMs) {
            switch max(latencyQualityScore, dnsQualityScore) {
            case 0:
                return "连接优秀"
            case 1:
                return "连接良好"
            case 2:
                return "连接一般"
            default:
                return "连接偏慢"
            }
        }

        if publicIPAddress != nil {
            return "公网可达"
        }

        return "采样不足"
    }

    public static func networkServiceQualityDetail(
        latencyMs: Double?,
        dnsLookupMs: Double?,
        publicIPAddress: String?
    ) -> String {
        var parts: [String] = []
        if latencyMs != nil {
            parts.append("RTT \(networkLatencySummary(latencyMs))")
        }
        if dnsLookupMs != nil {
            parts.append("DNS \(networkDNSLookupSummary(dnsLookupMs))")
        }
        if let publicIPAddress {
            parts.append("公网 \(publicIPAddress)")
        }

        return parts.isEmpty ? "等待采样" : parts.joined(separator: " · ")
    }

    public static func diskIOStateLabel(
        readMBps: Double?,
        writeMBps: Double?,
        unavailableReasons: [SystemStatusUnavailableReason]
    ) -> String {
        if unavailableReasons.contains(where: { $0.id == "disk-io-unavailable" }) {
            return "不可用"
        }

        if unavailableReasons.contains(where: { $0.id == "disk-io-warmup" }) {
            return "等待采样"
        }

        if readMBps != nil || writeMBps != nil {
            return "I/O 已采样"
        }

        return "已采样"
    }

    public static func diskIOStateDetail(
        readMBps: Double?,
        writeMBps: Double?,
        unavailableReasons: [SystemStatusUnavailableReason]
    ) -> String {
        if let reason = unavailableReasons.first(where: { $0.id == "disk-io-unavailable" || $0.id == "disk-io-warmup" }) {
            return reason.message
        }

        if readMBps != nil || writeMBps != nil {
            return "读取/写入速率"
        }

        return "等待采样"
    }

    public static func diskIOProcessSummary(_ process: DiskIOProcessSnapshot?) -> String {
        guard let process else { return "—" }
        let total = process.readMBps + process.writeMBps
        return "\(process.name) · \(String(format: "%.1f MB/s", total))"
    }

    public static func diskIOProcessDetail(_ process: DiskIOProcessSnapshot?) -> String {
        guard let process else { return "—" }
        return "读 \(String(format: "%.1f", process.readMBps)) / 写 \(String(format: "%.1f", process.writeMBps)) MB/s"
    }

    public static func diskIODeviceSummary(_ device: DiskIODeviceSnapshot?) -> String {
        guard let device else { return "—" }
        return "\(device.name) · \(String(format: "%.1f MB/s", device.readMBps + device.writeMBps))"
    }

    public static func diskIODeviceDetail(_ device: DiskIODeviceSnapshot?) -> String {
        guard let device else { return "—" }
        return "读 \(String(format: "%.1f", device.readMBps)) / 写 \(String(format: "%.1f", device.writeMBps)) MB/s"
    }

    public static func diskVolumeSummary(_ volume: DiskVolumeSnapshot?) -> String {
        guard let volume else { return "—" }
        let percent = volume.totalGB > 0 ? (volume.usedGB / volume.totalGB) * 100 : 0
        let currentTag = volume.isCurrent ? "当前" : nil
        if let currentTag {
            return "\(volume.name) · \(String(format: "%.0f", percent))% · \(currentTag)"
        }
        return "\(volume.name) · \(String(format: "%.0f", percent))%"
    }

    public static func diskCurrentVolumeSummary(_ volume: DiskVolumeSnapshot?) -> String {
        guard let volume else { return "—" }
        guard volume.isCurrent else {
            return diskVolumeSummary(volume)
        }
        let percent = volume.totalGB > 0 ? (volume.usedGB / volume.totalGB) * 100 : 0
        return "当前卷 · \(volume.name) · \(String(format: "%.0f", percent))%"
    }

    public static func diskCurrentVolumeDetail(_ volume: DiskVolumeSnapshot?) -> String {
        guard let volume else { return "—" }
        guard volume.isCurrent else {
            return diskVolumeDetail(volume)
        }
        return diskVolumeDetail(volume)
    }

    public static func diskVolumeDetail(_ volume: DiskVolumeSnapshot?) -> String {
        guard let volume else { return "—" }
        return "\(volume.mountPoint) · \(String(format: "%.1f GB / %.1f GB", volume.usedGB, volume.totalGB))"
    }

    public static func diskVolumeGroupLabel(_ volume: DiskVolumeSnapshot) -> String {
        if volume.isCurrent {
            return "当前卷"
        }
        if volume.isInternal {
            return "内部卷"
        }
        if volume.isRemovable {
            return "可移动卷"
        }
        return "其他卷"
    }

    public static func diskUsageSummary(
        mountPoint: String?,
        usedGB: Double?,
        totalGB: Double?
    ) -> String {
        let capacitySummary: String
        if let usedGB, let totalGB {
            capacitySummary = "\(formatGB(usedGB)) / \(formatGB(totalGB))"
        } else {
            capacitySummary = "—"
        }

        guard let mountPoint, mountPoint.isEmpty == false else {
            return capacitySummary
        }

        return "\(mountPoint) · \(capacitySummary)"
    }

    private static func latencyScore(for latencyMs: Double?) -> Int? {
        guard let latencyMs else { return nil }
        switch latencyMs {
        case ..<30:
            return 0
        case ..<80:
            return 1
        case ..<150:
            return 2
        default:
            return 3
        }
    }

    private static func formatGB(_ value: Double) -> String {
        String(format: "%.1f GB", value)
    }
}
