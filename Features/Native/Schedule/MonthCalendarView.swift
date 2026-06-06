import SwiftUI

// MARK: - Month Calendar View

struct MonthCalendarView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current
    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 0) {
            // 星期头
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }

            Divider()

            // 月份网格
            let weeks = monthWeeks
            VStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                    HStack(spacing: 0) {
                        ForEach(week.indices, id: \.self) { dayIndex in
                            if let date = week[dayIndex] {
                                MonthDayCell(
                                    date: date,
                                    isToday: calendar.isDateInToday(date),
                                    isSelected: calendar.isDate(date, inSameDayAs: viewModel.selectedDate),
                                    events: viewModel.events(for: date),
                                    viewModel: viewModel
                                )
                                .onTapGesture {
                                    viewModel.selectDate(date)
                                }
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity, minHeight: 100)
                            }
                        }
                    }

                    if weekIndex < weeks.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Month Day Cell

private struct MonthDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let events: [ScheduleEvent]
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current
    private let maxVisibleEvents = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 日期数字
            HStack {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: isToday ? 14 : 13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? AppSurfaceTokens.primaryText : AppSurfaceTokens.primaryText)
                    .frame(width: isToday ? 24 : 20, height: isToday ? 24 : 20)
                    .background(
                        isToday ? AnyShapeStyle(AppSurfaceTokens.accentBlue) : AnyShapeStyle(Color.clear)
                    )
                    .cornerRadius(isToday ? 12 : 0)

                Spacer()
            }

            // 事件列表
            VStack(alignment: .leading, spacing: 1) {
                let visibleEvents = Array(events.prefix(maxVisibleEvents))
                let overflowCount = events.count - maxVisibleEvents

                ForEach(visibleEvents) { event in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(viewModel.categoryColor(for: event.categoryId))
                            .frame(width: 3, height: 10)

                        Text(event.title)
                            .font(.system(size: 10))
                            .foregroundStyle(event.status == .done ? AppSurfaceTokens.tertiaryText : AppSurfaceTokens.primaryText)
                            .lineLimit(1)
                    }
                }

                if overflowCount > 0 {
                    Text("+\(overflowCount)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .padding(.leading, 6)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            isSelected && !isToday
                ? AppSurfaceTokens.accentBlue.opacity(0.06)
                : Color.clear
        )
        .cornerRadius(4)
    }
}

// MARK: - Helper: Month Weeks

private extension MonthCalendarView {
    var monthWeeks: [[Date?]] {
        let cal = calendar
        let components = cal.dateComponents([.year, .month], from: viewModel.selectedDate)
        guard let firstOfMonth = cal.date(from: components),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        // 调整为周一开始
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday - 2 + 7) % 7

        var allDays: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                allDays.append(date)
            }
        }
        // 补齐到完整行
        while allDays.count % 7 != 0 {
            allDays.append(nil)
        }

        // 分周
        var weeks: [[Date?]] = []
        let chunkSize = 7
        for index in stride(from: 0, to: allDays.count, by: chunkSize) {
            let chunk = Array(allDays[index..<min(index + chunkSize, allDays.count)])
            weeks.append(chunk)
        }
        return weeks
    }
}
