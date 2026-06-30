import SwiftUI
import AppKit

// MARK: - Schedule Sidebar

struct ScheduleSidebar: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    CalendarCategoryList(viewModel: viewModel)
                    TodayOverview(viewModel: viewModel)
                    TodayTodoList(viewModel: viewModel)
                    MiniMonthCalendar(viewModel: viewModel)
                    WorkloadSummary(viewModel: viewModel)
                }
                .padding(16)
            }
        }
        .frame(width: ScheduleLayout.sidebarWidth)
        .background(AppSurfaceTokens.cardBackground.opacity(0.94))
    }
}

// MARK: - 1. Calendar Category List

struct CalendarCategoryList: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日程分类")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 2) {
                ForEach(viewModel.categories) { category in
                    CategoryRow(
                        category: category,
                        todayCount: viewModel.todayCount(for: category.id),
                        weekCount: viewModel.weekCount(for: category.id),
                        isVisible: category.visible,
                        onToggle: { viewModel.toggleCategoryVisibility(category.id) }
                    )
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(0.94))
            )
        }
    }
}

private struct CategoryRow: View {
    let category: ScheduleCategory
    let todayCount: Int
    let weekCount: Int
    let isVisible: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                // 彩色 checkbox
                Image(systemName: isVisible ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(isVisible ? category.color : AppSurfaceTokens.secondaryText.opacity(0.4))

                Text(category.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isVisible ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText.opacity(0.5))
                    .lineLimit(1)

                Spacer()

                    Text("\(todayCount)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(isVisible ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.secondaryText.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                    .background(
                        (todayCount > 0 && isVisible)
                            ? category.color.opacity(0.12)
                            : AppSurfaceTokens.secondaryText.opacity(0.06)
                    )
                    .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 2. Today Overview

struct TodayOverview: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日总览")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                // 统计行
                HStack(spacing: 0) {
                    StatItem(value: "\(viewModel.todayEventCount)", label: "已安排", unit: "项")
                    StatItem(value: String(format: "%.1f", Double(viewModel.todayFocusMinutes) / 60.0), label: "专注时间", unit: "h")
                    StatItem(value: String(format: "%.1f", max(0, 10.0 - Double(viewModel.todayFocusMinutes) / 60.0)), label: "空闲", unit: "h")
                }

                // 饱和度进度条
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("饱和度")
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Spacer()
                        Text("\(viewModel.todayWorkloadPercent)%")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(viewModel.todayWorkloadLevel == .empty ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.primaryText)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppSurfaceTokens.secondaryText.opacity(0.1))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(viewModel.todayWorkloadLevel.color)
                                .frame(width: geo.size.width * min(CGFloat(viewModel.todayWorkloadPercent) / 100.0, 1.0))
                        }
                    }
                    .frame(height: 6)

                    Text(viewModel.todayWorkloadLevel.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(0.94))
            )
        }
    }
}

private struct StatItem: View {
    let value: String
    let label: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 3. Today Todo List

struct TodayTodoList: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日待办")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .textCase(.uppercase)
                Spacer()
                Text("\(viewModel.todayEvents.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppSurfaceTokens.secondaryText.opacity(0.08))
                    .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // 有时间的事件
                let timedEvents = viewModel.todayEvents.filter { !$0.isAllDay }
                let allDayEvents = viewModel.todayEvents.filter { $0.isAllDay }

                if !allDayEvents.isEmpty {
                    ForEach(allDayEvents) { event in
                        TodoRow(event: event, viewModel: viewModel)
                        if event.id != allDayEvents.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                    if !timedEvents.isEmpty {
                        Divider().padding(.leading, 52)
                    }
                }

                ForEach(timedEvents) { event in
                    TodoRow(event: event, viewModel: viewModel)
                    if event.id != timedEvents.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }

                if viewModel.todayEvents.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(AppSurfaceTokens.tertiaryText)
                        Text("今日无日程")
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
        }
    }
}

private struct TodoRow: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleViewModel

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: event.startAt)
    }

    private var durationString: String {
        let mins = event.durationMinutes
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(mins)min"
    }

    var body: some View {
        Button {
            viewModel.selectDate(event.startAt)
        } label: {
            HStack(spacing: 8) {
                // 完成状态
                Button {
                    viewModel.toggleEventStatus(event.id)
                } label: {
                    Image(systemName: event.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(event.status == .done ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.secondaryText.opacity(0.4))
                }
                .buttonStyle(.plain)

                // 分类色点
                Circle()
                    .fill(viewModel.categoryColor(for: event.categoryId))
                    .frame(width: 6, height: 6)

                // 时间
                VStack(alignment: .leading, spacing: 0) {
                    Text(timeString)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(event.status == .done ? AppSurfaceTokens.tertiaryText : AppSurfaceTokens.primaryText)
                    if !event.isAllDay {
                        Text(durationString)
                            .font(.system(size: 10))
                            .foregroundStyle(AppSurfaceTokens.tertiaryText)
                    }
                }
                .frame(width: 42, alignment: .leading)

                // 标题
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 13))
                        .foregroundStyle(event.status == .done ? AppSurfaceTokens.tertiaryText : AppSurfaceTokens.primaryText)
                        .strikethrough(event.status == .done)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let tag = event.tag {
                            Text(tag)
                                .font(.system(size: 10))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AppSurfaceTokens.secondaryText.opacity(0.08))
                                .cornerRadius(3)
                        }
                        if event.isAllDay {
                            Text("全天")
                                .font(.system(size: 10))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AppSurfaceTokens.secondaryText.opacity(0.08))
                                .cornerRadius(3)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
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

// MARK: - 4. Mini Month Calendar

struct MiniMonthCalendar: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @State private var displayMonth: Date = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 月份导航
            HStack {
                Button {
                    if let prev = calendar.date(byAdding: .month, value: -1, to: displayMonth) {
                        displayMonth = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Button {
                    if let next = calendar.date(byAdding: .month, value: 1, to: displayMonth) {
                        displayMonth = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // 星期头
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日期网格
            let days = monthDays
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        MiniDayCell(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            isSelected: calendar.isDate(date, inSameDayAs: viewModel.selectedDate),
                            hasEvents: viewModel.hasEvents(on: date)
                        )
                        .onTapGesture {
                            viewModel.selectDate(date)
                        }
                    } else {
                        Color.clear.frame(height: 28)
                    }
                }
            }
            .padding(6)
            .background(AppSurfaceTokens.cardBackgroundSoft)
            .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f.string(from: displayMonth)
    }

    private var monthDays: [Date?] {
        let cal = calendar
        let components = cal.dateComponents([.year, .month], from: displayMonth)
        guard let firstOfMonth = cal.date(from: components),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        // 调整为周一开始
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday - 2 + 7) % 7 // Monday = 0

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        // 补齐到完整行
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }
}

private struct MiniDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let hasEvents: Bool

    private var dayString: String {
        Calendar.current.component(.day, from: date).description
    }

    var body: some View {
        ZStack {
            // 选中背景
            if isSelected {
                Circle()
                    .fill(AppSurfaceTokens.accentBlue.opacity(0.10))
            }

            // 今天指示器
            if isToday {
                Circle()
                    .fill(AppSurfaceTokens.accentBlue)
                    .frame(width: 18, height: 18)
            }

            // 日期文字
            Text(dayString)
                .font(.system(size: 11, weight: isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? AppSurfaceTokens.primaryText : AppSurfaceTokens.primaryText)

            // 事件小点
            if hasEvents && !isToday {
                Circle()
                    .fill(AppSurfaceTokens.accentBlue.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .offset(x: 0, y: 8)
            }
        }
        .frame(height: 28)
    }
}

// MARK: - 5. Workload Summary

struct WorkloadSummary: View {
    @ObservedObject var viewModel: ScheduleViewModel

    private let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本周饱和度")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 6) {
                ForEach(Array(viewModel.weekWorkloadDays.enumerated()), id: \.offset) { index, day in
                    let weekdayIndex = Calendar.current.component(.weekday, from: day.date)
                    let labelIndex = (weekdayIndex + 5) % 7 // 转换为 Mon=0

                    HStack(spacing: 8) {
                        Text(weekdayLabels[labelIndex])
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                            .frame(width: 28, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppSurfaceTokens.secondaryText.opacity(0.08))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(day.workloadLevel.color)
                                    .frame(width: geo.size.width * min(CGFloat(day.workloadPercent) / 100.0, 1.0))
                            }
                        }
                        .frame(height: 8)

                        Text("\(day.workloadPercent)%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
            .padding(12)
            .background(AppSurfaceTokens.cardBackgroundSoft)
            .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
        }
    }
}
