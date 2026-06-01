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
        _ = shouldLoadEvents
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
