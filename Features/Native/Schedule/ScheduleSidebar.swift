import SwiftUI
import AppKit

struct ScheduleSidebar: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ACLayout.panelGap) {
                SidebarDaySummary(viewModel: viewModel)
                SidebarCategoryList(viewModel: viewModel)
                SidebarRecentRecords(viewModel: viewModel)
                SidebarWeekTrend(viewModel: viewModel)
            }
            .padding(.horizontal, ACLayout.pagePaddingX)
            .padding(.vertical, ACLayout.pagePaddingY)
            .padding(.bottom, ACLayout.pagePaddingBottom)
        }
        .frame(width: ScheduleLayout.sidebarWidth)
        .background(ACColors.pageBackground)
    }
}

// MARK: - Day Summary

private struct SidebarDaySummary: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        AppSurfaceCard(
            title: "今日概览",
            subtitle: dayLabel(viewModel.selectedDate),
            padding: 16
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    SummaryChip(value: "\(viewModel.selectedDayCount)", label: "记录")
                    SummaryChip(value: formatMinutes(viewModel.selectedDayFocusMinutes), label: "时长")
                }

                HStack(spacing: 10) {
                    SummaryChip(value: "\(viewModel.selectedDayWorkloadPercent)%", label: "饱和度")
                    SummaryChip(value: formatMinutes(viewModel.selectedDayFreeMinutes), label: "空闲")
                }
            }
        }
    }
}

private struct SummaryChip: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Categories

private struct SidebarCategoryList: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        AppSurfaceCard(title: "分类", padding: 16) {
            VStack(spacing: 6) {
                ForEach(viewModel.categories) { category in
                    Button {
                        viewModel.toggleCategoryVisibility(category.id)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 8, height: 8)

                            Text(category.name)
                                .font(.system(size: 12))
                                .foregroundStyle(category.visible ? .primary : .secondary)

                            Spacer()

                            Text("\(viewModel.todayCount(for: category.id))")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Recent Records

private struct SidebarRecentRecords: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        AppSurfaceCard(title: "最近记录", padding: 16) {
            VStack(spacing: 8) {
                let recentEvents = Array(viewModel.selectedDayEvents.prefix(5))
                if recentEvents.isEmpty {
                    Text("今天还没有记录。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                } else {
                    ForEach(recentEvents) { event in
                        SidebarRecordRow(event: event, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

private struct SidebarRecordRow: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleViewModel

    private var timeText: String {
        if event.isAllDay { return "全天" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.startAt)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.categoryColor(for: event.categoryId))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12))
                    .foregroundStyle(event.status == .done ? .secondary : .primary)
                    .lineLimit(1)
                Text(timeText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.toggleEventStatus(event.id)
            } label: {
                Image(systemName: event.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(event.status == .done ? .green : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
        )
    }
}

// MARK: - Week Trend

private struct SidebarWeekTrend: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        AppSurfaceCard(title: "本周趋势", padding: 16) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weekWorkloadDays, id: \.id) { day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.workloadLevel.color)
                            .frame(width: 16, height: max(6, CGFloat(day.workloadPercent) / 100.0 * 52.0))

                        Text(shortWeekdayLabel(for: day.date))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private func dayLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日 EEEE"
    return formatter.string(from: date)
}

private func shortWeekdayLabel(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "E"
    return formatter.string(from: date)
}

private func formatMinutes(_ minutes: Int) -> String {
    if minutes == 0 { return "0 分钟" }
    let hours = Double(minutes) / 60.0
    return String(format: "%.1f 小时", hours)
}
