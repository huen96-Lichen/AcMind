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

public enum KnowledgeTimelineStatus: String, Codable, Sendable, Equatable {
    case pending
    case active
    case completed
    case archived
    case deleted
}

public struct KnowledgeTimelineItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let detail: String?
    public let status: KnowledgeTimelineStatus
    public let occurredAt: Date?

    public init(
        id: String,
        title: String,
        detail: String? = nil,
        status: KnowledgeTimelineStatus,
        occurredAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.occurredAt = occurredAt
    }
}

public struct KnowledgeClosureSummary: Codable, Sendable, Equatable {
    public let cardId: String
    public let title: String
    public let stateLabel: String
    public let detail: String
    public let nextActionTitle: String?
    public let timeline: [KnowledgeTimelineItem]

    public init(
        cardId: String,
        title: String,
        stateLabel: String,
        detail: String,
        nextActionTitle: String?,
        timeline: [KnowledgeTimelineItem]
    ) {
        self.cardId = cardId
        self.title = title
        self.stateLabel = stateLabel
        self.detail = detail
        self.nextActionTitle = nextActionTitle
        self.timeline = timeline
    }

    public static func make(
        from card: KnowledgeCard,
        edges: [KnowledgeEdge] = []
    ) -> KnowledgeClosureSummary {
        let suggestedEdges = edges.filter { edge in
            edge.status == .suggested &&
            (edge.fromKnowledgeCardId == card.id || edge.toKnowledgeCardId == card.id)
        }

        return KnowledgeClosureSummary(
            cardId: card.id,
            title: card.canonicalTitle.isEmpty ? "未命名知识" : card.canonicalTitle,
            stateLabel: card.status.displayName,
            detail: detail(for: card, suggestedEdges: suggestedEdges),
            nextActionTitle: nextActionTitle(for: card, suggestedEdges: suggestedEdges),
            timeline: timeline(for: card, suggestedEdges: suggestedEdges)
        )
    }

    private static func detail(
        for card: KnowledgeCard,
        suggestedEdges: [KnowledgeEdge]
    ) -> String {
        if suggestedEdges.isEmpty == false {
            return "有 \(suggestedEdges.count) 条关联待确认"
        }
        if let summary = card.summary, summary.isEmpty == false {
            return summary
        }
        if card.referenceCount > 0 {
            return "已被引用 \(card.referenceCount) 次"
        }
        if card.tags.isEmpty == false {
            return card.tags.joined(separator: " · ")
        }
        return card.status.displayName
    }

    private static func nextActionTitle(
        for card: KnowledgeCard,
        suggestedEdges: [KnowledgeEdge]
    ) -> String? {
        if suggestedEdges.isEmpty == false {
            return "确认关联"
        }

        switch card.status {
        case .active:
            return card.referenceCount > 0 ? "继续关联" : "补充关联"
        case .archived:
            return "恢复为活跃"
        case .superseded:
            return "查看替代卡片"
        case .deleted:
            return nil
        }
    }

    private static func timeline(
        for card: KnowledgeCard,
        suggestedEdges: [KnowledgeEdge]
    ) -> [KnowledgeTimelineItem] {
        var items: [KnowledgeTimelineItem] = [
            KnowledgeTimelineItem(
                id: "\(card.id)-captured",
                title: "已捕获",
                detail: card.sourceItemId,
                status: .completed,
                occurredAt: card.createdAt
            )
        ]

        if card.distilledOutputId != nil {
            items.append(
                KnowledgeTimelineItem(
                    id: "\(card.id)-distilled",
                    title: "已蒸馏",
                    status: .completed,
                    occurredAt: card.updatedAt
                )
            )
        }

        if let vaultPath = card.vaultFilePath, vaultPath.isEmpty == false {
            items.append(
                KnowledgeTimelineItem(
                    id: "\(card.id)-vault",
                    title: "已写入 Vault",
                    detail: vaultPath,
                    status: .completed,
                    occurredAt: card.updatedAt
                )
            )
        }

        if card.referenceCount > 0 {
            items.append(
                KnowledgeTimelineItem(
                    id: "\(card.id)-references",
                    title: "已被引用",
                    detail: "\(card.referenceCount) 次",
                    status: .active,
                    occurredAt: card.lastAccessedAt ?? card.updatedAt
                )
            )
        }

        if suggestedEdges.isEmpty == false {
            items.append(
                KnowledgeTimelineItem(
                    id: "\(card.id)-suggested-edges",
                    title: "待确认关联",
                    detail: "\(suggestedEdges.count) 条",
                    status: .pending,
                    occurredAt: suggestedEdges.map(\.updatedAt).max()
                )
            )
        }

        switch card.status {
        case .archived:
            items.append(
                KnowledgeTimelineItem(
                    id: "\(card.id)-archived",
                    title: "已归档",
                    status: .archived,
                    occurredAt: card.updatedAt
                )
            )
        case .superseded:
            items.append(
                KnowledgeTimelineItem(
                    id: "\(card.id)-superseded",
                    title: "已被替代",
                    status: .archived,
                    occurredAt: card.updatedAt
                )
            )
        case .deleted:
            items.append(
                KnowledgeTimelineItem(
                    id: "\(card.id)-deleted",
                    title: "已删除",
                    status: .deleted,
                    occurredAt: card.updatedAt
                )
            )
        case .active:
            break
        }

        return items
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
