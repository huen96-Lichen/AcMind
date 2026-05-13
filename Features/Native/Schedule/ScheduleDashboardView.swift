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

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()
                .overlay(AppSurfaceTokens.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topBar
                    content
                }
                .padding(28)
            }
        }
        .background(AppSurfaceTokens.islandBackground.ignoresSafeArea())
        .sheet(isPresented: $viewModel.isCreatingEvent) {
            ScheduleEventEditorSheet(viewModel: viewModel)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("日程表")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text("今日待办、饱和度和分类总览")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            AppSurfaceCard(title: "今日概览", subtitle: "高密度时间管理") {
                VStack(alignment: .leading, spacing: 10) {
                    ScheduleKeyValueRow(key: "待办", value: "\(viewModel.todayEventCount)")
                    ScheduleKeyValueRow(key: "专注分钟", value: "\(viewModel.todayFocusMinutes)")
                    ScheduleKeyValueRow(key: "饱和度", value: "\(viewModel.todayWorkloadPercent)%")
                }
            }

            AppSurfaceCard(title: "分类", subtitle: "快速切换") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.categories.prefix(6)) { category in
                        HStack(spacing: 8) {
                            Circle().fill(category.color).frame(width: 8, height: 8)
                            Text(category.name)
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Spacer()
                            Text("\(viewModel.todayCount(for: category.id))")
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                }
            }

            AppSurfaceCard(title: "工作饱和度", subtitle: "最近 7 天") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(viewModel.weekWorkloadDays.prefix(7)) { day in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(heatColor(for: day.workloadPercent))
                                .frame(height: 18)
                            Text(day.date, format: .dateTime.weekday(.narrow))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.tertiaryText)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                viewModel.openCreateEvent()
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("快速新建任务")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundStrong)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(width: 280)
        .padding(20)
        .background(AppSurfaceTokens.islandBackgroundSoft)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Text(viewModel.viewTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Spacer()

            Picker("模式", selection: $dashboardMode) {
                ForEach(ScheduleDashboardMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Button {
                viewModel.goToPrevious()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.goToToday()
            } label: {
                Text("今天")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppSurfaceTokens.accentPurple)

            Button {
                viewModel.goToNext()
            } label: {
                Image(systemName: "chevron.right")
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
            AppSurfaceCard(title: "今日日程", subtitle: "双击时间块快速创建") {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.todayEvents.isEmpty {
                        Text("今天还没有安排")
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    } else {
                        ForEach(viewModel.todayEvents.prefix(6)) { event in
                            Button {
                                viewModel.selectDate(event.startAt)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Text(event.startAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                                        .foregroundStyle(AppSurfaceTokens.accentPurple)
                                        .frame(width: 56, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title)
                                            .foregroundStyle(AppSurfaceTokens.primaryText)
                                        Text(event.categoryId.isEmpty ? "未分类" : viewModel.categoryName(for: event.categoryId))
                                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                                    }
                                    Spacer()
                                }
                                .font(.system(size: 13, weight: .medium))
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 20) {
                AppSurfaceCard(title: "日视图", subtitle: "时间块与快速创建") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach([9, 11, 14, 16, 19], id: \.self) { hour in
                            HStack(spacing: 10) {
                                Text(String(format: "%02d:00", hour))
                                    .foregroundStyle(AppSurfaceTokens.accentPurple)
                                    .frame(width: 56, alignment: .leading)
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppSurfaceTokens.cardBackground)
                                    .frame(height: 34)
                                    .overlay(
                                        Text("双击添加任务")
                                            .foregroundStyle(AppSurfaceTokens.tertiaryText)
                                            .font(.system(size: 12, weight: .medium))
                                    )
                                    .onTapGesture(count: 2) {
                                        viewModel.openCreateEvent(on: viewModel.selectedDate, hour: hour, minute: 0)
                                    }
                            }
                        }
                    }
                }

                AppSurfaceCard(title: "下一事件", subtitle: "即将开始") {
                    if let next = viewModel.todayEvents.first {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(next.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text("\(next.startAt.formatted(date: .omitted, time: .shortened)) - \(next.endAt.formatted(date: .omitted, time: .shortened))")
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                    } else {
                        Text("今天暂无事件")
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
            }
            .frame(width: 300)
        }
    }

    private var weekOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurfaceCard(title: "周视图", subtitle: "一周饱和度与事件密度") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 12) {
                    ForEach(viewModel.weekWorkloadDays) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day.date, format: .dateTime.weekday(.narrow))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(heatColor(for: day.workloadPercent))
                                .frame(height: 38)
                            Text("\(day.eventCount) 项")
                                .foregroundStyle(AppSurfaceTokens.tertiaryText)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }
            }

            AppSurfaceCard(title: "本周事件", subtitle: "统一宽度内容区") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.currentWeekEvents.prefix(8)) { event in
                        ScheduleKeyValueRow(key: event.title, value: event.startAt.formatted(date: .omitted, time: .shortened))
                    }
                }
            }
        }
    }

    private var monthOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurfaceCard(title: "月视图", subtitle: "事件分布") {
                let days = Array(1...30)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(day % 5 == 0 ? AppSurfaceTokens.accentPurple.opacity(0.85) : AppSurfaceTokens.cardBackground)
                            .frame(height: 42)
                            .overlay(
                                Text("\(day)")
                                    .foregroundStyle(AppSurfaceTokens.primaryText)
                                    .font(.system(size: 12, weight: .semibold))
                            )
                    }
                }
            }

            AppSurfaceCard(title: "本月事件", subtitle: "摘要") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.currentMonthEvents.prefix(6)) { event in
                        ScheduleKeyValueRow(key: event.title, value: event.startAt.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
        }
    }

    private var yearOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurfaceCard(title: "年视图", subtitle: "年度热力图") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 13), spacing: 4) {
                    ForEach(viewModel.yearlyWorkloadDays.prefix(130)) { day in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(heatColor(for: day.workloadPercent))
                            .frame(height: 14)
                    }
                }
            }

            HStack(spacing: 20) {
                AppSurfaceCard(title: "年度统计", subtitle: "活跃日") {
                    ScheduleKeyValueRow(key: "活跃日", value: "\(viewModel.yearlyStats.activeDays)")
                    ScheduleKeyValueRow(key: "平均饱和度", value: "\(viewModel.yearlyStats.avgWorkload)%")
                }
                AppSurfaceCard(title: "分类状态", subtitle: "今年累计") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.categories.prefix(4)) { category in
                            ScheduleKeyValueRow(key: category.name, value: "\(viewModel.weekCount(for: category.id))")
                        }
                    }
                }
            }
        }
    }

    private func heatColor(for percent: Int) -> Color {
        switch percent {
        case 0:
            return AppSurfaceTokens.cardBackground
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") {
                    viewModel.closeCreateEvent()
                    dismiss()
                }
                .foregroundStyle(AppSurfaceTokens.secondaryText)

                Spacer()

                Text("新建日程")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Button("保存") {
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
            .background(AppSurfaceTokens.islandBackground)

            Divider().overlay(AppSurfaceTokens.separator)

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
            .background(AppSurfaceTokens.islandBackgroundSoft)
        }
        .frame(width: 440, height: 340)
    }
}

private struct ScheduleKeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack {
            Text(key)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .font(.system(size: 13, weight: .medium))
    }
}
