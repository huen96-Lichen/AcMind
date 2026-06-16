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
}

struct ScheduleDashboardView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var dashboardMode: ScheduleDashboardMode = .day
    @State private var selectedSidebarItem: String? = "today"

    private var sidebarSections: [SecondarySidebarSection] {
        [
            SecondarySidebarSection(
                id: "view",
                title: "视图",
                items: [
                    SecondarySidebarItem(id: "today", title: "今日", icon: "sun.max"),
                    SecondarySidebarItem(id: "week", title: "本周", icon: "calendar"),
                    SecondarySidebarItem(id: "month", title: "本月", icon: "calendar.circle"),
                    SecondarySidebarItem(id: "year", title: "年视图", icon: "calendar.badge.clock")
                ]
            ),
            SecondarySidebarSection(
                id: "status",
                title: "状态",
                items: [
                    SecondarySidebarItem(id: "pending", title: "待办", icon: "clock", badge: "\(viewModel.todayEventCount)"),
                    SecondarySidebarItem(id: "completed", title: "已完成", icon: "checkmark.circle")
                ]
            ),
            SecondarySidebarSection(
                id: "settings",
                title: "设置",
                items: [
                    SecondarySidebarItem(id: "scheduleSettings", title: "日程设置", icon: "gearshape")
                ]
            )
        ]
    }

    var body: some View {
        AcWorkShell(
            title: "日程",
            subtitle: "\(viewModel.todayEventCount) 项待办",
            headerActions: AnyView(headerActions),
            leadingRailWidth: 208,
            trailingRailWidth: 224,
            leadingRail: {
                SecondarySidebarWithHeader(
                    title: "日程",
                    subtitle: "\(viewModel.todayEventCount) 项待办",
                    sections: sidebarSections,
                    selectedItem: $selectedSidebarItem,
                    footerAction: { viewModel.openCreateEvent() },
                    footerTitle: "新建日程",
                    footerIcon: "plus"
                )
            },
            content: {
                dayContentShell
            },
            trailingRail: {
                scheduleRightRail
            }
        )
        .background(AppSurfaceBackdrop())
        .sheet(isPresented: $viewModel.isCreatingEvent) {
            ScheduleEventEditorSheet(viewModel: viewModel)
        }
        .onChange(of: selectedSidebarItem) { _, newValue in
            switch newValue {
            case "today": dashboardMode = .day
            case "week": dashboardMode = .week
            case "month": dashboardMode = .month
            case "year": dashboardMode = .year
            default: break
            }
        }
    }

    private var dayContentShell: some View {
        VStack(spacing: 0) {
            if let accessNotice = viewModel.accessNotice {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    Text(accessNotice)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 14) {
            Picker("模式", selection: $dashboardMode) {
                ForEach(ScheduleDashboardMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 152)
            .onChange(of: dashboardMode) { _, newMode in
                switch newMode {
                case .day: selectedSidebarItem = "today"
                case .week: selectedSidebarItem = "week"
                case .month: selectedSidebarItem = "month"
                case .year: selectedSidebarItem = "year"
                }
            }

            Button {
                viewModel.goToPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.goToToday()
            } label: {
                Text("今天")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppSurfaceTokens.accentPrimary)

            Button {
                viewModel.goToNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            planningOverviewCard

            switch dashboardMode {
            case .day:
                dayOverview
            case .week:
                weekOverview
            case .month:
                monthOverview
            case .year:
                yearOverview
            }
        }
    }

    private var dayOverview: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                todayEventsCard
                timelineCard
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 16) {
                nextEventCard
                dayStatsCard
            }
            .frame(width: 224)
        }
    }

    private var planningOverviewCard: some View {
        SchedulePlanningSnapshotCard(
            viewModel: viewModel,
            snapshot: viewModel.planningSnapshot(for: viewModel.selectedDate)
        )
    }

    private var todayEventsCard: some View {
        AppSurfaceCard(title: "今日日程", subtitle: "\(viewModel.todayEvents.count) 项", padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.todayEvents.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary.opacity(0.3))
                            Text("今天还没有安排")
                                .font(.caption)
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 18)
                } else {
                    ForEach(viewModel.todayEvents.prefix(6)) { event in
                        Button {
                            viewModel.selectDate(event.startAt)
                        } label: {
                            ScheduleEventCompactRow(
                                event: event,
                                categoryName: event.categoryId.isEmpty ? "未分类" : viewModel.categoryName(for: event.categoryId),
                                categoryColor: categoryColor(for: event.categoryId),
                                referenceDate: Date(),
                                onEdit: {
                                    viewModel.openEditEvent(event)
                                },
                                onDelete: {
                                    viewModel.deleteEvent(event.id)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var timelineCard: some View {
        AppSurfaceCard(title: "时间线", subtitle: "双击空白处创建", padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text(Date(), format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

                let cal = Calendar.current
                let hours = timelineHours

                ForEach(hours, id: \.self) { hour in
                    let hourEvents = viewModel.todayEvents.filter {
                        cal.component(.hour, from: $0.startAt) == hour && $0.status != .cancelled
                    }

                    HStack(spacing: 12) {
                        Text(String(format: "%02d:00", hour))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .frame(width: 48, alignment: .leading)

                        if hourEvents.isEmpty {
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .fill(AppSurfaceTokens.cardBackground)
                                .frame(height: 36)
                                .overlay(
                                    Text("双击添加任务")
                                        .font(.caption)
                                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                                )
                                .onTapGesture(count: 2) {
                                    viewModel.openCreateEvent(on: viewModel.selectedDate, hour: hour, minute: 0)
                                }
                        } else {
                            VStack(spacing: 4) {
                                ForEach(hourEvents) { event in
                                    HStack {
                                        Circle()
                                            .fill(viewModel.categoryColor(for: event.categoryId))
                                            .frame(width: 6, height: 6)
                                        Text(event.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                            .fill(viewModel.categoryColor(for: event.categoryId).opacity(0.12))
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var timelineHours: [Int] {
        let cal = Calendar.current
        let eventHours = viewModel.todayEvents
            .filter { $0.status != .cancelled }
            .map { cal.component(.hour, from: $0.startAt) }
        let uniqueHours = Set(eventHours)
        let defaultHours: Set<Int> = [9, 12, 15, 18]
        let allHours = uniqueHours.union(defaultHours)
        return allHours.sorted()
    }

    private var scheduleRightRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                AppSurfaceCard(title: "今日摘要", subtitle: "快速查看当前状态", padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        dashboardTopBadge(icon: "calendar", title: viewModel.viewTitle, tint: AppSurfaceTokens.accentBlue)
                        dashboardTopBadge(icon: "clock", title: "\(viewModel.todayEventCount) 项待办", tint: AppSurfaceTokens.accentGreen)
                        dashboardTopBadge(
                            icon: "checkmark.circle",
                            title: "已完成 \(viewModel.todayEvents.filter { $0.status == .done }.count)",
                            tint: AppSurfaceTokens.accentGreen
                        )
                    }
                }

                AppSurfaceCard(title: "快捷操作", subtitle: "保持外壳稳定", padding: 12) {
                    VStack(spacing: 6) {
                        Button("今天") { viewModel.goToToday() }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        Button("新建日程") { viewModel.openCreateEvent() }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(14)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private func dashboardTopBadge(icon: String, title: String, tint: Color = AppSurfaceTokens.secondaryText) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
    }

    private var nextEventCard: some View {
        AppSurfaceCard(title: "时间锚点", subtitle: "当前时段与下一件", padding: 16) {
            let snapshot = viewModel.planningSnapshot(for: viewModel.selectedDate)

            if let current = snapshot.currentEvent {
                ScheduleEventCompactRow(
                    event: current,
                    categoryName: viewModel.categoryName(for: current.categoryId),
                    categoryColor: categoryColor(for: current.categoryId),
                    referenceDate: Date()
                )
            } else if let next = snapshot.nextEvent {
                ScheduleEventCompactRow(
                    event: next,
                    categoryName: viewModel.categoryName(for: next.categoryId),
                    categoryColor: categoryColor(for: next.categoryId),
                    referenceDate: Date()
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今天暂无事件")
                        .font(.system(size: 13, weight: .medium))
                    Text("可以直接从右侧新建日程，或者在时间线双击空白处创建。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
        }
    }

    private var dayStatsCard: some View {
        AppSurfaceCard(title: "今日统计", subtitle: "关键数量概览", padding: 16) {
            let snapshot = viewModel.planningSnapshot(for: viewModel.selectedDate)

            VStack(alignment: .leading, spacing: 12) {
                statRow(label: "待办", value: "\(snapshot.activeEventCount)")
                statRow(label: "专注分钟", value: "\(viewModel.todayFocusMinutes)")
                statRow(label: "饱和度", value: "\(viewModel.todayWorkloadPercent)%")
                statRow(label: "全天", value: "\(snapshot.allDayEventCount)")
                statRow(label: "逾期", value: "\(snapshot.overdueEventCount)")
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }

    private var weekOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            weekGridCard
            weekEventsCard
        }
    }

    private var weekGridCard: some View {
        AppSurfaceCard(title: "周视图", subtitle: "一周负载分布", padding: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 12) {
                ForEach(viewModel.weekWorkloadDays) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.date, format: .dateTime.weekday(.narrow))
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                            .fill(heatColor(for: day.workloadPercent))
                            .frame(height: 48)
                        Text("\(day.eventCount) 项")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.tertiaryText)
                    }
                }
            }
        }
    }

    private var weekEventsCard: some View {
        AppSurfaceCard(title: "本周事件", subtitle: "最近 8 条", padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.currentWeekEvents.prefix(8)) { event in
                    ScheduleEventCompactRow(
                        event: event,
                        categoryName: viewModel.categoryName(for: event.categoryId),
                        categoryColor: categoryColor(for: event.categoryId),
                        referenceDate: Date(),
                        onEdit: {
                            viewModel.openEditEvent(event)
                        },
                        onDelete: {
                            viewModel.deleteEvent(event.id)
                        }
                    )
                }
            }
        }
    }

    private var monthOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            monthGridCard
            monthEventsCard
        }
    }

    private var monthGridCard: some View {
        AppSurfaceCard(title: "月视图", subtitle: "本月日期热图", padding: 16) {
            let cal = Calendar.current
            let monthInterval = cal.dateInterval(of: .month, for: viewModel.selectedDate)!
            let daysInMonth = cal.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day!
            let firstWeekday = cal.component(.weekday, from: monthInterval.start)
            let leadingBlanks = (firstWeekday - cal.firstWeekday + 7) % 7

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(0..<(leadingBlanks + daysInMonth), id: \.self) { index in
                    if index < leadingBlanks {
                        Color.clear.frame(height: 42)
                    } else {
                        let day = index - leadingBlanks + 1
                        let date = cal.date(byAdding: .day, value: day - 1, to: monthInterval.start)!
                        let isSelected = cal.isDate(date, inSameDayAs: viewModel.selectedDate)
                        let hasEvent = viewModel.hasEvents(on: date)
                        let isToday = cal.isDateInToday(date)

                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                            .fill(isSelected ? AppSurfaceTokens.accentPrimary.opacity(0.85) : AppSurfaceTokens.cardBackground)
                            .frame(height: 42)
                            .overlay(
                                VStack(spacing: 2) {
                                    Text("\(day)")
                                        .font(.system(size: 12, weight: isToday ? .bold : .semibold))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                    if hasEvent {
                                        Circle()
                                            .fill(isSelected ? .white.opacity(0.8) : AppSurfaceTokens.accentOrange)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                            )
                            .onTapGesture {
                                viewModel.selectDate(date)
                            }
                    }
                }
            }
        }
    }

    private var monthEventsCard: some View {
        AppSurfaceCard(title: "本月事件", subtitle: "最近 6 条", padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.currentMonthEvents.prefix(6)) { event in
                    ScheduleEventCompactRow(
                        event: event,
                        categoryName: viewModel.categoryName(for: event.categoryId),
                        categoryColor: categoryColor(for: event.categoryId),
                        referenceDate: Date(),
                        onEdit: {
                            viewModel.openEditEvent(event)
                        },
                        onDelete: {
                            viewModel.deleteEvent(event.id)
                        }
                    )
                }
            }
        }
    }

    private var yearOverview: some View {
        YearCalendarView(viewModel: viewModel)
    }

    private func heatColor(for percent: Int) -> Color {
        switch percent {
        case 0:
            return AppSurfaceTokens.cardBackground
        case 1..<25:
            return AppSurfaceTokens.accentPrimary.opacity(0.25)
        case 25..<50:
            return AppSurfaceTokens.accentPrimary.opacity(0.45)
        case 50..<75:
            return AppSurfaceTokens.accentPrimary.opacity(0.7)
        default:
            return AppSurfaceTokens.accentPrimary
        }
    }

    private func categoryColor(for categoryId: String) -> Color {
        if let category = viewModel.categories.first(where: { $0.id == categoryId }) {
            return category.color
        }
        return .gray
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
