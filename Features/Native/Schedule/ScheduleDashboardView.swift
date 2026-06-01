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
        HSplitView {
            SecondarySidebarWithHeader(
                title: "日程",
                subtitle: "\(viewModel.todayEventCount) 项待办",
                sections: sidebarSections,
                selectedItem: $selectedSidebarItem,
                footerAction: { viewModel.openCreateEvent() },
                footerTitle: "新建日程",
                footerIcon: "plus"
            )
            .frame(width: 220)

            mainContent
        }
        .background(AppSurfaceTokens.islandBackground.ignoresSafeArea())
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

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            if let accessNotice = viewModel.accessNotice {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    Text(accessNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private var topBar: some View {
        HStack(spacing: 14) {
            Text(viewModel.viewTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Spacer()

            Picker("模式", selection: $dashboardMode) {
                ForEach(ScheduleDashboardMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
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
            .tint(AppSurfaceTokens.accentPurple)

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
            .frame(width: 280)
        }
    }

    private var todayEventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日日程")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(viewModel.todayEvents.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.todayEvents.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary.opacity(0.3))
                        Text("今天还没有安排")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(viewModel.todayEvents.prefix(6)) { event in
                    Button {
                        viewModel.selectDate(event.startAt)
                    } label: {
                        HStack(spacing: 12) {
                            Text(event.startAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.accentPurple)
                                .frame(width: 48, alignment: .leading)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(categoryColor(for: event.categoryId))
                                .frame(width: 3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                Text(event.categoryId.isEmpty ? "未分类" : viewModel.categoryName(for: event.categoryId))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppSurfaceTokens.cardBackgroundSoft))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("编辑") {
                            viewModel.openEditEvent(event)
                        }

                        Button("删除", role: .destructive) {
                            viewModel.deleteEvent(event.id)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间线")
                .font(.system(size: 15, weight: .semibold))

            ForEach([9, 11, 14, 16, 19], id: \.self) { hour in
                HStack(spacing: 12) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .leading)

                    RoundedRectangle(cornerRadius: 8)
                            .fill(AppSurfaceTokens.cardBackgroundSoft)
                        .frame(height: 36)
                        .overlay(
                            Text("双击添加任务")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        )
                        .onTapGesture(count: 2) {
                            viewModel.openCreateEvent(on: viewModel.selectedDate, hour: hour, minute: 0)
                        }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var nextEventCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("下一事件")
                .font(.system(size: 15, weight: .semibold))

            if let next = viewModel.todayEvents.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text(next.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(next.startAt.formatted(date: .omitted, time: .shortened)) - \(next.endAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("今天暂无事件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var dayStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日统计")
                .font(.system(size: 15, weight: .semibold))

            statRow(label: "待办", value: "\(viewModel.todayEventCount)")
            statRow(label: "专注分钟", value: "\(viewModel.todayFocusMinutes)")
            statRow(label: "饱和度", value: "\(viewModel.todayWorkloadPercent)%")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("周视图")
                .font(.system(size: 15, weight: .semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 12) {
                ForEach(viewModel.weekWorkloadDays) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.date, format: .dateTime.weekday(.narrow))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(heatColor(for: day.workloadPercent))
                            .frame(height: 48)
                        Text("\(day.eventCount) 项")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var weekEventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本周事件")
                .font(.system(size: 15, weight: .semibold))

            ForEach(viewModel.currentWeekEvents.prefix(8)) { event in
                HStack {
                    Text(event.title)
                        .font(.system(size: 13))
                    Spacer()
                    Text(event.startAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(AppSurfaceTokens.cardBackgroundSoft))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var monthOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            monthGridCard
            monthEventsCard
        }
    }

    private var monthGridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("月视图")
                .font(.system(size: 15, weight: .semibold))

            let days = Array(1...30)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(day % 5 == 0 ? AppSurfaceTokens.accentPurple.opacity(0.85) : AppSurfaceTokens.cardBackgroundSoft)
                        .frame(height: 42)
                        .overlay(
                            Text("\(day)")
                                .font(.system(size: 12, weight: .semibold))
                        )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var monthEventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本月事件")
                .font(.system(size: 15, weight: .semibold))

            ForEach(viewModel.currentMonthEvents.prefix(6)) { event in
                HStack {
                    Text(event.title)
                        .font(.system(size: 13))
                    Spacer()
                    Text(event.startAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(AppSurfaceTokens.cardBackgroundSoft))
                .contextMenu {
                    Button("编辑") {
                        viewModel.openEditEvent(event)
                    }

                    Button("删除", role: .destructive) {
                        viewModel.deleteEvent(event.id)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var yearOverview: some View {
        YearCalendarView(viewModel: viewModel)
    }

    private func heatColor(for percent: Int) -> Color {
        switch percent {
        case 0:
            return AppSurfaceTokens.cardBackgroundSoft
        case 1..<25:
            return AppSurfaceTokens.accentPurple.opacity(0.25)
        case 25..<50:
            return AppSurfaceTokens.accentPurple.opacity(0.45)
        case 50..<75:
            return AppSurfaceTokens.accentPurple.opacity(0.7)
        default:
            return AppSurfaceTokens.accentPurple
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
                .foregroundStyle(.secondary)

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
                .tint(AppSurfaceTokens.accentPurple)
            }
            .padding(20)
            .background(AppSurfaceTokens.secondarySidebarBackground)

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
