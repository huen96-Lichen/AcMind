import SwiftUI
import AcMindKit

struct WorkbenchV2DashboardData {
    struct Header: Equatable {
        let title: String
        let subtitle: String
        let badges: [WorkbenchV2Badge]
    }

    struct CurrentFocus: Equatable {
        let state: WorkbenchV2State
        let title: String
        let summary: String
        let primaryMetricLabel: String
        let primaryMetricValue: String
        let secondaryMetricLabel: String
        let secondaryMetricValue: String
        let nextStepLabel: String
        let nextStepValue: String
    }

    struct WorkQueueItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let detail: String
        let priority: String
    }

    struct PendingItems: Equatable {
        let state: WorkbenchV2State
        let title: String
        let items: [WorkQueueItem]
    }

    struct RecentCollectionItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let detail: String
        let timeLabel: String
    }

    struct RecentCollection: Equatable {
        let state: WorkbenchV2State
        let title: String
        let items: [RecentCollectionItem]
    }

    struct TodayStatusItem: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let value: String
        let unit: String
        let meta: String
        let tint: Color
        let systemImage: String
    }

    struct TodayStatusToggle: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let subtitle: String
        let isOn: Bool
        let systemImage: String
    }

    struct TodayStatus: Equatable {
        let state: WorkbenchV2State
        let title: String
        let subtitle: String
        let items: [TodayStatusItem]
        let toggles: [TodayStatusToggle]
        let statusBlocks: [TodayStatusBlock]
    }

    struct TodayStatusBlock: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let value: String
        let tint: Color
        let systemImage: String
    }

    struct TrendSeries: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let tint: Color
        let values: [WorkbenchTrendPoint]
    }

    struct ActivityTrend: Equatable {
        let state: WorkbenchV2State
        let title: String
        let primarySeries: TrendSeries
        let secondarySeries: TrendSeries
        let emptyMessage: String
    }

    struct QuickAction: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let subtitle: String
        let systemImage: String
        let tint: Color
    }

    struct QuickActions: Equatable {
        let state: WorkbenchV2State
        let title: String
        let actions: [QuickAction]
    }

    struct DeviceStatusItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let value: String
        let tint: Color
    }

    struct DeviceStatus: Equatable {
        let state: WorkbenchV2State
        let title: String
        let items: [DeviceStatusItem]
    }

    let header: Header
    let currentFocus: CurrentFocus
    let pendingItems: PendingItems
    let recentCollection: RecentCollection
    let todayStatus: TodayStatus
    let activityTrend: ActivityTrend
    let quickActions: QuickActions
    let deviceStatus: DeviceStatus

    static func live(from snapshot: WorkspaceDashboardSnapshot) -> WorkbenchV2DashboardData {
        let pending = snapshot.pendingItems.enumerated().map { index, item in
            WorkQueueItem(
                title: item,
                detail: index == 0 ? snapshot.nextStep : "来自任务和收集箱状态",
                priority: index == 0 ? "当前" : "待办"
            )
        }
        let recent = snapshot.recentItems.map {
            RecentCollectionItem(title: $0, detail: "收集箱条目", timeLabel: "最近")
        }
        let deviceItems = buildDeviceStatusItems(from: snapshot)
        let scheduleCount = snapshot.scheduleItems.count
        let permissionWarning = snapshot.unavailableReasons.isEmpty == false

        return WorkbenchV2DashboardData(
            header: Header(
                title: "工作台",
                subtitle: "",
                badges: [
                    WorkbenchV2Badge(text: "当前数据", systemImage: "bolt.horizontal.fill", tint: .green),
                    WorkbenchV2Badge(text: snapshot.currentPage, systemImage: "rectangle.on.rectangle", tint: .blue)
                ]
            ),
            currentFocus: CurrentFocus(
                state: snapshot.pendingItems.isEmpty && snapshot.scheduleItems.isEmpty ? .empty : .normal,
                title: snapshot.currentFocus,
                summary: "工作台会根据智能体、日程和收集箱状态切换焦点。",
                primaryMetricLabel: "待处理",
                primaryMetricValue: "\(snapshot.pendingItems.count) 项",
                secondaryMetricLabel: "今日日程",
                secondaryMetricValue: "\(scheduleCount) 项",
                nextStepLabel: "下一步行动",
                nextStepValue: snapshot.nextStep
            ),
            pendingItems: PendingItems(
                state: pending.isEmpty ? .empty : .normal,
                title: "待处理",
                items: pending
            ),
            recentCollection: RecentCollection(
                state: recent.isEmpty ? .empty : .normal,
                title: "最近收集",
                items: recent
            ),
            todayStatus: TodayStatus(
                state: .normal,
                title: "今日总览",
                subtitle: snapshot.nowLabel,
                items: [
                    .init(label: "待处理", value: "\(snapshot.pendingItems.count)", unit: "项", meta: "现状", tint: .orange, systemImage: "checklist"),
                    .init(label: "最近收集", value: "\(snapshot.recentItems.count)", unit: "条", meta: "现状", tint: .blue, systemImage: "tray.full"),
                    .init(label: "智能体状态", value: snapshot.pendingItems.isEmpty ? "空闲" : "运行中", unit: "", meta: "\(snapshot.pendingItems.count) 个任务", tint: .green, systemImage: "command.circle.fill"),
                    .init(label: "今日日程", value: "\(scheduleCount)", unit: "项", meta: "现状", tint: .purple, systemImage: "calendar")
                ],
                toggles: [],
                statusBlocks: [
                    .init(
                        title: "权限与采样",
                        value: permissionWarning ? "需要关注" : "状态正常",
                        tint: permissionWarning ? .orange : .green,
                        systemImage: permissionWarning ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
                    ),
                    .init(
                        title: "服务状态",
                        value: snapshot.phase == .loaded ? "全部正常" : "同步中",
                        tint: snapshot.phase == .loaded ? .green : .orange,
                        systemImage: snapshot.phase == .loaded ? "checkmark.circle.fill" : "clock.fill"
                    )
                ]
            ),
            activityTrend: ActivityTrend(
                state: .empty,
                title: "活动趋势",
                primarySeries: .init(name: "CPU", tint: .blue, values: []),
                secondarySeries: .init(name: "内存", tint: .green, values: []),
                emptyMessage: "积累连续采样后显示"
            ),
            quickActions: QuickActions(
                state: .normal,
                title: "快捷动作",
                actions: [
                    .init(title: "截图", subtitle: "直接截屏 · ⌘⇧4", systemImage: "camera.viewfinder", tint: .blue),
                    .init(title: "快速记录", subtitle: "", systemImage: "pencil", tint: .gray),
                    .init(title: "新建任务", subtitle: "", systemImage: "checkmark.square", tint: .gray),
                    .init(title: "打开收集箱", subtitle: "", systemImage: "tray.full", tint: .gray),
                    .init(title: "启动智能体", subtitle: "", systemImage: "command", tint: .gray),
                    .init(title: "导入文件", subtitle: "", systemImage: "arrow.up.doc", tint: .gray)
                ]
            ),
            deviceStatus: DeviceStatus(
                state: deviceItems.isEmpty ? .empty : .normal,
                title: "设备状态",
                items: deviceItems
            )
        )
    }

    private static func buildDeviceStatusItems(from snapshot: WorkspaceDashboardSnapshot) -> [DeviceStatusItem] {
        guard let system = snapshot.systemStatusSnapshot else {
            return snapshot.systemMetrics.enumerated().map { index, metric -> DeviceStatusItem in
                let parts = metric.split(separator: " ", maxSplits: 1).map(String.init)
                return DeviceStatusItem(
                    title: parts.first ?? "状态",
                    value: parts.count > 1 ? parts[1] : metric,
                    tint: index == 0 ? .blue : index == 1 ? .green : .orange
                )
            }
        }

        return [
            DeviceStatusItem(title: "温度", value: primaryTemperatureSummary(from: system), tint: .orange),
            DeviceStatusItem(title: "电量", value: batterySummary(from: system), tint: .green),
            DeviceStatusItem(title: "网速", value: networkSpeedSummary(from: system), tint: .blue),
            DeviceStatusItem(title: "开机", value: uptimeSummary(from: system), tint: .purple),
            DeviceStatusItem(title: "负载", value: loadSummary(from: system), tint: .pink),
            DeviceStatusItem(title: "剩余空间", value: freeDiskSummary(from: system), tint: .teal)
        ]
    }

    private static func primaryTemperatureSummary(from snapshot: SystemStatusSnapshot) -> String {
        if let sensor = snapshot.temperatureSensors.first(where: { $0.isAvailable && $0.value != nil }),
           let value = sensor.value {
            return String(format: "%.1f°C", value)
        }
        if let batteryTemperature = snapshot.battery?.temperatureC {
            return String(format: "%.1f°C", batteryTemperature)
        }
        return "—"
    }

    private static func batterySummary(from snapshot: SystemStatusSnapshot) -> String {
        guard let battery = snapshot.battery, battery.isAvailable else { return "无电池" }
        if let percentage = battery.percentage {
            return "\(Int(percentage.rounded()))%"
        }
        return battery.state.isEmpty ? "—" : battery.state
    }

    private static func networkSpeedSummary(from snapshot: SystemStatusSnapshot) -> String {
        let download = snapshot.networkDownloadMBps
        let upload = snapshot.networkUploadMBps
        guard download != nil || upload != nil else { return "—" }
        return "↓\(formatRate(download)) ↑\(formatRate(upload))"
    }

    private static func uptimeSummary(from snapshot: SystemStatusSnapshot) -> String {
        guard let uptime = snapshot.hardwareInfo?.uptimeSeconds else { return "—" }
        let total = Int(uptime)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private static func loadSummary(from snapshot: SystemStatusSnapshot) -> String {
        if let load = snapshot.loadAverage1m {
            return String(format: "%.1f", load)
        }
        if let cpu = snapshot.cpu?.value {
            return String(format: "%.0f%%", cpu)
        }
        return "—"
    }

    private static func freeDiskSummary(from snapshot: SystemStatusSnapshot) -> String {
        if let total = snapshot.diskTotalGB, let used = snapshot.diskUsedGB {
            return "\(Int(max(total - used, 0).rounded())) GB"
        }
        if snapshot.diskUsagePercent > 0, let total = snapshot.diskTotalGB {
            let freeFraction = max(1 - snapshot.diskUsagePercent / 100, 0)
            return "\(Int((total * freeFraction).rounded())) GB"
        }
        return "—"
    }

    private static func formatRate(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value >= 10 {
            return String(format: "%.0fM", value)
        }
        return String(format: "%.1fM", value)
    }
}

struct WorkbenchTrendPoint: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let value: Double

    static func series(values: [Double], start: Date = .now, step: TimeInterval = 60) -> [WorkbenchTrendPoint] {
        values.enumerated().map { index, value in
            WorkbenchTrendPoint(
                id: UUID(),
                timestamp: start.addingTimeInterval(Double(index) * step),
                value: value
            )
        }
    }
}
