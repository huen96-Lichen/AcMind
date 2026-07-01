import Foundation

// MARK: - Schedule Service Protocol

public protocol ScheduleServiceProtocol: Sendable {
    func setup() async throws

    func createEvent(_ event: ScheduleEvent) async throws
    func getEvent(id: String) async throws -> ScheduleEvent?
    func listEvents(filter: ScheduleEventFilter?) async throws -> [ScheduleEvent]
    func updateEvent(_ event: ScheduleEvent) async throws
    func deleteEvent(id: String) async throws
    func getEventsForDate(_ date: Date) async throws -> [ScheduleEvent]
    func getEventsForWeek(of date: Date) async throws -> [ScheduleEvent]
    func searchEvents(query: String) async throws -> [ScheduleEvent]
    func getStats() async throws -> ScheduleStats
}

// MARK: - Schedule Service

public actor ScheduleService: ScheduleServiceProtocol {

    private let storage: StorageServiceProtocol
    private var isLoaded = false

    public init(storage: StorageServiceProtocol) {
        self.storage = storage
    }

    // MARK: - Setup

    public func setup() async throws {
        guard !isLoaded else { return }
        isLoaded = true
    }

    // MARK: - CRUD

    public func createEvent(_ event: ScheduleEvent) async throws {
        try await validate(event, ignoringEventID: nil)
        try await storage.insertScheduleEvent(event)
        await postChangeNotification()
    }

    public func getEvent(id: String) async throws -> ScheduleEvent? {
        try await storage.getScheduleEvent(id: id)
    }

    public func listEvents(filter: ScheduleEventFilter?) async throws -> [ScheduleEvent] {
        let allEvents = try await storage.listScheduleEvents()
        var result = allEvents

        if let filter = filter {
            if let status = filter.status {
                result = result.filter { $0.status == status }
            }
            if let categoryId = filter.categoryId {
                result = result.filter { $0.categoryId == categoryId }
            }
            if let priority = filter.priority {
                result = result.filter { $0.priority == priority }
            }
            if let startDate = filter.startDate {
                result = result.filter { $0.endAt >= startDate }
            }
            if let endDate = filter.endDate {
                result = result.filter { $0.startAt <= endDate }
            }
            if let query = filter.query, !query.isEmpty {
                let lowered = query.lowercased()
                result = result.filter {
                    $0.title.lowercased().contains(lowered)
                        || ($0.description?.lowercased().contains(lowered) ?? false)
                        || ($0.tag?.lowercased().contains(lowered) ?? false)
                }
            }
        }

        return result.sorted { $0.startAt < $1.startAt }
    }

    public func updateEvent(_ event: ScheduleEvent) async throws {
        let existing = try await storage.getScheduleEvent(id: event.id)
        guard existing != nil else {
            throw ScheduleError.eventNotFound
        }
        try await validate(event, ignoringEventID: event.id)
        try await storage.updateScheduleEvent(event)
        await postChangeNotification()
    }

    public func deleteEvent(id: String) async throws {
        let existing = try await storage.getScheduleEvent(id: id)
        guard existing != nil else {
            throw ScheduleError.eventNotFound
        }
        try await storage.deleteScheduleEvent(id: id)
        await postChangeNotification()
    }

    // MARK: - Query

    public func getEventsForDate(_ date: Date) async throws -> [ScheduleEvent] {
        let allEvents = try await storage.listScheduleEvents()
        let cal = Calendar.current
        return allEvents
            .filter { cal.isDate($0.startAt, inSameDayAs: date) && $0.status != .cancelled }
            .sorted { $0.startAt < $1.startAt }
    }

    public func getEventsForWeek(of date: Date) async throws -> [ScheduleEvent] {
        let allEvents = try await storage.listScheduleEvents()
        return allEvents
            .filter { $0.isIn(weekOf: date) && $0.status != .cancelled }
            .sorted { $0.startAt < $1.startAt }
    }

    public func searchEvents(query: String) async throws -> [ScheduleEvent] {
        let allEvents = try await storage.listScheduleEvents()
        guard !query.isEmpty else {
            return allEvents.sorted { $0.startAt < $1.startAt }
        }
        let lowered = query.lowercased()
        return allEvents.filter { event in
            event.title.lowercased().contains(lowered)
                || (event.description?.lowercased().contains(lowered) ?? false)
                || (event.tag?.lowercased().contains(lowered) ?? false)
        }
        .sorted { $0.startAt < $1.startAt }
    }

    // MARK: - Stats

    public func getStats() async throws -> ScheduleStats {
        let allEvents = try await storage.listScheduleEvents()
        let cal = Calendar.current
        let today = Date()

        let todayEvents = allEvents.filter {
            cal.isDate($0.startAt, inSameDayAs: today) && $0.status != .cancelled
        }

        let weekEvents = allEvents.filter {
            $0.isIn(weekOf: today) && $0.status != .cancelled
        }

        let completedToday = todayEvents.filter { $0.status == .done }.count

        let focusMinutes = todayEvents
            .filter { $0.status == .todo || $0.status == .done }
            .reduce(0) { $0 + $1.durationMinutes }

        return ScheduleStats(
            totalEvents: allEvents.count,
            todayEvents: todayEvents.count,
            weekEvents: weekEvents.count,
            completedToday: completedToday,
            focusMinutesToday: focusMinutes
        )
    }

    // MARK: - Validation

    private func validate(_ event: ScheduleEvent, ignoringEventID: String?) async throws {
        guard event.endAt > event.startAt else {
            throw ScheduleError.invalidDateRange
        }

        let events = try await storage.listScheduleEvents()
        if let conflict = events.first(where: { candidate in
            candidate.id != ignoringEventID
                && candidate.status != .cancelled
                && candidate.overlaps(with: event)
        }) {
            throw ScheduleError.conflict(conflict)
        }
    }

    private func postChangeNotification() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .scheduleDidChange, object: nil)
        }
    }
}

// MARK: - Schedule Errors

public enum ScheduleError: Error, LocalizedError {
    case eventNotFound
    case invalidDateRange
    case conflict(ScheduleEvent)

    public var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return "日程未找到"
        case .invalidDateRange:
            return "无效的时间范围"
        case .conflict(let event):
            return "与「\(event.title)」时间冲突"
        }
    }
}
