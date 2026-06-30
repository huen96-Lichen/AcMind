import SwiftUI

#if DEBUG
extension WorkbenchV2DashboardData {
    static func preview() -> WorkbenchV2DashboardData {
        let dayStart = Calendar.current.startOfDay(for: .now)
        let cpuSeries = WorkbenchTrendPoint.series(
            values: [56, 66, 51, 73, 60, 54, 72, 100, 78, 74, 82, 88, 76],
            start: dayStart,
            step: 7_200
        )

        return WorkbenchV2DashboardData(
            header: Header(
                title: "工作台",
                subtitle: "",
                badges: [
                    WorkbenchV2Badge(text: "当前数据", systemImage: "bolt.horizontal.fill", tint: .green),
                    WorkbenchV2Badge(text: "工作台", systemImage: "rectangle.on.rectangle", tint: .blue)
                ]
            ),
            currentFocus: CurrentFocus(
                state: .normal,
                title: "截图 2026-06-28 23:08",
                summary: "工作台会根据智能体、日程和收集箱状态切换焦点。",
                primaryMetricLabel: "待处理",
                primaryMetricValue: "6 项",
                secondaryMetricLabel: "今日已处理",
                secondaryMetricValue: "0 项",
                nextStepLabel: "下一步行动",
                nextStepValue: "打开收集箱继续整理"
            ),
            pendingItems: PendingItems(
                state: .normal,
                title: "待处理",
                items: [
                    .init(title: "已采集：截图 2026-06-28 23:08", detail: "打开收集箱继续整理", priority: "当前"),
                    .init(title: "已蒸馏：Distilled Item", detail: "来自任务和收集箱状态", priority: "待办")
                ]
            ),
            recentCollection: RecentCollection(
                state: .normal,
                title: "最近收集",
                items: [
                    .init(title: "截图 2026-06-28 23:08", detail: "收集箱条目", timeLabel: "09:20"),
                    .init(title: "Distilled Item", detail: "收集箱条目", timeLabel: "09:35")
                ]
            ),
            todayStatus: TodayStatus(
                state: .normal,
                title: "今日总览",
                subtitle: "更新于 10:42",
                items: [
                    .init(label: "待处理", value: "6", unit: "项", meta: "现状", tint: .orange, systemImage: "hourglass"),
                    .init(label: "最近收集", value: "6", unit: "条", meta: "现状", tint: .blue, systemImage: "square.stack.fill"),
                    .init(label: "今日日程", value: "0", unit: "项", meta: "现状", tint: .purple, systemImage: "calendar"),
                    .init(label: "待确认", value: "3", unit: "条", meta: "现状", tint: .green, systemImage: "checkmark.circle")
                ],
                toggles: [
                    .init(title: "灵动大陆", subtitle: "已开启", isOn: true, systemImage: "circle"),
                    .init(title: "说人法", subtitle: "已开启", isOn: true, systemImage: "music.note")
                ],
                statusBlocks: [
                    .init(title: "权限与采样", value: "状态正常", tint: .green, systemImage: "circle.fill")
                ]
            ),
            activityTrend: ActivityTrend(
                state: .normal,
                title: "活动趋势",
                primarySeries: .init(name: "主曲线", tint: .blue, values: cpuSeries),
                secondarySeries: .init(name: "次曲线", tint: .green, values: []),
                emptyMessage: "趋势尚未生成"
            ),
            quickActions: QuickActions(
                state: .warning,
                title: "快捷动作",
                actions: [
                    .init(title: "截图", subtitle: "直接截屏 · ⌘⇧4", systemImage: "camera.viewfinder", tint: .blue),
                    .init(title: "快速记录", subtitle: "", systemImage: "pencil", tint: .gray),
                    .init(title: "新建任务", subtitle: "", systemImage: "square", tint: .gray),
                    .init(title: "打开收集箱", subtitle: "", systemImage: "square.grid.2x2", tint: .gray),
                    .init(title: "启动智能体", subtitle: "", systemImage: "command", tint: .gray),
                    .init(title: "导入文件", subtitle: "", systemImage: "arrow.up.doc", tint: .gray)
                ]
            ),
            deviceStatus: DeviceStatus(
                state: .normal,
                title: "设备状态",
                items: [
                    .init(title: "CPU", value: "48%", tint: .blue),
                    .init(title: "电量", value: "74%", tint: .green),
                    .init(title: "网络", value: "良好", tint: .purple),
                    .init(title: "开机", value: "2天6小时", tint: .orange)
                ]
            )
        )
    }

    static func compactWarning() -> WorkbenchV2DashboardData {
        let data = preview()
        return WorkbenchV2DashboardData(
            header: data.header,
            currentFocus: data.currentFocus,
            pendingItems: PendingItems(
                state: .warning,
                title: "待处理",
                items: [
                    .init(title: "卡片压缩", detail: "紧凑模式隐藏次要文案", priority: "P0"),
                    .init(title: "列宽收缩", detail: "右侧上下文列缩到 252px", priority: "P1")
                ]
            ),
            recentCollection: data.recentCollection,
            todayStatus: data.todayStatus,
            activityTrend: data.activityTrend,
            quickActions: data.quickActions,
            deviceStatus: data.deviceStatus
        )
    }

    static func runtimeCompactAudit() -> WorkbenchV2DashboardData {
        let data = preview()
        return WorkbenchV2DashboardData(
            header: data.header,
            currentFocus: data.currentFocus,
            pendingItems: data.pendingItems,
            recentCollection: data.recentCollection,
            todayStatus: TodayStatus(
                state: .normal,
                title: "今日总览",
                subtitle: "2026年6月29日 22:11",
                items: data.todayStatus.items,
                toggles: [],
                statusBlocks: [
                    .init(title: "权限与采样", value: "状态正常", tint: .green, systemImage: "checkmark.circle.fill"),
                    .init(title: "服务状态", value: "全部正常", tint: .green, systemImage: "checkmark.circle.fill")
                ]
            ),
            activityTrend: ActivityTrend(
                state: .empty,
                title: "活动趋势",
                primarySeries: .init(name: "CPU", tint: .blue, values: []),
                secondarySeries: .init(name: "内存", tint: .green, values: []),
                emptyMessage: "积累连续采样后显示"
            ),
            quickActions: data.quickActions,
            deviceStatus: data.deviceStatus
        )
    }
}
#endif
