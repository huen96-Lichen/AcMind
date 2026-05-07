import Foundation

// MARK: - Knowledge Service

/// 知识库服务
/// 职责：
/// 1. 知识卡片 CRUD
/// 2. Vault 文件搜索
/// 3. 全文搜索
/// 4. 统计信息
public actor KnowledgeService: KnowledgeServiceProtocol {
    
    // MARK: - Dependencies
    
    private let storage: StorageServiceProtocol
    
    // MARK: - State
    
    private var cards: [String: KnowledgeCard] = [:]
    
    // MARK: - Initialization
    
    public init(storage: StorageServiceProtocol = StorageService()) {
        self.storage = storage
    }
    
    // MARK: - CRUD

    public func listCards(filter: KnowledgeCardFilter?) async throws -> [KnowledgeCard] {
        let cards = try await listCards(
            status: filter?.status,
            category: filter?.category,
            limit: nil,
            offset: nil
        )

        guard let tags = filter?.tags, !tags.isEmpty else {
            return cards
        }

        return cards.filter { card in
            tags.allSatisfy { tag in
                card.tags.contains { $0.localizedCaseInsensitiveContains(tag) }
            }
        }
    }
    
    public func listCards(
        status: KnowledgeCardStatus? = nil,
        category: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [KnowledgeCard] {
        var result = Array(cards.values)
        
        // 过滤状态
        if let status = status {
            result = result.filter { $0.status == status }
        }
        
        // 过滤分类
        if let category = category {
            result = result.filter { $0.category == category }
        }
        
        // 排序：最近更新在前
        result.sort { $0.updatedAt > $1.updatedAt }
        
        // 分页
        if let offset = offset {
            result = Array(result.dropFirst(offset))
        }
        if let limit = limit {
            result = Array(result.prefix(limit))
        }
        
        return result
    }
    
    public func getCard(id: String) async throws -> KnowledgeCard? {
        cards[id]
    }
    
    public func createCard(_ card: KnowledgeCard) async throws {
        var newCard = card
        newCard.updatedAt = Date()
        cards[card.id] = newCard
        
        // 更新搜索向量
        if newCard.searchVector == nil {
            newCard.searchVector = buildSearchVector(card: newCard)
            cards[card.id] = newCard
        }
        
        // 持久化
        try? await storage.insertKnowledgeCard(newCard)
    }
    
    public func createCardFromNote(_ note: DistilledNote) async throws -> KnowledgeCard {
        let card = KnowledgeCard(from: note)
        try await createCard(card)
        return card
    }

    public func createCard(from note: DistilledNote) async throws -> KnowledgeCard {
        try await createCardFromNote(note)
    }
    
    public func updateCard(_ card: KnowledgeCard) async throws {
        guard cards[card.id] != nil else {
            throw KnowledgeError.cardNotFound
        }
        
        var updated = card
        updated.updatedAt = Date()
        updated.searchVector = buildSearchVector(card: updated)
        cards[card.id] = updated
        
        try? await storage.updateKnowledgeCard(updated)
    }
    
    public func deleteCard(id: String) async throws {
        guard var card = cards[id] else {
            throw KnowledgeError.cardNotFound
        }
        
        card.status = .deleted
        card.updatedAt = Date()
        cards[id] = card
        
        try? await storage.updateKnowledgeCard(card)
    }
    
    public func archiveCard(id: String) async throws {
        guard var card = cards[id] else {
            throw KnowledgeError.cardNotFound
        }
        
        card.status = .archived
        card.updatedAt = Date()
        cards[id] = card
        
        try? await storage.updateKnowledgeCard(card)
    }
    
    public func restoreCard(id: String) async throws {
        guard var card = cards[id] else {
            throw KnowledgeError.cardNotFound
        }
        
        card.status = .active
        card.updatedAt = Date()
        cards[id] = card
        
        try? await storage.updateKnowledgeCard(card)
    }
    
    // MARK: - Search
    
    public func searchCards(query: String) async throws -> [KnowledgeCard] {
        guard !query.isEmpty else {
            return try await listCards()
        }
        
        let lowercasedQuery = query.lowercased()
        let keywords = lowercasedQuery.split(separator: " ").map(String.init)
        
        return cards.values.filter { card in
            guard card.status == .active else { return false }
            
            // 搜索向量匹配
            if let vector = card.searchVector {
                return keywords.allSatisfy { keyword in
                    vector.contains(keyword)
                }
            }
            
            // 降级：逐字段匹配
            let titleMatch = card.canonicalTitle.lowercased().contains(lowercasedQuery)
            let summaryMatch = card.summary?.lowercased().contains(lowercasedQuery) ?? false
            let tagMatch = card.tags.contains { $0.lowercased().contains(lowercasedQuery) }
            let bodyMatch = card.body?.lowercased().contains(lowercasedQuery) ?? false
            
            return titleMatch || summaryMatch || tagMatch || bodyMatch
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    public func searchCards(query: String, limit: Int) async throws -> [KnowledgeCard] {
        let results = try await searchCards(query: query)
        return Array(results.prefix(limit))
    }
    
    // MARK: - Vault Search
    
    public func searchVault(query: String) async throws -> [VaultSearchResult] {
        let vaultPath = (try? await storage.getSetting(key: "vault.path")) ?? ""
        
        guard !vaultPath.isEmpty,
              FileManager.default.fileExists(atPath: vaultPath) else {
            return []
        }
        
        let lowercasedQuery = query.lowercased()
        var results: [VaultSearchResult] = []
        
        // 递归搜索 .md 文件
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: vaultPath),
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        let fileURLs = enumerator.allObjects.compactMap { $0 as? URL }

        for fileURL in fileURLs {
            guard fileURL.pathExtension == "md" else { continue }
            
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lowerContent = content.lowercased()
                
                if lowerContent.contains(lowercasedQuery) {
                    // 提取标题（从 frontmatter 或第一行 # 标题）
                    let title = extractTitle(from: content) ?? fileURL.deletingPathExtension().lastPathComponent
                    
                    // 提取匹配的上下文片段
                    let excerpt = extractExcerpt(from: content, query: query)
                    
                    // 计算相关度分数
                    let score = calculateRelevanceScore(
                        content: content,
                        query: lowercasedQuery,
                        title: title.lowercased()
                    )
                    
                    // 查找关联的 KnowledgeCard
                    let relativePath = String(fileURL.path.dropFirst(vaultPath.count + 1))
                    let knowledgeCardId = cards.values.first { $0.vaultFilePath == relativePath }?.id
                    
                    let result = VaultSearchResult(
                        filePath: fileURL.path,
                        title: title,
                        excerpt: excerpt,
                        score: score,
                        knowledgeCardId: knowledgeCardId
                    )
                    results.append(result)
                }
            } catch {
                // 跳过无法读取的文件
                continue
            }
        }
        
        // 按相关度排序
        results.sort { ($0.score ?? 0) > ($1.score ?? 0) }
        
        return results
    }
    
    // MARK: - Stats
    
    public func getStats() async throws -> KnowledgeStats {
        let allCards = Array(cards.values).filter { $0.status != .deleted }
        
        let activeCards = allCards.filter { $0.status == .active }
        
        // 分类统计
        var categories: [String: Int] = [:]
        for card in activeCards {
            let cat = card.category ?? "未分类"
            categories[cat, default: 0] += 1
        }
        
        // 最近 7 天新增
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let recentCount = allCards.filter { $0.createdAt >= weekAgo }.count
        
        // 高价值卡片
        let highValueCount = activeCards.filter { ($0.valueScore ?? 0) >= 0.7 }.count
        
        return KnowledgeStats(
            totalCards: allCards.count,
            activeCards: activeCards.count,
            categories: categories,
            recentCount: recentCount,
            highValueCount: highValueCount
        )
    }
    
    // MARK: - Link to Export
    
    public func linkCardToExport(cardId: String, exportRecordId: String) async throws {
        guard var card = cards[cardId] else {
            throw KnowledgeError.cardNotFound
        }
        
        card.exportRecordId = exportRecordId
        card.updatedAt = Date()
        cards[cardId] = card
        
        try? await storage.updateKnowledgeCard(card)
    }
    
    public func setVaultPath(cardId: String, path: String) async throws {
        guard var card = cards[cardId] else {
            throw KnowledgeError.cardNotFound
        }
        
        card.vaultFilePath = path
        card.updatedAt = Date()
        cards[cardId] = card
        
        try? await storage.updateKnowledgeCard(card)
    }
    
    // MARK: - Helpers
    
    private func buildSearchVector(card: KnowledgeCard) -> String {
        var parts: [String] = []
        parts.append(card.canonicalTitle)
        if let summary = card.summary { parts.append(summary) }
        parts.append(contentsOf: card.tags)
        if let body = card.body { parts.append(String(body.prefix(200))) }
        return parts.joined(separator: " ").lowercased()
    }
    
    private func extractTitle(from markdown: String) -> String? {
        // 尝试从 frontmatter 提取 title
        if let range = markdown.range(of: "title:") {
            let afterTitle = markdown[range.upperBound...]
            let lines = afterTitle.components(separatedBy: .newlines)
            if let firstLine = lines.first {
                return firstLine
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        
        // 尝试从 # 标题提取
        if let range = markdown.range(of: "# ") {
            let afterHash = markdown[range.upperBound...]
            let lines = afterHash.components(separatedBy: .newlines)
            if let firstLine = lines.first, !firstLine.isEmpty {
                return firstLine.trimmingCharacters(in: .whitespaces)
            }
        }
        
        return nil
    }
    
    private func extractExcerpt(from content: String, query: String) -> String {
        guard let range = content.lowercased().range(of: query.lowercased()) else {
            return String(content.prefix(200))
        }
        
        let start = content.index(range.lowerBound, offsetBy: -50, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: 100, limitedBy: content.endIndex) ?? content.endIndex
        
        var excerpt = String(content[start..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if start > content.startIndex { excerpt = "..." + excerpt }
        if end < content.endIndex { excerpt = excerpt + "..." }
        
        return excerpt
    }
    
    private func calculateRelevanceScore(content: String, query: String, title: String) -> Double {
        var score = 0.0
        
        // 标题匹配权重高
        if title.contains(query) { score += 10.0 }
        
        // 计算出现次数
        let lowerContent = content.lowercased()
        let occurrences = lowerContent.components(separatedBy: query).count - 1
        score += Double(occurrences) * 0.5
        
        // frontmatter 匹配加分
        if let frontmatterEnd = content.range(of: "---")?.lowerBound,
           content[..<frontmatterEnd].lowercased().contains(query) {
            score += 5.0
        }
        
        return score
    }
}

// MARK: - Errors

public enum KnowledgeError: Error, LocalizedError {
    case cardNotFound
    case vaultNotFound
    case searchFailed(String)
    case invalidQuery
    
    public var errorDescription: String? {
        switch self {
        case .cardNotFound:
            return "知识卡片未找到"
        case .vaultNotFound:
            return "Vault 目录未找到"
        case .searchFailed(let message):
            return "搜索失败: \(message)"
        case .invalidQuery:
            return "无效的搜索查询"
        }
    }
}
