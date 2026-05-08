import Foundation

// MARK: - AgentMemory（Agent 记忆模型）

/// Agent 记忆类型
public enum MemoryType: String, Codable, Sendable, Hashable, CaseIterable {
    case preference   // 用户偏好
    case project      // 项目记忆
    case task         // 任务记忆
    case skill        // 技能记忆

    public var displayName: String {
        switch self {
        case .preference: return "偏好"
        case .project: return "项目"
        case .task: return "任务"
        case .skill: return "技能"
        }
    }
}

/// Agent 单条记忆
public struct AgentMemory: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var type: MemoryType
    public var key: String
    public var value: String
    public var tags: [String]
    public var relevanceScore: Double
    public var source: MemorySource
    public var lastAccessedAt: Date
    public var accessCount: Int
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        type: MemoryType,
        key: String,
        value: String,
        tags: [String] = [],
        relevanceScore: Double = 1.0,
        source: MemorySource = .manual,
        lastAccessedAt: Date = Date(),
        accessCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.key = key
        self.value = value
        self.tags = tags
        self.relevanceScore = relevanceScore
        self.source = source
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum MemorySource: String, Codable, Sendable, Hashable {
    case manual       // 手动添加
    case autoLearned // 自动学习
    case imported    // 从 Hermes/Skill 导入
    case system      // 系统生成

    public var displayName: String {
        switch self {
        case .manual: return "手动"
        case .autoLearned: return "自动学习"
        case .imported: return "导入"
        case .system: return "系统"
        }
    }
}

/// 记忆上下文（用于注入 Agent）
public struct MemoryContext: Codable, Sendable, Equatable {
    public var preferenceMemories: [AgentMemory]
    public var projectMemories: [AgentMemory]
    public var taskMemories: [AgentMemory]
    public var skillMemories: [AgentMemory]

    public init(
        preferenceMemories: [AgentMemory] = [],
        projectMemories: [AgentMemory] = [],
        taskMemories: [AgentMemory] = [],
        skillMemories: [AgentMemory] = []
    ) {
        self.preferenceMemories = preferenceMemories
        self.projectMemories = projectMemories
        self.taskMemories = taskMemories
        self.skillMemories = skillMemories
    }

    public var isEmpty: Bool {
        preferenceMemories.isEmpty && projectMemories.isEmpty &&
        taskMemories.isEmpty && skillMemories.isEmpty
    }

    public func toPromptString() -> String {
        var parts: [String] = []

        if !preferenceMemories.isEmpty {
            parts.append("## 用户偏好\n")
            for m in preferenceMemories {
                parts.append("- \(m.key): \(m.value)")
            }
        }

        if !projectMemories.isEmpty {
            parts.append("\n## 项目记忆\n")
            for m in projectMemories {
                parts.append("- \(m.key): \(m.value)")
            }
        }

        if !taskMemories.isEmpty {
            parts.append("\n## 任务记忆\n")
            for m in taskMemories {
                parts.append("- \(m.key): \(m.value)")
            }
        }

        if !skillMemories.isEmpty {
            parts.append("\n## 技能记忆\n")
            for m in skillMemories {
                parts.append("- \(m.key): \(m.value)")
            }
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - MemoryFilter

public struct MemoryFilter: Codable, Sendable, Equatable {
    public var types: [MemoryType]?
    public var tags: [String]?
    public var searchText: String?
    public var minRelevance: Double?
    public var limit: Int?

    public init(
        types: [MemoryType]? = nil,
        tags: [String]? = nil,
        searchText: String? = nil,
        minRelevance: Double? = nil,
        limit: Int? = 50
    ) {
        self.types = types
        self.tags = tags
        self.searchText = searchText
        self.minRelevance = minRelevance
        self.limit = limit
    }
}

// MARK: - MemoryAccessRecord

public struct MemoryAccessRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var memoryId: String
    public var accessedAt: Date

    public init(id: String = UUID().uuidString, memoryId: String, accessedAt: Date = Date()) {
        self.id = id
        self.memoryId = memoryId
        self.accessedAt = accessedAt
    }
}
