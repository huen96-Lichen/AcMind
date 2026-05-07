import Foundation

// MARK: - Distill Service

/// 蒸馏服务
/// 职责：
/// 1. 单条蒸馏（SourceItem -> DistilledNote）
/// 2. 批量蒸馏（错误隔离）
/// 3. 审核操作
/// 4. 蒸馏任务管理
public final class DistillService: DistillServiceProtocol {
    
    // MARK: - Dependencies
    
    private let aiRuntime: AIRuntimeProtocol
    private let storage: StorageServiceProtocol
    private let taskQueue: TaskQueue
    
    // MARK: - Initialization
    
    public init(
        aiRuntime: AIRuntimeProtocol = AIRuntimeService(),
        storage: StorageServiceProtocol = StorageService(),
        taskQueue: TaskQueue = TaskQueue()
    ) {
        self.aiRuntime = aiRuntime
        self.storage = storage
        self.taskQueue = taskQueue
    }
    
    // MARK: - Single Distill
    
    public func distill(sourceItem: SourceItem) async throws -> DistilledNote {
        // 创建任务
        let job = ProcessJob(
            sourceItemId: sourceItem.id,
            jobType: .distill,
            status: .queued
        )
        
        let jobId = await taskQueue.enqueue(job)
        
        do {
            // 更新任务状态
            try await taskQueue.updateStatus(id: jobId, status: .running)
            
            // 构建蒸馏 prompt
            let messages = buildDistillationPrompt(sourceItem: sourceItem)
            
            // 调用 AI
            let response = try await aiRuntime.chat(messages: messages)
            
            // 解析结果
            let note = parseDistillationResult(
                content: response.content,
                sourceItem: sourceItem
            )
            
            // 保存到数据库
            try await storage.insertDistilledNote(note)
            
            // 更新任务状态
            try await taskQueue.updateStatus(id: jobId, status: .succeeded)
            
            return note
            
        } catch {
            // 更新任务错误
            try? await taskQueue.updateError(id: jobId, error: error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Batch Distill
    
    public func batchDistill(sourceItems: [SourceItem]) async throws -> [DistilledNote] {
        var results: [DistilledNote] = []
        
        // 使用 TaskGroup 实现并发，但错误隔离
        await withTaskGroup(of: DistillResult.self) { group in
            for item in sourceItems {
                group.addTask {
                    do {
                        let note = try await self.distill(sourceItem: item)
                        return DistillResult.success(note)
                    } catch {
                        return DistillResult.failure(item.id, error)
                    }
                }
            }
            
            for await result in group {
                if let note = result.note {
                    results.append(note)
                }
            }
        }
        
        return results
    }
    
    // MARK: - Review
    
    public func review(note: DistilledNote, action: ReviewAction) async throws -> DistilledNote {
        var updatedNote = note
        
        switch action {
        case .approve:
            updatedNote.reviewStatus = .approved
            updatedNote.reviewedAt = Date()
            
        case .reject:
            updatedNote.reviewStatus = .rejected
            updatedNote.reviewedAt = Date()
            
        case .regenerate:
            // 重新蒸馏
            guard let sourceItem = try await storage.getSourceItem(id: note.sourceItemId) else {
                throw DistillError.sourceNotFound
            }
            
            let newNote = try await distill(sourceItem: sourceItem)
            updatedNote = newNote
            updatedNote.reviewStatus = .regenerated
            updatedNote.reviewedAt = Date()
        }
        
        try await storage.updateDistilledNote(updatedNote)
        return updatedNote
    }

    public func review(noteId: String, action: ReviewAction) async throws -> DistilledNote? {
        let notes = try await storage.listDistilledNotes()
        guard let note = notes.first(where: { $0.id == noteId }) else {
            return nil
        }
        return try await review(note: note, action: action)
    }
    
    // MARK: - Prompt Building
    
    private func buildDistillationPrompt(sourceItem: SourceItem) -> [ChatMessage] {
        let systemPrompt = """
        你是一个专业的知识整理助手。请根据用户提供的内容，生成一份结构化的笔记。

        ## 输出格式要求

        请严格按照以下 JSON 格式输出，不要包含任何其他内容：

        ```json
        {
            "title": "简洁的标题",
            "summary": "100字以内的核心要点摘要",
            "category": "分类（如：技术/生活/工作/学习）",
            "tags": ["标签1", "标签2", "标签3"],
            "documentType": "文档类型（如：笔记/教程/总结/清单）",
            "contentMarkdown": "Markdown 格式的详细内容",
            "valueScore": 0.8,
            "cleanSuggestion": "清理建议（可选）"
        }
        ```

        ## 评分标准

        - valueScore: 0.0-1.0，表示内容的价值程度
        - 0.9-1.0: 核心知识，值得长期保存
        - 0.7-0.9: 有价值，可以归档
        - 0.5-0.7: 一般信息，可选择性保存
        - 0.0-0.5: 低价值，建议清理
        """
        
        // 获取内容
        let content = extractContent(sourceItem: sourceItem)
        
        let userPrompt = """
        请整理以下内容：

        ## 来源信息
        - 类型: \(sourceItem.type.displayName)
        - 来源: \(sourceItem.source.displayName)
        - 时间: \(formatDate(sourceItem.createdAt))

        ## 内容
        \(content)
        """
        
        return [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userPrompt)
        ]
    }
    
    private func extractContent(sourceItem: SourceItem) -> String {
        // 优先级：transcript > ocrText > previewText > title
        if let transcript = sourceItem.transcript, !transcript.isEmpty {
            return transcript
        }
        if let ocrText = sourceItem.ocrText, !ocrText.isEmpty {
            return ocrText
        }
        if let previewText = sourceItem.previewText, !previewText.isEmpty {
            return previewText
        }
        return sourceItem.title ?? "(无内容)"
    }
    
    // MARK: - Result Parsing
    
    private func parseDistillationResult(content: String, sourceItem: SourceItem) -> DistilledNote {
        // 尝试解析 JSON
        if let jsonData = extractJSON(from: content).data(using: .utf8),
           let parsed = try? JSONDecoder().decode(DistillationOutput.self, from: jsonData) {
            return DistilledNote(
                sourceItemId: sourceItem.id,
                title: parsed.title,
                summary: parsed.summary,
                category: parsed.category,
                tags: parsed.tags,
                documentType: parsed.documentType,
                contentMarkdown: parsed.contentMarkdown,
                valueScore: parsed.valueScore,
                cleanSuggestion: parsed.cleanSuggestion,
                confidence: 0.9,
                reviewStatus: .pending
            )
        }
        
        // 降级处理：使用原始内容
        return DistilledNote(
            sourceItemId: sourceItem.id,
            title: sourceItem.title ?? "蒸馏结果",
            summary: content.prefix(100).description,
            category: "未分类",
            tags: [],
            documentType: "笔记",
            contentMarkdown: content,
            valueScore: 0.5,
            confidence: 0.5,
            reviewStatus: .pending
        )
    }
    
    private func extractJSON(from text: String) -> String {
        // 尝试提取 ```json ... ``` 块
        if let range = text.range(of: "```json"),
           let endRange = text.range(of: "```", range: text.index(after: range.lowerBound)..<text.endIndex) {
            return String(text[range.upperBound..<endRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 尝试提取 { ... }
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        
        return text
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Models

public struct DistillationOutput: Codable, Sendable {
    public let title: String
    public let summary: String
    public let category: String
    public let tags: [String]
    public let documentType: String
    public let contentMarkdown: String
    public let valueScore: Double?
    public let cleanSuggestion: String?
}

public enum DistillResult: Sendable, Equatable {
    case success(DistilledNote)
    case failure(String, Error)
    
    public var note: DistilledNote? {
        if case .success(let note) = self { return note }
        return nil
    }
    
    public var error: Error? {
        if case .failure(_, let error) = self { return error }
        return nil
    }
    
    public var sourceItemId: String? {
        switch self {
        case .success(let note): return note.sourceItemId
        case .failure(let id, _): return id
        }
    }

    public static func == (lhs: DistillResult, rhs: DistillResult) -> Bool {
        switch (lhs, rhs) {
        case let (.success(left), .success(right)):
            return left == right
        case let (.failure(leftId, leftError), .failure(rightId, rightError)):
            return leftId == rightId && String(describing: leftError) == String(describing: rightError)
        default:
            return false
        }
    }
}

// MARK: - Errors

public enum DistillError: Error, LocalizedError {
    case sourceNotFound
    case aiFailed(String)
    case parseFailed
    case saveFailed
    
    public var errorDescription: String? {
        switch self {
        case .sourceNotFound:
            return "源内容未找到"
        case .aiFailed(let message):
            return "AI 处理失败: \(message)"
        case .parseFailed:
            return "结果解析失败"
        case .saveFailed:
            return "保存失败"
        }
    }
}

// MARK: - ChatMessage Helper

extension ChatMessage {
    public init(role: String, content: String) {
        self.init(
            sessionId: "distill",
            role: role == "system" ? .system : (role == "assistant" ? .assistant : .user),
            content: content
        )
    }
}
