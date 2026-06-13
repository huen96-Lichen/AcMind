import Foundation

// MARK: - AgentTask（Agent 任务模型）

/// 任务状态
public enum AgentTaskStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending      // 待执行
    case running      // 执行中
    case waiting      // 等待确认
    case failed       // 失败
    case completed    // 已完成
    case archived     // 已归档（沉淀为技能）

    public var displayName: String {
        switch self {
        case .pending: return "待执行"
        case .running: return "执行中"
        case .waiting: return "等待确认"
        case .failed: return "失败"
        case .completed: return "已完成"
        case .archived: return "已归档"
        }
    }

    public var icon: String {
        switch self {
        case .pending: return "clock"
        case .running: return "play.fill"
        case .waiting: return "questionmark.circle"
        case .failed: return "xmark.circle"
        case .completed: return "checkmark.circle"
        case .archived: return "archivebox"
        }
    }
}

/// Agent 任务
public struct AgentTask: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var description: String
    public var status: AgentTaskStatus
    public var priority: TaskPriority
    public var steps: [TaskStep]
    public var currentStepIndex: Int
    public var products: [TaskProduct]
    public var dependencies: [String]
    public var relatedSkillIds: [String]
    public var errorMessage: String?
    public var retryCount: Int
    public var maxRetries: Int
    public var sourceMessageId: String?
    public let createdAt: Date
    public var updatedAt: Date
    public var startedAt: Date?
    public var completedAt: Date?

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        status: AgentTaskStatus = .pending,
        priority: TaskPriority = .medium,
        steps: [TaskStep] = [],
        currentStepIndex: Int = 0,
        products: [TaskProduct] = [],
        dependencies: [String] = [],
        relatedSkillIds: [String] = [],
        errorMessage: String? = nil,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        sourceMessageId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.steps = steps
        self.currentStepIndex = currentStepIndex
        self.products = products
        self.dependencies = dependencies
        self.relatedSkillIds = relatedSkillIds
        self.errorMessage = errorMessage
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.sourceMessageId = sourceMessageId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

public enum AgentTaskTimelineStatus: String, Codable, Sendable, Equatable {
    case pending
    case running
    case completed
    case failed
}

public struct AgentTaskTimelineItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let detail: String?
    public let status: AgentTaskTimelineStatus
    public let occurredAt: Date?

    public init(
        id: String,
        title: String,
        detail: String? = nil,
        status: AgentTaskTimelineStatus,
        occurredAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.occurredAt = occurredAt
    }
}

public struct AgentTaskClosureSummary: Codable, Sendable, Equatable {
    public let taskId: String
    public let title: String
    public let stateLabel: String
    public let detail: String
    public let nextActionTitle: String?
    public let canRetry: Bool
    public let timeline: [AgentTaskTimelineItem]

    public init(
        taskId: String,
        title: String,
        stateLabel: String,
        detail: String,
        nextActionTitle: String?,
        canRetry: Bool,
        timeline: [AgentTaskTimelineItem]
    ) {
        self.taskId = taskId
        self.title = title
        self.stateLabel = stateLabel
        self.detail = detail
        self.nextActionTitle = nextActionTitle
        self.canRetry = canRetry
        self.timeline = timeline
    }

    public static func make(from task: AgentTask) -> AgentTaskClosureSummary {
        AgentTaskClosureSummary(
            taskId: task.id,
            title: task.title,
            stateLabel: task.status.displayName,
            detail: detail(for: task),
            nextActionTitle: nextActionTitle(for: task),
            canRetry: task.status == .failed && task.retryCount < task.maxRetries,
            timeline: timeline(for: task)
        )
    }

    private static func detail(for task: AgentTask) -> String {
        if task.status == .failed, let error = task.errorMessage, error.isEmpty == false {
            return error
        }

        if task.status == .completed, task.products.isEmpty == false {
            return "已生成 \(task.products.count) 个产物"
        }

        if task.steps.isEmpty == false {
            let completedCount = task.steps.filter { $0.status == .completed }.count
            return "\(completedCount)/\(task.steps.count) 个步骤已完成"
        }

        return task.description.isEmpty ? task.status.displayName : task.description
    }

    private static func nextActionTitle(for task: AgentTask) -> String? {
        switch task.status {
        case .pending:
            return "开始执行"
        case .running:
            return "继续执行"
        case .waiting:
            return "处理确认"
        case .failed:
            return task.retryCount < task.maxRetries ? "重试任务" : "查看错误"
        case .completed:
            return "归档为沉淀"
        case .archived:
            return nil
        }
    }

    private static func timeline(for task: AgentTask) -> [AgentTaskTimelineItem] {
        var items: [AgentTaskTimelineItem] = [
            AgentTaskTimelineItem(
                id: "\(task.id)-created",
                title: "已创建",
                status: .completed,
                occurredAt: task.createdAt
            )
        ]

        if let startedAt = task.startedAt {
            items.append(
                AgentTaskTimelineItem(
                    id: "\(task.id)-started",
                    title: "已开始",
                    status: .completed,
                    occurredAt: startedAt
                )
            )
        }

        items.append(contentsOf: task.steps.sorted { $0.order < $1.order }.map { step in
            AgentTaskTimelineItem(
                id: step.id,
                title: step.title,
                detail: step.errorMessage ?? step.result ?? step.description.nilIfEmpty,
                status: timelineStatus(for: step.status),
                occurredAt: step.completedAt ?? step.startedAt
            )
        })

        if let completedAt = task.completedAt {
            items.append(
                AgentTaskTimelineItem(
                    id: "\(task.id)-completed",
                    title: "已完成",
                    status: .completed,
                    occurredAt: completedAt
                )
            )
        }

        if task.status == .failed, let error = task.errorMessage {
            items.append(
                AgentTaskTimelineItem(
                    id: "\(task.id)-failed",
                    title: "执行失败",
                    detail: error,
                    status: .failed,
                    occurredAt: task.updatedAt
                )
            )
        }

        return items
    }

    private static func timelineStatus(for stepStatus: StepStatus) -> AgentTaskTimelineStatus {
        switch stepStatus {
        case .pending, .skipped:
            return .pending
        case .running:
            return .running
        case .completed:
            return .completed
        case .failed:
            return .failed
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

/// 任务优先级
public enum TaskPriority: String, Codable, Sendable, Hashable, CaseIterable {
    case low
    case medium
    case high
    case critical

    public var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "紧急"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

// MARK: - TaskStep（任务步骤）

/// 任务步骤状态
public enum StepStatus: String, Codable, Sendable, Hashable {
    case pending
    case running
    case completed
    case failed
    case skipped

    public var icon: String {
        switch self {
        case .pending: return "circle"
        case .running: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "arrow.right.circle"
        }
    }
}

/// 任务执行步骤
public struct TaskStep: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var description: String
    public var status: StepStatus
    public var toolCall: ToolCall?
    public var result: String?
    public var errorMessage: String?
    public let order: Int
    public var startedAt: Date?
    public var completedAt: Date?

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        status: StepStatus = .pending,
        toolCall: ToolCall? = nil,
        result: String? = nil,
        errorMessage: String? = nil,
        order: Int,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.toolCall = toolCall
        self.result = result
        self.errorMessage = errorMessage
        self.order = order
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

/// 工具调用信息
public struct ToolCall: Codable, Sendable, Equatable {
    public var toolName: String
    public var toolType: ToolType
    public var parameters: [String: String]
    public var output: String?
    public var durationMs: Int?

    public enum ToolType: String, Codable, Sendable {
        case internalTool   // AcMind 内部工具
        case externalTool   // 外部 API
        case aiCall         // AI 模型调用
        case fileOperation  // 文件操作
        case userConfirm    // 用户确认

        public var displayName: String {
            switch self {
            case .internalTool: return "AcMind 工具"
            case .externalTool: return "外部 API"
            case .aiCall: return "AI 调用"
            case .fileOperation: return "文件操作"
            case .userConfirm: return "用户确认"
            }
        }
    }

    public init(
        toolName: String,
        toolType: ToolType,
        parameters: [String: String] = [:],
        output: String? = nil,
        durationMs: Int? = nil
    ) {
        self.toolName = toolName
        self.toolType = toolType
        self.parameters = parameters
        self.output = output
        self.durationMs = durationMs
    }
}

// MARK: - TaskProduct（任务产物）

/// 任务产物
public struct TaskProduct: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var type: ProductType
    public var path: String?
    public var content: String?
    public var metadata: [String: String]

    public enum ProductType: String, Codable, Sendable {
        case markdown
        case taskList
        case skill
        case code
        case data
        case other

        public var icon: String {
            switch self {
            case .markdown: return "doc.text"
            case .taskList: return "checklist"
            case .skill: return "wand.and.stars"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .data: return "cylinder"
            case .other: return "doc"
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: ProductType,
        path: String? = nil,
        content: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.path = path
        self.content = content
        self.metadata = metadata
    }
}

// MARK: - TaskBoard

/// 任务看板
public struct TaskBoard: Codable, Sendable, Equatable {
    public var tasks: [AgentTask]

    public init(tasks: [AgentTask] = []) {
        self.tasks = tasks
    }

    public var pendingTasks: [AgentTask] {
        tasks.filter { $0.status == .pending }
    }

    public var runningTasks: [AgentTask] {
        tasks.filter { $0.status == .running }
    }

    public var waitingTasks: [AgentTask] {
        tasks.filter { $0.status == .waiting }
    }

    public var failedTasks: [AgentTask] {
        tasks.filter { $0.status == .failed }
    }

    public var completedTasks: [AgentTask] {
        tasks.filter { $0.status == .completed }
    }

    public func tasks(for status: AgentTaskStatus) -> [AgentTask] {
        tasks.filter { $0.status == status }
    }
}

// MARK: - TaskFilter

public struct TaskFilter: Codable, Sendable, Equatable {
    public var statuses: [AgentTaskStatus]?
    public var priorities: [TaskPriority]?
    public var searchText: String?
    public var limit: Int?

    public init(
        statuses: [AgentTaskStatus]? = nil,
        priorities: [TaskPriority]? = nil,
        searchText: String? = nil,
        limit: Int? = 50
    ) {
        self.statuses = statuses
        self.priorities = priorities
        self.searchText = searchText
        self.limit = limit
    }
}
