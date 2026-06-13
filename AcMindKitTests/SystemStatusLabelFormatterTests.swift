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
}
