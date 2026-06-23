@preconcurrency import Foundation
import Combine
import AcMindKit

@MainActor
final class NotchDashboardDataStore: ObservableObject {
    @Published var currentTime: String = ""
    @Published var currentDate: String = ""
    @Published var calendarHeatmap: [HeatmapDay] = HeatmapDay.empty
    @Published var todayTasks: TodayTaskSummary = .empty
    @Published var recentActivities: String = ""

    init() {
        updateTime()
    }

    func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        currentTime = formatter.string(from: Date())
        formatter.dateFormat = "EEEE · MMMM"
        formatter.locale = Locale(identifier: "zh_CN")
        currentDate = formatter.string(from: Date())
    }

    func loadFromServices(storage: StorageServiceProtocol) async {
        updateTime()
        do {
            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)
            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

            let allItems = try await storage.listSourceItems(filter: nil)
            let items = allItems.filter { $0.createdAt >= weekStart }

            calendarHeatmap = buildHeatmap(from: items, calendar: calendar, referenceDate: now)

            let totalCount = items.count
            let completedCount = items.filter { $0.status.isTerminal }.count
            let rate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
            todayTasks = TodayTaskSummary(
                completionRate: rate,
                completedCount: completedCount,
                totalCount: totalCount,
                nextTaskTitle: items.first(where: { !$0.status.isTerminal })?.title
            )
            recentActivities = items.prefix(3).compactMap { $0.title }.joined(separator: " · ")
        } catch {
            // keep empty defaults
        }
    }

    private func buildHeatmap(from items: [SourceItem], calendar: Calendar, referenceDate: Date) -> [HeatmapDay] {
        let days = (0..<7).compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: referenceDate))
        }.reversed()

        let groupedByDay = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.createdAt)
        }

        return days.map { day in
            let dayItems = groupedByDay[day] ?? []
            var hourlyValues = Array(repeating: 0.0, count: 24)

            for item in dayItems {
                let hour = calendar.component(.hour, from: item.createdAt)
                hourlyValues[hour] += item.status.isTerminal ? 1.0 : 0.6
            }

            let weekdayFormatter = DateFormatter()
            weekdayFormatter.locale = Locale(identifier: "zh_CN")
            weekdayFormatter.dateFormat = "EEE"

            return HeatmapDay(
                weekday: weekdayFormatter.string(from: day),
                hourlyValues: hourlyValues
            )
        }
    }
}

@MainActor
final class NotchDashboardDataProvider: ObservableObject {
    @Published var store: NotchDashboardDataStore
    private let storage: StorageServiceProtocol?
    private var sourceItemsObserver: NSObjectProtocol?

    init(storage: StorageServiceProtocol? = nil) {
        self.storage = storage
        store = NotchDashboardDataStore()
        if storage != nil {
            sourceItemsObserver = NotificationCenter.default.addObserver(
                forName: .acmindSourceItemsDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshNow()
                }
            }
        }
        refreshNow()
    }

    deinit {
        if let sourceItemsObserver {
            NotificationCenter.default.removeObserver(sourceItemsObserver)
        }
    }

    func refreshNow() {
        store.updateTime()
        if let storage {
            Task { await store.loadFromServices(storage: storage) }
        }
    }

    var currentTime: String { store.currentTime }
    var currentDate: String { store.currentDate }
    var calendarHeatmap: [HeatmapDay] { store.calendarHeatmap }
    var todayTasks: TodayTaskSummary { store.todayTasks }
    var recentActivities: String { store.recentActivities }
}
