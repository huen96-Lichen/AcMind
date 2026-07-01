import SwiftUI
import AppKit

enum ScheduleDashboardMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        }
    }

    var todayButtonTitle: String {
        switch self {
        case .day: return "今天"
        case .week: return "本周"
        case .month: return "本月"
        case .year: return "今年"
        }
    }
}

struct ScheduleDashboardView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var dashboardMode: ScheduleDashboardMode = .day

    var body: some View {
        AcWorkShell(
            title: "日程",
            subtitle: pageSubtitle,
            headerActions: AnyView(headerActions),
            leadingRailWidth: 0,
            trailingRailWidth: 0,
            leadingRail: { EmptyView() },
            content: { scheduleCanvas },
            trailingRail: { EmptyView() }
        )
        .background(AppVisualBackdrop())
        .sheet(isPresented: $viewModel.isCreatingEvent) {
            ScheduleEventEditorSheet(viewModel: viewModel)
        }
    }

    private var scheduleCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusRow

                HStack(alignment: .top, spacing: 14) {
                    primarySurface
                        .frame(maxWidth: .infinity)

                    ScheduleAgendaInspector(viewModel: viewModel, mode: dashboardMode)
                        .frame(width: 300)
                }

                footerSummary
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: 1240, alignment: .leading)
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private var primarySurface: some View {
        switch dashboardMode {
        case .day:
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    AppSurfaceCard(title: "今日日程", subtitle: "\(viewModel.events(for: viewModel.selectedDate).count) 项安排", padding: 12) {
                        todaySummaryContent
                    }
                    AppSurfaceCard(title: "时间锚点", subtitle: "当前日期与关键区间", padding: 12) {
                        Text(rangeTitle)
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    AppSurfaceCard(title: "今日统计", subtitle: "完成度与饱和度", padding: 12) {
                        Text("\(eventCountForCurrentMode) 项安排 · 饱和度 \(workloadPercentForCurrentMode)%")
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
                AppSurfaceCard(title: "时间线", subtitle: "按时间排序的日程", padding: 12) {
                    ScheduleDayTimelinePanel(viewModel: viewModel)
                }
            }
        case .week:
            VStack(alignment: .leading, spacing: 12) {
                AppSurfaceCard(title: "周视图", subtitle: pageSubtitle, padding: 12) {
                    ScheduleWeekGridPanel(viewModel: viewModel)
                }
                AppSurfaceCard(title: "本周事件", subtitle: "\(viewModel.currentWeekEvents.count) 项安排", padding: 12) {
                    scheduleEventList(viewModel.currentWeekEvents)
                }
            }
        case .month:
            VStack(alignment: .leading, spacing: 12) {
                AppSurfaceCard(title: "月视图", subtitle: pageSubtitle, padding: 12) {
                    ScheduleMonthGridPanel(viewModel: viewModel)
                }
                AppSurfaceCard(title: "本月事件", subtitle: "\(viewModel.currentMonthEvents.count) 项安排", padding: 12) {
                    scheduleEventList(viewModel.currentMonthEvents)
                }
            }
        case .year:
            ScheduleYearGridPanel(viewModel: viewModel)
        }
    }

    private var todaySummaryContent: some View {
        let events = viewModel.events(for: viewModel.selectedDate)
        return VStack(alignment: .leading, spacing: 6) {
            Text(events.isEmpty ? "今天暂无日程" : events.prefix(3).map(\.title).joined(separator: " / "))
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(2)
        }
    }

    private func scheduleEventList(_ events: [ScheduleEvent]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if events.isEmpty {
                Text("暂无事件")
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            } else {
                ForEach(events.prefix(5)) { event in
                    Text(event.title)
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 10) {
            Picker("模式", selection: $dashboardMode) {
                ForEach(ScheduleDashboardMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 168)
            .onChange(of: dashboardMode) { _, mode in
                switch mode {
                case .day, .week:
                    viewModel.viewMode = .week
                case .month:
                    viewModel.viewMode = .month
                case .year:
                    viewModel.viewMode = .year
                }
            }

            Button { moveSelection(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.goToToday()
            } label: {
                Text(dashboardMode.todayButtonTitle)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppSurfaceTokens.accentPrimary)

            Button { moveSelection(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.openCreateEvent()
            } label: {
                Label("新建日程", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppSurfaceTokens.accentPrimary)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Text(rangeTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Text("本地日历 · \(viewModel.accessNotice == nil ? "已同步" : "仅本地")")
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            if viewModel.accessNotice != nil {
                Label("系统日历未授权", systemImage: "calendar.badge.exclamationmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppSurfaceTokens.accentOrange.opacity(0.09))
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }

    private var footerSummary: some View {
        let snapshot = viewModel.planningSnapshot(for: viewModel.selectedDate)
        return Text("\(eventCountForCurrentMode) 项安排 · \(snapshot.completedEventCount) 项完成 · 饱和度 \(workloadPercentForCurrentMode)%")
            .font(.system(size: 12))
            .foregroundStyle(AppSurfaceTokens.secondaryText)
            .padding(.horizontal, 2)
    }

    private var pageSubtitle: String {
        switch dashboardMode {
        case .day:
            return "\(viewModel.events(for: viewModel.selectedDate).count) 项安排"
        case .week:
            return "本周 \(viewModel.currentWeekEvents.count) 项安排"
        case .month:
            return "\(monthTitle) · \(viewModel.currentMonthEvents.count) 项安排"
        case .year:
            return "\(yearTitle) · 关键节奏"
        }
    }

    private var rangeTitle: String {
        switch dashboardMode {
        case .day:
            return format(viewModel.selectedDate, "M月d日 EEEE")
        case .week:
            let cal = Calendar.current
            guard let start = cal.dateInterval(of: .weekOfYear, for: viewModel.selectedDate)?.start,
                  let end = cal.date(byAdding: .day, value: 6, to: start) else {
                return "本周"
            }
            return "\(format(start, "M月d日")) – \(format(end, "M月d日"))"
        case .month:
            return format(viewModel.selectedDate, "yyyy年M月")
        case .year:
            return "\(yearTitle) 年度视图"
        }
    }

    private var monthTitle: String { format(viewModel.selectedDate, "M月") }
    private var yearTitle: String { format(viewModel.selectedDate, "yyyy年") }

    private var eventCountForCurrentMode: Int {
        switch dashboardMode {
        case .day: return viewModel.events(for: viewModel.selectedDate).count
        case .week: return viewModel.currentWeekEvents.count
        case .month: return viewModel.currentMonthEvents.count
        case .year: return viewModel.currentYearEvents.count
        }
    }

    private var workloadPercentForCurrentMode: Int {
        switch dashboardMode {
        case .day:
            let minutes = viewModel.events(for: viewModel.selectedDate).reduce(0) { $0 + $1.durationMinutes }
            return min(Int(Double(minutes) / 600.0 * 100), 100)
        case .week:
            let days = viewModel.weekWorkloadDays
            return days.isEmpty ? 0 : days.map(\.workloadPercent).reduce(0, +) / days.count
        case .month:
            let minutes = viewModel.currentMonthEvents.reduce(0) { $0 + $1.durationMinutes }
            return min(Int(Double(minutes) / (600.0 * 22.0) * 100), 100)
        case .year:
            return viewModel.yearlyStats.avgWorkload
        }
    }

    private func moveSelection(_ direction: Int) {
        let cal = Calendar.current
        switch dashboardMode {
        case .day:
            viewModel.selectedDate = cal.date(byAdding: .day, value: direction, to: viewModel.selectedDate) ?? viewModel.selectedDate
        case .week:
            viewModel.viewMode = .week
            direction < 0 ? viewModel.goToPrevious() : viewModel.goToNext()
        case .month:
            viewModel.viewMode = .month
            direction < 0 ? viewModel.goToPrevious() : viewModel.goToNext()
        case .year:
            viewModel.viewMode = .year
            direction < 0 ? viewModel.goToPrevious() : viewModel.goToNext()
        }
    }
}

private struct ScheduleDayTimelinePanel: View {
    @ObservedObject var viewModel: ScheduleViewModel
    private let hours = Array(8...18)
    private let calendar = Calendar.current

    private var events: [ScheduleEvent] {
        viewModel.events(for: viewModel.selectedDate)
    }

    private var timedEvents: [ScheduleEvent] {
        events.filter { !$0.isAllDay }
    }

    private var allDayEvents: [ScheduleEvent] {
        events.filter(\.isAllDay)
    }

    var body: some View {
        SchedulePanel {
            VStack(spacing: 0) {
                HStack {
                    Text("全天")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .frame(width: 54, alignment: .trailing)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if allDayEvents.isEmpty {
                                Text("无全天安排")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
                            } else {
                                ForEach(allDayEvents) { event in
                                    ScheduleEventChip(event: event, tint: viewModel.categoryColor(for: event.categoryId))
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

                Divider()

                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            ForEach(hours, id: \.self) { hour in
                                HStack(spacing: 12) {
                                    Text(String(format: "%02d:00", hour))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                                        .frame(width: 54, alignment: .trailing)

                                    Rectangle()
                                        .fill(AppSurfaceTokens.separator.opacity(0.55))
                                        .frame(height: 1)
                                }
                                .frame(height: hourHeight(proxy.size.height), alignment: .top)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 10)

                        ForEach(timedEvents) { event in
                            ScheduleTimelineEventBlock(
                                event: event,
                                tint: viewModel.categoryColor(for: event.categoryId)
                            )
                            .frame(width: max(160, proxy.size.width - 116), height: blockHeight(for: event, totalHeight: proxy.size.height))
                            .offset(x: 90, y: blockY(for: event, totalHeight: proxy.size.height) + 10)
                            .onTapGesture { viewModel.openEditEvent(event) }
                        }

                        if calendar.isDateInToday(viewModel.selectedDate),
                           let y = currentTimeY(totalHeight: proxy.size.height) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red.opacity(0.85))
                                    .frame(width: 7, height: 7)
                                Rectangle()
                                    .fill(Color.red.opacity(0.45))
                                    .frame(height: 1)
                            }
                            .offset(x: 84, y: y + 10)
                        }
                    }
                }
                .frame(minHeight: 600)
                .padding(.bottom, 10)
            }
        }
    }

    private func hourHeight(_ totalHeight: CGFloat) -> CGFloat {
        max(48, (totalHeight - 20) / CGFloat(hours.count))
    }

    private func blockY(for event: ScheduleEvent, totalHeight: CGFloat) -> CGFloat {
        let start = calendar.component(.hour, from: event.startAt) * 60 + calendar.component(.minute, from: event.startAt)
        let base = hours.first! * 60
        return max(0, CGFloat(start - base) / 60.0 * hourHeight(totalHeight))
    }

    private func blockHeight(for event: ScheduleEvent, totalHeight: CGFloat) -> CGFloat {
        max(34, CGFloat(event.durationMinutes) / 60.0 * hourHeight(totalHeight) - 4)
    }

    private func currentTimeY(totalHeight: CGFloat) -> CGFloat? {
        let now = Date()
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let minMinute = hours.first! * 60
        let maxMinute = (hours.last! + 1) * 60
        guard minutes >= minMinute, minutes <= maxMinute else { return nil }
        return CGFloat(minutes - minMinute) / 60.0 * hourHeight(totalHeight)
    }
}

private struct ScheduleWeekGridPanel: View {
    @ObservedObject var viewModel: ScheduleViewModel
    private let calendar = Calendar.current
    private let hours = Array(8...18)
    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        SchedulePanel {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 54)
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                        VStack(spacing: 4) {
                            Text(weekdayLabels[index])
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 16, weight: calendar.isDateInToday(date) ? .semibold : .medium))
                                .foregroundStyle(calendar.isDateInToday(date) ? AppSurfaceTokens.accentPrimary : AppSurfaceTokens.primaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(calendar.isDateInToday(date) ? AppSurfaceTokens.accentPrimary.opacity(0.06) : Color.clear)
                    }
                }

                Divider()

                HStack(spacing: 0) {
                    Text("全天")
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .frame(width: 54, alignment: .trailing)
                        .padding(.trailing, 10)
                    ForEach(weekDates, id: \.self) { date in
                        let events = viewModel.events(for: date).filter(\.isAllDay)
                        HStack(spacing: 4) {
                            ForEach(events.prefix(1)) { event in
                                ScheduleEventChip(event: event, tint: viewModel.categoryColor(for: event.categoryId))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                    }
                }
                .padding(.vertical, 4)

                Divider()

                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            ForEach(hours, id: \.self) { hour in
                                HStack(spacing: 0) {
                                    Text(String(format: "%02d:00", hour))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                                        .frame(width: 54, alignment: .trailing)
                                        .padding(.trailing, 10)

                                    ForEach(weekDates, id: \.self) { date in
                                        Rectangle()
                                            .fill(calendar.isDateInToday(date) ? AppSurfaceTokens.accentPrimary.opacity(0.035) : Color.clear)
                                            .overlay(AppSurfaceTokens.separator.opacity(0.45), in: Rectangle().stroke(lineWidth: 0.5))
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .frame(height: hourHeight(proxy.size.height))
                            }
                        }

                        ForEach(weekDates, id: \.self) { date in
                            ForEach(viewModel.events(for: date).filter { !$0.isAllDay }) { event in
                                let dayIndex = weekDates.firstIndex(of: date) ?? 0
                                ScheduleWeekEventBlock(event: event, tint: viewModel.categoryColor(for: event.categoryId))
                                    .frame(
                                        width: max(50, (proxy.size.width - 54) / 7 - 8),
                                        height: weekBlockHeight(for: event, totalHeight: proxy.size.height)
                                    )
                                    .offset(
                                        x: 58 + CGFloat(dayIndex) * ((proxy.size.width - 54) / 7) + 4,
                                        y: weekBlockY(for: event, totalHeight: proxy.size.height) + 3
                                    )
                                    .onTapGesture { viewModel.openEditEvent(event) }
                            }
                        }
                    }
                }
                .frame(minHeight: 560)
            }
        }
    }

    private var weekDates: [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func hourHeight(_ totalHeight: CGFloat) -> CGFloat {
        max(42, totalHeight / CGFloat(hours.count))
    }

    private func weekBlockY(for event: ScheduleEvent, totalHeight: CGFloat) -> CGFloat {
        let start = calendar.component(.hour, from: event.startAt) * 60 + calendar.component(.minute, from: event.startAt)
        let base = hours.first! * 60
        return max(0, CGFloat(start - base) / 60.0 * hourHeight(totalHeight))
    }

    private func weekBlockHeight(for event: ScheduleEvent, totalHeight: CGFloat) -> CGFloat {
        max(28, CGFloat(event.durationMinutes) / 60.0 * hourHeight(totalHeight) - 4)
    }
}

private struct ScheduleMonthGridPanel: View {
    @ObservedObject var viewModel: ScheduleViewModel
    private let calendar = Calendar.current
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        SchedulePanel {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                Divider()

                VStack(spacing: 0) {
                    ForEach(Array(monthWeeks.enumerated()), id: \.offset) { index, week in
                        HStack(spacing: 0) {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                                ScheduleMonthDayCell(
                                    date: date,
                                    selectedDate: viewModel.selectedDate,
                                    monthDate: viewModel.selectedDate,
                                    events: viewModel.events(for: date),
                                    viewModel: viewModel
                                )
                            }
                        }
                        if index < monthWeeks.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var monthWeeks: [[Date]] {
        let components = calendar.dateComponents([.year, .month], from: viewModel.selectedDate)
        guard let first = calendar.date(from: components),
              let monthInterval = calendar.dateInterval(of: .month, for: first) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: first)
        let leading = (firstWeekday - 2 + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: first) ?? first
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
            .chunked(into: 7)
            .filter { week in
                week.contains { calendar.isDate($0, equalTo: monthInterval.start, toGranularity: .month) }
            }
    }
}

private struct ScheduleYearGridPanel: View {
    @ObservedObject var viewModel: ScheduleViewModel
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        SchedulePanel {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(months, id: \.self) { month in
                    ScheduleYearMonthCard(month: month, viewModel: viewModel)
                }
            }
            .padding(16)
        }
    }

    private var months: [Date] {
        let components = calendar.dateComponents([.year], from: viewModel.selectedDate)
        guard let start = calendar.date(from: components) else { return [] }
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }
}

private struct ScheduleAgendaInspector: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let mode: ScheduleDashboardMode

    private var snapshot: SchedulePlanningSnapshot {
        viewModel.planningSnapshot(for: viewModel.selectedDate)
    }

    var body: some View {
        VStack(spacing: 12) {
            ScheduleSideCard(title: "下一项") {
                if let next = snapshot.nextEvent ?? snapshot.currentEvent {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(next.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                        Text(next.displayTimeRange())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Text(timeDistanceText(for: next))
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.accentPrimary)
                        Button("查看详情") { viewModel.openEditEvent(next) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    EmptyInspectorState(title: "暂无下一项", subtitle: "今天没有后续日程。")
                }
            }

            ScheduleSideCard(title: "空闲窗口") {
                if let window = snapshot.freeWindow {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(format(window.start, "HH:mm"))–\(format(window.end, "HH:mm"))")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(window.durationMinutes) 分钟")
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Button("安排专注时间") {
                            viewModel.openCreateEvent(
                                on: window.start,
                                hour: Calendar.current.component(.hour, from: window.start),
                                minute: Calendar.current.component(.minute, from: window.start)
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    EmptyInspectorState(title: "暂无明显空档", subtitle: "当前视图没有 30 分钟以上空闲。")
                }
            }

            ScheduleSideCard(title: sideListTitle) {
                VStack(alignment: .leading, spacing: 8) {
                    let list = sideEvents.prefix(5)
                    if list.isEmpty {
                        EmptyInspectorState(title: "暂无安排", subtitle: "可以从右上角新建日程。")
                    } else {
                        ForEach(list) { event in
                            ScheduleCompactEventLine(
                                event: event,
                                tint: viewModel.categoryColor(for: event.categoryId),
                                onTap: { viewModel.openEditEvent(event) }
                            )
                        }
                    }
                }
            }

            if mode == .week || mode == .month || mode == .year {
                ScheduleSideCard(title: rhythmTitle) {
                    ScheduleLoadBars(values: loadValues)
                }
            }
        }
    }

    private var sideListTitle: String {
        switch mode {
        case .day: return "今日待办"
        case .week: return "本周重点"
        case .month: return "近期重点"
        case .year: return "年度里程碑"
        }
    }

    private var rhythmTitle: String {
        switch mode {
        case .day: return "节奏"
        case .week: return "负载"
        case .month: return "月度节奏"
        case .year: return "年度节奏"
        }
    }

    private var sideEvents: [ScheduleEvent] {
        switch mode {
        case .day: return viewModel.events(for: viewModel.selectedDate)
        case .week: return viewModel.currentWeekEvents
        case .month: return viewModel.currentMonthEvents
        case .year: return viewModel.currentYearEvents
        }
    }

    private var loadValues: [Int] {
        switch mode {
        case .day:
            return [viewModel.todayWorkloadPercent]
        case .week:
            return viewModel.weekWorkloadDays.map(\.workloadPercent)
        case .month:
            let grouped = Dictionary(grouping: viewModel.currentMonthEvents) { Calendar.current.component(.weekOfMonth, from: $0.startAt) }
            return (1...5).map { week in min((grouped[week]?.reduce(0) { $0 + $1.durationMinutes } ?? 0) / 60 * 10, 100) }
        case .year:
            let grouped = Dictionary(grouping: viewModel.currentYearEvents) { Calendar.current.component(.month, from: $0.startAt) }
            return (1...12).map { month in min((grouped[month]?.count ?? 0) * 10, 100) }
        }
    }

    private func timeDistanceText(for event: ScheduleEvent) -> String {
        let minutes = Calendar.current.dateComponents([.minute], from: Date(), to: event.startAt).minute ?? 0
        if minutes <= 0 { return "进行中" }
        if minutes < 60 { return "还有 \(minutes) 分钟" }
        return "还有 \(minutes / 60) 小时 \(minutes % 60) 分钟"
    }
}

private struct SchedulePanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
            )
    }
}

private struct ScheduleSideCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct ScheduleEventChip: View {
    let event: ScheduleEvent
    let tint: Color

    var body: some View {
        Text(event.title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10))
            .clipShape(Capsule())
    }
}

private struct ScheduleTimelineEventBlock: View {
    let event: ScheduleEvent
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Text(event.displayTimeRange())
                .font(.system(size: 11))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct ScheduleWeekEventBlock: View {
    let event: ScheduleEvent
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            Text(format(event.startAt, "HH:mm"))
                .font(.system(size: 9))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct ScheduleMonthDayCell: View {
    let date: Date
    let selectedDate: Date
    let monthDate: Date
    let events: [ScheduleEvent]
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: calendar.isDateInToday(date) ? .semibold : .medium))
                    .foregroundStyle(dateColor)
                    .frame(width: 24, height: 24)
                    .background(calendar.isDateInToday(date) ? AppSurfaceTokens.accentPrimary.opacity(0.14) : Color.clear)
                    .clipShape(Circle())
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(events.prefix(2)) { event in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.categoryColor(for: event.categoryId))
                            .frame(width: 5, height: 5)
                        Text(event.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(dateColor)
                            .lineLimit(1)
                    }
                }
                if events.count > 2 {
                    Text("+\(events.count - 2)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(
            calendar.isDate(date, inSameDayAs: selectedDate)
                ? AppSurfaceTokens.accentPrimary.opacity(0.07)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectDate(date) }
    }

    private var dateColor: Color {
        calendar.isDate(date, equalTo: monthDate, toGranularity: .month)
            ? AppSurfaceTokens.primaryText
            : AppSurfaceTokens.tertiaryText
    }
}

private struct ScheduleYearMonthCard: View {
    let month: Date
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(format(month, "M月"))
                .font(.system(size: 13, weight: isCurrentMonth ? .semibold : .medium))
                .foregroundStyle(isCurrentMonth ? AppSurfaceTokens.accentPrimary : AppSurfaceTokens.primaryText)

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 8))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(monthCells.indices, id: \.self) { index in
                    if let date = monthCells[index] {
                        let count = viewModel.events(for: date).count
                        Circle()
                            .fill(dotColor(count: count, isToday: calendar.isDateInToday(date)))
                            .frame(width: 13, height: 13)
                            .overlay {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 7, weight: calendar.isDateInToday(date) ? .semibold : .regular))
                                    .foregroundStyle(count > 2 || calendar.isDateInToday(date) ? .white : AppSurfaceTokens.secondaryText)
                            }
                    } else {
                        Color.clear.frame(width: 13, height: 13)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCurrentMonth ? AppSurfaceTokens.accentPrimary.opacity(0.055) : AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isCurrentMonth ? AppSurfaceTokens.accentPrimary.opacity(0.22) : AppSurfaceTokens.separator.opacity(0.65), lineWidth: 1)
        )
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private var monthCells: [Date?] {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let first = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let leading = (calendar.component(.weekday, from: first) - 2 + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        cells += range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func dotColor(count: Int, isToday: Bool) -> Color {
        if isToday { return AppSurfaceTokens.accentPrimary }
        switch count {
        case 0: return AppSurfaceTokens.separator.opacity(0.55)
        case 1: return AppSurfaceTokens.accentPrimary.opacity(0.25)
        case 2: return AppSurfaceTokens.accentPrimary.opacity(0.45)
        default: return AppSurfaceTokens.accentPrimary.opacity(0.75)
        }
    }
}

private struct ScheduleCompactEventLine: View {
    let event: ScheduleEvent
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)
                    Text(event.displayTimeRange())
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                Spacer(minLength: 0)
                if event.status == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppSurfaceTokens.accentGreen)
                        .font(.system(size: 12))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ScheduleLoadBars: View {
    let values: [Int]

    var body: some View {
        VStack(spacing: 7) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                        .frame(width: 16, alignment: .trailing)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppSurfaceTokens.separator.opacity(0.35))
                            Capsule()
                                .fill(AppSurfaceTokens.accentPrimary.opacity(0.65))
                                .frame(width: proxy.size.width * CGFloat(min(value, 100)) / 100)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }
}

private struct EmptyInspectorState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }
}

private func format(_ date: Date, _ pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = pattern
    return formatter.string(from: date)
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private struct ScheduleEventEditorSheet: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var selectedCategoryId = "personal"
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var durationMinutes = 60
    @State private var isAllDay = false
    private var isEditing: Bool { viewModel.editingEvent != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") {
                    viewModel.closeCreateEvent()
                    dismiss()
                }
                .foregroundStyle(AppSurfaceTokens.secondaryText)

                Spacer()

                Text(isEditing ? "编辑日程" : "新建日程")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Button(isEditing ? "更新" : "保存") {
                    viewModel.createEvent(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        categoryId: selectedCategoryId,
                        startHour: startHour,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        isAllDay: isAllDay
                    )
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(AppSurfaceTokens.accentPrimary)
            }
            .padding(20)
            .background(AppSurfaceTokens.cardBackgroundSoft)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                TextField("输入日程标题", text: $title)
                    .textFieldStyle(.roundedBorder)

                Picker("分类", selection: $selectedCategoryId) {
                    ForEach(viewModel.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }

                Toggle("全天", isOn: $isAllDay)

                HStack {
                    Picker("开始", selection: $startHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .frame(width: 120)

                    Picker("分钟", selection: $startMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .frame(width: 100)
                }

                Picker("时长", selection: $durationMinutes) {
                    ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { duration in
                        Text("\(duration) 分钟").tag(duration)
                    }
                }
            }
            .padding(20)
            .background(AppSurfaceTokens.cardBackgroundSoft)
            .onAppear {
                if let editingEvent = viewModel.editingEvent {
                    title = editingEvent.title
                    selectedCategoryId = editingEvent.categoryId
                    startHour = Calendar.current.component(.hour, from: editingEvent.startAt)
                    startMinute = Calendar.current.component(.minute, from: editingEvent.startAt)
                    durationMinutes = max(15, editingEvent.durationMinutes)
                    isAllDay = editingEvent.isAllDay
                }
            }
        }
        .frame(width: 440, height: 380)
    }
}
