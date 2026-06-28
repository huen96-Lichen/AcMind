import SwiftUI

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
                detail: index == 0 ? snapshot.nextStep : "来自真实任务与收集箱状态",
                priority: index == 0 ? "当前" : "待办"
            )
        }
        let recent = snapshot.recentItems.map {
            RecentCollectionItem(title: $0, detail: "收集箱内容", timeLabel: "最近")
        }
        let deviceItems = snapshot.systemMetrics.enumerated().map { index, metric -> DeviceStatusItem in
            let parts = metric.split(separator: " ", maxSplits: 1).map(String.init)
            return DeviceStatusItem(
                title: parts.first ?? "状态",
                value: parts.count > 1 ? parts[1] : metric,
                tint: index == 0 ? .blue : index == 1 ? .green : .orange
            )
        }
        let scheduleCount = snapshot.scheduleItems.count
        let permissionWarning = snapshot.unavailableReasons.isEmpty == false

        return WorkbenchV2DashboardData(
            header: Header(
                title: "Workbench",
                subtitle: snapshot.nowLabel,
                badges: [
                    WorkbenchV2Badge(text: "实时数据", systemImage: "bolt.horizontal.fill", tint: .green),
                    WorkbenchV2Badge(text: snapshot.currentPage, systemImage: "rectangle.on.rectangle", tint: .blue)
                ]
            ),
            currentFocus: CurrentFocus(
                state: snapshot.pendingItems.isEmpty && snapshot.scheduleItems.isEmpty ? .empty : .normal,
                title: snapshot.currentFocus,
                summary: "当前工作台根据 Agent、日程与收集箱状态自动选择焦点。",
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
                    .init(label: "待处理", value: "\(snapshot.pendingItems.count)", unit: "项", meta: "实时", tint: .orange, systemImage: "checklist"),
                    .init(label: "最近收集", value: "\(snapshot.recentItems.count)", unit: "条", meta: "实时", tint: .blue, systemImage: "tray.full"),
                    .init(label: "今日日程", value: "\(scheduleCount)", unit: "项", meta: "实时", tint: .purple, systemImage: "calendar")
                ],
                toggles: [],
                statusBlocks: [
                    .init(
                        title: "权限与采样",
                        value: permissionWarning ? "需要关注" : "状态正常",
                        tint: permissionWarning ? .orange : .green,
                        systemImage: permissionWarning ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
                    )
                ]
            ),
            activityTrend: ActivityTrend(
                state: .empty,
                title: "活动趋势",
                primarySeries: .init(name: "CPU", tint: .blue, values: []),
                secondarySeries: .init(name: "内存", tint: .green, values: []),
                emptyMessage: "趋势会在积累连续采样后显示"
            ),
            quickActions: QuickActions(
                state: .normal,
                title: "快捷动作",
                actions: [
                    .init(title: "截图", subtitle: "直接截屏 · ⌘⇧4", systemImage: "camera.viewfinder", tint: .blue),
                    .init(title: "快速记录", subtitle: "", systemImage: "pencil", tint: .gray),
                    .init(title: "新建任务", subtitle: "", systemImage: "checkmark.square", tint: .gray),
                    .init(title: "打开收集箱", subtitle: "", systemImage: "tray.full", tint: .gray),
                    .init(title: "启动 Agent", subtitle: "", systemImage: "command", tint: .gray),
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
