import Foundation

// MARK: - Export Service

/// 导出服务
/// 职责：
/// 1. 导出 DistilledNote 到 Vault
/// 2. 冲突处理（覆盖/重命名/跳过）
/// 3. 批量导出（错误隔离）
/// 4. 导出记录管理
public actor ExportService: ExportServiceProtocol {
    
    // MARK: - Dependencies
    
    private let storage: StorageServiceProtocol
    private let markdownBuilder = ExportMarkdownBuilder()
    
    // MARK: - State
    
    private var exportRecords: [String: ExportRecord] = [:]
    
    // MARK: - Initialization
    
    public init(
        storage: StorageServiceProtocol = StorageService()
    ) {
        self.storage = storage
    }
    
    // MARK: - Single Export
    
    public func export(note: DistilledNote, config: ExportConfig) async throws -> ExportRecord {
        // 验证 Vault 路径
        guard let vaultPath = config.vaultPath else {
            throw ExportError.noVault
        }
        
        guard FileManager.default.fileExists(atPath: vaultPath) else {
            throw ExportError.vaultNotFound(vaultPath)
        }
        
        // 构建 Markdown
        let markdown = markdownBuilder.build(
            note: note,
            includeFrontmatter: config.autoFrontmatter,
            frontmatterTemplate: config.frontmatterTemplate
        )
        
        // 计算导出路径
        let relativePath = buildRelativePath(note: note, config: config)
        let absolutePath = (vaultPath as NSString).appendingPathComponent(relativePath)
        
        // 处理冲突
        let finalPath = try await resolveConflict(path: absolutePath, strategy: config.conflictStrategy)
        
        // 确保目录存在
        let directory = (finalPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        
        // 写入文件
        do {
            try markdown.write(toFile: finalPath, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
        
        // 创建导出记录
        let finalRelativePath = self.relativePath(from: vaultPath, absolutePath: finalPath)

        let record = ExportRecord(
            sourceItemId: note.sourceItemId,
            distilledOutputId: note.id,
            vaultPath: vaultPath,
            relativeFilePath: finalRelativePath,
            frontmatter: buildFrontmatterDict(note: note, config: config),
            status: .success,
            conflictResolution: absolutePath != finalPath ? config.conflictStrategy : nil
        )
        
        // 保存记录
        exportRecords[record.id] = record
        try? await storage.insertExportRecord(record)
        if let data = try? JSONEncoder().encode(Array(exportRecords.values)),
           let json = String(data: data, encoding: .utf8) {
            try? await storage.setSetting(key: "export_records", value: json)
        }

        return record
    }
    
    public func export(note: DistilledNote, sourceItem: SourceItem, config: ExportConfig) async throws -> ExportRecord {
        // 验证 Vault 路径
        guard let vaultPath = config.vaultPath else {
            throw ExportError.noVault
        }
        
        guard FileManager.default.fileExists(atPath: vaultPath) else {
            throw ExportError.vaultNotFound(vaultPath)
        }
        
        // 构建 Markdown（包含来源信息）
        let markdown = markdownBuilder.build(
            note: note,
            sourceItem: sourceItem,
            includeFrontmatter: config.autoFrontmatter,
            frontmatterTemplate: config.frontmatterTemplate
        )
        
        // 计算导出路径
        let relativePath = buildRelativePath(note: note, sourceItem: sourceItem, config: config)
        let absolutePath = (vaultPath as NSString).appendingPathComponent(relativePath)
        
        // 处理冲突
        let finalPath = try await resolveConflict(path: absolutePath, strategy: config.conflictStrategy)
        
        // 确保目录存在
        let directory = (finalPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        
        // 写入文件
        do {
            try markdown.write(toFile: finalPath, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
        
        // 创建导出记录
        let finalRelativePath = self.relativePath(from: vaultPath, absolutePath: finalPath)

        let record = ExportRecord(
            sourceItemId: note.sourceItemId,
            distilledOutputId: note.id,
            vaultPath: vaultPath,
            relativeFilePath: finalRelativePath,
            frontmatter: buildFrontmatterDict(note: note, sourceItem: sourceItem, config: config),
            status: .success,
            conflictResolution: absolutePath != finalPath ? config.conflictStrategy : nil
        )
        
        exportRecords[record.id] = record
        try? await storage.insertExportRecord(record)
        if let data = try? JSONEncoder().encode(Array(exportRecords.values)),
           let json = String(data: data, encoding: .utf8) {
            try? await storage.setSetting(key: "export_records", value: json)
        }

        return record
    }
    
    // MARK: - Batch Export
    
    public func exportBatch(notes: [DistilledNote], config: ExportConfig) async throws -> [ExportRecord] {
        var results: [ExportRecord] = []
        
        await withTaskGroup(of: ExportRecord?.self) { group in
            for note in notes {
                group.addTask {
                    try? await self.export(note: note, config: config)
                }
            }
            
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
        }
        
        return results
    }
    
    public func exportBatch(
        notes: [(note: DistilledNote, sourceItem: SourceItem)],
        config: ExportConfig
    ) async throws -> [ExportRecord] {
        var results: [ExportRecord] = []
        
        await withTaskGroup(of: ExportRecord?.self) { group in
            for (note, sourceItem) in notes {
                group.addTask {
                    try? await self.export(note: note, sourceItem: sourceItem, config: config)
                }
            }
            
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
        }
        
        return results
    }
    
    // MARK: - Preview
    
    public func preview(note: DistilledNote, config: ExportConfig) async throws -> String {
        markdownBuilder.build(
            note: note,
            includeFrontmatter: config.autoFrontmatter,
            frontmatterTemplate: config.frontmatterTemplate
        )
    }
    
    // MARK: - Conflict Resolution
    
    public func resolveConflict(path: String, strategy: ConflictStrategy) async throws -> String {
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: path) else {
            return path // 无冲突，直接返回
        }
        
        switch strategy {
        case .overwrite:
            // 删除现有文件
            try FileManager.default.removeItem(atPath: path)
            return path
            
        case .rename:
            // 生成新文件名
            return generateRenamedPath(originalPath: path)
            
        case .skip:
            // 抛出错误让调用者知道被跳过
            throw ExportError.conflictSkipped(path)
        }
    }
    
    private func generateRenamedPath(originalPath: String) -> String {
        let directory = (originalPath as NSString).deletingLastPathComponent
        let fileName = (originalPath as NSString).lastPathComponent
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        
        var counter = 1
        var newPath = originalPath
        
        while FileManager.default.fileExists(atPath: newPath) {
            let newName = "\(nameWithoutExt) (\(counter))"
            newPath = (directory as NSString).appendingPathComponent("\(newName).\(ext)")
            counter += 1
        }
        
        return newPath
    }
    
    // MARK: - Path Building
    
    private func buildRelativePath(note: DistilledNote, config: ExportConfig) -> String {
        let fileName = sanitizeFileName(note.title ?? "Untitled")
        
        switch config.pathRule {
        case .flat:
            return "\(config.defaultFolder)/\(fileName).md"
            
        case .categoryDate:
            let category = note.category ?? "未分类"
            let datePath = formatDatePath(note.createdAt)
            return "\(config.defaultFolder)/\(category)/\(datePath)/\(fileName).md"
            
        case .sourceType:
            let folder = note.documentType ?? "笔记"
            return "\(config.defaultFolder)/\(folder)/\(fileName).md"
        }
    }
    
    private func buildRelativePath(note: DistilledNote, sourceItem: SourceItem, config: ExportConfig) -> String {
        let fileName = sanitizeFileName(note.title ?? sourceItem.title ?? "Untitled")
        
        switch config.pathRule {
        case .flat:
            return "\(config.defaultFolder)/\(fileName).md"
            
        case .categoryDate:
            let category = note.category ?? "未分类"
            let datePath = formatDatePath(sourceItem.createdAt)
            return "\(config.defaultFolder)/\(category)/\(datePath)/\(fileName).md"
            
        case .sourceType:
            let folder = sourceItem.type.displayName
            return "\(config.defaultFolder)/\(folder)/\(fileName).md"
        }
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        // 移除不允许的字符
        let invalidChars = CharacterSet(charactersIn: "/:\\*?\"<>|")
        var sanitized = name.components(separatedBy: invalidChars).joined(separator: "_")
        
        // 限制长度
        if sanitized.count > 100 {
            sanitized = String(sanitized.prefix(100))
        }
        
        return sanitized.trimmingCharacters(in: .whitespaces)
    }

    private func relativePath(from vaultPath: String, absolutePath: String) -> String {
        let vaultURL = URL(fileURLWithPath: vaultPath)
        let absoluteURL = URL(fileURLWithPath: absolutePath)

        let vaultComponents = vaultURL.standardizedFileURL.pathComponents
        let absoluteComponents = absoluteURL.standardizedFileURL.pathComponents

        guard absoluteComponents.starts(with: vaultComponents),
              absoluteComponents.count > vaultComponents.count else {
            return absoluteURL.lastPathComponent
        }

        return absoluteComponents.dropFirst(vaultComponents.count).joined(separator: "/")
    }
    
    private func formatDatePath(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM"
        return formatter.string(from: date)
    }
    
    // MARK: - Frontmatter Dict
    
    private func buildFrontmatterDict(note: DistilledNote, config: ExportConfig) -> [String: String] {
        var dict: [String: String] = [
            "title": note.title ?? "",
            "created": ISO8601DateFormatter().string(from: note.createdAt),
            "tags": note.tags.joined(separator: ", "),
            "category": note.category ?? ""
        ]
        
        if let score = note.valueScore {
            dict["value_score"] = String(score)
        }

        for (key, value) in config.frontmatterTemplate {
            dict[key] = value
        }

        return dict
    }

    private func buildFrontmatterDict(note: DistilledNote, sourceItem: SourceItem, config: ExportConfig) -> [String: String] {
        var dict = buildFrontmatterDict(note: note, config: config)

        dict["source_type"] = sourceItem.type.rawValue
        dict["source_id"] = sourceItem.id

        if let url = sourceItem.originalUrl {
            dict["source_url"] = url
        }

        if let app = sourceItem.sourceApp {
            dict["source_app"] = app
        }

        for (key, value) in config.frontmatterTemplate {
            dict[key] = value
        }

        return dict
    }
    
    // MARK: - Records
    
    public func listExportRecords() async throws -> [ExportRecord] {
        if exportRecords.isEmpty {
            if let stored = try? await storage.getSetting(key: "export_records"),
               let data = stored.data(using: .utf8),
               let records = try? JSONDecoder().decode([ExportRecord].self, from: data) {
                for record in records {
                    exportRecords[record.id] = record
                }
            }
        }
        return Array(exportRecords.values).sorted { $0.exportedAt > $1.exportedAt }
    }
    
    public func getExportRecord(id: String) async throws -> ExportRecord? {
        exportRecords[id]
    }
}

// MARK: - Models

public enum ExportResult: Sendable {
    case success(ExportRecord)
    case failure(String, Error)
}

// MARK: - Errors

public enum ExportError: Error, LocalizedError {
    case noVault
    case vaultNotFound(String)
    case writeFailed(String)
    case conflictSkipped(String)
    case invalidPath
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .noVault:
            return "未配置 Vault 路径"
        case .vaultNotFound(let path):
            return "Vault 路径不存在: \(path)"
        case .writeFailed(let message):
            return "写入失败: \(message)"
        case .conflictSkipped(let path):
            return "文件已存在，已跳过: \(path)"
        case .invalidPath:
            return "无效的路径"
        case .permissionDenied:
            return "权限不足"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .noVault:
            return "请在设置中配置 Vault 路径"
        case .vaultNotFound:
            return "请检查 Vault 路径是否正确"
        case .writeFailed:
            return "请检查磁盘空间和写入权限"
        case .conflictSkipped:
            return "如需覆盖，请更改冲突策略"
        case .invalidPath:
            return "请检查文件名是否包含非法字符"
        case .permissionDenied:
            return "请授予文件访问权限"
        }
    }
}

// MARK: - Local Markdown Builder

private struct ExportMarkdownBuilder {
    func build(note: DistilledNote, includeFrontmatter: Bool = true, frontmatterTemplate: [String: String] = [:]) -> String {
        buildMarkdown(note: note, sourceItem: nil, includeFrontmatter: includeFrontmatter, frontmatterTemplate: frontmatterTemplate)
    }

    func build(note: DistilledNote, sourceItem: SourceItem, includeFrontmatter: Bool = true, frontmatterTemplate: [String: String] = [:]) -> String {
        buildMarkdown(note: note, sourceItem: sourceItem, includeFrontmatter: includeFrontmatter, frontmatterTemplate: frontmatterTemplate)
    }

    private func buildMarkdown(
        note: DistilledNote,
        sourceItem: SourceItem?,
        includeFrontmatter: Bool,
        frontmatterTemplate: [String: String]
    ) -> String {
        var parts: [String] = []
        if includeFrontmatter {
            parts.append(buildFrontmatter(note: note, sourceItem: sourceItem, frontmatterTemplate: frontmatterTemplate))
        }
        if let title = note.title, !title.isEmpty {
            parts.append("# \(title)")
        }
        if let summary = note.summary, !summary.isEmpty {
            parts.append("> [!summary] 摘要\n> \(summary)")
        }
        if !note.tags.isEmpty {
            parts.append("标签: " + note.tags.map { "#\($0)" }.joined(separator: " "))
        }
        if let sourceItem {
            parts.append(buildSourceInfo(sourceItem: sourceItem))
        }
        if let content = note.contentMarkdown, !content.isEmpty {
            parts.append(content)
        }
        return parts.joined(separator: "\n\n")
    }

    private func buildFrontmatter(note: DistilledNote, sourceItem: SourceItem?, frontmatterTemplate: [String: String]) -> String {
        var lines = ["---"]
        let pairs: [(String, String)] = [
            ("title", note.title ?? ""),
            ("created", ISO8601DateFormatter().string(from: note.createdAt)),
            ("category", note.category ?? ""),
            ("document_type", note.documentType ?? ""),
            ("value_score", note.valueScore.map { String($0) } ?? ""),
            ("review_status", note.reviewStatus.rawValue)
        ] + (sourceItem.map { [
            ("source_type", $0.type.rawValue),
            ("source_origin", $0.source.rawValue),
            ("source_id", $0.id)
        ] } ?? [])

        let customPairs = frontmatterTemplate.map { ($0.key, $0.value) }
        let mergedPairs = pairs + customPairs

        for (key, value) in mergedPairs where !value.isEmpty {
            lines.append("\(key): \(escape(value))")
        }
        lines.append("---")
        return lines.joined(separator: "\n")
    }

    private func buildSourceInfo(sourceItem: SourceItem) -> String {
        var lines = ["> [!info] 来源信息"]
        lines.append("> - 类型: \(sourceItem.type.displayName)")
        lines.append("> - 来源: \(sourceItem.source.displayName)")
        lines.append("> - 时间: \(formatDate(sourceItem.createdAt))")
        if let url = sourceItem.originalUrl {
            lines.append("> - URL: \(url)")
        }
        if let app = sourceItem.sourceApp {
            lines.append("> - 应用: \(app)")
        }
        return lines.joined(separator: "\n")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func escape(_ value: String) -> String {
        value.contains(":") || value.contains("#") || value.contains("\"")
            ? "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
            : value
    }
}
