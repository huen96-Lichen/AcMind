import Foundation

public struct NativeAIPipelineResult: Sendable, Equatable {
    public var sourceItem: SourceItem
    public var note: DistilledNote?
    public var exportRecord: ExportRecord?
    public var response: AIResponse

    public init(
        sourceItem: SourceItem,
        note: DistilledNote?,
        exportRecord: ExportRecord?,
        response: AIResponse
    ) {
        self.sourceItem = sourceItem
        self.note = note
        self.exportRecord = exportRecord
        self.response = response
    }
}

/// Orchestrates native AcMind AI tasks without coupling OCR, speech, cleanup, and export.
public final class NativeAIPipelineService: @unchecked Sendable {
    private let storage: StorageServiceProtocol
    private let exportService: ExportServiceProtocol
    private let router: TaskRouter
    private let visionProvider: any AIModelProvider
    private let speechProvider: any AIModelProvider
    private let cleanupProvider: any AIModelProvider

    public init(
        storage: StorageServiceProtocol = StorageService(),
        exportService: ExportServiceProtocol = ExportService(),
        router: TaskRouter = TaskRouter(),
        visionProvider: any AIModelProvider = AppleVisionOCRProvider(),
        speechProvider: any AIModelProvider = AppleSpeechProvider(),
        cleanupProvider: any AIModelProvider = RuleBasedCleanupProvider()
    ) {
        self.storage = storage
        self.exportService = exportService
        self.router = router
        self.visionProvider = visionProvider
        self.speechProvider = speechProvider
        self.cleanupProvider = cleanupProvider
    }

    @discardableResult
    public func process(sourceItem: SourceItem, exportConfig: ExportConfig? = nil) async throws -> NativeAIPipelineResult {
        var workingItem = sourceItem
        let route = router.route(sourceItem: workingItem)
        let recognitionResponse: AIResponse?

        switch route.taskType {
        case .imageOCR:
            recognitionResponse = try await visionProvider.run(router.makeRequest(for: workingItem))
            workingItem.ocrText = recognitionResponse?.text
            workingItem.previewText = recognitionResponse?.text.prefix(500).description
            workingItem.status = .parsed

        case .speechToText:
            recognitionResponse = try await speechProvider.run(router.makeRequest(for: workingItem))
            workingItem.transcript = recognitionResponse?.text
            workingItem.previewText = recognitionResponse?.text.prefix(500).description
            workingItem.status = .parsed

        default:
            recognitionResponse = nil
        }

        let cleanupRequest = AIRequest(
            taskType: route.taskType == .summarize ? .summarize : .textCleanup,
            sourceItemId: workingItem.id,
            inputText: workingItem.bestProcessableText,
            fileURL: workingItem.contentPath.map(URL.init(fileURLWithPath:)),
            metadata: workingItem.metadata.merging([
                AIMetadataKey.taskType: AITaskType.textCleanup.rawValue,
                AIMetadataKey.outputType: route.outputType.rawValue
            ]) { _, new in new }
        )

        let cleanupResponse = try await cleanupProvider.run(cleanupRequest)
        workingItem = workingItem.withAIMetadata(
            taskType: cleanupResponse.taskType,
            providerId: cleanupResponse.providerId,
            outputType: cleanupResponse.outputType,
            category: cleanupResponse.category,
            requiresUserConsent: false
        )
        workingItem.tags = Array(Set(workingItem.tags + cleanupResponse.tags)).sorted()
        workingItem.status = .distilled

        let note = cleanupResponse.makeDistilledNote(sourceItem: workingItem)
        try await storage.insertDistilledNote(note)
        try await storage.updateSourceItem(workingItem)

        let exportRecord: ExportRecord?
        if let exportConfig {
            exportRecord = try await exportService.export(note: note, config: exportConfig)
        } else {
            exportRecord = nil
        }

        return NativeAIPipelineResult(
            sourceItem: workingItem,
            note: note,
            exportRecord: exportRecord,
            response: recognitionResponse ?? cleanupResponse
        )
    }

    public func createDailyReview(
        for date: Date = Date(),
        vaultPath: String,
        calendar: Calendar = .current
    ) async throws -> URL {
        guard !vaultPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.invalidInput("日报生成需要 Vault 路径")
        }

        let allItems = try await storage.listSourceItems(filter: nil)
        let todayItems = allItems.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
        let markdown = buildDailyReviewMarkdown(items: todayItems, date: date)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "\(formatter.string(from: date)).md"
        let directory = URL(fileURLWithPath: vaultPath)
            .appendingPathComponent("03_Reviews", isDirectory: true)
            .appendingPathComponent("Daily", isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(fileName)
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    public func registerDailyReviewTask(
        name: String = "每日 AcMind 日报",
        cronExpression: String,
        vaultPath: String,
        enabled: Bool = false
    ) async throws -> ScheduledAgentTask {
        let task = ScheduledAgentTask(
            name: name,
            cronExpression: cronExpression,
            skillName: "acmind.dailyReview",
            inputParams: [
                "vaultPath": vaultPath,
                "outputPath": "03_Reviews/Daily",
                "requiresUserConsent": "true"
            ],
            enabled: enabled
        )
        try await storage.insertScheduledAgentTask(task)
        return task
    }

    public func setScheduledTask(_ task: ScheduledAgentTask, enabled: Bool) async throws -> ScheduledAgentTask {
        var updated = task
        updated.enabled = enabled
        updated.updatedAt = Date()
        try await storage.insertScheduledAgentTask(updated)
        return updated
    }

    public func deleteScheduledTask(id: String) async throws {
        try await storage.deleteScheduledAgentTask(id: id)
    }

    private func buildDailyReviewMarkdown(items: [SourceItem], date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let completed = items.filter { $0.status == .exported || $0.status == .distilled }
        let tasks = items.filter { $0.metadata[AIMetadataKey.inboxCategory] == InboxCategory.task.rawValue }
        let ideas = items.filter { $0.metadata[AIMetadataKey.inboxCategory] == InboxCategory.idea.rawValue }

        return """
        # \(dateString) 日报

        ## 今日完成
        \(bulletList(completed, fallback: "暂无已整理内容"))

        ## 今日收集
        \(bulletList(items, fallback: "暂无收集内容"))

        ## 重要想法
        \(bulletList(ideas, fallback: "暂无标记想法"))

        ## 未完成任务
        \(tasks.isEmpty ? "暂无待办" : tasks.map { "- [ ] \($0.title ?? $0.bestProcessableText)" }.joined(separator: "\n"))

        ## 明日建议
        - 从收集箱中挑选 1-3 条高价值内容继续整理。
        - 优先处理仍处于待确认或待处理状态的内容。

        ## 值得复盘的问题
        - 今天哪些零散信息值得沉淀为长期知识？
        - 哪些任务需要明确下一步行动和提醒时间？
        """
    }

    private func bulletList(_ items: [SourceItem], fallback: String) -> String {
        guard !items.isEmpty else { return fallback }
        return items.map { item in
            let title = item.title ?? item.bestProcessableText
            let source = item.source.displayName
            return "- \(title)（\(source)）"
        }.joined(separator: "\n")
    }
}
