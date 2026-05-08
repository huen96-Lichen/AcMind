import SwiftUI
import AppKit
import AcMindKit

// MARK: - Week Calendar View

struct WeekCalendarView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current
    private let hours = Array(6...23) // 06:00 - 23:00
    private let weekdaySymbols = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    var body: some View {
        VStack(spacing: 0) {
            // 周头部
            WeekHeader(viewModel: viewModel)

            Divider()

            // 全天事件区域
            AllDayEventRow(viewModel: viewModel)

            Divider()

            // 时间网格
            TimeGrid(viewModel: viewModel)
        }
    }
}

// MARK: - Week Header

private struct WeekHeader: View {
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current
    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        HStack(spacing: 0) {
            // 时间列占位
            Text("")
                .frame(width: ScheduleLayout.weekTimeColumnWidth)

            ForEach(weekDates(for: viewModel.selectedDate), id: \.self) { date in
                let isToday = calendar.isDateInToday(date)
                let weekdayIndex = (calendar.component(.weekday, from: date) + 5) % 7

                VStack(spacing: 2) {
                    Text(weekdaySymbols[weekdayIndex])
                        .font(.system(size: 10))
                        .foregroundStyle(isToday ? .primary : .secondary)

                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: isToday ? 16 : 14, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .white : .primary)
                        .frame(width: isToday ? 28 : 24, height: isToday ? 28 : 24)
                        .background(
                            isToday ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.clear)
                        )
                        .cornerRadius(isToday ? 14 : 0)
                }
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    viewModel.selectDate(date)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - All Day Event Row

private struct AllDayEventRow: View {
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 0) {
            Text("全天")
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary)
                .frame(width: ScheduleLayout.weekTimeColumnWidth, alignment: .trailing)
                .padding(.trailing, 8)

            ForEach(weekDates(for: viewModel.selectedDate), id: \.self) { date in
                let dayAllDayEvents = viewModel.events(for: date).filter { $0.isAllDay }

                VStack(spacing: 2) {
                    ForEach(dayAllDayEvents) { event in
                        Text(event.title)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(viewModel.categoryColor(for: event.categoryId).opacity(0.15))
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 24)
            }
        }
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Time Grid

private struct TimeGrid: View {
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current
    private let hours = Array(6...23)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                let week = weekDates(for: viewModel.selectedDate)
                let placementsByDay = Dictionary(uniqueKeysWithValues: week.map { day in
                    (day, timelinePlacements(for: viewModel.events(for: day)))
                })

                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { hour in
                        HourRow(hour: hour, weekDates: week, placementsByDay: placementsByDay, viewModel: viewModel)
                    }
                }
            }
            .onAppear {
                // 滚动到当前时间附近
                let currentHour = calendar.component(.hour, from: Date())
                let targetHour = max(6, currentHour - 1)
                proxy.scrollTo(targetHour, anchor: .top)
            }
        }
    }
}

private struct HourRow: View {
    let hour: Int
    let weekDates: [Date]
    let placementsByDay: [Date: [TimelineEventPlacement]]
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        HStack(spacing: 0) {
            Text(String(format: "%02d:00", hour))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: ScheduleLayout.weekTimeColumnWidth, alignment: .trailing)
                .padding(.trailing, 8)

            ForEach(weekDates, id: \.self) { date in
                ZStack(alignment: .top) {
                    TimeSlotBackground(date: date, hour: hour, viewModel: viewModel)

                    GeometryReader { geometry in
                        let hourPlacements = (placementsByDay[date] ?? []).filter { $0.startHour == hour }

                        ZStack(alignment: .topLeading) {
                            ForEach(hourPlacements, id: \.id) { placement in
                                if let event = viewModel.events(for: date).first(where: { $0.id == placement.id }) {
                                    EventCard(
                                        event: event,
                                        placement: placement,
                                        viewModel: viewModel,
                                        containerWidth: geometry.size.width
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ScheduleLayoutMetrics.hourHeight)
            }
        }
        .id(hour)
    }
}

private struct TimeSlotBackground: View {
    let date: Date
    let hour: Int
    @ObservedObject var viewModel: ScheduleViewModel

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // 上半部分（0分）
            Rectangle()
                .fill(Color.clear)
                .frame(height: ScheduleLayoutMetrics.hourHeight / 2)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    createEvent(at: date, hour: hour, minute: 0)
                }
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }

            Rectangle()
                .fill(Color(NSColor.separatorColor).opacity(0.3))
                .frame(height: 0.5)

            // 下半部分（30分）
            Rectangle()
                .fill(Color.clear)
                .frame(height: ScheduleLayoutMetrics.hourHeight / 2 - 0.5)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    createEvent(at: date, hour: hour, minute: 30)
                }
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        }
    }

    private func createEvent(at date: Date, hour: Int, minute: Int) {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard let eventDate = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: hour,
            minute: minute
        )) else { return }

        let snappedDate = ScheduleTimeGridLayout.snapToNearestQuarterHour(eventDate, calendar: calendar)
        let snappedComponents = calendar.dateComponents([.hour, .minute], from: snappedDate)

        viewModel.openCreateEvent(
            on: date,
            hour: snappedComponents.hour ?? hour,
            minute: snappedComponents.minute ?? minute
        )
    }
}

// MARK: - Event Card

private struct EventCard: View {
    let event: ScheduleEvent
    let placement: TimelineEventPlacement
    @ObservedObject var viewModel: ScheduleViewModel
    let containerWidth: CGFloat

    private let calendar = Calendar.current

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startAt)) - \(formatter.string(from: event.endAt))"
    }

    private var durationText: String {
        let dur = event.durationMinutes
        if dur < 60 {
            return "\(dur)m"
        } else {
            let h = dur / 60
            let m = dur % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
    }

    private var laneFrame: (left: CGFloat, width: CGFloat) {
        let laneGap: CGFloat = placement.laneCount > 1 ? 6 : 0
        let padding: CGFloat = placement.laneCount > 1 ? 4 : 18
        let usableWidth = max(0, containerWidth - padding * 2 - CGFloat(max(0, placement.laneCount - 1)) * laneGap)
        let laneWidth = placement.laneCount > 0 ? usableWidth / CGFloat(placement.laneCount) : usableWidth
        let left = padding + CGFloat(placement.lane) * (laneWidth + laneGap)
        return (left: left, width: laneWidth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(event.status == .done ? .tertiary : .primary)
                .lineLimit(1)

            if placement.height > 24 {
                HStack(alignment: .center, spacing: 4) {
                    Text(timeRange)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                    if placement.height > 40 {
                        Text("·")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                        Text(durationText)
                            .font(.system(size: 9))
                            .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                            .lineLimit(1)
                    }
                }
            }

            if placement.height > 40 {
                Text(viewModel.categoryName(for: event.categoryId))
                    .font(.system(size: 9))
                    .foregroundStyle(viewModel.categoryColor(for: event.categoryId))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: ScheduleLayout.eventCornerRadius)
                .fill(viewModel.categoryColor(for: event.categoryId).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ScheduleLayout.eventCornerRadius)
                .stroke(viewModel.categoryColor(for: event.categoryId).opacity(0.2), lineWidth: 0.5)
        )
        .opacity(event.status == .done ? 0.5 : 1.0)
        .frame(width: laneFrame.width, height: placement.height, alignment: .topLeading)
        .offset(x: laneFrame.left, y: placement.topOffset)
    }
}

// MARK: - Helper: Week Dates

private func weekDates(for date: Date) -> [Date] {
    let cal = Calendar.current
    guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: date) else { return [] }
    var dates: [Date] = []
    var current = weekInterval.start
    while current < weekInterval.end {
        dates.append(current)
        guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
        current = next
    }
    return dates
}

private func timelinePlacements(for events: [ScheduleEvent]) -> [TimelineEventPlacement] {
    let calendar = Calendar.current
    let slices = events
        .filter { !$0.isAllDay && $0.status != .cancelled }
        .map { event in
            TimelineEventSlice(
                id: event.id,
                startMinute: calendar.component(.hour, from: event.startAt) * 60 + calendar.component(.minute, from: event.startAt),
                endMinute: calendar.component(.hour, from: event.endAt) * 60 + calendar.component(.minute, from: event.endAt)
            )
        }

    return layoutTimelineEvents(
        slices,
        visibleStartHour: 6,
        hourHeight: ScheduleLayoutMetrics.hourHeight,
        minimumHeight: ScheduleLayoutMetrics.minEventHeight,
        overlapPadding: 4
    )
}
