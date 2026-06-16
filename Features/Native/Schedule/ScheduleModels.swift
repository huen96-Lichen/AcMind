import Foundation
import SwiftUI

// MARK: - Schedule Models

/// 日程事件
struct ScheduleEvent: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    var description: String? = nil
    let categoryId: String
    let startAt: Date
    let endAt: Date
    var isAllDay: Bool
    var status: EventStatus
    var priority: EventPriority
    var tag: String? // 可选标签，如「专注」「会议」「整理」

    enum EventStatus: String, Codable, CaseIterable {
        case todo
        case done
        case cancelled

        var displayName: String {
            switch self {
            case .todo: return "待办"
            case .done: return "已完成"
            case .cancelled: return "已取消"
            }
        }
    }

    enum EventPriority: String, Codable, CaseIterable {
        case low
        case medium
        case high

        var displayName: String {
            switch self {
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            }
        }
    }

    /// 日程时长（分钟）
    var durationMinutes: Int {
        Calendar.current.dateComponents([.minute], from: startAt, to: endAt).minute ?? 0
    }

    func displayTimeRange(using calendar: Calendar = .current) -> String {
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

    func timingState(referenceDate: Date = Date()) -> ScheduleEventTimingState {
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

    /// 是否在指定日期
    func isOn(date: Date) -> Bool {
        Calendar.current.isDate(startAt, inSameDayAs: date)
    }

    /// 是否在指定周内
    func isIn(weekOf date: Date) -> Bool {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: date)?.start,
              let eventWeekStart = cal.dateInterval(of: .weekOfYear, for: startAt)?.start else {
            return false
        }
        return cal.isDate(weekStart, inSameDayAs: eventWeekStart)
    }

    /// 是否在指定月内
    func isIn(monthOf date: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year, from: startAt) == cal.component(.year, from: date)
            && cal.component(.month, from: startAt) == cal.component(.month, from: date)
    }

    /// 是否在指定年内
    func isIn(yearOf date: Date) -> Bool {
        Calendar.current.component(.year, from: startAt) == Calendar.current.component(.year, from: date)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScheduleEvent, rhs: ScheduleEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Schedule Category

/// 日程分类
struct ScheduleCategory: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color
    var visible: Bool

    static let defaultCategories: [ScheduleCategory] = [
        ScheduleCategory(id: "personal", name: "个人", color: Color(red: 0.55, green: 0.55, blue: 0.58), visible: true),
        ScheduleCategory(id: "work", name: "工作", color: Color(red: 0.36, green: 0.49, blue: 0.85), visible: true),
        ScheduleCategory(id: "acmind", name: "AcWork", color: Color(red: 0.11, green: 0.49, blue: 0.84), visible: true),
        ScheduleCategory(id: "study", name: "学习", color: Color(red: 0.55, green: 0.34, blue: 0.78), visible: true),
        ScheduleCategory(id: "fitness", name: "健身", color: Color(red: 0.30, green: 0.69, blue: 0.31), visible: true),
        ScheduleCategory(id: "life", name: "生活", color: Color(red: 0.95, green: 0.59, blue: 0.38), visible: true),
        ScheduleCategory(id: "holiday", name: "节假日", color: Color(red: 0.90, green: 0.26, blue: 0.40), visible: true),
    ]
}

// MARK: - Workload Day

/// 工作饱和度（按天）
struct WorkloadDay: Identifiable {
    let id: String // date string
    let date: Date
    let scheduledMinutes: Int
    let availableMinutes: Int
    let eventCount: Int

    var workloadPercent: Int {
        guard availableMinutes > 0 else { return 0 }
        return Int(Double(scheduledMinutes) / Double(availableMinutes) * 100)
    }

    var workloadLevel: WorkloadLevel {
        WorkloadLevel.from(percent: workloadPercent)
    }

    var statusText: String {
        workloadLevel.displayName
    }
}

// MARK: - Workload Level

enum WorkloadLevel: String, CaseIterable {
    case empty
    case low
    case medium
    case high
    case overload

    var displayName: String {
        switch self {
        case .empty: return "空闲"
        case .low: return "轻松"
        case .medium: return "适中"
        case .high: return "偏满"
        case .overload: return "过载"
        }
    }

    var color: Color {
        switch self {
        case .empty: return Color(red: 0.93, green: 0.94, blue: 0.95)
        case .low: return Color(red: 0.85, green: 0.93, blue: 1.0)
        case .medium: return Color(red: 0.66, green: 0.83, blue: 1.0)
        case .high: return Color(red: 0.37, green: 0.66, blue: 0.95)
        case .overload: return Color(red: 0.11, green: 0.49, blue: 0.84)
        }
    }

    static func from(percent: Int) -> WorkloadLevel {
        switch percent {
        case 0: return .empty
        case 1...35: return .low
        case 36...65: return .medium
        case 66...85: return .high
        default: return .overload
        }
    }
}

// MARK: - Calendar View Mode

enum ScheduleViewMode: String, CaseIterable {
    case week
    case month
    case year

    var displayName: String {
        switch self {
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        }
    }

    var icon: String {
        switch self {
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        case .year: return "calendar.circle"
        }
    }
}

enum ScheduleEventTimingState: String, Equatable {
    case upcoming
    case ongoing
    case overdue
    case allDay
    case done
    case cancelled

    var displayName: String {
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

struct ScheduleEventConflict: Equatable {
    let first: ScheduleEvent
    let second: ScheduleEvent
}

struct ScheduleFreeWindow: Equatable {
    let start: Date
    let end: Date

    var durationMinutes: Int {
        max(0, Calendar.current.dateComponents([.minute], from: start, to: end).minute ?? 0)
    }
}

struct SchedulePlanningSnapshot: Equatable {
    let referenceDate: Date
    let selectedDate: Date
    let totalEventCount: Int
    let activeEventCount: Int
    let completedEventCount: Int
    let allDayEventCount: Int
    let overdueEventCount: Int
    let currentEvent: ScheduleEvent?
    let nextEvent: ScheduleEvent?
    let conflict: ScheduleEventConflict?
    let freeWindow: ScheduleFreeWindow?
    let selectedDateLabel: String
    let currentTimeLabel: String
}

// MARK: - Layout Constants

enum ScheduleLayout {
    static let sidebarWidth: CGFloat = 240
    static let mainMinWidth: CGFloat = 780
    static let pagePadding: CGFloat = 24
    static let pageRadius: CGFloat = 20
    static let toolbarHeight: CGFloat = 64
    static let weekTimeColumnWidth: CGFloat = 56
    static let weekHourHeight: CGFloat = 56
    static let weekHalfHourHeight: CGFloat = 28
    static let eventCornerRadius: CGFloat = 8
}

// MARK: - Schedule Layout Metrics

struct ScheduleLayoutMetrics {
    static let hourHeight: CGFloat = 64
    static let minEventHeight: CGFloat = 18
    static let snapMinutes: Int = 15
    static let dayColumnSpacing: CGFloat = 8
    static let eventHorizontalPadding: CGFloat = 6
}

// MARK: - Schedule Time Grid Layout

struct ScheduleTimeGridLayout {
    static func yOffset(
        for date: Date,
        dayStartHour: Int = 6,
        calendar: Calendar = .current
    ) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? dayStartHour
        let minute = components.minute ?? 0
        let totalMinutes = max(0, (hour - dayStartHour) * 60 + minute)
        return CGFloat(totalMinutes) / 60.0 * ScheduleLayoutMetrics.hourHeight
    }

    static func height(durationMinutes: Int) -> CGFloat {
        max(
            CGFloat(durationMinutes) / 60.0 * ScheduleLayoutMetrics.hourHeight,
            ScheduleLayoutMetrics.minEventHeight
        )
    }

    static func minutesFromYOffset(_ y: CGFloat) -> Int {
        let rawMinutes = y / ScheduleLayoutMetrics.hourHeight * 60
        let snapped = round(rawMinutes / CGFloat(ScheduleLayoutMetrics.snapMinutes)) * CGFloat(ScheduleLayoutMetrics.snapMinutes)
        return max(0, Int(snapped))
    }

    static func snapToNearestQuarterHour(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = components.minute ?? 0
        let snappedMinute = round(CGFloat(minute) / 15.0) * 15
        let adjustedMinute = snappedMinute >= 60 ? 0 : snappedMinute
        let adjustedHour = snappedMinute >= 60 ? (components.hour ?? 0) + 1 : (components.hour ?? 0)
        
        return calendar.date(from: DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: adjustedHour,
            minute: Int(adjustedMinute)
        )) ?? date
    }

    static func dateFromYOffset(
        _ y: CGFloat,
        day: Date,
        dayStartHour: Int = 6,
        calendar: Calendar = .current
    ) -> Date {
        let totalMinutes = minutesFromYOffset(y)
        let hour = dayStartHour + (totalMinutes / 60)
        let minute = totalMinutes % 60
        
        return calendar.date(from: DateComponents(
            year: calendar.component(.year, from: day),
            month: calendar.component(.month, from: day),
            day: calendar.component(.day, from: day),
            hour: hour,
            minute: minute
        )) ?? day
    }

    static func nearestHourForNewEvent(calendar: Calendar = .current) -> (hour: Int, minute: Int) {
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        
        let totalMinutes = hour * 60 + minute
        let roundedMinutes = ((totalMinutes + 15) / 30) * 30
        let resultHour = roundedMinutes / 60
        let resultMinute = roundedMinutes % 60
        
        return (resultHour, resultMinute)
    }
}
