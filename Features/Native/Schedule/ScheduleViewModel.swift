import Foundation
import SwiftUI
import EventKit

@MainActor
class ScheduleViewModel: ObservableObject {
    // MARK: - Dependencies

    private let eventStore = EKEventStore()
    // MARK: - Published State

    @Published var viewMode: ScheduleViewMode = .week
    @Published var selectedDate: Date = Date()
    @Published var categories: [ScheduleCategory] = ScheduleCategory.defaultCategories
    @Published var events: [ScheduleEvent] = []
    @Published var searchText: String = ""

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

    // MARK: - Computed Properties

    /// 今日事件（按时间排序）
    var todayEvents: [ScheduleEvent] {
        let cal = Calendar.current
        return events
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
        var days: [WorkloadDay] = []
        var current = weekInterval.start
        let end = weekInterval.end
        while current < end {
            let dayEvents = events.filter { cal.isDate($0.startAt, inSameDayAs: current) && $0.status != .cancelled }
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
        events.filter { $0.isIn(weekOf: selectedDate) && $0.status != .cancelled }
    }

    /// 当前月的事件
    var currentMonthEvents: [ScheduleEvent] {
        events.filter { $0.isIn(monthOf: selectedDate) && $0.status != .cancelled }
    }

    /// 当前年事件
    var currentYearEvents: [ScheduleEvent] {
        events.filter { $0.isIn(yearOf: selectedDate) && $0.status != .cancelled }
    }

    /// 过去 365 天的饱和度数据
    var yearlyWorkloadDays: [WorkloadDay] {
        let cal = Calendar.current
        let today = Date()
        guard let oneYearAgo = cal.date(byAdding: .year, value: -1, to: today) else { return [] }
        var days: [WorkloadDay] = []
        var current = cal.startOfDay(for: oneYearAgo)
        let end = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: today)!)
        while current < end {
            let dayEvents = events.filter { cal.isDate($0.startAt, inSameDayAs: current) && $0.status != .cancelled }
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
        return events
            .filter { cal.isDate($0.startAt, inSameDayAs: date) && $0.status != .cancelled }
            .sorted { $0.startAt < $1.startAt }
    }

    /// 获取指定日期有事件的标记
    func hasEvents(on date: Date) -> Bool {
        let cal = Calendar.current
        return events.contains { cal.isDate($0.startAt, inSameDayAs: date) && $0.status != .cancelled }
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
    }

    // MARK: - Event Creation

    /// 打开新建日程弹窗（从工具栏按钮触发）
    func openCreateEvent() {
        let cal = Calendar.current
        newEventDate = selectedDate
        let (hour, minute) = ScheduleTimeGridLayout.nearestHourForNewEvent(calendar: cal)
        newEventStartHour = max(6, min(hour, 22))
        newEventStartMinute = minute
        isCreatingEvent = true
    }

    /// 打开新建日程弹窗（从点击时间格触发）
    func openCreateEvent(on date: Date, hour: Int, minute: Int) {
        newEventDate = date
        newEventStartHour = hour
        newEventStartMinute = minute
        isCreatingEvent = true
    }

    /// 关闭新建日程弹窗
    func closeCreateEvent() {
        isCreatingEvent = false
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

        events.append(newEvent)

        // 尝试同步到系统日历
        saveToSystemCalendar(event: newEvent)

        createError = nil
        isCreatingEvent = false
    }

    /// 保存事件到系统日历 (EventKit)
    private func saveToSystemCalendar(event: ScheduleEvent) {
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.startDate = event.startAt
        ekEvent.endDate = event.endAt
        ekEvent.isAllDay = event.isAllDay
        ekEvent.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            // 更新本地事件 ID 为系统日历 ID
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index] = ScheduleEvent(
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
            }
        } catch {
            print("⚠️ 保存到系统日历失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Initialization

    init() {
        loadEvents()
    }

    // MARK: - Event Loading

    private func loadEvents() {
        Task {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                guard granted else {
                    print("⚠️ 日历访问被拒绝，使用 fallback 数据")
                    events = generateMockEvents(around: Date(), calendar: Calendar.current)
                    return
                }

                let calendars = eventStore.calendars(for: .event)
                let cal = Calendar.current
                let today = Date()

                // 查询范围：过去 12 个月到未来 1 个月
                guard let startDate = cal.date(byAdding: .month, value: -12, to: today),
                      let endDate = cal.date(byAdding: .month, value: 1, to: today) else {
                    events = []
                    return
                }

                let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
                let ekEvents = eventStore.events(matching: predicate)

                events = ekEvents.map { ekEvent -> ScheduleEvent in
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
            } catch {
                print("⚠️ EventKit 错误: \(error.localizedDescription)，使用 fallback 数据")
                events = generateMockEvents(around: Date(), calendar: Calendar.current)
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

    // MARK: - Mock Data (Fallback)

    private func generateMockEvents(around today: Date, calendar: Calendar) -> [ScheduleEvent] {
        var events: [ScheduleEvent] = []

        // --- 今天的事件 ---
        let todayEvents: [(String, String, String, Int, Int, Bool, String?)] = [
            ("e1", "晨间回顾", "personal", 9, 0, false, "整理"),
            ("e2", "团队站会", "work", 10, 30, false, "会议"),
            ("e3", "整理笔记", "acmind", 11, 0, false, "整理"),
            ("e4", "午餐 & 休息", "life", 12, 0, false, nil),
            ("e5", "深度工作", "acmind", 14, 0, false, "专注"),
            ("e6", "阅读技术文档", "study", 16, 0, false, "专注"),
            ("e7", "健身", "fitness", 18, 0, false, nil),
            ("e8", "今日复盘", "personal", 20, 0, false, "整理"),
        ]

        for (id, title, catId, h, m, done, tag) in todayEvents {
            let start = calendar.date(bySettingHour: h, minute: m, second: 0, of: today)!
            let durations: [String: Int] = [
                "晨间回顾": 60, "团队站会": 30, "整理笔记": 60,
                "午餐 & 休息": 90, "深度工作": 120, "阅读技术文档": 90,
                "健身": 60, "今日复盘": 30
            ]
            let dur = durations[title] ?? 60
            let end = start.addingTimeInterval(TimeInterval(dur * 60))
            events.append(ScheduleEvent(
                id: id, title: title, categoryId: catId,
                startAt: start, endAt: end,
                isAllDay: false, status: done ? .done : .todo,
                priority: .medium, tag: tag
            ))
        }

        // --- 本周其他天的事件 ---
        let weekDayData: [(Int, [(String, String, Int, Int, Int)])] = [
            (-2, [("项目规划", "work", 9, 0, 120), ("英语学习", "study", 14, 0, 90)]),
            (-1, [("代码评审", "work", 10, 0, 60), ("产品设计讨论", "work", 14, 0, 90), ("跑步", "fitness", 18, 0, 45)]),
            (1, [("周会", "work", 9, 0, 60), ("写作", "acmind", 14, 0, 120), ("冥想", "personal", 21, 0, 20)]),
            (2, [("客户沟通", "work", 10, 0, 60), ("学习 SwiftUI", "study", 14, 0, 90), ("瑜伽", "fitness", 18, 0, 60)]),
            (3, [("冲刺回顾", "work", 9, 0, 90), ("读书", "study", 15, 0, 60)]),
            (4, [("周末计划", "personal", 10, 0, 30), ("采购", "life", 14, 0, 90)]),
        ]

        for (dayOffset, dayEvents) in weekDayData {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            for (i, (title, catId, h, m, dur)) in dayEvents.enumerated() {
                let start = calendar.date(bySettingHour: h, minute: m, second: 0, of: day)!
                let end = start.addingTimeInterval(TimeInterval(dur * 60))
                events.append(ScheduleEvent(
                    id: "w\(dayOffset)_\(i)", title: title, categoryId: catId,
                    startAt: start, endAt: end,
                    isAllDay: false, status: dayOffset < 0 ? .done : .todo,
                    priority: .medium, tag: nil
                ))
            }
        }

        // --- 过去几个月的随机事件（用于热力图） ---
        var seed = 42
        func nextRandom() -> Int {
            seed = (seed &* 1103515245 &+ 12345) & 0x7FFFFFFF
            return seed
        }

        for monthOffset in (-11)...(-1) {
            guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: today) else { continue }
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count
            let component = calendar.dateComponents([.year, .month], from: monthStart)
            let firstDay = calendar.date(from: component)!

            for day in 1...daysInMonth {
                let r = nextRandom() % 100
                guard r < 70 else { continue } // 70% 概率有事件

                guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) else { continue }

                let eventCount = (nextRandom() % 3) + 1
                var currentHour = 8 + (nextRandom() % 3)
                let titles = ["深度工作", "会议", "学习", "整理", "写作", "阅读", "健身", "复盘", "规划"]
                let catIds = ["work", "acmind", "study", "personal", "fitness", "life"]

                for j in 0..<eventCount {
                    guard currentHour < 20 else { break }
                    let titleIdx = nextRandom() % titles.count
                    let catIdx = nextRandom() % catIds.count
                    let dur = [30, 60, 90, 120][nextRandom() % 4]

                    let start = calendar.date(bySettingHour: currentHour, minute: 0, second: 0, of: date)!
                    let end = start.addingTimeInterval(TimeInterval(dur * 60))

                    events.append(ScheduleEvent(
                        id: "past_\(monthOffset)_\(day)_\(j)",
                        title: titles[titleIdx],
                        categoryId: catIds[catIdx],
                        startAt: start, endAt: end,
                        isAllDay: false, status: .done,
                        priority: .medium, tag: nil
                    ))
                    currentHour += dur / 60 + 1
                }
            }
        }

        // --- 全天事件 ---
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            events.append(ScheduleEvent(
                id: "allday_1", title: "项目截止日", categoryId: "work",
                startAt: calendar.startOfDay(for: tomorrow),
                endAt: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: tomorrow))!,
                isAllDay: true, status: .todo, priority: .high, tag: nil
            ))
        }

        if let nextWeek = calendar.date(byAdding: .day, value: 3, to: today) {
            events.append(ScheduleEvent(
                id: "allday_2", title: "团建活动", categoryId: "life",
                startAt: calendar.startOfDay(for: nextWeek),
                endAt: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: nextWeek))!,
                isAllDay: true, status: .todo, priority: .medium, tag: nil
            ))
        }

        return events
    }
}
