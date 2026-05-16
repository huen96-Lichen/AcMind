import SwiftUI
import AppKit

// MARK: - Year Calendar View

struct YearCalendarView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 12 个月迷你日历
                YearMiniCalendarGrid(viewModel: viewModel)

                Divider()
                    .padding(.horizontal, 20)

                // 年度工作饱和热力图
                WorkloadHeatmap(viewModel: viewModel)
            }
            .padding(24)
        }
    }
}

// MARK: - Year Mini Calendar Grid

private struct YearMiniCalendarGrid: View {
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current
    private let shortWeekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("年历总览")
                .font(.system(size: 15, weight: .semibold))

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<12, id: \.self) { monthOffset in
                    if let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: yearStart) {
                        MiniMonthCard(
                            monthDate: monthDate,
                            viewModel: viewModel,
                            isCurrentMonth: calendar.isDate(monthDate, equalTo: Date(), toGranularity: .month)
                        )
                    }
                }
            }
        }
    }

    private var yearStart: Date {
        let components = calendar.dateComponents([.year], from: viewModel.selectedDate)
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - Mini Month Card

private struct MiniMonthCard: View {
    let monthDate: Date
    @ObservedObject var viewModel: ScheduleViewModel
    let isCurrentMonth: Bool

    private let calendar = Calendar.current
    private let shortWeekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 6) {
            // 月份标题
            Text(monthTitle)
                .font(.system(size: 12, weight: isCurrentMonth ? .semibold : .medium))
                .foregroundStyle(isCurrentMonth ? Color.accentColor : .primary)

            // 星期头
            HStack(spacing: 0) {
                ForEach(shortWeekdays, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日期网格
            let days = monthDays
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        let isToday = calendar.isDateInToday(date)
                        let hasEvents = viewModel.hasEvents(on: date)

                        ZStack {
                            if isToday {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 14, height: 14)
                            }

                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                                .foregroundStyle(isToday ? .white : .primary)
                        }
                        .frame(height: 16)

                        if hasEvents && !isToday {
                            Circle()
                                .fill(Color.accentColor.opacity(0.5))
                                .frame(width: 3, height: 3)
                                .padding(.top, -2)
                        }
                    } else {
                            Color.clear.frame(height: 16)
                    }
                }
            }
        }
        .padding(8)
        .background(
            isCurrentMonth
                ? Color.accentColor.opacity(0.05)
                : Color(NSColor.controlBackgroundColor)
        )
        .cornerRadius(ACLayout.controlRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.controlRadius)
                .stroke(isCurrentMonth ? Color.accentColor.opacity(0.2) : Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    private var monthDays: [Date?] {
        let cal = calendar
        let components = cal.dateComponents([.year, .month], from: monthDate)
        guard let firstOfMonth = cal.date(from: components),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday - 2 + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter.string(from: monthDate)
    }
}

// MARK: - Workload Heatmap

private struct WorkloadHeatmap: View {
    @ObservedObject var viewModel: ScheduleViewModel

    @State private var hoveredDay: WorkloadDay?

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let weekdayLabels = ["Mon", "", "Wed", "", "Fri", "", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            VStack(alignment: .leading, spacing: 4) {
                Text("过去一年工作饱和度")
                    .font(.system(size: 15, weight: .semibold))

                let stats = viewModel.yearlyStats
                Text("最近 365 天中有 \(stats.activeDays) 天安排了日程，平均饱和度 \(stats.avgWorkload)%")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }

            // 热力图
            HStack(alignment: .top, spacing: 0) {
                // 星期标签
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(weekdayLabels[index])
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .frame(height: cellSize)
                    }
                }
                .frame(width: 28, alignment: .trailing)
                .padding(.trailing, 6)

                // 热力图网格
                let weeks = heatmapWeeks
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cellSpacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                            VStack(spacing: cellSpacing) {
                                ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, day in
                                    if let day = day {
                                        HeatmapCell(day: day, isHovered: hoveredDay?.id == day.id)
                                            .onHover { isHovering in
                                                if isHovering {
                                                    hoveredDay = day
                                                } else if hoveredDay?.id == day.id {
                                                    hoveredDay = nil
                                                }
                                            }
                                    } else {
                                        Color.clear
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Tooltip
            if let day = hoveredDay {
                HStack(spacing: 12) {
                    Text(dayLabel(day.date))
                        .font(.system(size: 12, weight: .medium))
                    Text("已安排 \(day.eventCount) 项")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Text("总时长 \(String(format: "%.1f", Double(day.scheduledMinutes) / 60.0))h")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Text("饱和度 \(day.workloadPercent)%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(day.workloadLevel.color == Color(red: 0.93, green: 0.94, blue: 0.95) ? .secondary : .primary)
                    Text("状态：\(day.statusText)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
                .transition(.opacity)
            }

            // 图例
            HStack(spacing: 16) {
                Text("少")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                ForEach(WorkloadLevel.allCases, id: \.rawValue) { level in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level.color)
                            .frame(width: 12, height: 12)
                        Text(level.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                }

                Text("多")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    /// 将年度数据按周组织
    private var heatmapWeeks: [[WorkloadDay?]] {
        let days = viewModel.yearlyWorkloadDays
        guard let firstDay = days.first else { return [] }

        // 计算第一天是周几（周一 = 0）
        let weekday = calendar.component(.weekday, from: firstDay.date)
        let mondayOffset = (weekday - 2 + 7) % 7

        // 填充前面的空白
        var allDays: [WorkloadDay?] = Array(repeating: nil, count: mondayOffset)
        allDays.append(contentsOf: days)

        // 补齐到完整周
        while allDays.count % 7 != 0 {
            allDays.append(nil)
        }

        // 分周
        var weeks: [[WorkloadDay?]] = []
        for index in stride(from: 0, to: allDays.count, by: 7) {
            let chunk = Array(allDays[index..<min(index + 7, allDays.count)])
            weeks.append(chunk)
        }
        return weeks
    }
}

// MARK: - Heatmap Cell

private struct HeatmapCell: View {
    let day: WorkloadDay
    let isHovered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(day.workloadLevel.color)
            .frame(width: 12, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isHovered ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.3 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
