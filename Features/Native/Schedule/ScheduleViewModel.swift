import Foundation
import SwiftUI

@MainActor
final class ScheduleViewModel: ObservableObject {
    // MARK: - Published State

    @Published var viewMode: ScheduleViewMode = .day
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var categories: [ScheduleCategory] = ScheduleCategory.defaultCategories
    @Published var events: [ScheduleEvent] = []
    @Published var searchText: String = ""

    // MARK: - Event Editor State

    @Published var isCreatingEvent: Bool = false
    @Published var newEventDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var newEventStartHour: Int = Calendar.current.component(.hour, from: Date())
    @Published var newEventStartMinute: Int = 0
    @Published var createError: String? = nil

    // MARK: - Persistence

    private let fileName = "schedule-records.json"

    private var recordsURL: URL {
        let fileManager = FileManager.default
        let baseURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL?.appendingPathComponent("AcMind", isDirectory: true)
        if let directory {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent(fileName)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: - Initialization

    init() {
        loadEvents()
    }

    // MARK: - Derived Data

    var todayEvents: [ScheduleEvent] {
        events(on: Date())
    }

    var selectedDayEvents: [ScheduleEvent] {
        events(on: selectedDate)
    }

    var selectedWeekEvents: [ScheduleEvent] {
        events(inWeekContaining: selectedDate)
    }

    var selectedDayCount: Int {
        selectedDayEvents.count
    }

    var selectedDayFocusMinutes: Int {
        selectedDayEvents
            .filter { $0.status == .todo || $0.status == .done }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var selectedDayFreeMinutes: Int {
        max(0, 10 * 60 - selectedDayFocusMinutes)
    }

    var selectedDayWorkloadPercent: Int {
        let available = 10.0 * 60.0
        return min(Int((Double(selectedDayFocusMinutes) / available) * 100), 100)
    }

    var selectedDayWorkloadLevel: WorkloadLevel {
        WorkloadLevel.from(percent: selectedDayWorkloadPercent)
    }

    var selectedWeekFocusMinutes: Int {
        selectedWeekEvents
            .filter { $0.status == .todo || $0.status == .done }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var selectedWeekDayCount: Int {
        weekDates(containing: selectedDate).count
    }

    var viewTitle: String {
        let cal = Calendar.current
        let f = DateFormatter()
        switch viewMode {
        case .day:
            f.dateFormat = "M月d日"
            return f.string(from: selectedDate)
        case .week:
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start,
                  let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) else {
                return "本周"
            }
            f.dateFormat = "M月d日"
            return "\(f.string(from: weekStart)) - \(f.string(from: weekEnd))"
        }
    }

    var viewSubtitle: String {
        switch viewMode {
        case .day:
            return "\(selectedDayCount) 条记录 · \(formatHours(selectedDayFocusMinutes))"
        case .week:
            return "本周 \(selectedWeekEvents.count) 条记录 · \(formatHours(selectedWeekFocusMinutes))"
        }
    }

    var weekWorkloadDays: [WorkloadDay] {
        weekDates(containing: selectedDate).map { day in
            let dayEvents = events(on: day)
            let scheduledMinutes = dayEvents
                .filter { $0.status == .todo || $0.status == .done }
                .reduce(0) { $0 + $1.durationMinutes }
            return WorkloadDay(
                id: dayKey(for: day),
                date: day,
                scheduledMinutes: scheduledMinutes,
                availableMinutes: 600,
                eventCount: dayEvents.count
            )
        }
    }

    var yearlyWorkloadDays: [WorkloadDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let oneYearAgo = cal.date(byAdding: .year, value: -1, to: today) else { return [] }

        var days: [WorkloadDay] = []
        var current = cal.startOfDay(for: oneYearAgo)
        let end = cal.date(byAdding: .day, value: 1, to: today) ?? today

        while current < end {
            let dayEvents = events(on: current)
            let scheduledMinutes = dayEvents
                .filter { $0.status == .todo || $0.status == .done }
                .reduce(0) { $0 + $1.durationMinutes }
            days.append(
                WorkloadDay(
                    id: dayKey(for: current),
                    date: current,
                    scheduledMinutes: scheduledMinutes,
                    availableMinutes: 600,
                    eventCount: dayEvents.count
                )
            )
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return days
    }

    var yearlyStats: (activeDays: Int, avgWorkload: Int) {
        let activeDays = yearlyWorkloadDays.filter { $0.eventCount > 0 }
        let avgWorkload = activeDays.isEmpty ? 0 : activeDays.map(\.workloadPercent).reduce(0, +) / activeDays.count
        return (activeDays.count, avgWorkload)
    }

    var currentMonthEvents: [ScheduleEvent] {
        events(inMonthContaining: selectedDate)
    }

    var currentYearEvents: [ScheduleEvent] {
        events(inYearContaining: selectedDate)
    }

    // MARK: - Lookup

    func events(on date: Date) -> [ScheduleEvent] {
        let day = dayKey(for: date)
        return groupedVisibleEvents[day, default: []]
            .sorted { $0.startAt < $1.startAt }
    }

    func events(inWeekContaining date: Date) -> [ScheduleEvent] {
        let cal = Calendar.current
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return visibleEvents
            .filter { weekInterval.contains($0.startAt) }
            .sorted { $0.startAt < $1.startAt }
    }

    func events(inMonthContaining date: Date) -> [ScheduleEvent] {
        let cal = Calendar.current
        return visibleEvents
            .filter { cal.isDate($0.startAt, equalTo: date, toGranularity: .month) }
            .sorted { $0.startAt < $1.startAt }
    }

    func events(inYearContaining date: Date) -> [ScheduleEvent] {
        let cal = Calendar.current
        return visibleEvents
            .filter { cal.isDate($0.startAt, equalTo: date, toGranularity: .year) }
            .sorted { $0.startAt < $1.startAt }
    }

    func weekDates(containing date: Date) -> [Date] {
        let cal = Calendar.current
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: date) else { return [] }

        var dates: [Date] = []
        var current = cal.startOfDay(for: weekInterval.start)
        let end = cal.startOfDay(for: weekInterval.end)

        while current < end {
            dates.append(current)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }

    func hasEvents(on date: Date) -> Bool {
        groupedVisibleEvents[dayKey(for: date)]?.isEmpty == false
    }

    func categoryColor(for categoryId: String) -> Color {
        categories.first { $0.id == categoryId }?.color ?? .secondary
    }

    func categoryName(for categoryId: String) -> String {
        categories.first { $0.id == categoryId }?.name ?? "未分类"
    }

    func todayCount(for categoryId: String) -> Int {
        selectedDayEvents.filter { $0.categoryId == categoryId }.count
    }

    func weekCount(for categoryId: String) -> Int {
        selectedWeekEvents.filter { $0.categoryId == categoryId }.count
    }

    func selectDate(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    func goToToday() {
        selectedDate = calendar.startOfDay(for: Date())
    }

    func goToPrevious() {
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        }
        selectedDate = calendar.startOfDay(for: selectedDate)
    }

    func goToNext() {
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        }
        selectedDate = calendar.startOfDay(for: selectedDate)
    }

    func toggleCategoryVisibility(_ categoryId: String) {
        guard let index = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        categories[index].visible.toggle()
    }

    func toggleEventStatus(_ eventId: String) {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else { return }
        events[index].status = events[index].status == .done ? .todo : .done
        saveEvents()
    }

    func deleteEvent(_ eventId: String) {
        events.removeAll { $0.id == eventId }
        saveEvents()
    }

    // MARK: - Creation

    func openCreateEvent() {
        newEventDate = selectedDate
        let (hour, minute) = ScheduleTimeGridLayout.nearestHourForNewEvent(calendar: calendar)
        newEventStartHour = max(6, min(hour, 22))
        newEventStartMinute = minute
        isCreatingEvent = true
    }

    func openCreateEvent(on date: Date, hour: Int, minute: Int) {
        newEventDate = calendar.startOfDay(for: date)
        newEventStartHour = hour
        newEventStartMinute = minute
        isCreatingEvent = true
    }

    func closeCreateEvent() {
        isCreatingEvent = false
        createError = nil
    }

    func hasConflict(newStart: Date, newEnd: Date, excluding eventID: String? = nil) -> ScheduleEvent? {
        visibleEvents.first { event in
            event.id != eventID && newStart < event.endAt && newEnd > event.startAt
        }
    }

    func createEvent(title: String, categoryId: String, startHour: Int, startMinute: Int, durationMinutes: Int, isAllDay: Bool) {
        let startComponents = calendar.dateComponents([.year, .month, .day], from: newEventDate)
        guard let startDate = calendar.date(from: DateComponents(
            year: startComponents.year,
            month: startComponents.month,
            day: startComponents.day,
            hour: isAllDay ? 0 : startHour,
            minute: isAllDay ? 0 : startMinute
        )) else { return }

        let endDate: Date
        if isAllDay {
            endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startDate)) ?? startDate.addingTimeInterval(86400)
        } else {
            endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        }

        if let conflict = hasConflict(newStart: startDate, newEnd: endDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            createError = "该时间段已有记录：\(conflict.title) \(formatter.string(from: conflict.startAt)) - \(formatter.string(from: conflict.endAt))"
            return
        }

        let newEvent = ScheduleEvent(
            id: UUID().uuidString,
            title: title,
            description: nil,
            categoryId: categoryId,
            startAt: startDate,
            endAt: endDate,
            isAllDay: isAllDay,
            status: .todo,
            priority: .medium,
            tag: nil
        )

        events.append(newEvent)
        events.sort { $0.startAt < $1.startAt }
        createError = nil
        isCreatingEvent = false
        saveEvents()
    }

    // MARK: - Persistence

    private func loadEvents() {
        if let data = try? Data(contentsOf: recordsURL),
           let decoded = try? decoder.decode([ScheduleEvent].self, from: data) {
            events = decoded.sorted { $0.startAt < $1.startAt }
            return
        }

        events = Self.makeSeedEvents(calendar: calendar)
        saveEvents()
    }

    private func saveEvents() {
        let sorted = events.sorted { $0.startAt < $1.startAt }
        events = sorted
        guard let data = try? encoder.encode(sorted) else { return }
        try? data.write(to: recordsURL, options: [.atomic])
    }

    // MARK: - Helpers

    private var calendar: Calendar {
        Calendar.current
    }

    private var visibleEvents: [ScheduleEvent] {
        events.filter { event in
            let categoryVisible = categories.first { $0.id == event.categoryId }?.visible ?? true
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || event.title.localizedCaseInsensitiveContains(searchText)
                || (event.tag?.localizedCaseInsensitiveContains(searchText) ?? false)

            return event.status != .cancelled && categoryVisible && matchesSearch
        }
    }

    private var groupedVisibleEvents: [String: [ScheduleEvent]] {
        Dictionary(grouping: visibleEvents) { dayKey(for: $0.startAt) }
    }

    private func dayKey(for date: Date) -> String {
        let normalized = calendar.startOfDay(for: date)
        return ISO8601DateFormatter().string(from: normalized)
    }

    private func formatHours(_ minutes: Int) -> String {
        if minutes == 0 { return "0 分钟" }
        let hours = Double(minutes) / 60.0
        return String(format: "%.1f 小时", hours)
    }

    private static func makeSeedEvents(calendar: Calendar) -> [ScheduleEvent] {
        let today = calendar.startOfDay(for: Date())
        let samples: [(Int, String, String, Int, Int, Int, Bool, ScheduleEvent.EventStatus, String?)] = [
            (0, "晨间回顾", "personal", 9, 0, 60, false, .done, "整理"),
            (0, "团队站会", "work", 10, 30, 30, false, .done, "会议"),
            (0, "整理笔记", "acmind", 11, 15, 45, false, .todo, "记录"),
            (0, "午餐 & 休息", "life", 12, 0, 90, false, .todo, nil),
            (1, "深度工作", "acmind", 14, 0, 120, false, .todo, "专注"),
            (1, "学习 SwiftUI", "study", 16, 0, 90, false, .todo, "学习"),
            (-1, "昨日复盘", "personal", 20, 0, 30, false, .done, "复盘"),
            (2, "采购", "life", 18, 0, 60, false, .todo, nil),
            (3, "项目截止日", "work", 0, 0, 1440, true, .todo, nil),
        ]

        return samples.compactMap { offset, title, categoryId, hour, minute, duration, isAllDay, status, tag in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let start = calendar.date(bySettingHour: isAllDay ? 0 : hour, minute: isAllDay ? 0 : minute, second: 0, of: day) ?? day
            let end = isAllDay
                ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)) ?? start.addingTimeInterval(86400)
                : start.addingTimeInterval(TimeInterval(duration * 60))
            return ScheduleEvent(
                id: UUID().uuidString,
                title: title,
                description: nil,
                categoryId: categoryId,
                startAt: start,
                endAt: end,
                isAllDay: isAllDay,
                status: status,
                priority: .medium,
                tag: tag
            )
        }.sorted { $0.startAt < $1.startAt }
    }
}
