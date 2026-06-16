import XCTest
@testable import AcMindKit

final class SystemStatusLabelFormatterTests: XCTestCase {
    func testAvailabilityStateUsesSharedCopy() {
        XCTAssertEqual(SystemStatusLabelFormatter.availabilityState(isAvailable: true), "正常")
        XCTAssertEqual(SystemStatusLabelFormatter.availabilityState(isAvailable: false), "不可用")
        XCTAssertEqual(
            SystemStatusLabelFormatter.availabilityState(
                isAvailable: false,
                availableText: "在线",
                unavailableText: "离线"
            ),
            "离线"
        )
    }

    func testHealthStateUsesSharedCopy() {
        XCTAssertEqual(SystemStatusLabelFormatter.healthState(isHealthy: true), "正常")
        XCTAssertEqual(SystemStatusLabelFormatter.healthState(isHealthy: false), "异常")
        XCTAssertEqual(
            SystemStatusLabelFormatter.healthState(
                isHealthy: false,
                healthyText: "良好",
                unhealthyText: "不佳"
            ),
            "不佳"
        )
    }

    func testPermissionStateLabelNormalizesCommonStates() {
        let authorized = SystemPermissionSnapshot(
            id: "mic",
            name: "麦克风",
            category: "permission",
            value: "已授权",
            source: "PermissionManager",
            isAvailable: true,
            unavailableReason: nil
        )
        let unknown = SystemPermissionSnapshot(
            id: "calendar",
            name: "日历",
            category: "permission",
            value: nil,
            source: "EKEventStore",
            isAvailable: true,
            unavailableReason: nil
        )
        let unavailable = SystemPermissionSnapshot(
            id: "screen",
            name: "屏幕录制",
            category: "permission",
            value: nil,
            source: "PermissionManager",
            isAvailable: false,
            unavailableReason: "未启用"
        )

        XCTAssertEqual(SystemStatusLabelFormatter.permissionStateLabel(for: authorized), "已授权")
        XCTAssertEqual(SystemStatusLabelFormatter.permissionStateLabel(for: unknown), "未知")
        XCTAssertEqual(SystemStatusLabelFormatter.permissionStateLabel(for: unavailable), "不可用")
    }

    func testPermissionOverviewSummaryBreaksOutStates() {
        let permissions = [
            SystemPermissionSnapshot(
                id: "mic",
                name: "麦克风",
                category: "permission",
                value: "已授权",
                source: "PermissionManager",
                isAvailable: true,
                unavailableReason: nil
            ),
            SystemPermissionSnapshot(
                id: "calendar",
                name: "日历",
                category: "permission",
                value: nil,
                source: "EKEventStore",
                isAvailable: true,
                unavailableReason: nil
            ),
            SystemPermissionSnapshot(
                id: "screen",
                name: "屏幕录制",
                category: "permission",
                value: nil,
                source: "PermissionManager",
                isAvailable: false,
                unavailableReason: "未启用"
            )
        ]

        XCTAssertEqual(
            SystemStatusLabelFormatter.permissionOverviewSummary(permissions),
            "已授权 1 · 未知 1 · 不可用 1"
        )
    }

    func testThermalThrottleStatusTextUsesQuantifiedSummaryWhenAvailable() {
        let throttle = SystemThermalThrottleInfo(
            speedLimit: 92,
            schedulerLimit: 71,
            availableCPUs: 8,
            source: "pmset -g therm",
            isAvailable: true,
            unavailableReason: nil
        )

        XCTAssertEqual(SystemStatusLabelFormatter.thermalThrottleStatusText(throttle), "92% · 71%")
    }

    func testThermalThrottleStatusTextFallsBackForMissingOrUnavailableData() {
        let unavailable = SystemThermalThrottleInfo(
            source: "pmset -g therm",
            isAvailable: false,
            unavailableReason: "pmset failed"
        )

        XCTAssertEqual(SystemStatusLabelFormatter.thermalThrottleStatusText(nil), "采样中")
        XCTAssertEqual(SystemStatusLabelFormatter.thermalThrottleStatusText(unavailable), "pmset failed")
    }

    func testNetworkInterfaceSummaryPrefersSSIDAndInterfaceNameWhenAvailable() {
        let interface = SystemNetworkInterfaceSnapshot(
            id: "wifi-en0",
            name: "Wi-Fi",
            category: "network",
            value: nil,
            unit: "",
            source: "CoreWLAN",
            isAvailable: true,
            unavailableReason: nil,
            interfaceName: "en0",
            ssid: "AcMind",
            bssid: nil,
            rssi: -48,
            transmitRateMbps: 433,
            channel: "5 GHz",
            isVPN: false
        )

        XCTAssertEqual(
            SystemStatusLabelFormatter.networkInterfaceSummary(for: interface),
            "Wi‑Fi · AcMind · en0"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkQualitySummary(for: interface),
            "RSSI -48 · 433 Mbps · 5 GHz"
        )
    }

    func testNetworkInterfaceSummaryFallsBackToVPNAndUnavailableDescriptions() {
        let vpnInterface = SystemNetworkInterfaceSnapshot(
            id: "primary-utun3",
            name: "主接口",
            category: "network",
            value: nil,
            unit: "",
            source: "SCDynamicStoreCopyValue",
            isAvailable: true,
            unavailableReason: nil,
            interfaceName: "utun3",
            ssid: nil,
            bssid: nil,
            rssi: nil,
            transmitRateMbps: nil,
            channel: nil,
            isVPN: true
        )
        let unavailableInterface = SystemNetworkInterfaceSnapshot(
            id: "primary-interface-unavailable",
            name: "主接口",
            category: "network",
            value: nil,
            unit: "",
            source: "SCDynamicStoreCopyValue",
            isAvailable: false,
            unavailableReason: "无法读取主接口",
            interfaceName: nil,
            ssid: nil,
            bssid: nil,
            rssi: nil,
            transmitRateMbps: nil,
            channel: nil,
            isVPN: false
        )

        XCTAssertEqual(SystemStatusLabelFormatter.networkInterfaceSummary(for: vpnInterface), "主接口 · utun3 · VPN")
        XCTAssertEqual(SystemStatusLabelFormatter.networkQualitySummary(for: vpnInterface), "VPN / scoped")
        XCTAssertEqual(SystemStatusLabelFormatter.networkInterfaceSummary(for: unavailableInterface), "主接口")
        XCTAssertEqual(SystemStatusLabelFormatter.networkQualitySummary(for: unavailableInterface), "无法读取主接口")
    }

    func testNetworkLinkQualityLabelUsesRSSIThresholds() {
        let excellent = makeWiFiInterface(rssi: -48)
        let good = makeWiFiInterface(rssi: -60)
        let fair = makeWiFiInterface(rssi: -72)
        let weak = makeWiFiInterface(rssi: -88)

        XCTAssertEqual(SystemStatusLabelFormatter.networkLinkQualityLabel(for: excellent), "信号优秀")
        XCTAssertEqual(SystemStatusLabelFormatter.networkLinkQualityLabel(for: good), "信号良好")
        XCTAssertEqual(SystemStatusLabelFormatter.networkLinkQualityLabel(for: fair), "信号一般")
        XCTAssertEqual(SystemStatusLabelFormatter.networkLinkQualityLabel(for: weak), "信号较弱")
    }

    func testWifiDetailCombinesQualityLabelWithMetrics() {
        let interface = makeWiFiInterface(rssi: -57, transmitRate: 390, channel: "5 GHz")

        let quality = SystemStatusLabelFormatter.networkLinkQualityLabel(for: interface)
        let metrics = SystemStatusLabelFormatter.networkQualitySummary(for: interface)

        XCTAssertEqual(quality, "信号良好")
        XCTAssertEqual(metrics, "RSSI -57 · 390 Mbps · 5 GHz")
    }

    func testNetworkLatencySummariesUseReadableThresholds() {
        XCTAssertEqual(SystemStatusLabelFormatter.networkLatencySummary(18.2), "18 ms")
        XCTAssertEqual(SystemStatusLabelFormatter.networkLatencyQualityLabel(18.2), "延迟优秀")
        XCTAssertEqual(SystemStatusLabelFormatter.networkLatencyQualityLabel(52.0), "延迟良好")
        XCTAssertEqual(SystemStatusLabelFormatter.networkLatencyQualityLabel(110.0), "延迟一般")
        XCTAssertEqual(SystemStatusLabelFormatter.networkLatencyQualityLabel(220.0), "延迟偏高")
        XCTAssertEqual(SystemStatusLabelFormatter.networkLatencyQualityLabel(nil), "等待采样")
    }

    func testNetworkDNSSummariesUseReadableThresholds() {
        XCTAssertEqual(SystemStatusLabelFormatter.networkDNSLookupSummary(14.0), "14 ms")
        XCTAssertEqual(SystemStatusLabelFormatter.networkDNSLookupQualityLabel(14.0), "DNS 很快")
        XCTAssertEqual(SystemStatusLabelFormatter.networkDNSLookupQualityLabel(41.0), "DNS 正常")
        XCTAssertEqual(SystemStatusLabelFormatter.networkDNSLookupQualityLabel(100.0), "DNS 偏慢")
        XCTAssertEqual(SystemStatusLabelFormatter.networkDNSLookupQualityLabel(190.0), "DNS 很慢")
        XCTAssertEqual(SystemStatusLabelFormatter.networkDNSLookupQualityLabel(nil), "等待采样")
    }

    func testNetworkServiceQualitySummariesCombineLatencyDNSAndPublicIP() {
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualitySummary(
                latencyMs: 18,
                dnsLookupMs: 12,
                publicIPAddress: "203.0.113.7"
            ),
            "连接优秀"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualitySummary(
                latencyMs: 55,
                dnsLookupMs: 70,
                publicIPAddress: "203.0.113.7"
            ),
            "连接良好"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualitySummary(
                latencyMs: 120,
                dnsLookupMs: 110,
                publicIPAddress: "203.0.113.7"
            ),
            "连接一般"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualitySummary(
                latencyMs: 240,
                dnsLookupMs: 180,
                publicIPAddress: "203.0.113.7"
            ),
            "连接偏慢"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualitySummary(
                latencyMs: nil,
                dnsLookupMs: 12,
                publicIPAddress: "203.0.113.7"
            ),
            "公网可达"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualitySummary(
                latencyMs: 18,
                dnsLookupMs: nil,
                publicIPAddress: "203.0.113.7"
            ),
            "公网可达"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualitySummary(
                latencyMs: nil,
                dnsLookupMs: nil,
                publicIPAddress: "203.0.113.7"
            ),
            "公网可达"
        )
    }

    func testNetworkServiceQualityDetailCombinesAvailableSignals() {
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualityDetail(
                latencyMs: 18,
                dnsLookupMs: 12,
                publicIPAddress: "203.0.113.7"
            ),
            "RTT 18 ms · DNS 12 ms · 公网 203.0.113.7"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualityDetail(
                latencyMs: nil,
                dnsLookupMs: nil,
                publicIPAddress: "203.0.113.7"
            ),
            "公网 203.0.113.7"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.networkServiceQualityDetail(
                latencyMs: nil,
                dnsLookupMs: nil,
                publicIPAddress: nil
            ),
            "等待采样"
        )
    }

    func testDiskIOStateLabelsUseWarmupAndUnavailableReasons() {
        let warmupReason = SystemStatusUnavailableReason(
            id: "disk-io-warmup",
            category: "disk",
            message: "磁盘 I/O 等待基线",
            detail: "first sample requires a previous reading"
        )
        let unavailableReason = SystemStatusUnavailableReason(
            id: "disk-io-unavailable",
            category: "disk",
            message: "磁盘 I/O 读取不可用",
            detail: "iostat failed"
        )

        XCTAssertEqual(
            SystemStatusLabelFormatter.diskIOStateLabel(
                readMBps: nil,
                writeMBps: nil,
                unavailableReasons: [warmupReason]
            ),
            "等待采样"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskIOStateDetail(
                readMBps: nil,
                writeMBps: nil,
                unavailableReasons: [warmupReason]
            ),
            "磁盘 I/O 等待基线"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskIOStateLabel(
                readMBps: nil,
                writeMBps: nil,
                unavailableReasons: [unavailableReason]
            ),
            "不可用"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskIOStateDetail(
                readMBps: nil,
                writeMBps: nil,
                unavailableReasons: [unavailableReason]
            ),
            "磁盘 I/O 读取不可用"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskIOStateLabel(
                readMBps: 1.4,
                writeMBps: 0.8,
                unavailableReasons: []
            ),
            "I/O 已采样"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskIOStateDetail(
                readMBps: 1.4,
                writeMBps: 0.8,
                unavailableReasons: []
            ),
            "读取/写入速率"
        )
    }

    func testDiskUsageSummaryIncludesMountPointWhenAvailable() {
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskUsageSummary(
                mountPoint: "/",
                usedGB: 218.4,
                totalGB: 494.4
            ),
            "/ · 218.4 GB / 494.4 GB"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskUsageSummary(
                mountPoint: nil,
                usedGB: 218.4,
                totalGB: 494.4
            ),
            "218.4 GB / 494.4 GB"
        )
    }

    func testDiskIOProcessSummariesUseReadableLabels() {
        let process = DiskIOProcessSnapshot(pid: 101, name: "alpha", readMBps: 2.0, writeMBps: 0.5)

        XCTAssertEqual(SystemStatusLabelFormatter.diskIOProcessSummary(process), "alpha · 2.5 MB/s")
        XCTAssertEqual(SystemStatusLabelFormatter.diskIOProcessDetail(process), "读 2.0 / 写 0.5 MB/s")
        XCTAssertEqual(SystemStatusLabelFormatter.diskIOProcessSummary(nil), "—")
        XCTAssertEqual(SystemStatusLabelFormatter.diskIOProcessDetail(nil), "—")
    }

    func testDiskIODeviceSummariesUseReadableLabels() {
        let device = DiskIODeviceSnapshot(name: "disk1", readMBps: 2.5, writeMBps: 1.5)

        XCTAssertEqual(SystemStatusLabelFormatter.diskIODeviceSummary(device), "disk1 · 4.0 MB/s")
        XCTAssertEqual(SystemStatusLabelFormatter.diskIODeviceDetail(device), "读 2.5 / 写 1.5 MB/s")
        XCTAssertEqual(SystemStatusLabelFormatter.diskIODeviceSummary(nil), "—")
        XCTAssertEqual(SystemStatusLabelFormatter.diskIODeviceDetail(nil), "—")
    }

    func testDiskVolumeSummariesUseReadableLabels() {
        let volume = DiskVolumeSnapshot(
            mountPoint: "/Volumes/White Atlas",
            name: "White Atlas",
            usedGB: 520.0,
            totalGB: 1000.0,
            isRemovable: false,
            isInternal: false,
            isCurrent: false
        )
        let currentVolume = DiskVolumeSnapshot(
            mountPoint: "/",
            name: "Macintosh HD",
            usedGB: 520.0,
            totalGB: 1000.0,
            isRemovable: false,
            isInternal: true,
            isCurrent: true
        )
        let removableVolume = DiskVolumeSnapshot(
            mountPoint: "/Volumes/USB",
            name: "USB",
            usedGB: 32.0,
            totalGB: 64.0,
            isRemovable: true,
            isInternal: false,
            isCurrent: false
        )
        let internalVolume = DiskVolumeSnapshot(
            mountPoint: "/Volumes/Data",
            name: "Data",
            usedGB: 120.0,
            totalGB: 256.0,
            isRemovable: false,
            isInternal: true,
            isCurrent: false
        )

        XCTAssertEqual(SystemStatusLabelFormatter.diskVolumeSummary(volume), "White Atlas · 52%")
        XCTAssertEqual(SystemStatusLabelFormatter.diskVolumeSummary(currentVolume), "Macintosh HD · 52% · 当前")
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskCurrentVolumeSummary(currentVolume),
            "当前卷 · Macintosh HD · 52%"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskCurrentVolumeDetail(currentVolume),
            "/ · 520.0 GB / 1000.0 GB"
        )
        XCTAssertEqual(
            SystemStatusLabelFormatter.diskVolumeDetail(volume),
            "/Volumes/White Atlas · 520.0 GB / 1000.0 GB"
        )
        XCTAssertEqual(SystemStatusLabelFormatter.diskVolumeSummary(nil), "—")
        XCTAssertEqual(SystemStatusLabelFormatter.diskVolumeDetail(nil), "—")
        XCTAssertEqual(SystemStatusLabelFormatter.diskVolumeGroupLabel(volume), "其他卷")
        XCTAssertEqual(SystemStatusLabelFormatter.diskVolumeGroupLabel(internalVolume), "内部卷")
        XCTAssertEqual(SystemStatusLabelFormatter.diskVolumeGroupLabel(removableVolume), "可移动卷")
        XCTAssertEqual(SystemStatusLabelFormatter.diskVolumeGroupLabel(currentVolume), "当前卷")
    }

    private func makeWiFiInterface(rssi: Int, transmitRate: Double? = 433, channel: String? = "5 GHz") -> SystemNetworkInterfaceSnapshot {
        SystemNetworkInterfaceSnapshot(
            id: "wifi-en0",
            name: "Wi‑Fi",
            category: "network",
            value: nil,
            unit: "",
            source: "CoreWLAN",
            isAvailable: true,
            unavailableReason: nil,
            interfaceName: "en0",
            ssid: "AcMind",
            bssid: nil,
            rssi: rssi,
            transmitRateMbps: transmitRate,
            channel: channel,
            isVPN: false
        )
    }
}
