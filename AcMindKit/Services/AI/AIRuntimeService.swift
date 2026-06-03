import Foundation

// MARK: - AI Runtime Service

/// AI 运行时服务
/// 职责：
/// 1. Provider 管理（添加/删除/更新/健康检查）
/// 2. Chat 对话（同步/流式）
/// 3. 蒸馏任务
/// 4. 任务队列管理
public final class AIRuntimeService: AIRuntimeProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    private var providers: [String: any AIProvider] = [:]
    private var configs: [ProviderConfig] = []
    private var defaultProviderId: String?
    private let taskQueue: TaskQueue
    private let storage: StorageServiceProtocol
    private let settingsDefaults: UserDefaults
    private let modelRouter: AgentModelRouterProtocol?
    
    // MARK: - Initialization
    
    public convenience init(storage: StorageServiceProtocol? = nil, modelRouter: AgentModelRouterProtocol? = nil) {
        self.init(storage: storage, settingsDefaults: .standard, modelRouter: modelRouter)
    }

    public init(storage: StorageServiceProtocol? = nil, settingsDefaults: UserDefaults = .standard, modelRouter: AgentModelRouterProtocol? = nil) {
        self.storage = storage ?? StorageService()
        self.taskQueue = TaskQueue(maxConcurrent: 2)
        self.settingsDefaults = settingsDefaults
        self.modelRouter = modelRouter
    }
    
    // MARK: - Provider Management

    public func listProviders() async -> [ProviderConfig] {
        await refreshProvidersFromStorageIfNeeded()
        return configs
    }

    public func addProvider(_ config: ProviderConfig) async throws {
        await refreshProvidersFromStorageIfNeeded()

        if configs.contains(where: { $0.id == config.id }) {
            throw AIError.providerNotFound("Provider 已存在: \(config.id)")
        }

        try await storage.addProvider(config)
        try await initProvider(config)
        configs.append(config)

        if configs.count == 1 {
            defaultProviderId = config.id
        }
    }

    public func updateProvider(_ config: ProviderConfig) async throws {
        await refreshProvidersFromStorageIfNeeded()

        guard let index = configs.firstIndex(where: { $0.id == config.id }) else {
            throw AIError.providerNotFound(config.id)
        }

        providers.removeValue(forKey: config.id)

        try await storage.updateProvider(config)
        try await initProvider(config)

        configs[index] = config
    }

    public func removeProvider(id: String) async throws {
        await refreshProvidersFromStorageIfNeeded()

        guard let index = configs.firstIndex(where: { $0.id == id }) else {
            throw AIError.providerNotFound(id)
        }

        configs.remove(at: index)
        providers.removeValue(forKey: id)

        if defaultProviderId == id {
            defaultProviderId = configs.first?.id
        }

        try await storage.removeProvider(id: id)
        try? await SecretStore.shared.deleteAPIKey(for: id)
    }
    
    public func healthCheck(providerId: String) async throws -> Bool {
        guard let provider = providers[providerId] else {
            throw AIError.providerNotFound(providerId)
        }
        return try await provider.healthCheck()
    }

    public func listModels(providerId: String) async throws -> [String] {
        guard let provider = providers[providerId] else {
            throw AIError.providerNotFound(providerId)
        }
        return try await provider.listModels()
    }

    public func healthCheckAll() async -> [String: Bool] {
        var results: [String: Bool] = [:]
        for (id, provider) in providers {
            results[id] = (try? await provider.healthCheck()) ?? false
        }
        return results
    }
    
    public func setDefaultProvider(id: String) throws {
        guard configs.contains(where: { $0.id == id }) else {
            throw AIError.providerNotFound(id)
        }
        defaultProviderId = id
    }
    
    public func getDefaultProvider() -> String? {
        defaultProviderId
    }
    
    // MARK: - Chat
    
    public func chat(messages: [ChatMessage]) async throws -> ChatResponse {
        guard let providerId = preferredProviderId(),
              let provider = providers[providerId] else {
            throw AIError.noProvider
        }
        
        let config = ChatConfig(
            model: configs.first(where: { $0.id == providerId })?.modelId
        )
        
        return try await provider.chat(messages: messages, config: config)
    }
    
    public func chat(
        messages: [ChatMessage],
        providerId: String,
        model: String? = nil
    ) async throws -> ChatResponse {
        guard let provider = providers[providerId] else {
            throw AIError.providerNotFound(providerId)
        }

        let modelId = model ?? configs.first(where: { $0.id == providerId })?.modelId ?? ""
        let config = ChatConfig(model: modelId.isEmpty ? nil : modelId)

        let startTime = Date()
        do {
            let response = try await provider.chat(messages: messages, config: config)
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            let promptTokens = response.usage?.promptTokens ?? response.promptTokens ?? 0
            let completionTokens = response.usage?.completionTokens ?? response.completionTokens ?? 0
            await recordModelUsage(
                providerId: providerId,
                modelId: response.model ?? modelId,
                taskType: .simpleChat,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                latencyMs: response.latencyMs ?? elapsed,
                success: true
            )
            return response
        } catch {
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            await recordModelUsage(
                providerId: providerId,
                modelId: modelId,
                taskType: .simpleChat,
                promptTokens: 0,
                completionTokens: 0,
                latencyMs: elapsed,
                success: false,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }
    
    public func chatStream(messages: [ChatMessage]) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let providerId = self.preferredProviderId(),
                          let provider = providers[providerId] else {
                        continuation.finish(throwing: AIError.noProvider)
                        return
                    }
                    
                    let config = ChatConfig(
                        model: configs.first(where: { $0.id == providerId })?.modelId,
                        stream: true
                    )
                    
                    for try await response in provider.chatStream(messages: messages, config: config) {
                        continuation.yield(response)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Distillation
    
    public func runDistillation(sourceItem: SourceItem) async throws -> DistilledNote {
        guard let providerId = preferredProviderId(),
              let provider = providers[providerId] else {
            throw AIError.noProvider
        }

        let modelId = configs.first(where: { $0.id == providerId })?.modelId ?? ""
        let config = ChatConfig(model: modelId.isEmpty ? nil : modelId)

        let messages = buildDistillationMessages(sourceItem: sourceItem)

        let startTime = Date()
        do {
            let response = try await provider.chat(messages: messages, config: config)
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            let promptTokens = response.usage?.promptTokens ?? response.promptTokens ?? 0
            let completionTokens = response.usage?.completionTokens ?? response.completionTokens ?? 0
            await recordModelUsage(
                providerId: providerId,
                modelId: response.model ?? modelId,
                taskType: .textSummarize,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                latencyMs: response.latencyMs ?? elapsed,
                success: true
            )
            return parseDistillationResult(content: response.content, sourceItem: sourceItem)
        } catch {
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            await recordModelUsage(
                providerId: providerId,
                modelId: modelId,
                taskType: .textSummarize,
                promptTokens: 0,
                completionTokens: 0,
                latencyMs: elapsed,
                success: false,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }
    
    public func runDistillation(sourceItemIds: [String]) async throws -> DistilledNote {
        guard !sourceItemIds.isEmpty else {
            throw AIError.invalidInput("sourceItemIds 不能为空")
        }
        
        // 从数据库加载所有 SourceItem
        var sourceItems: [SourceItem] = []
        var failedIds: [String] = []
        
        for id in sourceItemIds {
            do {
                if let item = try await storage.getSourceItem(id: id) {
                    sourceItems.append(item)
                } else {
                    failedIds.append(id)
                }
            } catch {
                failedIds.append(id)
            }
        }
        
        guard !sourceItems.isEmpty else {
            throw AIError.invalidInput("所有 SourceItem 都未找到: \(failedIds.joined(separator: ", "))")
        }
        
        // 合并文本内容
        let combinedText = sourceItems.enumerated().map { index, item in
            let content = item.previewText ?? item.transcript ?? item.ocrText ?? ""
            return "【内容 \(index + 1)】\n\(content)"
        }.joined(separator: "\n\n---\n\n")
        
        // 创建合并后的虚拟 SourceItem
        let mergedItem = SourceItem(
            type: .text,
            source: .manual,
            status: .captured,
            title: "批量蒸馏 (\(sourceItems.count) 条)",
            previewText: combinedText,
            metadata: [
                "sourceItemIds": sourceItemIds.joined(separator: ","),
                "failedIds": failedIds.joined(separator: ",")
            ]
        )
        
        // 调用单条蒸馏
        var note = try await runDistillation(sourceItem: mergedItem)
        
        // 更新关联的 sourceItemId 为第一个成功的
        if let first = sourceItems.first {
            note = DistilledNote(
                id: note.id,
                sourceItemId: first.id,
                title: note.title,
                summary: note.summary,
                category: note.category,
                tags: note.tags,
                documentType: note.documentType,
                contentMarkdown: note.contentMarkdown,
                valueScore: note.valueScore,
                cleanSuggestion: note.cleanSuggestion,
                confidence: note.confidence,
                reviewStatus: note.reviewStatus,
                reviewedAt: note.reviewedAt,
                acceptedKnowledgeCardId: note.acceptedKnowledgeCardId,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt
            )
        }
        
        return note
    }
    
    private func buildDistillationMessages(sourceItem: SourceItem) -> [ChatMessage] {
        let systemPrompt = """
        你是一个专业的知识整理助手。请根据用户提供的内容，生成一份结构化的笔记。
        
        输出格式要求：
        1. 标题：简洁概括主题
        2. 摘要：100字以内的核心要点
        3. 标签：3-5个关键词标签
        4. 正文：Markdown 格式的详细内容
        """
        
        let content = sourceItem.previewText ?? sourceItem.transcript ?? sourceItem.ocrText ?? ""
        
        return [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: "请整理以下内容：\n\n\(content)")
        ]
    }
    
    private func parseDistillationResult(content: String, sourceItem: SourceItem) -> DistilledNote {
        // 简单解析，实际应该更智能
        let lines = content.components(separatedBy: .newlines)
        
        var title = sourceItem.title ?? "蒸馏结果"
        var summary = ""
        var tags: [String] = []
        let bodyMarkdown = content
        
        for line in lines {
            if line.hasPrefix("# ") {
                title = String(line.dropFirst(2))
            } else if line.hasPrefix("摘要：") || line.hasPrefix("摘要:") {
                summary = String(line.dropFirst(3))
            } else if line.hasPrefix("标签：") || line.hasPrefix("标签:") {
                tags = String(line.dropFirst(3))
                    .components(separatedBy: CharacterSet(charactersIn: "，,、 "))
                    .filter { !$0.isEmpty }
            }
        }
        
        return DistilledNote(
            sourceItemId: sourceItem.id,
            title: title,
            summary: summary,
            tags: tags,
            contentMarkdown: bodyMarkdown
        )
    }
    
    // MARK: - Task Queue
    
    public func listJobs() async throws -> [ProcessJob] {
        await taskQueue.list()
    }
    
    public func getJob(id: String) async -> ProcessJob? {
        await taskQueue.get(id: id)
    }
    
    public func cancelJob(id: String) async throws {
        try await taskQueue.cancel(id: id)
    }
    
    public func getQueueStats() async -> TaskQueueStats {
        await taskQueue.stats()
    }
    
    // MARK: - Private

    private func recordModelUsage(
        providerId: String,
        modelId: String,
        taskType: ModelRoute.TaskType,
        promptTokens: Int,
        completionTokens: Int,
        latencyMs: Int,
        success: Bool,
        errorMessage: String? = nil
    ) async {
        guard let router = modelRouter else { return }
        let pricing = await router.getPricing(for: modelId)
        let (costUSD, costCNY) = pricing?.calculateCost(promptTokens: promptTokens, completionTokens: completionTokens) ?? (0, 0)
        let usage = ModelUsage(
            taskType: taskType,
            providerId: providerId,
            modelId: modelId,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: promptTokens + completionTokens,
            costUSD: costUSD,
            costCNY: costCNY,
            latencyMs: latencyMs,
            success: success,
            errorMessage: errorMessage
        )
        await router.recordUsage(usage)
    }

    private func initProvider(_ config: ProviderConfig) async throws {
        let resolvedBaseURL = config.baseURL.isEmpty ? config.providerType.defaultBaseURL : config.baseURL
        switch config.providerType {
        case .ollama:
            let provider = OllamaProvider(
                baseURL: resolvedBaseURL
            )
            providers[config.id] = provider
            
        case .openAI, .openAICompatible, .anthropic, .google:
            guard let key = await SecretStore.shared.getAPIKey(for: config.id) else {
                throw AIError.noKey
            }
            let provider = OpenAICompatibleProvider(
                baseURL: resolvedBaseURL.isEmpty ? "https://api.openai.com" : resolvedBaseURL,
                apiKey: key
            )
            providers[config.id] = provider

        case .local:
            let provider = OllamaProvider(
                baseURL: resolvedBaseURL.isEmpty ? "http://localhost:11434" : resolvedBaseURL
            )
            providers[config.id] = provider
        }
    }

    private func refreshProvidersFromStorageIfNeeded() async {
        let storedConfigs = (try? await storage.listProviders()) ?? []

        configs = storedConfigs
        providers = [:]

        for config in storedConfigs {
            do {
                try await initProvider(config)
            } catch {
                // 没有 API Key 或 Provider 初始化失败时，仍保留配置供 UI 展示
            }
        }

        if let currentDefaultProviderId = defaultProviderId,
           configs.contains(where: { $0.id == currentDefaultProviderId }) == false {
            defaultProviderId = configs.first?.id
        } else if defaultProviderId == nil {
            defaultProviderId = configs.first?.id
        }
    }

    func preferredProviderId(explicitProviderId: String? = nil) -> String? {
        if let explicitProviderId {
            return explicitProviderId
        }

        let prefersLocal = SettingsLocalPreferences.loadOrDefault(from: settingsDefaults).localFirstMode
        if prefersLocal, let localProvider = configs.first(where: { $0.tier.isLocal }) {
            return localProvider.id
        }

        return defaultProviderId ?? configs.first?.id
    }
}
