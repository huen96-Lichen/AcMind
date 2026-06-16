import SwiftUI
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
        NotchV2DashboardLayout(leftColumnWidth: 176, rightColumnWidth: 176) {
            leftColumn
        } centerColumn: {
            centerColumn
        } rightColumn: {
            rightColumn
        }
    }

    private var leftColumn: some View {
        NotchV2Card(title: "今日时间线", symbol: "timeline.selection", padding: 12, fillHeight: true) {
            if scheduleVm.todayEvents.isEmpty {
                emptyTimeline
            } else {
                timelineContent
            }
        }
    }

    private var centerColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "当前焦点", symbol: "scope", padding: 12, cardAccent: nil) {
                focusCard
            }

            NotchV2Card(title: "今日饱和度", symbol: "gauge.medium", padding: 12) {
                workloadCard
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2SystemRail(viewModel: viewModel)

            NotchV2Card(title: "本周概览", symbol: "chart.bar.fill", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                weekOverviewCard
            }

            NotchV2Card(title: "快捷视图", symbol: "list.bullet.rectangle", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                quickViewCard
            }
        }
    }

    private var scheduleVm: ScheduleViewModel {
        scheduleViewModel
    }

    private var emptyTimeline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("暂无安排")
                .font(NotchV2DesignTokens.Typography.title)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
            Text("有日程时会按时间显示进度。")
                .font(NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(2)
        }
    }

    private var timelineContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(scheduleVm.todayEvents.prefix(6)) { event in
                    timelineItem(event)
                }
            }
        }
    }

    private func timelineItem(_ event: ScheduleEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(statusColor(for: event.status))
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(NotchV2DesignTokens.separator.opacity(0.3))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(event.title)
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isCurrentEvent(event) {
                        Text("进行中")
                            .font(NotchV2DesignTokens.Typography.caption)
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                }
                Text(eventTimeText(for: event))
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(event.status.displayName)
                    Text("·")
                    Text(eventSubtitle(for: event))
                }
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                if let tag = event.tag, tag.isEmpty == false {
                    HStack(spacing: 3) {
                        Image(systemName: "tag")
                            .font(.system(size: 8))
                        Text(tag)
                    }
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let item = currentEvent {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 6) {
                    Text(eventTimeText(for: item))
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    Text(eventSubtitle(for: item))
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let tag = item.tag, tag.isEmpty == false {
                        Text("·")
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        Text(tag)
                            .font(NotchV2DesignTokens.Typography.body)
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                if let next = nextEvent {
                    Divider()
                        .overlay(NotchV2DesignTokens.separator.opacity(0.45))
                    HStack(spacing: 6) {
                        Text("下一条")
                            .font(NotchV2DesignTokens.Typography.caption)
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                        Text(next.title)
                            .font(NotchV2DesignTokens.Typography.body)
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(eventTimeText(for: next))
                            .font(NotchV2DesignTokens.Typography.caption)
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("当前没有进行中的事项")
                    .font(NotchV2DesignTokens.Typography.title)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                Text("有日程时会自动进入焦点。")
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private var workloadCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("\(scheduleVm.todayWorkloadPercent)%")
                    .font(NotchV2DesignTokens.Typography.title)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                Text(scheduleVm.todayWorkloadLevel.displayName)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text("今日专注 \(scheduleVm.todayFocusMinutes) 分钟 · \(scheduleVm.todayEventCount) 项日程")
                .font(NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)

            ProgressView(value: Double(scheduleVm.todayWorkloadPercent) / 100.0)
                .tint(NotchV2DesignTokens.secondaryText)

            HStack(spacing: 8) {
                legendItem(color: NotchV2DesignTokens.secondaryText, title: "专注", value: Double(scheduleVm.todayFocusMinutes) / 60.0)
                legendItem(color: NotchV2DesignTokens.secondaryText.opacity(0.8), title: "事件", value: Double(scheduleVm.todayEventCount))
            }
        }
    }

    private var weekOverviewCard: some View {
        let weekDays = ["一", "二", "三", "四", "五", "六", "日"]
        let days = scheduleVm.weekWorkloadDays

        let maxCount = max(1, days.map(\.eventCount).max() ?? 1)

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                let dayData = index < days.count ? days[index] : nil
                HStack(spacing: 6) {
                    Text(day)
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .frame(width: 14, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { proxy in
                        let ratio = CGFloat(dayData?.eventCount ?? 0) / CGFloat(maxCount)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(NotchV2DesignTokens.secondaryText.opacity(0.25 + 0.25 * Double(ratio)))
                            .frame(width: max(3, proxy.size.width * ratio))
                    }
                    .frame(height: 6)

                    Text("\(dayData?.eventCount ?? 0)")
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .frame(width: 16, alignment: .trailing)
                        .lineLimit(1)
                }
            }
        }
    }

    private var quickViewCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            let statusFilters: [(String, ScheduleEvent.EventStatus?)] = [
                ("待办", .todo),
                ("已完成", .done),
                ("已取消", .cancelled)
            ]

            ForEach(statusFilters, id: \.0) { filter in
                let count = filter.1 != nil ? scheduleVm.events.filter { $0.status == filter.1 }.count : scheduleVm.events.count
                HStack {
                    Text(filter.0)
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(count)")
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.94))
                )
            }

            Divider()
                .overlay(NotchV2DesignTokens.separator.opacity(0.45))

            Button("打开日程") {
                NotificationCenter.default.post(name: .companionShowSchedule, object: nil)
            }
            .buttonStyle(.plain)
            .font(NotchV2DesignTokens.Typography.caption)
            .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
    }

    private func legendItem(color: Color, title: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Text(title == "专注" ? String(format: "%.1fh", value) : "\(Int(value))")
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
        }
    }

    private var currentEvent: ScheduleEvent? {
        let now = Date()
        if let active = scheduleVm.todayEvents.first(where: { $0.startAt <= now && now < $0.endAt }) {
            return active
        }
        return scheduleVm.todayEvents.first
    }

    private var nextEvent: ScheduleEvent? {
        let now = Date()
        return scheduleVm.todayEvents.first(where: { $0.startAt > now }) ?? scheduleVm.todayEvents.dropFirst().first
    }

    private func isCurrentEvent(_ event: ScheduleEvent) -> Bool {
        guard let currentEvent else { return false }
        return currentEvent.id == event.id
    }

    private func eventTimeText(for event: ScheduleEvent) -> String {
        if event.isAllDay {
            return "全天"
        }
        return "\(event.startAt.formatted(date: .omitted, time: .shortened)) - \(event.endAt.formatted(date: .omitted, time: .shortened))"
    }

    private func eventSubtitle(for event: ScheduleEvent) -> String {
        let category = scheduleVm.categoryName(for: event.categoryId)
        let duration = event.isAllDay ? "全天" : "\(event.durationMinutes) 分钟"
        return "\(category) · \(duration)"
    }

    private func statusColor(for status: ScheduleEvent.EventStatus) -> Color {
        switch status {
        case .todo: return NotchV2DesignTokens.secondaryText.opacity(0.7)
        case .done: return NotchV2DesignTokens.secondaryText.opacity(0.45)
        case .cancelled: return NotchV2DesignTokens.secondaryText
        }
    }
}

struct DynamicContinentSystemStatusPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 176, rightColumnWidth: 176) {
            leftColumn
        } centerColumn: {
            centerColumn
        } rightColumn: {
            rightColumn
        }
    }

    private var leftColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "运行摘要", symbol: "desktopcomputer", fillHeight: true, cornerRadius: NotchV2DesignTokens.cardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    NotchV2InfoRow(title: "主机", value: Host.current().localizedName ?? "Mac", icon: "desktopcomputer", accent: NotchV2DesignTokens.secondaryText, compactValue: true)
                    NotchV2InfoRow(title: "系统", value: ProcessInfo.processInfo.operatingSystemVersionString, icon: "cpu", accent: NotchV2DesignTokens.secondaryText, compactValue: true)
                    NotchV2InfoRow(title: "CPU 核心", value: "\(ProcessInfo.processInfo.processorCount)", icon: "cpu.fill", accent: NotchV2DesignTokens.secondaryText, compactValue: true)

                    Divider()
                        .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                    Text("设备信息")
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)

                    NotchV2InfoRow(title: "电池", value: viewModel.batteryStateText, icon: "battery.100", accent: NotchV2DesignTokens.secondaryText, compactValue: true)
                    NotchV2InfoRow(title: "电量", value: viewModel.batteryDisplayText, icon: "battery.75", accent: NotchV2DesignTokens.secondaryText, compactValue: true)
                }
            }
        }
    }

    private var centerColumn: some View {
        NotchV2Card(title: "核心摘要", symbol: "cpu", fillHeight: true, cardAccent: nil) {
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]

            return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                statusMetricTile(
                    title: "电池电量",
                    value: viewModel.systemBatterySummary,
                    detail: viewModel.batteryStateText,
                    color: NotchV2DesignTokens.primaryText
                )

                statusMetricTile(
                    title: "网速（上传下载量）",
                    value: viewModel.systemNetworkDownloadSummary,
                    detail: "↑ \(viewModel.systemNetworkUploadSummary)",
                    color: NotchV2DesignTokens.primaryText
                )

                statusMetricTile(
                    title: "当前设备温度",
                    value: viewModel.systemTemperatureSummary,
                    detail: viewModel.systemTemperatureDetail,
                    color: NotchV2DesignTokens.primaryText
                )

                fanControlTile

                statusMetricTile(
                    title: "CPU 负载率",
                    value: viewModel.systemCPUUsageSummary,
                    detail: "当前使用率",
                    color: NotchV2DesignTokens.primaryText
                )

                statusMetricTile(
                    title: "内存负载率",
                    value: viewModel.systemMemoryUsageSummary,
                    detail: "当前占用率",
                    color: NotchV2DesignTokens.primaryText
                )
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2SystemRail(viewModel: viewModel)
        }
    }

    private func miniMetricRow(icon: String, title: String, value: String, accent: Color) -> some View {
        NotchV2InfoRow(title: title, value: value, icon: icon, accent: accent, compactValue: true)
    }

    private func statusMetricTile(title: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
            if detail.isEmpty == false {
                Text(detail)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground)
        )
    }

    private var fanControlTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前设备风扇转速")
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)

            Text(viewModel.systemFanSummary)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)

            HStack(spacing: 6) {
                ForEach(viewModel.systemFanControlPresets) { preset in
                    NotchV2SegmentedPill(
                        title: preset.rawValue,
                        isSelected: viewModel.fanControlPreset == preset
                    ) {
                        viewModel.selectFanControlPreset(preset)
                    }
                }
            }

            Text(viewModel.systemFanDetail)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground)
        )
    }

}
