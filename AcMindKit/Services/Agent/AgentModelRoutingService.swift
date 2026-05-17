import Foundation

// MARK: - AgentModelRouter

/// Agent 模型路由器
public protocol AgentModelRouterProtocol: Sendable {
    func route(request: ModelRouteRequest) async throws -> ModelRoute
    func recordUsage(_ usage: ModelUsage) async
    func getUsageSummary(sessionId: String?) async -> UsageSummary
    func getCurrentSessionUsage() async -> CurrentSessionUsage
    func getPricing(for modelId: String) -> PricingConfig?
}

/// Agent 模型路由器实现
public actor AgentModelRouter {
    private var usageHistory: [ModelUsage] = []
    private var currentSessionUsages: [ModelUsage] = []
    private var pricingConfig: [String: PricingConfig]
    private let defaultProviders: [ModelRoute.TaskType: String]
    private let defaultModels: [ModelRoute.TaskType: String]

    public init() {
        self.pricingConfig = Dictionary(uniqueKeysWithValues: PricingConfig.defaultPricing.map { ("\($0.providerId)_\($0.modelId)", $0) })

        self.defaultProviders = [
            .simpleChat: "ollama",
            .textSummarize: "ollama",
            .longTextProcess: "deepseek",
            .codeGeneration: "openai",
            .codeReview: "anthropic",
            .complexReasoning: "anthropic",
            .vision: "openai",
            .voice: "ollama"
        ]

        self.defaultModels = [
            .simpleChat: "llama3",
            .textSummarize: "llama3",
            .longTextProcess: "deepseek-chat",
            .codeGeneration: "gpt-4o-mini",
            .codeReview: "claude-sonnet-4-20250514",
            .complexReasoning: "claude-3-5-haiku-20241022",
            .vision: "gpt-4o",
            .voice: "whisper"
        ]
    }

    public func route(request: ModelRouteRequest) async throws -> ModelRoute {
        let taskType = request.taskType ?? inferTaskType(request: request)

        let providerId = defaultProviders[taskType] ?? "ollama"
        let modelId = defaultModels[taskType] ?? "llama3"

        let reason = buildRouteReason(taskType: taskType, request: request)

        var estimatedCost: Double? = nil
        if let pricing = pricingConfig["\(providerId)_\(modelId)"] {
            let tokens = estimateTokens(inputLength: request.inputLength, taskType: taskType)
            estimatedCost = pricing.calculateCost(promptTokens: tokens, completionTokens: tokens / 2).usd
        }

        return ModelRoute(
            taskType: taskType,
            providerId: providerId,
            modelId: modelId,
            reason: reason,
            estimatedCost: estimatedCost
        )
    }

    public func recordUsage(_ usage: ModelUsage) async {
        usageHistory.append(usage)
        currentSessionUsages.append(usage)
    }

    public func getUsageSummary(sessionId: String?) async -> UsageSummary {
        let usages: [ModelUsage]
        if let sessionId = sessionId {
            usages = usageHistory.filter { $0.sessionId == sessionId }
        } else {
            usages = usageHistory
        }

        return calculateSummary(from: usages)
    }

    public func getCurrentSessionUsage() async -> CurrentSessionUsage {
        let summary = calculateSummary(from: currentSessionUsages)
        let currentCall = currentSessionUsages.last

        return CurrentSessionUsage(
            currentCall: currentCall,
            sessionUsages: currentSessionUsages,
            sessionSummary: summary
        )
    }

    public func getPricing(for modelId: String) -> PricingConfig? {
        pricingConfig.values.first { $0.modelId == modelId }
    }

    public func updatePricing(_ config: PricingConfig) {
        pricingConfig["\(config.providerId)_\(config.modelId)"] = config
    }

    // MARK: - Private Methods

    private func inferTaskType(request: ModelRouteRequest) -> ModelRoute.TaskType {
        if request.taskType != nil {
            return request.taskType!
        }

        if request.inputLength > 5000 {
            return .longTextProcess
        }

        if request.requiresPrivacy {
            return .simpleChat
        }

        return .simpleChat
    }

    private func buildRouteReason(taskType: ModelRoute.TaskType, request: ModelRouteRequest) -> String {
        var reasons: [String] = []

        switch taskType {
        case .simpleChat:
            reasons.append("简单对话任务")
        case .textSummarize:
            reasons.append("文本摘要任务")
        case .longTextProcess:
            reasons.append("长文本处理")
        case .codeGeneration:
            reasons.append("代码生成")
        case .codeReview:
            reasons.append("代码审查")
        case .complexReasoning:
            reasons.append("复杂推理")
        case .vision:
            reasons.append("视觉理解")
        case .voice:
            reasons.append("语音处理")
        }

        if request.inputLength > 10000 {
            reasons.append("输入较长")
        }

        if request.requiresPrivacy {
            reasons.append("隐私优先")
        }

        switch request.complexity {
        case .low:
            reasons.append("复杂度低")
        case .medium:
            reasons.append("复杂度中等")
        case .high:
            reasons.append("复杂度高")
        }

        return reasons.joined(separator: "，")
    }

    private func estimateTokens(inputLength: Int, taskType: ModelRoute.TaskType) -> Int {
        let baseTokens = inputLength / 4

        let multiplier: Double
        switch taskType {
        case .simpleChat:
            multiplier = 1.0
        case .textSummarize:
            multiplier = 1.5
        case .longTextProcess:
            multiplier = 2.0
        case .codeGeneration:
            multiplier = 1.2
        case .codeReview:
            multiplier = 1.3
        case .complexReasoning:
            multiplier = 2.5
        case .vision:
            multiplier = 1.5
        case .voice:
            multiplier = 1.0
        }

        return Int(Double(baseTokens) * multiplier)
    }

    private func calculateSummary(from usages: [ModelUsage]) -> UsageSummary {
        guard !usages.isEmpty else { return .zero }

        let totalPrompt = usages.reduce(0) { $0 + $1.promptTokens }
        let totalCompletion = usages.reduce(0) { $0 + $1.completionTokens }
        let totalTokens = usages.reduce(0) { $0 + $1.totalTokens }
        let totalCostUSD = usages.reduce(0) { $0 + $1.costUSD }
        let totalCostCNY = usages.reduce(0) { $0 + $1.costCNY }
        let successCount = usages.filter { $0.success }.count
        let failedCount = usages.filter { !$0.success }.count
        let totalLatency = usages.reduce(0) { $0 + $1.latencyMs }
        let avgLatency = totalLatency / usages.count

        return UsageSummary(
            totalPromptTokens: totalPrompt,
            totalCompletionTokens: totalCompletion,
            totalTokens: totalTokens,
            totalCostUSD: totalCostUSD,
            totalCostCNY: totalCostCNY,
            totalRequests: usages.count,
            successRequests: successCount,
            failedRequests: failedCount,
            avgLatencyMs: avgLatency
        )
    }
}

// MARK: - ModelRouterError

public enum ModelRouterError: Error, LocalizedError {
    case noAvailableProvider
    case invalidRequest
    case pricingNotFound

    public var errorDescription: String? {
        switch self {
        case .noAvailableProvider: return "没有可用的模型提供商"
        case .invalidRequest: return "无效的路由请求"
        case .pricingNotFound: return "未找到定价配置"
        }
    }
}
