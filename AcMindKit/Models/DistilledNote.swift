import Foundation

// MARK: - DistilledNote（蒸馏结果）

/// AI 蒸馏管线的输出结果
/// 对齐 Electron distilled_outputs + distilled_notes 表
public struct DistilledNote: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var sourceItemId: String
    public var taskId: String?
    public var title: String?
    public var summary: String?
    public var category: String?
    public var tags: [String]
    public var documentType: String?
    public var contentMarkdown: String?
    public var valueScore: Double?
    public var cleanSuggestion: String?
    public var confidence: Double?
    public var reviewStatus: ReviewStatus
    public var reviewedAt: Date?
    public var acceptedKnowledgeCardId: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceItemId: String,
        taskId: String? = nil,
        title: String? = nil,
        summary: String? = nil,
        category: String? = nil,
        tags: [String] = [],
        documentType: String? = nil,
        contentMarkdown: String? = nil,
        valueScore: Double? = nil,
        cleanSuggestion: String? = nil,
        confidence: Double? = nil,
        reviewStatus: ReviewStatus = .pending,
        reviewedAt: Date? = nil,
        acceptedKnowledgeCardId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceItemId = sourceItemId
        self.taskId = taskId
        self.title = title
        self.summary = summary
        self.category = category
        self.tags = tags
        self.documentType = documentType
        self.contentMarkdown = contentMarkdown
        self.valueScore = valueScore
        self.cleanSuggestion = cleanSuggestion
        self.confidence = confidence
        self.reviewStatus = reviewStatus
        self.reviewedAt = reviewedAt
        self.acceptedKnowledgeCardId = acceptedKnowledgeCardId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ReviewStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case approved
    case rejected
    case regenerated

    public static var allCases: [ReviewStatus] {
        [.pending, .approved, .rejected, .regenerated]
    }

    public var displayName: String {
        switch self {
        case .pending: return "待审核"
        case .approved: return "已通过"
        case .rejected: return "已拒绝"
        case .regenerated: return "已重新生成"
        }
    }
}

public enum ReviewAction: String, Codable, Sendable, Hashable {
    case approve
    case reject
    case regenerate
}

// MARK: - ExportRecord（导出记录）

/// 导出操作的记录
/// 对齐 Electron export_records 表
public struct ExportRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var sourceItemId: String
    public var distilledOutputId: String
    public var knowledgeCardId: String?
    public var vaultPath: String
    public var relativeFilePath: String
    public var frontmatter: [String: String]
    public var exportedAt: Date
    public var status: ExportStatus
    public var conflictResolution: ConflictStrategy?

    public init(
        id: String = UUID().uuidString,
        sourceItemId: String,
        distilledOutputId: String,
        knowledgeCardId: String? = nil,
        vaultPath: String = "",
        relativeFilePath: String = "",
        frontmatter: [String: String] = [:],
        exportedAt: Date = Date(),
        status: ExportStatus = .success,
        conflictResolution: ConflictStrategy? = nil
    ) {
        self.id = id
        self.sourceItemId = sourceItemId
        self.distilledOutputId = distilledOutputId
        self.knowledgeCardId = knowledgeCardId
        self.vaultPath = vaultPath
        self.relativeFilePath = relativeFilePath
        self.frontmatter = frontmatter
        self.exportedAt = exportedAt
        self.status = status
        self.conflictResolution = conflictResolution
    }
}

public enum ExportTarget: String, Codable, Sendable, Hashable, CaseIterable {
    case obsidian
    case icloud
    case local
    case markdown

    public static var allCases: [ExportTarget] { [.obsidian, .icloud, .local, .markdown] }

    public var displayName: String {
        switch self {
        case .obsidian: return "Obsidian"
        case .icloud: return "iCloud"
        case .local: return "本地"
        case .markdown: return "Markdown"
        }
    }
}

public enum ExportStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case exporting
    case success
    case failed

    public static var allCases: [ExportStatus] { [.pending, .exporting, .success, .failed] }

    public var displayName: String {
        switch self {
        case .pending: return "待导出"
        case .exporting: return "导出中"
        case .success: return "成功"
        case .failed: return "失败"
        }
    }
}

public enum ConflictStrategy: String, Codable, Sendable, Hashable, CaseIterable {
    case overwrite
    case rename
    case skip

    public static var allCases: [ConflictStrategy] { [.overwrite, .rename, .skip] }

    public var displayName: String {
        switch self {
        case .overwrite: return "覆盖"
        case .rename: return "重命名"
        case .skip: return "跳过"
        }
    }
}

public struct ExportConfig: Codable, Sendable, Hashable, Equatable {
    public var target: ExportTarget
    public var vaultPath: String?
    public var defaultFolder: String
    public var pathRule: PathRule
    public var conflictStrategy: ConflictStrategy
    public var autoFrontmatter: Bool
    public var frontmatterTemplate: [String: String]

    public enum PathRule: String, Codable, Sendable, Hashable {
        case categoryDate
        case flat
        case sourceType
    }

    public init(
        target: ExportTarget = .obsidian,
        vaultPath: String? = nil,
        defaultFolder: String = "Inbox",
        pathRule: PathRule = .categoryDate,
        conflictStrategy: ConflictStrategy = .rename,
        autoFrontmatter: Bool = true,
        frontmatterTemplate: [String: String] = [:]
    ) {
        self.target = target
        self.vaultPath = vaultPath
        self.defaultFolder = defaultFolder
        self.pathRule = pathRule
        self.conflictStrategy = conflictStrategy
        self.autoFrontmatter = autoFrontmatter
        self.frontmatterTemplate = frontmatterTemplate
    }
}

// MARK: - ProviderConfig（AI 提供者配置）

/// AI 服务提供商配置
/// 对齐 Electron provider_configs 表
public struct ProviderConfig: Codable, Sendable, Identifiable, Hashable, Equatable {
    public let id: String
    public var name: String
    public var providerType: ProviderType
    public var tier: ProviderTier
    public var baseURL: String
    public var apiKeyRef: String?  // Keychain reference, not the actual key
    public var modelId: String
    public var enabled: Bool
    public var capabilities: [String]

    public init(
        id: String = UUID().uuidString,
        name: String = "",
        providerType: ProviderType = .ollama,
        tier: ProviderTier = .localLight,
        baseURL: String = "",
        apiKeyRef: String? = nil,
        modelId: String = "",
        enabled: Bool = true,
        capabilities: [String] = []
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.tier = tier
        self.baseURL = baseURL
        self.apiKeyRef = apiKeyRef
        self.modelId = modelId
        self.enabled = enabled
        self.capabilities = capabilities
    }
}

public enum ProviderType: String, Codable, Sendable, Hashable, CaseIterable {
    case ollama
    case openAI
    case openAICompatible
    case anthropic
    case google
    case local

    public static var allCases: [ProviderType] {
        [.ollama, .openAI, .openAICompatible, .anthropic, .google, .local]
    }

    public var displayName: String {
        switch self {
        case .ollama: return "Ollama (本地)"
        case .openAI: return "OpenAI"
        case .openAICompatible: return "OpenAI 兼容"
        case .anthropic: return "Anthropic"
        case .google: return "Google AI"
        case .local: return "本地模型"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .ollama: return "http://localhost:11434"
        case .openAI: return "https://api.openai.com"
        case .openAICompatible: return ""
        case .anthropic: return "https://api.anthropic.com"
        case .google: return "https://generativelanguage.googleapis.com"
        case .local: return ""
        }
    }
}

public enum ProviderTier: String, Codable, Sendable, Hashable, CaseIterable {
    case localLight
    case localHeavy
    case cloudLight
    case cloudHeavy

    public static var allCases: [ProviderTier] {
        [.localLight, .localHeavy, .cloudLight, .cloudHeavy]
    }

    public var displayName: String {
        switch self {
        case .localLight: return "本地轻量"
        case .localHeavy: return "本地重量"
        case .cloudLight: return "云端轻量"
        case .cloudHeavy: return "云端重量"
        }
    }
}

// MARK: - ProcessJob（处理任务）

/// 统一处理任务模型
/// 对齐 Electron process_jobs 表
public struct ProcessJob: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var sourceItemId: String?
    public var jobType: ProcessJobType
    public var status: ProcessJobStatus
    public var input: [String: AnyCodable]?
    public var output: [String: AnyCodable]?
    public var error: String?
    public var createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var progress: Double?
    public var result: String?

    public init(
        id: String = UUID().uuidString,
        sourceItemId: String? = nil,
        jobType: ProcessJobType,
        status: ProcessJobStatus = .queued,
        input: [String: AnyCodable]? = nil,
        output: [String: AnyCodable]? = nil,
        error: String? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        progress: Double? = nil,
        result: String? = nil
    ) {
        self.id = id
        self.sourceItemId = sourceItemId
        self.jobType = jobType
        self.status = status
        self.input = input
        self.output = output
        self.error = error
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.progress = progress
        self.result = result
    }
}

public enum ProcessJobType: String, Codable, Sendable, Hashable, CaseIterable {
    case ocr
    case asr
    case distill
    case export
    case imported
    case parse

    public static var allCases: [ProcessJobType] {
        [.ocr, .asr, .distill, .export, .imported, .parse]
    }

    public var displayName: String {
        switch self {
        case .ocr: return "OCR 识别"
        case .asr: return "语音转写"
        case .distill: return "AI 蒸馏"
        case .export: return "导出"
        case .imported: return "导入"
        case .parse: return "解析"
        }
    }
}

public enum ProcessJobStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case queued
    case running
    case succeeded
    case failed
    case cancelled

    public static var allCases: [ProcessJobStatus] {
        [.queued, .running, .succeeded, .failed, .cancelled]
    }

    public var displayName: String {
        switch self {
        case .queued: return "排队中"
        case .running: return "运行中"
        case .succeeded: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}

// MARK: - AITask（AI 任务队列）

/// AI 任务队列项
/// 对齐 Electron ai_tasks 表
public struct AITask: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var sourceItemId: String
    public var tier: ProviderTier
    public var operation: String
    public var status: ProcessJobStatus
    public var provider: String
    public var model: String
    public var input: [String: AnyCodable]
    public var output: [String: AnyCodable]?
    public var error: String?
    public let createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var latencyMs: Int?

    public init(
        id: String = UUID().uuidString,
        sourceItemId: String,
        tier: ProviderTier = .localLight,
        operation: String = "summarize",
        status: ProcessJobStatus = .queued,
        provider: String = "",
        model: String = "",
        input: [String: AnyCodable] = [:],
        output: [String: AnyCodable]? = nil,
        error: String? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        latencyMs: Int? = nil
    ) {
        self.id = id
        self.sourceItemId = sourceItemId
        self.tier = tier
        self.operation = operation
        self.status = status
        self.provider = provider
        self.model = model
        self.input = input
        self.output = output
        self.error = error
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.latencyMs = latencyMs
    }
}

// MARK: - Chat Models（对话模型）

/// Agent 对话消息
public struct ChatMessage: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var sessionId: String
    public var role: ChatRole
    public var content: String
    public var status: ChatMessageStatus
    public var modelId: String?
    public var providerId: String?
    public var promptTokens: Int?
    public var completionTokens: Int?
    public var latencyMs: Int?
    public var error: String?
    public var actionProposals: [ActionProposal]
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        role: ChatRole,
        content: String = "",
        status: ChatMessageStatus = .pending,
        modelId: String? = nil,
        providerId: String? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        latencyMs: Int? = nil,
        error: String? = nil,
        actionProposals: [ActionProposal] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.status = status
        self.modelId = modelId
        self.providerId = providerId
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.latencyMs = latencyMs
        self.error = error
        self.actionProposals = actionProposals
        self.createdAt = createdAt
    }
}

public enum ChatRole: String, Codable, Sendable, Hashable {
    case system
    case user
    case assistant
    case tool
}

public enum ChatMessageStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case streaming
    case completed
    case failed
    case cancelled

    public static var allCases: [ChatMessageStatus] {
        [.pending, .streaming, .completed, .failed, .cancelled]
    }
}

public struct ActionProposal: Codable, Sendable, Hashable, Equatable, Identifiable {
    public let id: String
    public var label: String
    public var action: String
    public var params: [String: String]

    public init(id: String = UUID().uuidString, label: String, action: String, params: [String: String] = [:]) {
        self.id = id
        self.label = label
        self.action = action
        self.params = params
    }
}

/// Agent 对话会话
public struct ChatSession: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var providerId: String?
    public var modelId: String?
    public var status: ChatSessionStatus
    public var metadata: [String: String]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String = "新对话",
        providerId: String? = nil,
        modelId: String? = nil,
        status: ChatSessionStatus = .active,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.providerId = providerId
        self.modelId = modelId
        self.status = status
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ChatSessionStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case active
    case archived
    case deleted

    public static var allCases: [ChatSessionStatus] { [.active, .archived, .deleted] }
}

/// AI 聊天配置（传给 Provider）
public struct ChatConfig: Codable, Sendable, Hashable, Equatable {
    public var model: String?
    public var temperature: Double?
    public var maxTokens: Int?
    public var topP: Double?
    public var stream: Bool
    
    public init(
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        stream: Bool = false
    ) {
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.stream = stream
    }
}

/// AI 聊天响应
public struct ChatResponse: Codable, Sendable, Equatable {
    public var content: String
    public var model: String?
    public var providerId: String?
    public var promptTokens: Int?
    public var completionTokens: Int?
    public var latencyMs: Int?
    public var finishReason: String?
    public var usage: ChatUsage?
    public var isStreaming: Bool

    public init(
        content: String,
        model: String? = nil,
        providerId: String? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        latencyMs: Int? = nil,
        finishReason: String? = nil,
        usage: ChatUsage? = nil,
        isStreaming: Bool = false
    ) {
        self.content = content
        self.model = model
        self.providerId = providerId
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.latencyMs = latencyMs
        self.finishReason = finishReason
        self.usage = usage
        self.isStreaming = isStreaming
    }
}

public struct ChatUsage: Codable, Sendable, Equatable {
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalDuration: Int64?

    public init(
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        totalDuration: Int64? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalDuration = totalDuration
    }
}

// MARK: - AnyCodable（动态 JSON 支持）

/// 类型擦除的 Codable 包装，用于 ProcessJob.input/output 等动态字段
public struct AnyCodable: Codable, @unchecked Sendable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (left as String, right as String):
            return left == right
        case let (left as Int, right as Int):
            return left == right
        case let (left as Double, right as Double):
            return left == right
        case let (left as Bool, right as Bool):
            return left == right
        case let (left as [String: Any], right as [String: Any]):
            return NSDictionary(dictionary: left).isEqual(to: right)
        case let (left as [Any], right as [Any]):
            return NSArray(array: left).isEqual(to: right)
        default:
            return String(describing: lhs.value) == String(describing: rhs.value)
        }
    }
}
