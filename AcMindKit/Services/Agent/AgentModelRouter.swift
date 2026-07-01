import Foundation

// MARK: - AgentModelRouter

/// Agent 模型路由器
public protocol AgentModelRouterProtocol: Sendable {
    func route(request: ModelRouteRequest) async throws -> ModelRoute
    func recordUsage(_ usage: ModelUsage) async
    func getUsageSummary(sessionId: String?) async -> UsageSummary
    func getCurrentSessionUsage() async -> CurrentSessionUsage
    func getPricing(for modelId: String) async -> PricingConfig?
}

/// Agent 模型路由器实现
public actor AgentModelRouter: AgentModelRouterProtocol {
    private var usageHistory: [ModelUsage] = []
    private var currentSessionUsages: [ModelUsage] = []
    private var pricingConfig: [String: PricingConfig]
    private var strategy: ModelRoutingStrategy
    private var routingHistory: [RoutingRecord] = []
    private var configurableCandidates: [ModelRoute.TaskType: [RouteCandidate]] = [:]

    private struct RouteCandidate {
        let providerId: String
        let modelId: String
        let tier: ProviderTier
        let qualityScore: Int
    }

    public init(strategy: ModelRoutingStrategy = .automatic) {
        self.strategy = strategy
        self.pricingConfig = Dictionary(uniqueKeysWithValues: PricingConfig.defaultPricing.map { ("\($0.providerId)_\($0.modelId)", $0) })
    }

    public func route(request: ModelRouteRequest) async throws -> ModelRoute {
        let taskType = request.taskType ?? inferTaskType(request: request)
        let candidate = selectCandidate(for: taskType, request: request)
        let providerId = candidate.providerId
        let modelId = candidate.modelId

        let reason = buildRouteReason(taskType: taskType, request: request, candidate: candidate)

        var estimatedCost: Double? = nil
        if let pricing = pricingConfig["\(providerId)_\(modelId)"] {
            let tokens = estimateTokens(inputLength: request.inputLength, taskType: taskType)
            estimatedCost = pricing.calculateCost(promptTokens: tokens, completionTokens: tokens / 2).usd
        }

        let record = RoutingRecord(
            taskType: taskType,
            providerId: providerId,
            modelId: modelId,
            strategy: strategy,
            reason: reason,
            estimatedCost: estimatedCost
        )
        routingHistory.append(record)

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

    public func getPricing(for modelId: String) async -> PricingConfig? {
        pricingConfig.values.first { $0.modelId == modelId }
    }

    private func updatePricing(_ config: PricingConfig) {
        pricingConfig["\(config.providerId)_\(config.modelId)"] = config
    }

    // MARK: - Routing History

    public func getRoutingHistory(limit: Int = 50) async -> [RoutingRecord] {
        Array(routingHistory.suffix(limit))
    }

    public func getRoutingHistory(for taskType: ModelRoute.TaskType) async -> [RoutingRecord] {
        routingHistory.filter { $0.taskType == taskType }
    }

    // MARK: - Strategy Management

    public func updateStrategy(_ newStrategy: ModelRoutingStrategy) {
        strategy = newStrategy
    }

    public func getCurrentStrategy() async -> ModelRoutingStrategy {
        strategy
    }

    // MARK: - Configurable Candidates

    public func setCandidates(_ candidates: [(providerId: String, modelId: String, tier: ProviderTier, qualityScore: Int)], for taskType: ModelRoute.TaskType) {
        configurableCandidates[taskType] = candidates.map {
            RouteCandidate(providerId: $0.providerId, modelId: $0.modelId, tier: $0.tier, qualityScore: $0.qualityScore)
        }
    }

    public func clearCandidates(for taskType: ModelRoute.TaskType) {
        configurableCandidates.removeValue(forKey: taskType)
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

    private func buildRouteReason(
        taskType: ModelRoute.TaskType,
        request: ModelRouteRequest,
        candidate: RouteCandidate
    ) -> String {
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

        reasons.append("策略: \(strategy.displayName)")
        reasons.append("模型: \(candidate.providerId)_\(candidate.modelId)")

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

    private func selectCandidate(for taskType: ModelRoute.TaskType, request: ModelRouteRequest) -> RouteCandidate {
        let candidates = routeCandidates(for: taskType)
        let filteredCandidates: [RouteCandidate]

        if let preferredTier = request.preferredTier,
           candidates.contains(where: { $0.tier == preferredTier }) {
            filteredCandidates = candidates.filter { $0.tier == preferredTier }
        } else {
            filteredCandidates = candidates
        }

        let baseCandidate = filteredCandidates.first ?? candidates.first ?? RouteCandidate(
            providerId: "ollama",
            modelId: "local",
            tier: .localLight,
            qualityScore: 0
        )

        switch strategy {
        case .automatic:
            return baseCandidate
        case .localPriority:
            return filteredCandidates.first(where: { $0.tier.isLocal }) ?? baseCandidate
        case .cloudPriority:
            return filteredCandidates.first(where: { $0.tier.isCloud }) ?? baseCandidate
        case .costPriority:
            return filteredCandidates.min(by: { candidateCost($0, taskType: taskType, inputLength: request.inputLength) < candidateCost($1, taskType: taskType, inputLength: request.inputLength) })
                ?? baseCandidate
        case .qualityPriority:
            return filteredCandidates.max(by: { lhs, rhs in
                if lhs.qualityScore != rhs.qualityScore {
                    return lhs.qualityScore < rhs.qualityScore
                }
                return candidateCost(lhs, taskType: taskType, inputLength: request.inputLength) > candidateCost(rhs, taskType: taskType, inputLength: request.inputLength)
            }) ?? baseCandidate
        case .privacyPriority:
            return filteredCandidates.first(where: { $0.tier.isLocal }) ?? baseCandidate
        }
    }

    private func routeCandidates(for taskType: ModelRoute.TaskType) -> [RouteCandidate] {
        if let custom = configurableCandidates[taskType], !custom.isEmpty {
            return custom
        }

        switch taskType {
        case .simpleChat:
            return [
                RouteCandidate(providerId: "ollama", modelId: "llama3", tier: .localLight, qualityScore: 2),
                RouteCandidate(providerId: "openai", modelId: "gpt-4o-mini", tier: .cloudLight, qualityScore: 3),
                RouteCandidate(providerId: "openai", modelId: "gpt-4o", tier: .cloudHeavy, qualityScore: 5)
            ]
        case .textSummarize:
            return [
                RouteCandidate(providerId: "ollama", modelId: "llama3", tier: .localLight, qualityScore: 2),
                RouteCandidate(providerId: "deepseek", modelId: "deepseek-chat", tier: .cloudLight, qualityScore: 3),
                RouteCandidate(providerId: "openai", modelId: "gpt-4o-mini", tier: .cloudLight, qualityScore: 4)
            ]
        case .longTextProcess:
            return [
                RouteCandidate(providerId: "deepseek", modelId: "deepseek-chat", tier: .cloudLight, qualityScore: 3),
                RouteCandidate(providerId: "anthropic", modelId: "claude-3-5-haiku-20241022", tier: .cloudHeavy, qualityScore: 4),
                RouteCandidate(providerId: "openai", modelId: "gpt-4o-mini", tier: .cloudLight, qualityScore: 4)
            ]
        case .codeGeneration:
            return [
                RouteCandidate(providerId: "openai", modelId: "gpt-4o-mini", tier: .cloudLight, qualityScore: 4),
                RouteCandidate(providerId: "anthropic", modelId: "claude-sonnet-4-20250514", tier: .cloudHeavy, qualityScore: 5),
                RouteCandidate(providerId: "deepseek", modelId: "deepseek-chat", tier: .cloudLight, qualityScore: 3)
            ]
        case .codeReview:
            return [
                RouteCandidate(providerId: "anthropic", modelId: "claude-sonnet-4-20250514", tier: .cloudHeavy, qualityScore: 5),
                RouteCandidate(providerId: "openai", modelId: "gpt-4o", tier: .cloudHeavy, qualityScore: 5),
                RouteCandidate(providerId: "openai", modelId: "gpt-4o-mini", tier: .cloudLight, qualityScore: 4)
            ]
        case .complexReasoning:
            return [
                RouteCandidate(providerId: "anthropic", modelId: "claude-sonnet-4-20250514", tier: .cloudHeavy, qualityScore: 5),
                RouteCandidate(providerId: "openai", modelId: "gpt-4o", tier: .cloudHeavy, qualityScore: 5),
                RouteCandidate(providerId: "anthropic", modelId: "claude-3-5-haiku-20241022", tier: .cloudHeavy, qualityScore: 4)
            ]
        case .vision:
            return [
                RouteCandidate(providerId: "openai", modelId: "gpt-4o", tier: .cloudHeavy, qualityScore: 5),
                RouteCandidate(providerId: "openai", modelId: "gpt-4o-mini", tier: .cloudLight, qualityScore: 3)
            ]
        case .voice:
            return [
                RouteCandidate(providerId: "ollama", modelId: "whisper", tier: .localLight, qualityScore: 2)
            ]
        }
    }

    private func candidateCost(_ candidate: RouteCandidate, taskType: ModelRoute.TaskType, inputLength: Int) -> Double {
        if let pricing = pricingConfig["\(candidate.providerId)_\(candidate.modelId)"] {
            let tokens = estimateTokens(inputLength: inputLength, taskType: taskType)
            return pricing.calculateCost(promptTokens: tokens, completionTokens: tokens / 2).usd
        }

        if candidate.tier.isLocal {
            return 0
        }

        return candidate.qualityScore > 0 ? Double(candidate.qualityScore) * 1000 : .greatestFiniteMagnitude
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

// MARK: - Routing Record

public struct RoutingRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let taskType: ModelRoute.TaskType
    public let providerId: String
    public let modelId: String
    public let strategy: ModelRoutingStrategy
    public let reason: String
    public let estimatedCost: Double?
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        taskType: ModelRoute.TaskType,
        providerId: String,
        modelId: String,
        strategy: ModelRoutingStrategy,
        reason: String,
        estimatedCost: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.taskType = taskType
        self.providerId = providerId
        self.modelId = modelId
        self.strategy = strategy
        self.reason = reason
        self.estimatedCost = estimatedCost
        self.timestamp = timestamp
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
