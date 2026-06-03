import Foundation

// MARK: - KnowledgeCard（知识卡片）

/// 知识沉淀的最终形态
/// 对齐旧版 knowledge_cards 表
public struct KnowledgeCard: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var sourceItemId: String
    public var distilledOutputId: String?
    public var exportRecordId: String?
    public var canonicalTitle: String
    public var summary: String?
    public var category: String?
    public var tags: [String]
    public var body: String?
    public var bodyMarkdown: String?
    public var documentType: String?
    public var valueScore: Double?
    public var confidence: Double?
    public var status: KnowledgeCardStatus
    public var vaultFilePath: String?
    public var searchVector: String?
    public var referenceCount: Int
    public var lastAccessedAt: Date?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceItemId: String,
        distilledOutputId: String? = nil,
        exportRecordId: String? = nil,
        canonicalTitle: String = "",
        summary: String? = nil,
        category: String? = nil,
        tags: [String] = [],
        body: String? = nil,
        bodyMarkdown: String? = nil,
        documentType: String? = nil,
        valueScore: Double? = nil,
        confidence: Double? = nil,
        status: KnowledgeCardStatus = .active,
        vaultFilePath: String? = nil,
        searchVector: String? = nil,
        referenceCount: Int = 0,
        lastAccessedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceItemId = sourceItemId
        self.distilledOutputId = distilledOutputId
        self.exportRecordId = exportRecordId
        self.canonicalTitle = canonicalTitle
        self.summary = summary
        self.category = category
        self.tags = tags
        self.body = body
        self.bodyMarkdown = bodyMarkdown
        self.documentType = documentType
        self.valueScore = valueScore
        self.confidence = confidence
        self.status = status
        self.vaultFilePath = vaultFilePath
        self.searchVector = searchVector
        self.referenceCount = referenceCount
        self.lastAccessedAt = lastAccessedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// 从 DistilledNote 创建 KnowledgeCard
    public init(from note: DistilledNote) {
        self.id = UUID().uuidString
        self.sourceItemId = note.sourceItemId
        self.distilledOutputId = note.id
        self.exportRecordId = nil
        self.canonicalTitle = note.title ?? "未命名"
        self.summary = note.summary
        self.category = note.category
        self.tags = note.tags
        self.body = note.contentMarkdown
        self.bodyMarkdown = note.contentMarkdown
        self.documentType = note.documentType
        self.valueScore = note.valueScore
        self.confidence = note.confidence
        self.status = .active
        self.vaultFilePath = nil
        self.searchVector = Self.buildSearchVector(
            title: note.title,
            summary: note.summary,
            tags: note.tags,
            content: note.contentMarkdown
        )
        self.referenceCount = 0
        self.lastAccessedAt = nil
        self.createdAt = note.createdAt
        self.updatedAt = Date()
    }
    
    /// 构建搜索向量（用于全文搜索）
    private static func buildSearchVector(
        title: String?,
        summary: String?,
        tags: [String],
        content: String?
    ) -> String {
        var parts: [String] = []
        if let title = title { parts.append(title) }
        if let summary = summary { parts.append(summary) }
        parts.append(contentsOf: tags)
        if let content = content { parts.append(String(content.prefix(200))) }
        return parts.joined(separator: " ").lowercased()
    }
}

public enum KnowledgeCardStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case active
    case archived
    case superseded
    case deleted

    public static var allCases: [KnowledgeCardStatus] {
        [.active, .archived, .superseded, .deleted]
    }

    public var displayName: String {
        switch self {
        case .active: return "活跃"
        case .archived: return "已归档"
        case .superseded: return "已被替代"
        case .deleted: return "已删除"
        }
    }
}

// MARK: - KnowledgeEdge（知识关系）

/// 知识卡片之间的关系边
public struct KnowledgeEdge: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var fromKnowledgeCardId: String
    public var toKnowledgeCardId: String
    public var relationType: String
    public var status: EdgeStatus
    public var confidence: Double?
    public var reason: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        fromKnowledgeCardId: String,
        toKnowledgeCardId: String,
        relationType: String,
        status: EdgeStatus = .suggested,
        confidence: Double? = nil,
        reason: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.fromKnowledgeCardId = fromKnowledgeCardId
        self.toKnowledgeCardId = toKnowledgeCardId
        self.relationType = relationType
        self.status = status
        self.confidence = confidence
        self.reason = reason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum EdgeStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case suggested
    case confirmed
    case rejected

    public static var allCases: [EdgeStatus] { [.suggested, .confirmed, .rejected] }

    public var displayName: String {
        switch self {
        case .suggested: return "建议"
        case .confirmed: return "已确认"
        case .rejected: return "已拒绝"
        }
    }
}

// MARK: - VaultSearchResult

/// Vault 搜索结果
public struct VaultSearchResult: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let filePath: String
    public let title: String
    public let excerpt: String
    public var score: Double?
    public var knowledgeCardId: String?

    public init(
        id: String = UUID().uuidString,
        filePath: String,
        title: String,
        excerpt: String,
        score: Double? = nil,
        knowledgeCardId: String? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.excerpt = excerpt
        self.score = score
        self.knowledgeCardId = knowledgeCardId
    }
}

// MARK: - Knowledge Graph

public struct KnowledgeGraph: Sendable, Equatable {
    public let nodes: [KnowledgeGraphNode]
    public let edges: [KnowledgeGraphEdge]

    public init(nodes: [KnowledgeGraphNode] = [], edges: [KnowledgeGraphEdge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
}

public struct KnowledgeGraphNode: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let category: String?
    public let tags: [String]
    public let valueScore: Double?

    public init(
        id: String,
        title: String,
        category: String? = nil,
        tags: [String] = [],
        valueScore: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.tags = tags
        self.valueScore = valueScore
    }
}

public struct KnowledgeGraphEdge: Sendable, Equatable, Identifiable {
    public let id: String
    public let sourceId: String
    public let targetId: String
    public let relationType: String
    public let confidence: Double?

    public init(
        id: String,
        sourceId: String,
        targetId: String,
        relationType: String,
        confidence: Double? = nil
    ) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.relationType = relationType
        self.confidence = confidence
    }
}

// MARK: - Knowledge Stats

public struct KnowledgeStats: Sendable, Equatable {
    public let totalCards: Int
    public let activeCards: Int
    public let categories: [String: Int]
    public let recentCount: Int
    public let highValueCount: Int
    
    public init(
        totalCards: Int = 0,
        activeCards: Int = 0,
        categories: [String: Int] = [:],
        recentCount: Int = 0,
        highValueCount: Int = 0
    ) {
        self.totalCards = totalCards
        self.activeCards = activeCards
        self.categories = categories
        self.recentCount = recentCount
        self.highValueCount = highValueCount
    }
}
