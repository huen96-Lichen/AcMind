import SwiftUI

struct WorkbenchV2MockData {
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

    static func preview() -> WorkbenchV2MockData {
        let cpuSeries = WorkbenchTrendPoint.series(
            values: [42, 45, 44, 50, 47, 51, 55, 54, 58, 57, 61, 59]
        )
        let memorySeries = WorkbenchTrendPoint.series(
            values: [61, 60, 59, 62, 63, 61, 64, 66, 65, 67, 66, 68]
        )

        return WorkbenchV2MockData(
            header: Header(
                title: "Workbench",
                subtitle: "V2 静态骨架",
                badges: [
                    WorkbenchV2Badge(text: "Debug", systemImage: "ladybug.fill", tint: .orange),
                    WorkbenchV2Badge(text: "Mock", systemImage: "shippingbox.fill", tint: .blue),
                    WorkbenchV2Badge(text: "1500 × 888", systemImage: "ruler", tint: .green)
                ]
            ),
            currentFocus: CurrentFocus(
                state: .normal,
                title: "AcWork Phase 1 UI 重制",
                summary: "完成首页视觉方案并与 SwiftUI 对齐，准备 0.1.0 发布。",
                primaryMetricLabel: "当前阶段",
                primaryMetricValue: "HTML 原型确认",
                secondaryMetricLabel: "整体进度",
                secondaryMetricValue: "60%",
                nextStepLabel: "下一步行动",
                nextStepValue: "确定视觉方案并输出 HTML"
            ),
            pendingItems: PendingItems(
                state: .warning,
                title: "待处理",
                items: [
                    .init(title: "页面骨架对齐", detail: "确认 1500×888 画布和卡片边界", priority: "P0"),
                    .init(title: "HTML 原型映射", detail: "等候视觉稿后接入真实结构", priority: "P1"),
                    .init(title: "布局回归检查", detail: "确保不越界、不滚动", priority: "P1")
                ]
            ),
            recentCollection: RecentCollection(
                state: .normal,
                title: "最近收集",
                items: [
                    .init(title: "审计结果", detail: "当前布局测量与截图已完成", timeLabel: "09:20"),
                    .init(title: "重构目标", detail: "先保留旧版，再搭 V2", timeLabel: "09:35"),
                    .init(title: "交付约束", detail: "不接真实业务数据", timeLabel: "09:48")
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
                    .init(title: "快速记录", subtitle: "", systemImage: "pencil", tint: .blue),
                    .init(title: "新建任务", subtitle: "", systemImage: "square", tint: .gray),
                    .init(title: "打开收集箱", subtitle: "", systemImage: "square.grid.2x2", tint: .gray),
                    .init(title: "启动 Agent", subtitle: "", systemImage: "command", tint: .gray),
                    .init(title: "导入文件", subtitle: "", systemImage: "arrow.up.doc", tint: .gray),
                    .init(title: "添加日程", subtitle: "", systemImage: "calendar", tint: .gray)
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

    static func compactWarning() -> WorkbenchV2MockData {
        let data = preview()
        return WorkbenchV2MockData(
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
