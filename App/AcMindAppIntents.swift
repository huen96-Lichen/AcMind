import AppIntents
import Foundation

struct OpenAgentIntent: AppIntent {
    static let title: LocalizedStringResource = "打开智能体"
    static let description = IntentDescription("打开 AcWork 的智能体页面。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .companionShowAgent, object: nil)
        return .result()
    }
}

struct OpenInboxIntent: AppIntent {
    static let title: LocalizedStringResource = "打开收集箱"
    static let description = IntentDescription("打开 AcWork 的收集箱页面。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .companionShowInbox, object: nil)
        return .result()
    }
}

struct OpenScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "打开日程"
    static let description = IntentDescription("打开 AcWork 的日程页面。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .companionShowSchedule, object: nil)
        return .result()
    }
}
