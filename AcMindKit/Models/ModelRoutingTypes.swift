import Foundation

// MARK: - ModelRouter（模型路由器）

/// 模型路由策略
public struct ModelRoute: Codable, Sendable, Equatable {
    public var routeId: String
    public var taskType: TaskType
    public var providerId: String
    public var modelId: String
    public var reason: String
    public var estimatedCost: Double?

    public enum TaskType: String, Codable, Sendable, CaseIterable {
        case simpleChat        // 简单对话
        case textSummarize     // 文本摘要
        case longTextProcess   // 长文本处理
        case codeGeneration    // 代码生成
        case codeReview        // 代码审查
        case complexReasoning  // 复杂推理
        case vision            // 视觉理解
        case voice             // 语音处理

        public var displayName: String {
            switch self {
            case .simpleChat: return "简单对话"
            case .textSummarize: return "文本摘要"
            case .longTextProcess: return "长文本处理"
            case .codeGeneration: return "代码生成"
            case .codeReview: return "代码审查"
            case .complexReasoning: return "复杂推理"
            case .vision: return "视觉理解"
            case .voice: return "语音处理"
            }
        }

        public var defaultTier: ProviderTier {
            switch self {
            case .simpleChat, .textSummarize, .longTextProcess:
                return .localLight
            case .codeGeneration, .codeReview:
                return .cloudLight
            case .complexReasoning:
                return .cloudHeavy
            case .vision:
                return .cloudLight
            case .voice:
                return .localLight
            }
        }
    }

    public init(
        routeId: String = UUID().uuidString,
        taskType: TaskType,
        providerId: String,
        modelId: String,
        reason: String,
        estimatedCost: Double? = nil
    ) {
        self.routeId = routeId
        self.taskType = taskType
        self.providerId = providerId
        self.modelId = modelId
        self.reason = reason
        self.estimatedCost = estimatedCost
    }
}

/// 模型路由请求
public struct ModelRouteRequest: Codable, Sendable {
    public var taskType: ModelRoute.TaskType?
    public var inputLength: Int
    public var requiresPrivacy: Bool
    public var complexity: Complexity
    public var preferredTier: ProviderTier?

    public enum Complexity: String, Codable, Sendable {
        case low
        case medium
        case high

        public var multiplier: Double {
            switch self {
            case .low: return 1.0
            case .medium: return 1.5
            case .high: return 2.0
            }
        }
    }

    public init(
        taskType: ModelRoute.TaskType? = nil,
        inputLength: Int = 0,
        requiresPrivacy: Bool = false,
        complexity: Complexity = .medium,
        preferredTier: ProviderTier? = nil
    ) {
        self.taskType = taskType
        self.inputLength = inputLength
        self.requiresPrivacy = requiresPrivacy
        self.complexity = complexity
        self.preferredTier = preferredTier
    }
}

// MARK: - UsageTracker（消耗追踪器）

/// 单次模型调用记录
public struct ModelUsage: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var sessionId: String?
    public var taskId: String?
    public var taskType: ModelRoute.TaskType?
    public var providerId: String
    public var modelId: String
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int
    public var costUSD: Double
    public var costCNY: Double
    public var latencyMs: Int
    public var success: Bool
    public var errorMessage: String?
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        sessionId: String? = nil,
        taskId: String? = nil,
        taskType: ModelRoute.TaskType? = nil,
        providerId: String,
        modelId: String,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        totalTokens: Int = 0,
        costUSD: Double = 0,
        costCNY: Double = 0,
        latencyMs: Int = 0,
        success: Bool = true,
        errorMessage: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.taskId = taskId
        self.taskType = taskType
        self.providerId = providerId
        self.modelId = modelId
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.costUSD = costUSD
        self.costCNY = costCNY
        self.latencyMs = latencyMs
        self.success = success
        self.errorMessage = errorMessage
        self.timestamp = timestamp
    }
}

/// 消耗汇总
public struct UsageSummary: Codable, Sendable, Equatable {
    public var totalPromptTokens: Int
    public var totalCompletionTokens: Int
    public var totalTokens: Int
    public var totalCostUSD: Double
    public var totalCostCNY: Double
    public var totalRequests: Int
    public var successRequests: Int
    public var failedRequests: Int
    public var avgLatencyMs: Int

    public init(
        totalPromptTokens: Int = 0,
        totalCompletionTokens: Int = 0,
        totalTokens: Int = 0,
        totalCostUSD: Double = 0,
        totalCostCNY: Double = 0,
        totalRequests: Int = 0,
        successRequests: Int = 0,
        failedRequests: Int = 0,
        avgLatencyMs: Int = 0
    ) {
        self.totalPromptTokens = totalPromptTokens
        self.totalCompletionTokens = totalCompletionTokens
        self.totalTokens = totalTokens
        self.totalCostUSD = totalCostUSD
        self.totalCostCNY = totalCostCNY
        self.totalRequests = totalRequests
        self.successRequests = successRequests
        self.failedRequests = failedRequests
        self.avgLatencyMs = avgLatencyMs
    }

    public static var zero: UsageSummary { UsageSummary() }
}

/// 本次会话消耗信息
public struct CurrentSessionUsage: Codable, Sendable, Equatable {
    public var currentCall: ModelUsage?
    public var sessionUsages: [ModelUsage]
    public var sessionSummary: UsageSummary

    public init(
        currentCall: ModelUsage? = nil,
        sessionUsages: [ModelUsage] = [],
        sessionSummary: UsageSummary = .zero
    ) {
        self.currentCall = currentCall
        self.sessionUsages = sessionUsages
        self.sessionSummary = sessionSummary
    }

    public var formattedSummary: String {
        """
        本次会话
        模型：\(currentCall?.modelId ?? "未知")
        消耗：¥\(String(format: "%.2f", sessionSummary.totalCostCNY))
        Token：\(sessionSummary.totalTokens)
        请求：\(sessionSummary.totalRequests) 次
        """
    }
}

// MARK: - PricingConfig（定价配置）

public struct PricingConfig: Codable, Sendable, Equatable {
    public var providerId: String
    public var modelId: String
    public var inputPricePer1M: Double  // 每百万 token 价格（美元）
    public var outputPricePer1M: Double
    public var currency: String

    public init(
        providerId: String,
        modelId: String,
        inputPricePer1M: Double,
        outputPricePer1M: Double,
        currency: String = "USD"
    ) {
        self.providerId = providerId
        self.modelId = modelId
        self.inputPricePer1M = inputPricePer1M
        self.outputPricePer1M = outputPricePer1M
        self.currency = currency
    }

    public func calculateCost(promptTokens: Int, completionTokens: Int, exchangeRate: Double = 7.2) -> (usd: Double, cny: Double) {
        let inputCost = Double(promptTokens) / 1_000_000 * inputPricePer1M
        let outputCost = Double(completionTokens) / 1_000_000 * outputPricePer1M
        let totalUSD = inputCost + outputCost
        let totalCNY = totalUSD * exchangeRate
        return (totalUSD, totalCNY)
    }
}

// MARK: - Default Pricing

extension PricingConfig {
    public static let defaultPricing: [PricingConfig] = [
        PricingConfig(providerId: "openai", modelId: "gpt-4o", inputPricePer1M: 5.0, outputPricePer1M: 15.0),
        PricingConfig(providerId: "openai", modelId: "gpt-4o-mini", inputPricePer1M: 0.15, outputPricePer1M: 0.6),
        PricingConfig(providerId: "anthropic", modelId: "claude-sonnet-4-20250514", inputPricePer1M: 3.0, outputPricePer1M: 15.0),
        PricingConfig(providerId: "anthropic", modelId: "claude-3-5-haiku-20241022", inputPricePer1M: 0.8, outputPricePer1M: 4.0),
        PricingConfig(providerId: "deepseek", modelId: "deepseek-chat", inputPricePer1M: 0.27, outputPricePer1M: 1.1),
        PricingConfig(providerId: "ollama", modelId: "local", inputPricePer1M: 0, outputPricePer1M: 0),
    ]
}

// MARK: - Model Routing Strategy

/// 模型路由偏好，用于设置页和路由器之间共享
public enum ModelRoutingStrategy: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case automatic
    case localPriority
    case cloudPriority
    case costPriority
    case qualityPriority
    case privacyPriority

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automatic: return "自动"
        case .localPriority: return "优先本地"
        case .cloudPriority: return "优先云端"
        case .costPriority: return "低成本"
        case .qualityPriority: return "高质量"
        case .privacyPriority: return "隐私优先"
        }
    }

    public var subtitle: String {
        switch self {
        case .automatic: return "按任务类型自动路由"
        case .localPriority: return "优先选择本地模型"
        case .cloudPriority: return "优先选择云端模型"
        case .costPriority: return "优先选择更便宜的模型"
        case .qualityPriority: return "优先选择更高质量的模型"
        case .privacyPriority: return "优先选择本地或低外发路径"
        }
    }
}

public extension ProviderTier {
    var isLocal: Bool {
        switch self {
        case .localLight, .localHeavy:
            return true
        case .cloudLight, .cloudHeavy:
            return false
        }
    }

    var isCloud: Bool {
        !isLocal
    }
}
