import SwiftUI
import AppKit
import AcMindKit

struct DynamicContinentTodayPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2OverviewPage(viewModel: viewModel)
    }
}

struct DynamicContinentMusicPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2MusicPage(viewModel: viewModel)
    }
}

struct DynamicContinentAgentPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2AgentPage(viewModel: viewModel)
    }
}

struct DynamicContinentSchedulePage: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    @StateObject private var scheduleViewModel = ScheduleViewModel()

    var body: some View {
        let todayEvents = scheduleViewModel.todayEvents
        let weekEvents = scheduleViewModel.currentWeekEvents
        let nextEvent = todayEvents.first
        let workloadLevel = scheduleViewModel.todayWorkloadLevel

        NotchV2DashboardLayout(leftColumnWidth: 208, rightColumnWidth: 232) {
            DynamicCard(title: "今日时间线", subtitle: timelineSubtitle, symbol: "calendar") {
                VStack(alignment: .leading, spacing: 8) {
                    if let accessNotice = scheduleViewModel.accessNotice {
                        Text(accessNotice)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if todayEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("今天还没有安排")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                            Text("完整日程里有更丰富的周/月/年视图，这里先展示今日摘要。")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(DynamicContinentDesignTokens.tertiaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                    } else {
                        ForEach(todayEvents.prefix(4)) { event in
                            scheduleEventRow(event)
                        }
                    }
                }
            }
        } centerColumn: {
            VStack(spacing: DynamicContinentLayoutMetrics.rowGap) {
                DynamicCard(title: "当前焦点", subtitle: currentFocusSubtitle, symbol: "target") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let nextEvent {
                            Text(nextEvent.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(nextEventTimeText(for: nextEvent))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                                .lineLimit(1)
                            Text("分类：\(scheduleViewModel.categoryName(for: nextEvent.categoryId))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                NotchV2StatusPill(title: nextEvent.isAllDay ? "全天" : "\(nextEvent.durationMinutes) 分钟", accent: DynamicContinentDesignTokens.accentPurple)
                                NotchV2StatusPill(title: nextEvent.status.displayName, accent: DynamicContinentDesignTokens.cardBackgroundStrong)
                            }
                        } else {
                            Text("今天暂时没有下一项安排")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                            Text("可以在完整日程里创建新的任务或查看本周安排。")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                        }
                    }
                }

                DynamicCard(title: "今日饱和度", subtitle: workloadLevel.displayName, symbol: "chart.bar") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(scheduleViewModel.todayWorkloadPercent)%")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("今日专注 \(scheduleViewModel.todayFocusMinutes) 分钟")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                                Text("今日 \(scheduleViewModel.todayEventCount) 项日程 · 本周 \(weekEvents.count) 项")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(DynamicContinentDesignTokens.tertiaryText)
                                    .lineLimit(2)
                            }
                        }

                        ProgressView(value: Double(scheduleViewModel.todayWorkloadPercent) / 100.0)
                            .tint(DynamicContinentDesignTokens.accentPurple)
                        Text("根据已安排时长估算的今日负载")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                    }
                }
            }
        } rightColumn: {
            VStack(spacing: DynamicContinentLayoutMetrics.rowGap) {
                NotchV2SystemRail(viewModel: viewModel)

                DynamicCard(title: "本周概览", subtitle: "真实日程数据", symbol: "calendar.badge.clock", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                    VStack(alignment: .leading, spacing: 8) {
                        if weekEvents.isEmpty {
                            Text("本周暂时没有安排")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                            Text("打开完整日程后可以在周视图里直接新增或编辑事件。")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ForEach(Array(weekEvents.prefix(3))) { event in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                                        .lineLimit(1)
                                    Text(weekEventSubtitle(for: event))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                            }
                        }

                        HStack(spacing: 6) {
                            NotchV2StatusPill(icon: "plus", title: "打开完整日程", accent: DynamicContinentDesignTokens.innerCardBackground)
                                .onTapGesture {
                                    NotificationCenter.default.post(name: .companionShowSchedule, object: nil)
                                }
                            NotchV2StatusPill(icon: "sparkles", title: "今日总结", accent: DynamicContinentDesignTokens.innerCardBackground)
                        }
                    }
                }

                DynamicCard(title: "快速视图", subtitle: "今日聚焦", symbol: "bolt", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                    VStack(alignment: .leading, spacing: 6) {
                        statusChip(scheduleViewModel.todayWorkloadLevel.displayName, color: scheduleViewModel.todayWorkloadLevel.color)
                        statusChip("\(scheduleViewModel.todayEventCount) 项日程", color: .blue)
                        statusChip("\(scheduleViewModel.todayFocusMinutes) 分钟专注", color: .green)
                    }
                }
            }
        }
    }

    private var timelineSubtitle: String {
        if let accessNotice = scheduleViewModel.accessNotice, scheduleViewModel.todayEvents.isEmpty {
            return accessNotice
        }
        return "\(scheduleViewModel.todayEventCount) 项日程 · \(scheduleViewModel.todayFocusMinutes) 分钟专注"
    }

    private var currentFocusSubtitle: String {
        if let nextEvent {
            return nextEvent.isAllDay ? "全天事件" : nextEvent.startAt.formatted(date: .omitted, time: .shortened)
        }
        return "待开始"
    }

    private var nextEvent: ScheduleEvent? {
        scheduleViewModel.todayEvents.first
    }

    private func scheduleEventRow(_ event: ScheduleEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(eventTimeText(for: event))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DynamicContinentDesignTokens.accentPurple)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(eventSubtitle(for: event))
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(DynamicContinentDesignTokens.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 32, alignment: .topLeading)
    }

    private func eventTimeText(for event: ScheduleEvent) -> String {
        if event.isAllDay {
            return "全天"
        }
        return event.startAt.formatted(date: .omitted, time: .shortened)
    }

    private func nextEventTimeText(for event: ScheduleEvent) -> String {
        if event.isAllDay {
            return "全天事件"
        }
        return "\(event.startAt.formatted(date: .omitted, time: .shortened)) - \(event.endAt.formatted(date: .omitted, time: .shortened))"
    }

    private func eventSubtitle(for event: ScheduleEvent) -> String {
        let category = scheduleViewModel.categoryName(for: event.categoryId)
        let duration = event.isAllDay ? "全天" : "\(event.durationMinutes) 分钟"
        return "\(category) · \(duration) · \(event.status.displayName)"
    }

    private func weekEventSubtitle(for event: ScheduleEvent) -> String {
        let time = event.isAllDay ? "全天" : event.startAt.formatted(date: .omitted, time: .shortened)
        return "\(time) · \(scheduleViewModel.categoryName(for: event.categoryId))"
    }

    private func statusChip(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(DynamicContinentDesignTokens.innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DynamicContinentSystemStatusPage: View {
    @StateObject private var viewModel: SystemStatusViewModel

    init(systemStatusService: SystemStatusService) {
        _viewModel = StateObject(wrappedValue: SystemStatusViewModel(service: systemStatusService))
    }

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 238, rightColumnWidth: 238) {
            DynamicCard(title: "状态入口", subtitle: "跳转到主状态中心", symbol: "arrow.right.circle") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("这里只保留轻量摘要，不再重复完整状态面板。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("查看状态") {
                        (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } centerColumn: {
            DynamicCard(title: "核心摘要", subtitle: "真实可读字段", symbol: "chart.line.uptrend.xyaxis") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    DynamicMetricCard(title: "CPU", value: viewModel.cpuSummary, icon: "cpu", tint: .blue, trend: .up)
                    DynamicMetricCard(title: "内存", value: viewModel.memorySummary, icon: "memorychip", tint: .purple, trend: .stable)
                    DynamicMetricCard(title: "磁盘", value: viewModel.diskSummary, icon: "internaldrive", tint: .orange, trend: .up)
                    DynamicMetricCard(title: "网络", value: viewModel.networkSummary, icon: "network", tint: .green, trend: .down)
                }
            }
        } rightColumn: {
            DynamicCard(title: "运行摘要", subtitle: "进程与刷新时间", symbol: "list.bullet.rectangle", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 10) {
                    deviceOverviewRow(title: "最近刷新", value: viewModel.lastUpdatedText)
                    deviceOverviewRow(title: "电池", value: viewModel.batterySummary)
                    deviceOverviewRow(title: "温度", value: viewModel.temperatureSummary)

                    Divider()
                        .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                    DynamicProcessListSection(processes: Array(viewModel.snapshot.topCPUProcesses.prefix(2)))
                }
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    private func statusChip(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(DynamicContinentDesignTokens.innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func deviceOverviewRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(DynamicContinentDesignTokens.innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DynamicMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    let trend: Trend

    enum Trend {
        case up, down, stable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .bottom, spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: trendIcon)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(trendColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DynamicContinentDesignTokens.innerCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DynamicContinentDesignTokens.cardStroke.opacity(0.75), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var trendIcon: String {
        switch trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .up: return .red
        case .down: return .green
        case .stable: return .gray
        }
    }
}

private struct DynamicProcessListSection: View {
    let processes: [SystemProcessSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let rows = Array(processes.prefix(5).enumerated())

            if rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                    Text("等待进程采样")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                        .lineLimit(1)
                    Text("刷新后会显示活跃进程的 CPU 和内存占用。")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            } else {
                ForEach(rows, id: \.offset) { row in
                    let process = row.element
                    HStack(spacing: 8) {
                        Text(process.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                        Text(String(format: "%.0f%%", process.cpuUsage))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                            .lineLimit(1)
                        Text(String(format: "%.0f MB", process.memoryUsageMB))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(DynamicContinentDesignTokens.innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}
