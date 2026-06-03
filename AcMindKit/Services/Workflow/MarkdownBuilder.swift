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

// MARK: - TOC Support

extension MarkdownBuilder {

    public func buildTOC(from markdown: String) -> String {
        let sourceLines = markdown.components(separatedBy: .newlines)
        var tocEntries: [(level: Int, title: String)] = []

        for line in sourceLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { continue }

            var level = 0
            for char in trimmed {
                if char == "#" { level += 1 } else { break }
            }
            guard level > 0, level <= 6 else { continue }

            let title = trimmed.drop(while: { $0 == "#" })
                .trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }

            tocEntries.append((level: level, title: title))
        }

        guard !tocEntries.isEmpty else { return "" }

        var outputLines: [String] = ["## 目录", ""]
        for entry in tocEntries {
            let indent = String(repeating: "  ", count: entry.level - 1)
            let anchor = entry.title.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9\\p{Han}\\-]", with: "", options: .regularExpression)
            outputLines.append("\(indent)- [\(entry.title)](#\(anchor))")
        }

        return outputLines.joined(separator: "\n")
    }
}

// MARK: - Code Block Enhancement

extension MarkdownBuilder {

    public func enhanceCodeBlocks(in markdown: String) -> String {
        let pattern = "```\\s*\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return markdown
        }

        let nsString = markdown as NSString
        let results = regex.matches(in: markdown, range: NSRange(location: 0, length: nsString.length))

        var enhanced = markdown
        for result in results.reversed() {
            let codeBlock = nsString.substring(with: result.range)
            let codeContent = codeBlock
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let language = detectLanguage(codeContent)
            let enhancedBlock = "```\(language)\n\(codeContent)\n```"
            enhanced = (enhanced as NSString).replacingCharacters(in: result.range, with: enhancedBlock)
        }

        return enhanced
    }

    private func detectLanguage(_ code: String) -> String {
        let patterns: [(String, String)] = [
            ("func ", "swift"),
            ("import ", "swift"),
            ("class ", "swift"),
            ("struct ", "swift"),
            ("def ", "python"),
            ("import ", "python"),
            ("from ", "python"),
            ("function ", "javascript"),
            ("const ", "javascript"),
            ("let ", "javascript"),
            ("var ", "javascript"),
            ("console.log", "javascript"),
            ("public class", "java"),
            ("public static", "java"),
            ("fn ", "rust"),
            ("let mut", "rust"),
            ("use ", "rust"),
            ("package ", "go"),
            ("func ", "go"),
            ("fmt.", "go"),
            ("SELECT ", "sql"),
            ("INSERT ", "sql"),
            ("UPDATE ", "sql"),
            ("DELETE ", "sql"),
            ("CREATE TABLE", "sql"),
            ("<html", "html"),
            ("<div", "html"),
            ("<span", "html"),
            (".class ", "css"),
            ("#id ", "css"),
            ("@media", "css"),
            ("#!/bin/bash", "bash"),
            ("#!/bin/sh", "bash"),
            ("echo ", "bash"),
        ]

        let lowered = code.lowercased()
        for (pattern, lang) in patterns {
            if lowered.contains(pattern.lowercased()) {
                return lang
            }
        }
        return ""
    }
}

// MARK: - Template System

public struct MarkdownTemplate: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let description: String?
    public let contentPattern: String
    public let frontmatterDefaults: [String: String]

    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        contentPattern: String,
        frontmatterDefaults: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.contentPattern = contentPattern
        self.frontmatterDefaults = frontmatterDefaults
    }
}

extension MarkdownBuilder {

    private static let builtInTemplates: [MarkdownTemplate] = [
        MarkdownTemplate(
            id: "default",
            name: "默认笔记",
            description: "标准笔记模板",
            contentPattern: "# {{title}}\n\n{{content}}",
            frontmatterDefaults: ["type": "note"]
        ),
        MarkdownTemplate(
            id: "meeting",
            name: "会议记录",
            description: "会议记录模板",
            contentPattern: "# {{title}}\n\n## 参会人员\n\n- \n\n## 议程\n\n1. \n\n## 决议\n\n- \n\n## 待办\n\n- [ ] ",
            frontmatterDefaults: ["type": "meeting", "status": "draft"]
        ),
        MarkdownTemplate(
            id: "research",
            name: "研究笔记",
            description: "研究笔记模板",
            contentPattern: "# {{title}}\n\n## 摘要\n\n{{summary}}\n\n## 关键发现\n\n- \n\n## 参考资料\n\n- ",
            frontmatterDefaults: ["type": "research"]
        ),
        MarkdownTemplate(
            id: "daily",
            name: "每日记录",
            description: "每日记录模板",
            contentPattern: "# {{title}}\n\n## 今日完成\n\n- \n\n## 明日计划\n\n- \n\n## 备注\n\n",
            frontmatterDefaults: ["type": "daily"]
        )
    ]

    public func listTemplates() -> [MarkdownTemplate] {
        Self.builtInTemplates
    }

    public func applyTemplate(_ template: MarkdownTemplate, to note: DistilledNote) -> String {
        var content = template.contentPattern

        content = content.replacingOccurrences(of: "{{title}}", with: note.title ?? "未命名")
        content = content.replacingOccurrences(of: "{{summary}}", with: note.summary ?? "")
        content = content.replacingOccurrences(of: "{{content}}", with: note.contentMarkdown ?? "")
        content = content.replacingOccurrences(of: "{{category}}", with: note.category ?? "")
        content = content.replacingOccurrences(of: "{{tags}}", with: note.tags.joined(separator: ", "))
        content = content.replacingOccurrences(of: "{{date}}", with: formatDate(note.createdAt))

        var frontmatter = template.frontmatterDefaults
        frontmatter["title"] = note.title ?? ""
        frontmatter["created"] = ISO8601DateFormatter().string(from: note.createdAt)
        if !note.tags.isEmpty {
            frontmatter["tags"] = note.tags.joined(separator: ", ")
        }

        var lines = ["---"]
        for (key, value) in frontmatter.sorted(by: { $0.key < $1.key }) {
            if value.contains(":") || value.contains("#") || value.contains("\"") {
                lines.append("\(key): \"\(value.replacingOccurrences(of: "\"", with: "\\\""))\"")
            } else {
                lines.append("\(key): \(value)")
            }
        }
        lines.append("---")
        lines.append("")

        return lines.joined(separator: "\n") + content
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
