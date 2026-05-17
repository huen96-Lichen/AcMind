import Foundation

// MARK: - Native AI Task Types

public enum AITaskType: String, Codable, Sendable, Hashable, CaseIterable {
    case speechToText
    case imageOCR
    case textCleanup
    case summarize
    case classify
    case generateTitle
    case generateTags
    case createTodo
    case createDailyReview
    case createWeeklyReview
    case complexPlanning
    case knowledgeRecall
}

public enum AICapability: String, Codable, Sendable, Hashable, CaseIterable {
    case speechToText
    case imageOCR
    case textCleanup
    case summarization
    case classification
    case titleGeneration
    case tagGeneration
    case todoExtraction
    case dailyReview
    case weeklyReview
    case complexReasoning
    case knowledgeRecall
    case local
    case cloud
}

public enum AcMindOutputType: String, Codable, Sendable, Hashable, CaseIterable {
    case markdownNote
    case todo
    case calendarEvent
    case dailyReview
    case weeklyReview
    case knowledgeCard
    case reminder
    case rawTranscript
    case rawOCR
    case cleanedText
}

public enum InboxCategory: String, Codable, Sendable, Hashable, CaseIterable {
    case idea
    case task
    case diary
    case reference
    case link
    case needsConfirmation

    public var displayName: String {
        switch self {
        case .idea: return "想法"
        case .task: return "任务"
        case .diary: return "日记"
        case .reference: return "资料"
        case .link: return "链接"
        case .needsConfirmation: return "待确认"
        }
    }
}

public enum AIMetadataKey {
    public static let taskType = "ai.taskType"
    public static let providerId = "ai.providerId"
    public static let processedAt = "ai.processedAt"
    public static let outputType = "ai.outputType"
    public static let inboxCategory = "inbox.category"
    public static let requiresUserConsent = "privacy.requiresUserConsent"
}

public struct AIRequest: Sendable, Equatable {
    public var id: String
    public var taskType: AITaskType
    public var sourceItemId: String?
    public var inputText: String?
    public var fileURL: URL?
    public var createdAt: Date
    public var metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        taskType: AITaskType,
        sourceItemId: String? = nil,
        inputText: String? = nil,
        fileURL: URL? = nil,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.taskType = taskType
        self.sourceItemId = sourceItemId
        self.inputText = inputText
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

public struct AIResponse: Sendable, Equatable {
    public var id: String
    public var requestId: String
    public var providerId: String
    public var taskType: AITaskType
    public var outputType: AcMindOutputType
    public var text: String
    public var markdown: String?
    public var title: String?
    public var summary: String?
    public var category: InboxCategory?
    public var tags: [String]
    public var confidence: Double?
    public var createdAt: Date
    public var metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        requestId: String,
        providerId: String,
        taskType: AITaskType,
        outputType: AcMindOutputType,
        text: String,
        markdown: String? = nil,
        title: String? = nil,
        summary: String? = nil,
        category: InboxCategory? = nil,
        tags: [String] = [],
        confidence: Double? = nil,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.requestId = requestId
        self.providerId = providerId
        self.taskType = taskType
        self.outputType = outputType
        self.text = text
        self.markdown = markdown
        self.title = title
        self.summary = summary
        self.category = category
        self.tags = tags
        self.confidence = confidence
        self.createdAt = createdAt
        self.metadata = metadata
    }

    public func makeDistilledNote(sourceItem: SourceItem) -> DistilledNote {
        DistilledNote(
            sourceItemId: sourceItem.id,
            taskId: id,
            title: title ?? sourceItem.title ?? "整理结果",
            summary: summary ?? String(text.prefix(120)),
            category: category?.displayName,
            tags: tags,
            documentType: outputType == .knowledgeCard ? "资料卡" : "笔记",
            contentMarkdown: markdown ?? text,
            valueScore: 0.6,
            confidence: confidence,
            reviewStatus: .pending
        )
    }
}

public protocol AIModelProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var capabilities: [AICapability] { get }
    func run(_ request: AIRequest) async throws -> AIResponse
}

public struct TaskRoute: Sendable, Equatable {
    public var taskType: AITaskType
    public var preferredCapabilities: [AICapability]
    public var requiresCloud: Bool
    public var requiresKnowledgeBase: Bool
    public var requiresUserConfirmation: Bool
    public var outputType: AcMindOutputType

    public init(
        taskType: AITaskType,
        preferredCapabilities: [AICapability],
        requiresCloud: Bool = false,
        requiresKnowledgeBase: Bool = false,
        requiresUserConfirmation: Bool = false,
        outputType: AcMindOutputType
    ) {
        self.taskType = taskType
        self.preferredCapabilities = preferredCapabilities
        self.requiresCloud = requiresCloud
        self.requiresKnowledgeBase = requiresKnowledgeBase
        self.requiresUserConfirmation = requiresUserConfirmation
        self.outputType = outputType
    }
}

public struct TaskRouter: Sendable {
    public init() {}

    public func route(sourceItem: SourceItem) -> TaskRoute {
        switch sourceItem.type {
        case .audio where sourceItem.transcript.isEmptyOrNil,
             .video where sourceItem.transcript.isEmptyOrNil:
            return TaskRoute(
                taskType: .speechToText,
                preferredCapabilities: [.speechToText, .local],
                outputType: .rawTranscript
            )

        case .image where sourceItem.ocrText.isEmptyOrNil,
             .screenshot where sourceItem.ocrText.isEmptyOrNil:
            return TaskRoute(
                taskType: .imageOCR,
                preferredCapabilities: [.imageOCR, .local],
                outputType: .rawOCR
            )

        case .webpage where sourceItem.originalUrl != nil:
            return TaskRoute(
                taskType: .textCleanup,
                preferredCapabilities: [.textCleanup, .classification, .local],
                outputType: .knowledgeCard
            )

        default:
            let content = sourceItem.bestProcessableText
            let taskType: AITaskType = content.count > 2_000 ? .summarize : .textCleanup
            return TaskRoute(
                taskType: taskType,
                preferredCapabilities: [.textCleanup, .summarization, .classification, .local],
                outputType: sourceItem.type == .text ? .markdownNote : .knowledgeCard
            )
        }
    }

    public func category(for taskType: AITaskType) -> AIModelCategory {
        switch taskType {
        case .speechToText:
            return .speechToText
        case .imageOCR:
            return .imageOCR
        case .textCleanup, .generateTitle, .generateTags, .createTodo:
            return .textCleanup
        case .summarize, .createDailyReview, .createWeeklyReview:
            return .summarization
        case .knowledgeRecall:
            return .knowledgeRetrieval
        case .complexPlanning:
            return .complexTask
        case .classify:
            return .textCleanup
        }
    }

    public func resolveModelOption(
        for taskType: AITaskType,
        preferences: [AIModelCategoryPreference],
        providers: [ProviderConfig]
    ) -> AIModelOption? {
        let category = category(for: taskType)
        let options = AIModelCatalog.options(for: category, providers: providers)
        return AIModelCatalog.selection(for: category, preferences: preferences, options: options)
    }

    public func makeRequest(for sourceItem: SourceItem) -> AIRequest {
        let route = route(sourceItem: sourceItem)
        return AIRequest(
            taskType: route.taskType,
            sourceItemId: sourceItem.id,
            inputText: sourceItem.bestProcessableText,
            fileURL: sourceItem.contentPath.map(URL.init(fileURLWithPath:)),
            metadata: sourceItem.metadata.merging([
                AIMetadataKey.taskType: route.taskType.rawValue,
                AIMetadataKey.outputType: route.outputType.rawValue
            ]) { _, new in new }
        )
    }
}

public extension TaskRouter {
    func resolveModelOption(
        for sourceItem: SourceItem,
        preferences: [AIModelCategoryPreference],
        providers: [ProviderConfig]
    ) -> AIModelOption? {
        let route = route(sourceItem: sourceItem)
        return resolveModelOption(for: route.taskType, preferences: preferences, providers: providers)
    }
}

private extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool {
        guard let value = self else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public extension SourceItem {
    var bestProcessableText: String {
        if let polishedTranscript, !polishedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return polishedTranscript
        }
        if let transcript, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return transcript
        }
        if let ocrText, !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ocrText
        }
        if let previewText, !previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return previewText
        }
        return title ?? ""
    }

    func withAIMetadata(
        taskType: AITaskType,
        providerId: String,
        outputType: AcMindOutputType,
        category: InboxCategory?,
        requiresUserConsent: Bool = false,
        processedAt: Date = Date()
    ) -> SourceItem {
        var updated = self
        updated.metadata[AIMetadataKey.taskType] = taskType.rawValue
        updated.metadata[AIMetadataKey.providerId] = providerId
        updated.metadata[AIMetadataKey.processedAt] = ISO8601DateFormatter().string(from: processedAt)
        updated.metadata[AIMetadataKey.outputType] = outputType.rawValue
        updated.metadata[AIMetadataKey.requiresUserConsent] = requiresUserConsent ? "true" : "false"
        if let category {
            updated.metadata[AIMetadataKey.inboxCategory] = category.rawValue
        }
        updated.updatedAt = processedAt
        return updated
    }
}
