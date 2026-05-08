import Foundation

// MARK: - ScheduledAgentTask（定时任务数据模型）

/// 对齐 scheduled_agent_tasks 表 schema v22
public struct ScheduledAgentTask: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var cronExpression: String
    public var skillName: String
    public var inputParams: [String: String]
    public var enabled: Bool
    public var lastRunAt: Date?
    public var lastRunStatus: String?
    public var lastRunTaskId: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        cronExpression: String,
        skillName: String,
        inputParams: [String: String] = [:],
        enabled: Bool = true,
        lastRunAt: Date? = nil,
        lastRunStatus: String? = nil,
        lastRunTaskId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.cronExpression = cronExpression
        self.skillName = skillName
        self.inputParams = inputParams
        self.enabled = enabled
        self.lastRunAt = lastRunAt
        self.lastRunStatus = lastRunStatus
        self.lastRunTaskId = lastRunTaskId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
