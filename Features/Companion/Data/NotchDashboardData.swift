import Foundation

struct HeatmapDay: Identifiable, Equatable {
    let id = UUID()
    var weekday: String
    var hourlyValues: [Double]

    static let empty: [HeatmapDay] = []
}

struct TodayTaskSummary: Equatable {
    var completionRate: Double
    var completedCount: Int
    var totalCount: Int
    var nextTaskTitle: String?

    static let empty = TodayTaskSummary(completionRate: 0, completedCount: 0, totalCount: 0, nextTaskTitle: nil)
}
