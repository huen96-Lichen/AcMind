import SwiftUI

#if DEBUG
extension WorkbenchV2DashboardData {
    static func preview() -> WorkbenchV2DashboardData {
        let cpuSeries = WorkbenchTrendPoint.series(
            values: [42, 45, 44, 50, 47, 51, 55, 54, 58, 57, 61, 59]
        )
        let memorySeries = WorkbenchTrendPoint.series(
            values: [61, 60, 59, 62, 63, 61, 64, 66, 65, 67, 66, 68]
        )

        return WorkbenchV2DashboardData(
            header: Header(
                title: "Workbench",
                subtitle: "V2 示意",
                badges: [
                    WorkbenchV2Badge(text: "Debug", systemImage: "ladybug.fill", tint: .orange),
                    WorkbenchV2Badge(text: "Preview", systemImage: "shippingbox.fill", tint: .blue),
                    WorkbenchV2Badge(text: "1500 × 888", systemImage: "ruler", tint: .green)
                ]
            ),
            currentFocus: CurrentFocus(
                state: .normal,
                title: "AcWork Phase 1 UI 重制",
                summary: "完成首页视觉方案并与 SwiftUI 对齐，准备 0.1.0 发布。",
                primaryMetricLabel: "当前阶段",
                primaryMetricValue: "布局确认",
                secondaryMetricLabel: "整体进度",
                secondaryMetricValue: "60%",
                nextStepLabel: "下一步行动",
                nextStepValue: "确定视觉方案并收敛结构"
            ),
            pendingItems: PendingItems(
                state: .warning,
                title: "待处理",
                items: [
                    .init(title: "页面骨架对齐", detail: "确认 1500×888 画布和卡片边界", priority: "P0"),
                    .init(title: "结构映射", detail: "等候视觉稿后接入真实结构", priority: "P1"),
                    .init(title: "布局回归检查", detail: "确保不越界、不滚动", priority: "P1")
                ]
            ),
            recentCollection: RecentCollection(
                state: .normal,
                title: "最近收集",
                items: [
                    .init(title: "审计结果", detail: "当前布局测量与截图已完成", timeLabel: "09:20"),
                    .init(title: "重构目标", detail: "先保留旧版，再搭 V2", timeLabel: "09:35"),
                    .init(title: "回归验证", detail: "用于布局和视觉回归验证", timeLabel: "09:48")
                ]
            ),
            todayStatus: TodayStatus(
                state: .normal,
                title: "今日总览",
                subtitle: "更新于 10:42",
                items: [
                    .init(label: "今日收集", value: "12", unit: "条", meta: "+4", tint: .blue, systemImage: "square.stack.fill"),
                    .init(label: "待确认", value: "3", unit: "条", meta: "-1", tint: .orange, systemImage: "plus.square.fill"),
                    .init(label: "Agent 状态", value: "运行中", unit: "", meta: "2 个任务", tint: .green, systemImage: "command.circle.fill"),
                    .init(label: "今日日程", value: "2", unit: "项", meta: "1 项进行中", tint: .purple, systemImage: "calendar.badge.clock")
                ],
                toggles: [
                    .init(title: "灵动大陆", subtitle: "已开启", isOn: true, systemImage: "circle"),
                    .init(title: "说人法", subtitle: "已开启", isOn: true, systemImage: "music.note")
                ],
                statusBlocks: [
                    .init(title: "本地模型", value: "Qwen", tint: .teal, systemImage: "circle.fill"),
                    .init(title: "服务状态", value: "全部正常", tint: .green, systemImage: "circle.fill")
                ]
            ),
            activityTrend: ActivityTrend(
                state: .normal,
                title: "活动趋势",
                primarySeries: .init(name: "主曲线", tint: .blue, values: cpuSeries),
                secondarySeries: .init(name: "次曲线", tint: .green, values: memorySeries),
                emptyMessage: "暂无趋势数据"
            ),
            quickActions: QuickActions(
                state: .warning,
                title: "快捷动作",
                actions: [
                    .init(title: "截图", subtitle: "直接截屏 · ⌘⇧4", systemImage: "camera.viewfinder", tint: .blue),
                    .init(title: "快速记录", subtitle: "", systemImage: "pencil", tint: .gray),
                    .init(title: "新建任务", subtitle: "", systemImage: "square", tint: .gray),
                    .init(title: "打开收集箱", subtitle: "", systemImage: "square.grid.2x2", tint: .gray),
                    .init(title: "启动 Agent", subtitle: "", systemImage: "command", tint: .gray),
                    .init(title: "导入文件", subtitle: "", systemImage: "arrow.up.doc", tint: .gray)
                ]
            ),
            deviceStatus: DeviceStatus(
                state: .normal,
                title: "设备状态",
                items: [
                    .init(title: "CPU", value: "48%", tint: .blue),
                    .init(title: "内存", value: "61%", tint: .green),
                    .init(title: "温度", value: "--", tint: .gray),
                    .init(title: "风扇", value: "--", tint: .gray),
                    .init(title: "电源", value: "接电", tint: .orange),
                    .init(title: "权限", value: "已授权", tint: .teal)
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
}
#endif
