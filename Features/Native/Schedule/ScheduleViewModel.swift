import Foundation
import SwiftUI
import EventKit

@MainActor
class ScheduleViewModel: ObservableObject {
    // MARK: - Dependencies

    private let eventStore = EKEventStore()
    private let localStore = LocalScheduleStore()
    private var calendarAccessGranted = false
    // MARK: - Published State

    @Published var viewMode: ScheduleViewMode = .week
    @Published var selectedDate: Date = Date()
    @Published var categories: [ScheduleCategory] = ScheduleCategory.defaultCategories
    @Published var events: [ScheduleEvent] = []
    @Published var searchText: String = ""
    @Published var accessNotice: String? = nil

    // MARK: - Event Editor State

    /// 是否显示新建日程弹窗
    @Published var isCreatingEvent: Bool = false
    /// 新建日程的预设日期
    @Published var newEventDate: Date = Date()
    /// 新建日程的预设开始时间（小时）
    @Published var newEventStartHour: Int = Calendar.current.component(.hour, from: Date())
    /// 新建日程的预设开始时间（分钟）
    @Published var newEventStartMinute: Int = 0
    /// 创建错误信息
    @Published var createError: String? = nil
    /// 正在编辑的事件
    @Published var editingEvent: ScheduleEvent? = nil

    // MARK: - Computed Properties

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
            categoryName(for: event.categoryId),
            event.status.displayName
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private func matchesSearch(_ event: ScheduleEvent) -> Bool {
        guard isSearching else { return true }
        return searchableText(for: event).contains(normalizedSearchText)
    }

    private func filteredEvents(_ input: [ScheduleEvent]) -> [ScheduleEvent] {
        guard isSearching else { return input }
        return input.filter(matchesSearch)
    }

    /// 今日事件（按时间排序）
    var todayEvents: [ScheduleEvent] {
        let cal = Calendar.current
        return filteredEvents(events)
            .filter { cal.isDate($0.startAt, inSameDayAs: Date()) && $0.status != .cancelled }
            .sorted { $0.startAt < $1.startAt }
    }

    /// 今日已安排事件数
    var todayEventCount: Int {
        todayEvents.filter { $0.status != .cancelled }.count
    }

    /// 今日专注时间（分钟）
    var todayFocusMinutes: Int {
        todayEvents
            .filter { $0.status == .todo || $0.status == .done }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    /// 今日饱和度
    var todayWorkloadPercent: Int {
        let available = 600 // 10 小时
        return min(Int(Double(todayFocusMinutes) / Double(available) * 100), 100)
    }

    /// 今日饱和度状态
    var todayWorkloadLevel: WorkloadLevel {
        WorkloadLevel.from(percent: todayWorkloadPercent)
    }

    /// 本周每天饱和度（周一到周五）
    var weekWorkloadDays: [WorkloadDay] {
        let cal = Calendar.current
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        let visibleEvents = filteredEvents(events)
        var days: [WorkloadDay] = []
        var current = weekInterval.start
        let end = weekInterval.end
        while current < end {
            let dayEvents = visibleEvents.filter { cal.isDate($0.startAt, inSameDayAs: current) && $0.status != .cancelled }
            let scheduledMinutes = dayEvents.reduce(0) { $0 + $1.durationMinutes }
            let dateStr = ISO8601DateFormatter().string(from: current)
            days.append(WorkloadDay(
                id: dateStr,
                date: current,
                scheduledMinutes: scheduledMinutes,
                availableMinutes: 600,
                eventCount: dayEvents.count
            ))
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    /// 当前周的事件
    var currentWeekEvents: [ScheduleEvent] {
        filteredEvents(events).filter { $0.isIn(weekOf: selectedDate) && $0.status != .cancelled }
    }

    /// 当前月的事件
    var currentMonthEvents: [ScheduleEvent] {
        filteredEvents(events).filter { $0.isIn(monthOf: selectedDate) && $0.status != .cancelled }
    }

    /// 当前年事件
    var currentYearEvents: [ScheduleEvent] {
        filteredEvents(events).filter { $0.isIn(yearOf: selectedDate) && $0.status != .cancelled }
    }

    /// 过去 365 天的饱和度数据
    var yearlyWorkloadDays: [WorkloadDay] {
        let cal = Calendar.current
        let today = Date()
        guard let oneYearAgo = cal.date(byAdding: .year, value: -1, to: today) else { return [] }
        let visibleEvents = filteredEvents(events)
        var days: [WorkloadDay] = []
        var current = cal.startOfDay(for: oneYearAgo)
        let end = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: today)!)
        while current < end {
            let dayEvents = visibleEvents.filter { cal.isDate($0.startAt, inSameDayAs: current) && $0.status != .cancelled }
            let scheduledMinutes = dayEvents.reduce(0) { $0 + $1.durationMinutes }
            let dateStr = ISO8601DateFormatter().string(from: current)
            days.append(WorkloadDay(
                id: dateStr,
                date: current,
                scheduledMinutes: scheduledMinutes,
                availableMinutes: 600,
                eventCount: dayEvents.count
            ))
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    /// 年度统计
    var yearlyStats: (activeDays: Int, avgWorkload: Int) {
        let days = yearlyWorkloadDays.filter { $0.eventCount > 0 }
        let activeDays = days.count
        let avgWorkload = days.isEmpty ? 0 : days.map(\.workloadPercent).reduce(0, +) / days.count
        return (activeDays, avgWorkload)
    }

    /// 当前视图标题
    var viewTitle: String {
        let cal = Calendar.current
        switch viewMode {
        case .week:
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start,
                  let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) else {
                return "本周"
            }
            let f = DateFormatter()
            f.dateFormat = "M月d日"
            return "\(f.string(from: weekStart)) - \(f.string(from: weekEnd))"
        case .month:
            let f = DateFormatter()
            f.dateFormat = "yyyy年M月"
            return f.string(from: selectedDate)
        case .year:
            let f = DateFormatter()
            f.dateFormat = "yyyy年"
            return f.string(from: selectedDate)
        }
    }

    /// 当前视图副标题
    var viewSubtitle: String {
        switch viewMode {
        case .week:
            let count = currentWeekEvents.count
            let avg = weekWorkloadDays.isEmpty ? 0 : weekWorkloadDays.map(\.workloadPercent).reduce(0, +) / weekWorkloadDays.count
            return "本周 \(count) 项日程 · 平均饱和度 \(avg)%"
        case .month:
            let count = currentMonthEvents.count
            return "本月 \(count) 项日程"
        case .year:
            let stats = yearlyStats
            return "过去 365 天中有 \(stats.activeDays) 天安排了日程，平均饱和度 \(stats.avgWorkload)%"
        }
    }

    /// 按分类统计今日事件数
    func todayCount(for categoryId: String) -> Int {
        todayEvents.filter { $0.categoryId == categoryId }.count
    }

    /// 按分类统计本周事件数
    func weekCount(for categoryId: String) -> Int {
        currentWeekEvents.filter { $0.categoryId == categoryId }.count
    }

    /// 获取指定日期的事件
    func events(for date: Date) -> [ScheduleEvent] {
        let cal = Calendar.current
        return filteredEvents(events)
            .filter { cal.isDate($0.startAt, inSameDayAs: date) && $0.status != .cancelled }
            .sorted { $0.startAt < $1.startAt }
    }

    /// 获取指定日期有事件的标记
    func hasEvents(on date: Date) -> Bool {
        let cal = Calendar.current
        return filteredEvents(events).contains { cal.isDate($0.startAt, inSameDayAs: date) && $0.status != .cancelled }
    }

    /// 获取分类颜色
    func categoryColor(for categoryId: String) -> Color {
        categories.first { $0.id == categoryId }?.color ?? .secondary
    }

    /// 获取分类名称
    func categoryName(for categoryId: String) -> String {
        categories.first { $0.id == categoryId }?.name ?? "未分类"
    }

    // MARK: - Navigation

    func goToToday() {
        selectedDate = Date()
    }

    func goToPrevious() {
        let cal = Calendar.current
        switch viewMode {
        case .week:
            selectedDate = cal.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = cal.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        case .year:
            selectedDate = cal.date(byAdding: .year, value: -1, to: selectedDate) ?? selectedDate
        }
    }

    func goToNext() {
        let cal = Calendar.current
        switch viewMode {
        case .week:
            selectedDate = cal.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = cal.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        case .year:
            selectedDate = cal.date(byAdding: .year, value: 1, to: selectedDate) ?? selectedDate
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    func toggleCategoryVisibility(_ categoryId: String) {
        guard let index = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        categories[index].visible.toggle()
    }

    func toggleEventStatus(_ eventId: String) {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else { return }
        if events[index].status == .done {
            events[index].status = .todo
        } else {
            events[index].status = .done
        }
        persistLocalEvent(events[index])
    }

    // MARK: - Event Creation

    /// 打开新建日程弹窗（从工具栏按钮触发）
    func openCreateEvent() {
        editingEvent = nil
        let cal = Calendar.current
        newEventDate = selectedDate
        let (hour, minute) = ScheduleTimeGridLayout.nearestHourForNewEvent(calendar: cal)
        newEventStartHour = max(6, min(hour, 22))
        newEventStartMinute = minute
        isCreatingEvent = true
    }

    /// 打开新建日程弹窗（从点击时间格触发）
    func openCreateEvent(on date: Date, hour: Int, minute: Int) {
        editingEvent = nil
        newEventDate = date
        newEventStartHour = hour
        newEventStartMinute = minute
        isCreatingEvent = true
    }

    func openEditEvent(_ event: ScheduleEvent) {
        editingEvent = event
        newEventDate = event.startAt
        newEventStartHour = Calendar.current.component(.hour, from: event.startAt)
        newEventStartMinute = Calendar.current.component(.minute, from: event.startAt)
        isCreatingEvent = true
    }

    /// 关闭新建日程弹窗
    func closeCreateEvent() {
        isCreatingEvent = false
        editingEvent = nil
    }

    /// 检测新日程是否与现有日程冲突
    func hasConflict(newStart: Date, newEnd: Date, excluding eventID: String? = nil) -> ScheduleEvent? {
        let activeEvents = events.filter { $0.status != .cancelled && $0.id != eventID }
        return activeEvents.first { event in
            return newStart < event.endAt && newEnd > event.startAt
        }
    }

    /// 创建新日程并保存到系统日历
    func createEvent(title: String, categoryId: String, startHour: Int, startMinute: Int, durationMinutes: Int, isAllDay: Bool) {
        let cal = Calendar.current
        let startComponents = cal.dateComponents([.year, .month, .day], from: newEventDate)
        guard let startDate = cal.date(from: DateComponents(
            year: startComponents.year,
            month: startComponents.month,
            day: startComponents.day,
            hour: isAllDay ? 0 : startHour,
            minute: isAllDay ? 0 : startMinute
        )) else { return }

        let endDate: Date
        if isAllDay {
            endDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: startDate)) ?? startDate.addingTimeInterval(86400)
        } else {
            endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        }

        // 冲突检测
        if let conflictingEvent = hasConflict(newStart: startDate, newEnd: endDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            createError = "该时间段已有任务：\(conflictingEvent.title) \(formatter.string(from: conflictingEvent.startAt)) - \(formatter.string(from: conflictingEvent.endAt))\n请选择其他时间，或先调整已有任务。"
            return
        }

        if let editingEvent {
            let updatedEvent = ScheduleEvent(
                id: editingEvent.id,
                title: title,
                categoryId: categoryId,
                startAt: startDate,
                endAt: endDate,
                isAllDay: isAllDay,
                status: editingEvent.status,
                priority: editingEvent.priority,
                tag: editingEvent.tag
            )
            upsertEvent(updatedEvent, replacing: editingEvent.id)
            createError = nil
            isCreatingEvent = false
            self.editingEvent = nil
            return
        }

        let newEvent = ScheduleEvent(
            id: UUID().uuidString,
            title: title,
            categoryId: categoryId,
            startAt: startDate,
            endAt: endDate,
            isAllDay: isAllDay,
            status: .todo,
            priority: .medium,
            tag: nil
        )

        upsertEvent(newEvent)

        createError = nil
        isCreatingEvent = false
    }

    func deleteEvent(_ eventID: String) {
        guard let existing = events.first(where: { $0.id == eventID }) else { return }

        if calendarAccessGranted, let ekEvent = eventStore.event(withIdentifier: eventID) {
            do {
                try eventStore.remove(ekEvent, span: .thisEvent)
            } catch {
                print("⚠️ 删除系统日历事件失败: \(error.localizedDescription)")
            }
        }

        events.removeAll { $0.id == eventID }
        removeLocalEvent(id: eventID)

        if editingEvent?.id == existing.id {
            editingEvent = nil
            isCreatingEvent = false
        }
    }

    /// 保存事件到系统日历 (EventKit)
    private func saveToSystemCalendar(event: ScheduleEvent, existingIdentifier: String? = nil) -> ScheduleEvent? {
        if let existingIdentifier, let ekEvent = eventStore.event(withIdentifier: existingIdentifier) {
            ekEvent.title = event.title
            ekEvent.startDate = event.startAt
            ekEvent.endDate = event.endAt
            ekEvent.isAllDay = event.isAllDay

            do {
                try eventStore.save(ekEvent, span: .thisEvent)
                return ScheduleEvent(
                    id: ekEvent.eventIdentifier,
                    title: event.title,
                    categoryId: event.categoryId,
                    startAt: event.startAt,
                    endAt: event.endAt,
                    isAllDay: event.isAllDay,
                    status: event.status,
                    priority: event.priority,
                    tag: event.tag
                )
            } catch {
                print("⚠️ 更新系统日历事件失败: \(error.localizedDescription)")
                return nil
            }
        }

        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.startDate = event.startAt
        ekEvent.endDate = event.endAt
        ekEvent.isAllDay = event.isAllDay
        ekEvent.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            return ScheduleEvent(
                id: ekEvent.eventIdentifier,
                title: event.title,
                categoryId: event.categoryId,
                startAt: event.startAt,
                endAt: event.endAt,
                isAllDay: event.isAllDay,
                status: event.status,
                priority: event.priority,
                tag: event.tag
            )
        } catch {
            print("⚠️ 保存到系统日历失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Initialization

    init(shouldLoadEvents: Bool = true) {
        if shouldLoadEvents {
            loadEvents()
        }
    }

    // MARK: - Event Loading

    private func loadEvents() {
        Task {
            let localEvents = localStore.load()

            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    self.calendarAccessGranted = granted
                }
                if granted == false {
                    await MainActor.run {
                        self.events = localEvents
                        self.accessNotice = localEvents.isEmpty
                            ? "系统日历访问未授权，当前仅显示本地保存的日程。"
                            : "系统日历访问未授权，当前优先显示本地保存的日程。"
                    }
                    return
                }

                let calendars = eventStore.calendars(for: .event)
                let cal = Calendar.current
                let today = Date()

                // 查询范围：过去 12 个月到未来 1 个月
                guard let startDate = cal.date(byAdding: .month, value: -12, to: today),
                      let endDate = cal.date(byAdding: .month, value: 1, to: today) else {
                    await MainActor.run {
                        self.events = localEvents
                        self.accessNotice = localEvents.isEmpty ? nil : "已加载本地保存的日程。"
                    }
                    return
                }

                let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
                let ekEvents = eventStore.events(matching: predicate)

                let systemEvents = ekEvents.map { ekEvent -> ScheduleEvent in
                    ScheduleEvent(
                        id: ekEvent.eventIdentifier,
                        title: ekEvent.title ?? "无标题",
                        categoryId: mapCalendarToCategory(ekEvent.calendar.title),
                        startAt: ekEvent.startDate,
                        endAt: ekEvent.endDate,
                        isAllDay: ekEvent.isAllDay,
                        status: .todo,
                        priority: .medium,
                        tag: nil
                    )
                }
                await MainActor.run {
                    self.events = self.mergeEvents(localEvents + systemEvents)
                    self.accessNotice = self.events.isEmpty ? "没有可显示的日程。" : nil
                }
            } catch {
                print("⚠️ EventKit 错误: \(error.localizedDescription)")
                await MainActor.run {
                    self.events = localEvents
                    self.accessNotice = localEvents.isEmpty
                        ? "日历读取失败，当前仅显示本地保存的日程。"
                        : "日历读取失败，当前优先显示本地保存的日程。"
                }
            }
        }
    }

    /// 将系统日历名称映射到 ScheduleCategory id
    private func mapCalendarToCategory(_ calendarTitle: String) -> String {
        let title = calendarTitle.lowercased()
        if title.contains("个人") || title.contains("personal") { return "personal" }
        if title.contains("工作") || title.contains("work") { return "work" }
        if title.contains("健身") || title.contains("fitness") || title.contains("sport") { return "fitness" }
        if title.contains("学习") || title.contains("study") { return "study" }
        if title.contains("生活") || title.contains("life") { return "life" }
        if title.contains("假日") || title.contains("holiday") || title.contains("生日") || title.contains("birthday") { return "holiday" }
        return "acmind"
    }

    private func persistLocalEvent(_ event: ScheduleEvent) {
        var stored = localStore.load()
        if let index = stored.firstIndex(where: { $0.id == event.id }) {
            stored[index] = event
        } else {
            stored.append(event)
        }
        localStore.save(stored)
    }

    private func removeLocalEvent(id: String) {
        var stored = localStore.load()
        stored.removeAll { $0.id == id }
        localStore.save(stored)
    }

    private func upsertEvent(_ event: ScheduleEvent, replacing originalID: String? = nil) {
        var candidate = event
        if calendarAccessGranted {
            if let synced = saveToSystemCalendar(event: event, existingIdentifier: originalID) {
                candidate = synced
            }
        }

        if let originalID, originalID != candidate.id {
            events.removeAll { $0.id == originalID }
            removeLocalEvent(id: originalID)
        }

        if let index = events.firstIndex(where: { $0.id == candidate.id }) {
            events[index] = candidate
        } else {
            events.append(candidate)
        }
        persistLocalEvent(candidate)
        events = mergeEvents(events)
    }

    private func mergeEvents(_ allEvents: [ScheduleEvent]) -> [ScheduleEvent] {
        var unique: [String: ScheduleEvent] = [:]
        for event in allEvents {
            unique[event.id] = event
        }
        return unique.values.sorted { $0.startAt < $1.startAt }
    }
}

// MARK: - Local Schedule Store

private final class LocalScheduleStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = base.appendingPathComponent("AcMind", isDirectory: true)
            .appendingPathComponent("Schedule", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("local-events.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [ScheduleEvent] {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([ScheduleEvent].self, from: data)) ?? []
    }

    func save(_ events: [ScheduleEvent]) {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
