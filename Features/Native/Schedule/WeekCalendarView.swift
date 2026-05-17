import SwiftUI
import AppKit

// MARK: - Shared Journal Surface

struct ScheduleDayLogView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ACLayout.panelGap) {
            DayOverviewHeader(viewModel: viewModel)
            DailyRecordList(
                title: "今天的记录",
                subtitle: "按时间排序，适合快速回顾当天做了什么。",
                events: viewModel.selectedDayEvents,
                viewModel: viewModel
            )
        }
    }
}

struct ScheduleWeekLogView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ACLayout.panelGap) {
            WeekOverviewHeader(viewModel: viewModel)

            ForEach(viewModel.weekDates(containing: viewModel.selectedDate), id: \.self) { date in
                DailyRecordList(
                    title: dayTitle(for: date),
                    subtitle: viewModel.events(on: date).isEmpty ? "这一天还没有记录。" : nil,
                    events: viewModel.events(on: date),
                    viewModel: viewModel,
                    isHighlighted: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                )
            }
        }
    }

    private func dayTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Headers

private struct DayOverviewHeader: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        AppSurfaceCard(
            title: "今天概览",
            subtitle: "\(viewModel.selectedDayCount) 条记录 · \(formatMinutes(viewModel.selectedDayFocusMinutes))",
            padding: 16
        ) {
            HStack(spacing: 10) {
                StatPill(value: "\(viewModel.selectedDayCount)", label: "条记录")
                StatPill(value: formatMinutes(viewModel.selectedDayFocusMinutes), label: "已记录")
                StatPill(value: formatMinutes(viewModel.selectedDayFreeMinutes), label: "空闲")
                StatPill(value: "\(viewModel.selectedDayWorkloadPercent)%", label: "饱和度")
            }
        }
    }
}

private struct WeekOverviewHeader: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        AppSurfaceCard(
            title: "本周概览",
            subtitle: "\(viewModel.selectedWeekEvents.count) 条记录 · \(formatMinutes(viewModel.selectedWeekFocusMinutes))",
            padding: 16
        ) {
            HStack(spacing: 10) {
                StatPill(value: "\(viewModel.selectedWeekEvents.count)", label: "条记录")
                StatPill(value: formatMinutes(viewModel.selectedWeekFocusMinutes), label: "记录时长")
                StatPill(value: "\(viewModel.weekWorkloadDays.filter { $0.eventCount > 0 }.count)", label: "有记录的天")
            }
        }
    }
}

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ACColors.softFill)
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Record List

private struct DailyRecordList: View {
    let title: String
    let subtitle: String?
    let events: [ScheduleEvent]
    @ObservedObject var viewModel: ScheduleViewModel
    var isHighlighted: Bool = false

    var body: some View {
        AppSurfaceCard(
            title: title,
            subtitle: subtitle,
            padding: 16
        ) {
            VStack(spacing: 8) {
                if events.isEmpty {
                    EmptyRecordState()
                } else {
                    ForEach(events) { event in
                        ScheduleRecordRow(event: event, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

private struct EmptyRecordState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text("还没有记录")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("可以点右上角「+」快速记录今天做了什么。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

private struct ScheduleRecordRow: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleViewModel

    private var timeText: String {
        if event.isAllDay { return "全天" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.startAt)
    }

    private var durationText: String {
        let minutes = event.durationMinutes
        if event.isAllDay {
            return "全天"
        }
        if minutes < 60 {
            return "\(minutes) 分钟"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder > 0 ? "\(hours) 小时 \(remainder) 分钟" : "\(hours) 小时"
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.toggleEventStatus(event.id)
            } label: {
                Image(systemName: event.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(event.status == .done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            RoundedRectangle(cornerRadius: 2)
                .fill(viewModel.categoryColor(for: event.categoryId))
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(event.status == .done ? .secondary : .primary)
                        .strikethrough(event.status == .done)
                        .lineLimit(1)

                    if let tag = event.tag {
                        Text(tag)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Text(timeText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(durationText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text(viewModel.categoryName(for: event.categoryId))
                        .font(.system(size: 11))
                        .foregroundStyle(viewModel.categoryColor(for: event.categoryId))
                }
            }

            Spacer()

            Button {
                viewModel.deleteEvent(event.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("删除记录")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .fill(event.status == .done ? ACColors.softFill.opacity(0.55) : Color.clear)
        )
    }
}

private func formatMinutes(_ minutes: Int) -> String {
    if minutes == 0 { return "0 分钟" }
    let hours = Double(minutes) / 60.0
    return String(format: "%.1f 小时", hours)
}
