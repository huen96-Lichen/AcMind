import Foundation

// MARK: - Markdown Builder

/// Markdown 构建器
/// 功能：
/// 1. 生成符合 Obsidian 规范的 Markdown
/// 2. 支持自定义 frontmatter
/// 3. 支持多种模板风格
public struct MarkdownBuilder {
    
    // MARK: - Configuration
    
    public var includeFrontmatter: Bool = true
    public var includeSummary: Bool = true
    public var includeTags: Bool = true
    public var includeMetadata: Bool = true
    public var frontmatterTemplate: [String: String] = [:]
    
    public init() {}
    
    // MARK: - Build
    
    public func build(note: DistilledNote) -> String {
        var parts: [String] = []
        
        // 1. Frontmatter
        if includeFrontmatter {
            parts.append(buildFrontmatter(note: note))
        }
        
        // 2. Title
        if let title = note.title, !title.isEmpty {
            parts.append("# \(title)")
        }
        
        // 3. Summary (as callout)
        if includeSummary, let summary = note.summary, !summary.isEmpty {
            parts.append("""
                > [!summary] 摘要
                > \(summary)
                """)
        }
        
        // 4. Tags
        if includeTags, !note.tags.isEmpty {
            parts.append(buildTags(tags: note.tags))
        }
        
        // 5. Metadata
        if includeMetadata {
            parts.append(buildMetadata(note: note))
        }
        
        // 6. Main Content
        if let content = note.contentMarkdown, !content.isEmpty {
            parts.append(content)
        }
        
        return parts.joined(separator: "\n\n")
    }
    
    public func build(note: DistilledNote, sourceItem: SourceItem) -> String {
        var parts: [String] = []
        
        // 1. Frontmatter (包含更多来源信息)
        if includeFrontmatter {
            parts.append(buildFrontmatter(note: note, sourceItem: sourceItem))
        }
        
        // 2. Title
        if let title = note.title, !title.isEmpty {
            parts.append("# \(title)")
        }
        
        // 3. Summary
        if includeSummary, let summary = note.summary, !summary.isEmpty {
            parts.append("""
                > [!summary] 摘要
                > \(summary)
                """)
        }
        
        // 4. Tags
        if includeTags, !note.tags.isEmpty {
            parts.append(buildTags(tags: note.tags))
        }
        
        // 5. Source Info
        parts.append(buildSourceInfo(sourceItem: sourceItem))
        
        // 6. Main Content
        if let content = note.contentMarkdown, !content.isEmpty {
            parts.append("---\n\n" + content)
        }
        
        return parts.joined(separator: "\n\n")
    }
    
    // MARK: - Frontmatter
    
    private func buildFrontmatter(note: DistilledNote) -> String {
        var frontmatter: [String: String] = [
            "title": note.title ?? "",
            "created": ISO8601DateFormatter().string(from: note.createdAt),
            "tags": note.tags.joined(separator: ", "),
            "category": note.category ?? "",
            "document_type": note.documentType ?? "",
            "value_score": note.valueScore.map { String($0) } ?? "",
            "review_status": note.reviewStatus.rawValue
        ]
        
        // 合并自定义模板
        for (key, value) in frontmatterTemplate {
            frontmatter[key] = value
        }
        
        // 移除空值
        frontmatter = frontmatter.filter { !$0.value.isEmpty }
        
        var lines = ["---"]
        for (key, value) in frontmatter.sorted(by: { $0.key < $1.key }) {
            // 处理包含特殊字符的值
            if value.contains(":") || value.contains("#") || value.contains("\"") {
                lines.append("\(key): \"\(value.replacingOccurrences(of: "\"", with: "\\\""))\"")
            } else {
                lines.append("\(key): \(value)")
            }
        }
        lines.append("---")
        
        return lines.joined(separator: "\n")
    }
    
    private func buildFrontmatter(note: DistilledNote, sourceItem: SourceItem) -> String {
        var frontmatter: [String: String] = [
            "title": note.title ?? "",
            "created": ISO8601DateFormatter().string(from: note.createdAt),
            "source_type": sourceItem.type.rawValue,
            "source_origin": sourceItem.source.rawValue,
            "tags": note.tags.joined(separator: ", "),
            "category": note.category ?? "",
            "document_type": note.documentType ?? "",
            "value_score": note.valueScore.map { String($0) } ?? "",
            "source_id": sourceItem.id
        ]
        
        // 添加来源 URL（如果有）
        if let url = sourceItem.originalUrl {
            frontmatter["source_url"] = url
        }
        
        // 添加来源应用（如果有）
        if let app = sourceItem.sourceApp {
            frontmatter["source_app"] = app
        }
        
        // 合并自定义模板
        for (key, value) in frontmatterTemplate {
            frontmatter[key] = value
        }
        
        // 移除空值
        frontmatter = frontmatter.filter { !$0.value.isEmpty }
        
        var lines = ["---"]
        for (key, value) in frontmatter.sorted(by: { $0.key < $1.key }) {
            if value.contains(":") || value.contains("#") || value.contains("\"") {
                lines.append("\(key): \"\(value.replacingOccurrences(of: "\"", with: "\\\""))\"")
            } else {
                lines.append("\(key): \(value)")
            }
        }
        lines.append("---")
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Tags
    
    private func buildTags(tags: [String]) -> String {
        let tagLinks = tags.map { "#\($0)" }.joined(separator: " ")
        return "标签: \(tagLinks)"
    }
    
    // MARK: - Metadata
    
    private func buildMetadata(note: DistilledNote) -> String {
        var items: [String] = []
        
        if let category = note.category, !category.isEmpty {
            items.append("分类: \(category)")
        }
        
        if let docType = note.documentType, !docType.isEmpty {
            items.append("类型: \(docType)")
        }
        
        if let score = note.valueScore {
            items.append("价值评分: \(String(format: "%.1f", score))")
        }
        
        if let confidence = note.confidence {
            items.append("置信度: \(String(format: "%.0f%%", confidence * 100))")
        }
        
        if items.isEmpty {
            return ""
        }
        
        return items.joined(separator: " | ")
    }
    
    // MARK: - Source Info
    
    private func buildSourceInfo(sourceItem: SourceItem) -> String {
        var lines = ["> [!info] 来源信息"]
        
        lines.append("> - 类型: \(sourceItem.type.displayName)")
        lines.append("> - 来源: \(sourceItem.source.displayName)")
        lines.append("> - 时间: \(formatDate(sourceItem.createdAt))")
        
        if let app = sourceItem.sourceApp {
            lines.append("> - 应用: \(app)")
        }
        
        if let url = sourceItem.originalUrl {
            lines.append("> - URL: [\(url)](\(url))")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

extension MarkdownBuilder {
    
    public func preview(note: DistilledNote, maxLength: Int = 500) -> String {
        let fullMarkdown = build(note: note)
        if fullMarkdown.count <= maxLength {
            return fullMarkdown
        }
        return String(fullMarkdown.prefix(maxLength)) + "..."
    }
}
