import Foundation
import SwiftUI

public struct ScheduleEvent: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public var description: String?
    public let categoryId: String
    public let startAt: Date
    public let endAt: Date
    public var isAllDay: Bool
    public var status: EventStatus
    public var priority: EventPriority
    public var tag: String?

    public init(
        id: String,
        title: String,
        description: String? = nil,
        categoryId: String,
        startAt: Date,
        endAt: Date,
        isAllDay: Bool,
        status: EventStatus,
        priority: EventPriority,
        tag: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.categoryId = categoryId
        self.startAt = startAt
        self.endAt = endAt
        self.isAllDay = isAllDay
        self.status = status
        self.priority = priority
        self.tag = tag
    }

    public enum EventStatus: String, Codable, CaseIterable, Sendable {
        case todo
        case done
        case cancelled

        public var displayName: String {
            switch self {
            case .todo: return "待办"
            case .done: return "已完成"
            case .cancelled: return "已取消"
            }
        }
    }

    public enum EventPriority: String, Codable, CaseIterable, Sendable {
        case low
        case medium
        case high

        public var displayName: String {
            switch self {
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            }
        }
    }

    public var durationMinutes: Int {
        Calendar.current.dateComponents([.minute], from: startAt, to: endAt).minute ?? 0
    }

    public func displayTimeRange(using calendar: Calendar = .current) -> String {
        guard isAllDay == false else {
            return "全天"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: startAt)) - \(formatter.string(from: endAt))"
    }

    public func timingState(referenceDate: Date = Date()) -> ScheduleEventTimingState {
        switch status {
        case .done:
            return .done
        case .cancelled:
            return .cancelled
        case .todo:
            break
        }

        if isAllDay {
            return .allDay
        }

        if referenceDate >= endAt {
            return .overdue
        }

        if referenceDate >= startAt && referenceDate < endAt {
            return .ongoing
        }

        return .upcoming
    }

    public func isOn(date: Date) -> Bool {
        Calendar.current.isDate(startAt, inSameDayAs: date)
    }

    public func isIn(weekOf date: Date) -> Bool {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: date)?.start,
              let eventWeekStart = cal.dateInterval(of: .weekOfYear, for: startAt)?.start else {
            return false
        }
        return cal.isDate(weekStart, inSameDayAs: eventWeekStart)
    }

    public func isIn(monthOf date: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year, from: startAt) == cal.component(.year, from: date)
            && cal.component(.month, from: startAt) == cal.component(.month, from: date)
    }

    public func isIn(yearOf date: Date) -> Bool {
        Calendar.current.component(.year, from: startAt) == Calendar.current.component(.year, from: date)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Schedule Event Filter

public struct ScheduleEventFilter: Sendable, Equatable {
    public let status: ScheduleEvent.EventStatus?
    public let categoryId: String?
    public let priority: ScheduleEvent.EventPriority?
    public let startDate: Date?
    public let endDate: Date?
    public let query: String?

    public init(
        status: ScheduleEvent.EventStatus? = nil,
        categoryId: String? = nil,
        priority: ScheduleEvent.EventPriority? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        query: String? = nil
    ) {
        self.status = status
        self.categoryId = categoryId
        self.priority = priority
        self.startDate = startDate
        self.endDate = endDate
        self.query = query
    }
}

// MARK: - Schedule Stats

public struct ScheduleStats: Sendable, Equatable {
    public let totalEvents: Int
    public let todayEvents: Int
    public let weekEvents: Int
    public let completedToday: Int
    public let focusMinutesToday: Int

    public init(
        totalEvents: Int = 0,
        todayEvents: Int = 0,
        weekEvents: Int = 0,
        completedToday: Int = 0,
        focusMinutesToday: Int = 0
    ) {
        self.totalEvents = totalEvents
        self.todayEvents = todayEvents
        self.weekEvents = weekEvents
        self.completedToday = completedToday
        self.focusMinutesToday = focusMinutesToday
    }
}

public enum ScheduleEventTimingState: String, Sendable, Equatable {
    case upcoming
    case ongoing
    case overdue
    case allDay
    case done
    case cancelled

    public var displayName: String {
        switch self {
        case .upcoming: return "待开始"
        case .ongoing: return "进行中"
        case .overdue: return "逾期"
        case .allDay: return "全天"
        case .done: return "已完成"
        case .cancelled: return "已取消"
        }
    }
}

public struct ScheduleEventConflict: Sendable, Equatable {
    public let first: ScheduleEvent
    public let second: ScheduleEvent

    public init(first: ScheduleEvent, second: ScheduleEvent) {
        self.first = first
        self.second = second
    }
}

public struct ScheduleFreeWindow: Sendable, Equatable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var durationMinutes: Int {
        max(0, Calendar.current.dateComponents([.minute], from: start, to: end).minute ?? 0)
    }
}

public struct SchedulePlanningSnapshot: Sendable, Equatable {
    public let referenceDate: Date
    public let selectedDate: Date
    public let totalEventCount: Int
    public let activeEventCount: Int
    public let completedEventCount: Int
    public let allDayEventCount: Int
    public let overdueEventCount: Int
    public let currentEvent: ScheduleEvent?
    public let nextEvent: ScheduleEvent?
    public let conflict: ScheduleEventConflict?
    public let freeWindow: ScheduleFreeWindow?
    public let selectedDateLabel: String
    public let currentTimeLabel: String

    public init(
        referenceDate: Date,
        selectedDate: Date,
        totalEventCount: Int,
        activeEventCount: Int,
        completedEventCount: Int,
        allDayEventCount: Int,
        overdueEventCount: Int,
        currentEvent: ScheduleEvent?,
        nextEvent: ScheduleEvent?,
        conflict: ScheduleEventConflict?,
        freeWindow: ScheduleFreeWindow?,
        selectedDateLabel: String,
        currentTimeLabel: String
    ) {
        self.referenceDate = referenceDate
        self.selectedDate = selectedDate
        self.totalEventCount = totalEventCount
        self.activeEventCount = activeEventCount
        self.completedEventCount = completedEventCount
        self.allDayEventCount = allDayEventCount
        self.overdueEventCount = overdueEventCount
        self.currentEvent = currentEvent
        self.nextEvent = nextEvent
        self.conflict = conflict
        self.freeWindow = freeWindow
        self.selectedDateLabel = selectedDateLabel
        self.currentTimeLabel = currentTimeLabel
    }
}

@MainActor
public final class ScheduleViewModel: ObservableObject {
    @Published public var selectedDate: Date
    @Published public var events: [ScheduleEvent]
    @Published public var searchText: String

    public init(shouldLoadEvents: Bool = true) {
        self.selectedDate = Date()
        self.events = []
        self.searchText = ""
        if shouldLoadEvents {
            loadEvents()
        }
    }

    private func loadEvents() {
        // Events are loaded by the internal ScheduleViewModel in Features/Native/Schedule/ScheduleViewModel.swift
        // This public model serves as the AcMindKit-level data contract
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool {
        !normalizedSearchText.isEmpty
    }

    private func searchableText(for event: ScheduleEvent) -> String {
        [
            event.title,
            event.description ?? "",
            event.tag ?? "",
            categoryDisplayName(for: event.categoryId),
            event.status.displayName
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private func matchesSearch(_ event: ScheduleEvent) -> Bool {
        guard isSearching else { return true }
        return searchableText(for: event).contains(normalizedSearchText)
    }

    public func events(for date: Date) -> [ScheduleEvent] {
        let cal = Calendar.current
        return events
            .filter { cal.isDate($0.startAt, inSameDayAs: date) && $0.status != .cancelled }
            .filter(matchesSearch)
            .sorted { $0.startAt < $1.startAt }
    }

    public func hasEvents(on date: Date) -> Bool {
        !events(for: date).isEmpty
    }

    public func planningSnapshot(
        for date: Date = Date(),
        referenceDate now: Date = Date(),
        minimumFreeWindowMinutes: Int = 30
    ) -> SchedulePlanningSnapshot {
        let visibleEvents = events(for: date)
        let activeEvents = visibleEvents.filter { $0.status != .cancelled }

        let selectedDateLabel = selectedDateLabel(for: date)
        let currentTimeLabel = timeLabel(for: now)
        let currentEvent = currentEvent(on: date, referenceDate: now)
        let nextEvent = nextEvent(after: date, referenceDate: now)
        let conflict = eventConflict(on: date)
        let freeWindow = freeWindow(on: date, referenceDate: now, minimumMinutes: minimumFreeWindowMinutes)

        return SchedulePlanningSnapshot(
            referenceDate: now,
            selectedDate: date,
            totalEventCount: visibleEvents.count,
            activeEventCount: activeEvents.count,
            completedEventCount: activeEvents.filter { $0.status == .done }.count,
            allDayEventCount: activeEvents.filter(\.isAllDay).count,
            overdueEventCount: activeEvents.filter { $0.timingState(referenceDate: now) == .overdue }.count,
            currentEvent: currentEvent,
            nextEvent: nextEvent,
            conflict: conflict,
            freeWindow: freeWindow,
            selectedDateLabel: selectedDateLabel,
            currentTimeLabel: currentTimeLabel
        )
    }

    public func currentEvent(on date: Date = Date(), referenceDate now: Date = Date()) -> ScheduleEvent? {
        let cal = Calendar.current
        guard cal.isDate(date, inSameDayAs: now) else { return nil }
        return events(for: date).first {
            $0.status != .cancelled && $0.startAt <= now && now < $0.endAt
        }
    }

    public func nextEvent(after date: Date = Date(), referenceDate now: Date = Date()) -> ScheduleEvent? {
        let cal = Calendar.current
        let sorted = events(for: date).filter { $0.status != .cancelled }

        if cal.isDate(date, inSameDayAs: now) {
            return sorted.first { $0.startAt > now }
        }

        let startOfDay = cal.startOfDay(for: date)
        return sorted.first { $0.endAt > startOfDay }
    }

    public func eventConflict(on date: Date = Date()) -> ScheduleEventConflict? {
        let activeEvents = events(for: date).filter { $0.status != .cancelled }
        guard activeEvents.count > 1 else { return nil }

        for index in 0..<(activeEvents.count - 1) {
            let current = activeEvents[index]
            let rest = activeEvents[(index + 1)...]
            if let overlap = rest.first(where: { current.startAt < $0.endAt && current.endAt > $0.startAt }) {
                return ScheduleEventConflict(first: current, second: overlap)
            }
        }

        return nil
    }

    public func freeWindow(on date: Date = Date(), referenceDate now: Date = Date(), minimumMinutes: Int = 30) -> ScheduleFreeWindow? {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)
        let anchor = cal.isDate(date, inSameDayAs: now) ? max(now, startOfDay) : startOfDay
        let activeEvents = events(for: date).filter { $0.status != .cancelled }.sorted { $0.startAt < $1.startAt }
        var cursor = anchor

        for event in activeEvents {
            if event.endAt <= cursor {
                cursor = max(cursor, event.endAt)
                continue
            }

            if event.startAt > cursor {
                let gap = ScheduleFreeWindow(start: cursor, end: event.startAt)
                if gap.durationMinutes >= minimumMinutes {
                    return gap
                }
            }

            cursor = max(cursor, event.endAt)
        }

        if endOfDay > cursor {
            let tailGap = ScheduleFreeWindow(start: cursor, end: endOfDay)
            if tailGap.durationMinutes >= minimumMinutes {
                return tailGap
            }
        }

        return nil
    }

    private func categoryDisplayName(for categoryId: String) -> String {
        switch categoryId {
        case "personal": return "个人"
        case "work": return "工作"
        case "acmind": return "AcWork"
        case "study": return "学习"
        case "fitness": return "健身"
        case "life": return "生活"
        case "holiday": return "节假日"
        default: return categoryId
        }
    }

    private func selectedDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    private func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
