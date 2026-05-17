import Foundation

public enum AIModelCategory: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case speechToText
    case imageOCR
    case textCleanup
    case summarization
    case knowledgeRetrieval
    case complexTask

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .speechToText: return "语音转文字"
        case .imageOCR: return "图片/OCR 识别"
        case .textCleanup: return "文本清洗"
        case .summarization: return "摘要与复盘"
        case .knowledgeRetrieval: return "知识检索"
        case .complexTask: return "复杂任务 / Agent"
        }
    }

    public var shortHint: String {
        switch self {
        case .speechToText: return "录音、会议、语音想法"
        case .imageOCR: return "截图、图片、票据、表格"
        case .textCleanup: return "清洗、分类、标题、标签"
        case .summarization: return "日报、周报、长文复盘"
        case .knowledgeRetrieval: return "本地知识库、关键词检索"
        case .complexTask: return "多步任务、规划、Agent"
        }
    }
}

public struct AIModelCategoryPreference: Codable, Identifiable, Hashable, Sendable {
    public var id: String { category.rawValue }
    public let category: AIModelCategory
    public var selectedProviderId: String
    public var selectedModelId: String?
    public var fallbackProviderId: String
    public var fallbackModelId: String?
    public var isEnabled: Bool

    public init(
        category: AIModelCategory,
        selectedProviderId: String,
        selectedModelId: String? = nil,
        fallbackProviderId: String,
        fallbackModelId: String? = nil,
        isEnabled: Bool = true
    ) {
        self.category = category
        self.selectedProviderId = selectedProviderId
        self.selectedModelId = selectedModelId
        self.fallbackProviderId = fallbackProviderId
        self.fallbackModelId = fallbackModelId
        self.isEnabled = isEnabled
    }
}

public struct AIModelOption: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let providerId: String
    public let modelId: String?
    public let category: AIModelCategory
    public let isSystemDefault: Bool
    public let isAvailable: Bool
    public let privacyLevel: String
    public let costLevel: String
    public let loadLevel: String
    public let description: String

    public init(
        id: String,
        displayName: String,
        providerId: String,
        modelId: String? = nil,
        category: AIModelCategory,
        isSystemDefault: Bool = false,
        isAvailable: Bool = true,
        privacyLevel: String,
        costLevel: String,
        loadLevel: String,
        description: String
    ) {
        self.id = id
        self.displayName = displayName
        self.providerId = providerId
        self.modelId = modelId
        self.category = category
        self.isSystemDefault = isSystemDefault
        self.isAvailable = isAvailable
        self.privacyLevel = privacyLevel
        self.costLevel = costLevel
        self.loadLevel = loadLevel
        self.description = description
    }
}

public enum AIModelCatalog {
    public static let speechFallbackProviderId = "builtin.apple.speech"
    public static let imageFallbackProviderId = "builtin.apple.vision"
    public static let cleanupFallbackProviderId = "builtin.rule.cleanup"
    public static let summaryFallbackProviderId = "builtin.rule.summary"
    public static let knowledgeFallbackProviderId = "builtin.keyword.search"
    public static let complexFallbackProviderId = "builtin.manual.only"

    public static func defaultPreferences() -> [AIModelCategoryPreference] {
        [
            .init(
                category: .speechToText,
                selectedProviderId: speechFallbackProviderId,
                selectedModelId: "Apple Speech",
                fallbackProviderId: speechFallbackProviderId,
                fallbackModelId: "Apple Speech",
                isEnabled: true
            ),
            .init(
                category: .imageOCR,
                selectedProviderId: imageFallbackProviderId,
                selectedModelId: "Apple Vision OCR",
                fallbackProviderId: imageFallbackProviderId,
                fallbackModelId: "Apple Vision OCR",
                isEnabled: true
            ),
            .init(
                category: .textCleanup,
                selectedProviderId: cleanupFallbackProviderId,
                selectedModelId: "RuleBased Cleanup",
                fallbackProviderId: cleanupFallbackProviderId,
                fallbackModelId: "RuleBased Cleanup",
                isEnabled: true
            ),
            .init(
                category: .summarization,
                selectedProviderId: summaryFallbackProviderId,
                selectedModelId: "RuleBased Summary",
                fallbackProviderId: summaryFallbackProviderId,
                fallbackModelId: "RuleBased Summary",
                isEnabled: true
            ),
            .init(
                category: .knowledgeRetrieval,
                selectedProviderId: knowledgeFallbackProviderId,
                selectedModelId: "Keyword Search",
                fallbackProviderId: knowledgeFallbackProviderId,
                fallbackModelId: "Keyword Search",
                isEnabled: true
            ),
            .init(
                category: .complexTask,
                selectedProviderId: complexFallbackProviderId,
                selectedModelId: nil,
                fallbackProviderId: complexFallbackProviderId,
                fallbackModelId: nil,
                isEnabled: false
            )
        ]
    }

    public static func defaultPreference(for category: AIModelCategory) -> AIModelCategoryPreference {
        defaultPreferences().first(where: { $0.category == category }) ?? defaultPreferences()[0]
    }

    public static func options(
        for category: AIModelCategory,
        providers: [ProviderConfig]
    ) -> [AIModelOption] {
        var options = builtInOptions(for: category)

        for provider in providers {
            guard supports(category: category, provider: provider) else { continue }
            let isCloud = provider.tier == .cloudLight || provider.tier == .cloudHeavy
            let privacyLevel = isCloud ? "云端" : "本地"
            let costLevel = isCloud ? "付费" : "免费"
            let loadLevel = loadLevelText(provider.tier)
            let suffix = provider.modelId.isEmpty ? provider.name : provider.modelId
            let id = "\(provider.id):\(provider.modelId.isEmpty ? category.rawValue : provider.modelId)"

            options.append(
                AIModelOption(
                    id: id,
                    displayName: provider.name.isEmpty ? suffix : provider.name,
                    providerId: provider.id,
                    modelId: provider.modelId.isEmpty ? nil : provider.modelId,
                    category: category,
                    isSystemDefault: false,
                    isAvailable: provider.enabled,
                    privacyLevel: privacyLevel,
                    costLevel: costLevel,
                    loadLevel: loadLevel,
                    description: provider.modelId.isEmpty ? provider.name : "\(provider.name) · \(provider.modelId)"
                )
            )
        }

        return deduplicated(options)
    }

    public static func preferredOption(
        for category: AIModelCategory,
        preferences: [AIModelCategoryPreference],
        options: [AIModelOption]
    ) -> AIModelOption? {
        let preference = preferences.first(where: { $0.category == category }) ?? defaultPreference(for: category)
        return option(providerId: preference.selectedProviderId, modelId: preference.selectedModelId, in: options)
    }

    public static func fallbackOption(
        for category: AIModelCategory,
        preferences: [AIModelCategoryPreference],
        options: [AIModelOption]
    ) -> AIModelOption? {
        let preference = preferences.first(where: { $0.category == category }) ?? defaultPreference(for: category)
        return option(providerId: preference.fallbackProviderId, modelId: preference.fallbackModelId, in: options)
    }

    public static func option(
        providerId: String,
        modelId: String?,
        in options: [AIModelOption]
    ) -> AIModelOption? {
        if let modelId {
            if let exact = options.first(where: { $0.providerId == providerId && $0.modelId == modelId }) {
                return exact
            }
        }
        return options.first(where: { $0.providerId == providerId })
    }

    public static func selection(
        for category: AIModelCategory,
        preferences: [AIModelCategoryPreference],
        options: [AIModelOption]
    ) -> AIModelOption? {
        guard let preferred = preferredOption(for: category, preferences: preferences, options: options) else {
            return fallbackOption(for: category, preferences: preferences, options: options)
        }
        if preferred.isAvailable {
            return preferred
        }
        return fallbackOption(for: category, preferences: preferences, options: options)
    }

    public static func normalize(
        _ preferences: [AIModelCategoryPreference],
        providers: [ProviderConfig]
    ) -> [AIModelCategoryPreference] {
        let categories = AIModelCategory.allCases
        var normalized: [AIModelCategoryPreference] = []

        for category in categories {
            let existing = preferences.first(where: { $0.category == category }) ?? defaultPreference(for: category)
            let options = options(for: category, providers: providers)
            let preferred = option(providerId: existing.selectedProviderId, modelId: existing.selectedModelId, in: options)
            let fallback = option(providerId: existing.fallbackProviderId, modelId: existing.fallbackModelId, in: options)

            var updated = existing
            updated.selectedProviderId = preferred?.providerId ?? fallback?.providerId ?? existing.selectedProviderId
            updated.selectedModelId = preferred?.modelId ?? fallback?.modelId ?? existing.selectedModelId
            updated.fallbackProviderId = fallback?.providerId ?? existing.fallbackProviderId
            updated.fallbackModelId = fallback?.modelId ?? existing.fallbackModelId
            updated.isEnabled = (preferred?.isAvailable ?? fallback?.isAvailable ?? existing.isEnabled)
            normalized.append(updated)
        }

        return normalized
    }

    private static func builtInOptions(for category: AIModelCategory) -> [AIModelOption] {
        switch category {
        case .speechToText:
            return [
                .init(
                    id: "builtin.apple.speech",
                    displayName: "Apple Speech",
                    providerId: speechFallbackProviderId,
                    modelId: "Apple Speech",
                    category: category,
                    isSystemDefault: true,
                    isAvailable: true,
                    privacyLevel: "系统内置",
                    costLevel: "免费",
                    loadLevel: "轻量",
                    description: "系统原生语音识别"
                )
            ]
        case .imageOCR:
            return [
                .init(
                    id: "builtin.apple.vision",
                    displayName: "Apple Vision OCR",
                    providerId: imageFallbackProviderId,
                    modelId: "Apple Vision OCR",
                    category: category,
                    isSystemDefault: true,
                    isAvailable: true,
                    privacyLevel: "系统内置",
                    costLevel: "免费",
                    loadLevel: "轻量",
                    description: "系统原生 OCR"
                )
            ]
        case .textCleanup:
            return [
                .init(
                    id: "builtin.rule.cleanup",
                    displayName: "RuleBased Cleanup",
                    providerId: cleanupFallbackProviderId,
                    modelId: "RuleBased Cleanup",
                    category: category,
                    isSystemDefault: true,
                    isAvailable: true,
                    privacyLevel: "本地",
                    costLevel: "免费",
                    loadLevel: "轻量",
                    description: "本地规则清洗 / 标题 / 标签"
                )
            ]
        case .summarization:
            return [
                .init(
                    id: "builtin.rule.summary",
                    displayName: "RuleBased Summary",
                    providerId: summaryFallbackProviderId,
                    modelId: "RuleBased Summary",
                    category: category,
                    isSystemDefault: true,
                    isAvailable: true,
                    privacyLevel: "本地",
                    costLevel: "免费",
                    loadLevel: "轻量",
                    description: "本地摘要 / 复盘占位"
                )
            ]
        case .knowledgeRetrieval:
            return [
                .init(
                    id: "builtin.keyword.search",
                    displayName: "Keyword Search",
                    providerId: knowledgeFallbackProviderId,
                    modelId: "Keyword Search",
                    category: category,
                    isSystemDefault: true,
                    isAvailable: true,
                    privacyLevel: "本地",
                    costLevel: "免费",
                    loadLevel: "轻量",
                    description: "本地关键词检索占位"
                )
            ]
        case .complexTask:
            return [
                .init(
                    id: "builtin.manual.only",
                    displayName: "Manual Only / Disabled",
                    providerId: complexFallbackProviderId,
                    modelId: nil,
                    category: category,
                    isSystemDefault: true,
                    isAvailable: false,
                    privacyLevel: "本地",
                    costLevel: "免费",
                    loadLevel: "轻量",
                    description: "默认关闭，复杂任务需手动开启"
                )
            ]
        }
    }

    private static func supports(category: AIModelCategory, provider: ProviderConfig) -> Bool {
        switch category {
        case .speechToText:
            return containsAny(provider.modelId, ["whisper", "asr", "speech", "sensevoice", "qwen3"])
        case .imageOCR:
            return containsAny(provider.modelId, ["vision", "vl", "ocr", "multimodal"])
        case .textCleanup, .summarization, .complexTask:
            return provider.capabilities.contains("chat") || provider.capabilities.contains("stream") || provider.providerType == .ollama || provider.providerType == .openAICompatible || provider.providerType == .openAI
        case .knowledgeRetrieval:
            return provider.capabilities.contains("chat") || provider.capabilities.contains("stream") || provider.providerType == .ollama || provider.providerType == .openAICompatible || provider.providerType == .openAI
        }
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        let lowercased = text.lowercased()
        return needles.contains(where: { lowercased.contains($0.lowercased()) })
    }

    private static func loadLevelText(_ tier: ProviderTier) -> String {
        switch tier {
        case .localLight: return "轻量"
        case .localHeavy: return "高负载"
        case .cloudLight: return "轻量"
        case .cloudHeavy: return "高负载"
        }
    }

    private static func deduplicated(_ options: [AIModelOption]) -> [AIModelOption] {
        var seen = Set<String>()
        return options.filter { seen.insert($0.id).inserted }
    }
}
