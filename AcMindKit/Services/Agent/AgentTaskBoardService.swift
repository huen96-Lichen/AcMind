import Foundation

// MARK: - AgentTaskBoardService

/// Agent 任务看板服务协议
public protocol AgentTaskBoardServiceProtocol: Sendable {
    func createTask(_ task: AgentTask) async throws -> AgentTask
    func getTask(id: String) async throws -> AgentTask?
    func listTasks(filter: TaskFilter?) async throws -> [AgentTask]
    func updateTask(_ task: AgentTask) async throws
    func deleteTask(id: String) async throws
    func startTask(id: String) async throws
    func completeTask(id: String) async throws
    func failTask(id: String, error: String) async throws
    func retryTask(id: String) async throws
    func addStep(taskId: String, step: TaskStep) async throws
    func updateStep(taskId: String, step: TaskStep) async throws
    func archiveTask(id: String) async throws
}

/// Agent 任务看板服务
public actor AgentTaskBoardService: AgentTaskBoardServiceProtocol {
    private let storage: any StorageServiceProtocol

    public init(storage: any StorageServiceProtocol = StorageService()) {
        self.storage = storage
    }

    public func createTask(_ task: AgentTask) async throws -> AgentTask {
        let now = Date()
        let newTask = AgentTask(
            id: task.id,
            title: task.title,
            description: task.description,
            status: task.status,
            priority: task.priority,
            steps: task.steps,
            currentStepIndex: task.currentStepIndex,
            products: task.products,
            dependencies: task.dependencies,
            relatedSkillIds: task.relatedSkillIds,
            errorMessage: task.errorMessage,
            retryCount: task.retryCount,
            maxRetries: task.maxRetries,
            sourceMessageId: task.sourceMessageId,
            createdAt: now,
            updatedAt: now,
            startedAt: task.startedAt,
            completedAt: task.completedAt
        )
        try await storage.setSetting(key: "task_\(newTask.id)", value: encodeTask(newTask))
        await updateTaskIndex(taskId: newTask.id, add: true)
        return newTask
    }

    public func getTask(id: String) async throws -> AgentTask? {
        guard let data = try await storage.getSetting(key: "task_\(id)") else {
            return nil
        }
        return decodeTask(from: data)
    }

    public func listTasks(filter: TaskFilter?) async throws -> [AgentTask] {
        let allTasks = try await loadAllTasks()
        guard let filter = filter else { return allTasks }

        return allTasks.filter { task in
            if let statuses = filter.statuses, !statuses.contains(task.status) {
                return false
            }
            if let priorities = filter.priorities, !priorities.contains(task.priority) {
                return false
            }
            if let searchText = filter.searchText, !searchText.isEmpty {
                let lowercased = searchText.lowercased()
                let matches = task.title.lowercased().contains(lowercased) ||
                             task.description.lowercased().contains(lowercased)
                if !matches { return false }
            }
            return true
        }
        .sorted { lhs, rhs in
            if lhs.priority.sortOrder != rhs.priority.sortOrder {
                return lhs.priority.sortOrder < rhs.priority.sortOrder
            }
            return lhs.createdAt > rhs.createdAt
        }
        .prefix(filter.limit ?? 50)
        .map { $0 }
    }

    public func updateTask(_ task: AgentTask) async throws {
        var updated = task
        updated.updatedAt = Date()
        try await storage.setSetting(key: "task_\(task.id)", value: encodeTask(updated))
    }

    public func deleteTask(id: String) async throws {
        try await storage.setSetting(key: "task_\(id)", value: "")
        await updateTaskIndex(taskId: id, add: false)
    }

    public func startTask(id: String) async throws {
        guard var task = try await getTask(id: id) else {
            throw AgentTaskError.taskNotFound
        }
        task.status = .running
        task.startedAt = Date()
        try await updateTask(task)
    }

    public func completeTask(id: String) async throws {
        guard var task = try await getTask(id: id) else {
            throw AgentTaskError.taskNotFound
        }
        task.status = .completed
        task.completedAt = Date()
        try await updateTask(task)
    }

    public func failTask(id: String, error: String) async throws {
        guard var task = try await getTask(id: id) else {
            throw AgentTaskError.taskNotFound
        }
        task.status = .failed
        task.errorMessage = error
        task.retryCount += 1
        try await updateTask(task)
    }

    public func retryTask(id: String) async throws {
        guard var task = try await getTask(id: id) else {
            throw AgentTaskError.taskNotFound
        }
        guard task.retryCount < task.maxRetries else {
            throw AgentTaskError.maxRetriesExceeded
        }
        task.status = .pending
        task.errorMessage = nil
        try await updateTask(task)
    }

    public func addStep(taskId: String, step: TaskStep) async throws {
        guard var task = try await getTask(id: taskId) else {
            throw AgentTaskError.taskNotFound
        }
        task.steps.append(step)
        try await updateTask(task)
    }

    public func updateStep(taskId: String, step: TaskStep) async throws {
        guard var task = try await getTask(id: taskId) else {
            throw AgentTaskError.taskNotFound
        }
        if let index = task.steps.firstIndex(where: { $0.id == step.id }) {
            task.steps[index] = step
            try await updateTask(task)
        }
    }

    public func archiveTask(id: String) async throws {
        guard var task = try await getTask(id: id) else {
            throw AgentTaskError.taskNotFound
        }
        task.status = .archived
        try await updateTask(task)
    }

    private func loadAllTasks() async throws -> [AgentTask] {
        var tasks: [AgentTask] = []
        var index = 0
        while true {
            guard let data = try await storage.getSetting(key: "task_index_\(index)") else {
                break
            }
            let ids = data.components(separatedBy: ",").filter { !$0.isEmpty }
            for id in ids {
                if let task = try await getTask(id: id) {
                    tasks.append(task)
                }
            }
            index += 1
        }
        return tasks
    }

    private func updateTaskIndex(taskId: String, add: Bool) async {
        // 简化版索引更新
    }

    private func encodeTask(_ task: AgentTask) -> String {
        guard let data = try? JSONEncoder().encode(task),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func decodeTask(from string: String) -> AgentTask? {
        guard let data = string.data(using: .utf8),
              let task = try? JSONDecoder().decode(AgentTask.self, from: data) else {
            return nil
        }
        return task
    }
}

// MARK: - AgentTaskError

public enum AgentTaskError: Error, LocalizedError {
    case taskNotFound
    case maxRetriesExceeded
    case invalidStateTransition

    public var errorDescription: String? {
        switch self {
        case .taskNotFound: return "任务不存在"
        case .maxRetriesExceeded: return "已达到最大重试次数"
        case .invalidStateTransition: return "无效的状态转换"
        }
    }
}
