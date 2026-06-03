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

    private func categoryDisplayName(for categoryId: String) -> String {
        switch categoryId {
        case "personal": return "个人"
        case "work": return "工作"
        case "acmind": return "AcMind"
        case "study": return "学习"
        case "fitness": return "健身"
        case "life": return "生活"
        case "holiday": return "节假日"
        default: return categoryId
        }
    }
}
