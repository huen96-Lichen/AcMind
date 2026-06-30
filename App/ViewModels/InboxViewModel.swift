import Foundation
import AppKit
import AcMindKit
import UniformTypeIdentifiers

@MainActor
class InboxViewModel: ObservableObject {
    private static let logger = AcMindLogger(category: .storage)
    // MARK: - Published Properties
    
    @Published var items: [SourceItem] = []
    @Published var statusFilter: SourceItemStatus?
    @Published var selectedItem: SourceItem?
    @Published var markdownPreview: String?
    @Published var searchQuery: String = "" {
        didSet { if !searchQuery.isEmpty { Task { await searchItems() } } }
    }
    
    // 统计
    @Published var todayCount: Int = 0
    @Published var pendingCount: Int = 0
    @Published var distilledCount: Int = 0
    @Published var exportedCount: Int = 0
    
    // 状态
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Dependencies

    private let storage: StorageServiceProtocol
    private let exportService: ExportServiceProtocol
    private let distillService: DistillServiceProtocol
    private let knowledgeService: KnowledgeServiceProtocol
    private let previewScenario: AcWorkPreviewScenario?
    
    // MARK: - Init
    
    init(
        storage: StorageServiceProtocol? = nil,
        exportService: ExportServiceProtocol? = nil,
        distillService: DistillServiceProtocol? = nil,
        knowledgeService: KnowledgeServiceProtocol? = nil,
        previewScenario: AcWorkPreviewScenario? = nil
    ) {
        self.storage = storage ?? StorageService()
        self.exportService = exportService ?? ExportService()
        self.distillService = distillService ?? DistillService(storage: self.storage)
        self.knowledgeService = knowledgeService ?? KnowledgeService(storage: self.storage)
#if DEBUG
        self.previewScenario = previewScenario ?? DebugAcWorkPreviewScenario.resolve()
#else
        self.previewScenario = previewScenario
#endif
    }
    
    // MARK: - Load
    
    func loadItems() async {
        if let previewScenario {
            applyPreviewScenario(previewScenario)
            return
        }

        isLoading = true
        defer { isLoading = false }
        
        do {
            let filter = SourceItemFilter(status: statusFilter)
            items = try await storage.listSourceItems(filter: filter)
            await computeStats()
            errorMessage = nil
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func refresh() async {
        await loadItems()
    }
    
    // MARK: - Search
    
    func searchItems() async {
        guard !searchQuery.isEmpty else {
            await loadItems()
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let query = searchQuery.lowercased()
            let all = try await storage.listSourceItems(filter: nil)
            items = all.filter { item in
                let titleMatch = item.title?.lowercased().contains(query) ?? false
                let previewMatch = item.previewText?.lowercased().contains(query) ?? false
                let transcriptMatch = item.transcript?.lowercased().contains(query) ?? false
                let ocrMatch = item.ocrText?.lowercased().contains(query) ?? false
                let tagMatch = item.tags.contains { $0.lowercased().contains(query) }
                return titleMatch || previewMatch || transcriptMatch || ocrMatch || tagMatch
            }
        } catch {
            errorMessage = "搜索失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Select
    
    func selectItem(_ item: SourceItem?) {
        selectedItem = item
        markdownPreview = nil
    }
    
    // MARK: - Delete
    
    func delete(item: SourceItem) async {
        do {
            try await storage.deleteSourceItem(id: item.id)
            if selectedItem?.id == item.id {
                selectedItem = nil
                markdownPreview = nil
            }
            await loadItems()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
            showError = true
        }
    }

    func archive(item: SourceItem) async {
        do {
            var updated = item
            updated.status = .archived
            try await storage.updateSourceItem(updated)
            if selectedItem?.id == item.id {
                selectedItem = updated
            }
            await loadItems()
        } catch {
            errorMessage = "归档失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Distill
    
    func distillItem(_ item: SourceItem) async {
        do {
            let note = try await distillService.distill(sourceItem: item)
            
            // 更新 SourceItem 状态
            var updated = item
            updated.status = .distilled
            try await storage.updateSourceItem(updated)
            
            // 生成 Markdown 预览
            let builder = InboxMarkdownBuilder()
            markdownPreview = builder.build(note: note, sourceItem: item)
            
            await loadItems()
        } catch {
            errorMessage = "蒸馏失败: \(error.localizedDescription)"
            showError = true
        }
    }

    func moveToWorkbench(item: SourceItem) async {
        await distillItem(item)
        AppState.shared.navigate(to: .workbench)
    }

    func sendToKnowledgeBase(item: SourceItem) async {
        do {
            if item.status != .distilled && item.status != .exported {
                await distillItem(item)
            }

            let notes = try await storage.listDistilledNotes()
            guard let note = notes.first(where: { $0.sourceItemId == item.id }) else {
                throw NSError(domain: "InboxViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到可发送的蒸馏笔记"])
            }

            _ = try await knowledgeService.createCard(from: note)
            AppState.shared.navigate(to: .agent)
        } catch {
            errorMessage = "发送到知识库失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Markdown Preview
    
    func generateMarkdownPreview() async {
        guard let item = selectedItem else { return }
        
        // 如果已有蒸馏结果，使用蒸馏内容
        if item.status == .distilled || item.status == .exported {
            do {
                let notes = try await storage.listDistilledNotes().filter { $0.sourceItemId == item.id }
                if let note = notes.first {
                    let builder = InboxMarkdownBuilder()
                    markdownPreview = builder.build(note: note, sourceItem: item)
                    return
                }
            } catch {}
        }
        
        // 兼容路径：使用原始内容生成预览
        let md = """
        # \(item.title ?? "未命名")

        > 来源：\(item.source.displayName) · \(formatDate(item.createdAt))

        ---

        \(item.previewText ?? item.transcript ?? item.ocrText ?? "无内容")

        ---

        *点击「AI 蒸馏」生成结构化笔记*
        """
        markdownPreview = md
    }
    
    // MARK: - Open in Vault
    
    func openInVault(item: SourceItem) async {
        // 查找关联的导出记录
        do {
            let records = try await exportService.listExportRecords()
            let matched = records.filter { $0.sourceItemId == item.id }
            if let record = matched.first, !record.vaultPath.isEmpty {
                let fullPath = (record.vaultPath as NSString).appendingPathComponent(record.relativeFilePath)
                if FileManager.default.fileExists(atPath: fullPath) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: fullPath))
                    return
                }
            }
        } catch {}
        
        errorMessage = "未找到关联的 Vault 文件"
        showError = true
    }
    
    // MARK: - Private
    
    private func computeStats() async {
        do {
            let all = try await storage.listSourceItems(filter: nil)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            todayCount = all.filter { calendar.isDate($0.createdAt, inSameDayAs: today) }.count
            pendingCount = all.filter { $0.status == .pending || $0.status == .captured }.count
            distilledCount = all.filter { $0.status == .distilled }.count
            exportedCount = all.filter { $0.status == .exported }.count
        } catch {
            Self.logger.error("Failed to compute stats: \(error)")
        }
    }

    private func applyPreviewScenario(_ scenario: AcWorkPreviewScenario) {
        #if DEBUG
        items = AcWorkPreviewData.inboxItems(for: scenario)
        todayCount = items.count
        pendingCount = items.filter { $0.status == .pending || $0.status == .captured }.count
        distilledCount = items.filter { $0.status == .distilled }.count
        exportedCount = items.filter { $0.status == .exported }.count

        switch scenario {
        case .populated, .empty:
            isLoading = false
            errorMessage = nil
            showError = false
        case .loading:
            isLoading = true
            errorMessage = nil
            showError = false
        case .error:
            isLoading = false
            errorMessage = "AcWork 预览：收集箱加载失败"
            showError = true
        }
        #else
        items = []
        todayCount = 0
        pendingCount = 0
        distilledCount = 0
        exportedCount = 0
        isLoading = false
        errorMessage = nil
        showError = false
        #endif
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

private struct InboxMarkdownBuilder {
    func build(note: DistilledNote) -> String {
        note.contentMarkdown ?? ""
    }

    func build(note: DistilledNote, sourceItem: SourceItem) -> String {
        var parts: [String] = []
        parts.append("# \(note.title ?? sourceItem.title ?? "未命名")")
        parts.append("> 来源：\(sourceItem.source.displayName) · \(sourceItem.createdAt.formatted(date: .abbreviated, time: .shortened))")
        if let summary = note.summary, !summary.isEmpty {
            parts.append("## 摘要\n\n\(summary)")
        }
        if let content = note.contentMarkdown, !content.isEmpty {
            parts.append(content)
        } else if let preview = sourceItem.previewText, !preview.isEmpty {
            parts.append(preview)
        }
        return parts.joined(separator: "\n\n")
    }
}

enum CollectedItemWorkflowAction: String, CaseIterable {
    case sendToAgent
    case createTask
    case createSchedule
    case saveToKnowledge
    case exportMarkdown

    var title: String {
        switch self {
        case .sendToAgent: return "发送给智能体"
        case .createTask: return "转任务"
        case .createSchedule: return "添加到日程"
        case .saveToKnowledge: return "保存到知识库"
        case .exportMarkdown: return "导出 Markdown"
        }
    }
}

struct CollectedItemWorkflowFeedback: Equatable {
    let actionTitle: String
    let message: String
    let isError: Bool
}

@MainActor
final class CollectedItemWorkflowCoordinator: ObservableObject {
    @Published private(set) var isPerforming = false
    @Published private(set) var feedback: CollectedItemWorkflowFeedback?
    @Published private(set) var activeAIAction: CollectedItemAIAction?
    @Published private(set) var activeItemID: CollectedItemID?

    func perform(_ action: CollectedItemWorkflowAction, item: CollectedItem) async {
        isPerforming = true
        defer { isPerforming = false }

        do {
            let message = try await execute(action, item: item)
            feedback = CollectedItemWorkflowFeedback(actionTitle: action.title, message: message, isError: false)
        } catch {
            feedback = CollectedItemWorkflowFeedback(
                actionTitle: action.title,
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    func performBatch(_ action: CollectedItemWorkflowAction, items: [CollectedItem]) async {
        guard items.isEmpty == false else { return }
        isPerforming = true
        defer { isPerforming = false }

        if action == .exportMarkdown {
            do {
                let directory = try selectExportDirectory()
                var failureMessages: [String] = []
                for item in items {
                    do {
                        try writeMarkdown(for: item, to: directory)
                    } catch {
                        failureMessages.append("\(item.workflowTitle)：\(error.localizedDescription)")
                    }
                }
                setBatchFeedback(action: action, total: items.count, failureMessages: failureMessages)
            } catch {
                feedback = CollectedItemWorkflowFeedback(
                    actionTitle: action.title,
                    message: error.localizedDescription,
                    isError: true
                )
            }
            return
        }

        var failureMessages: [String] = []
        for item in items {
            do {
                _ = try await execute(action, item: item, shouldNavigate: false)
            } catch {
                failureMessages.append("\(item.workflowTitle)：\(error.localizedDescription)")
            }
        }
        setBatchFeedback(action: action, total: items.count, failureMessages: failureMessages)

        if failureMessages.count < items.count {
            navigateAfterWorkflow(action)
        }
    }

    func performAI(
        _ action: CollectedItemAIAction,
        item: CollectedItem,
        applyResult: @escaping (CollectedItemAIResult, CollectedItemID) async throws -> Void
    ) async {
        guard ServiceContainer.isInitialized() else {
            feedback = CollectedItemWorkflowFeedback(
                actionTitle: action.title,
                message: CollectedItemWorkflowError.servicesUnavailable.localizedDescription,
                isError: true
            )
            return
        }

        isPerforming = true
        activeAIAction = action
        activeItemID = item.id
        defer {
            isPerforming = false
            activeAIAction = nil
            activeItemID = nil
        }

        do {
            let response = try await ServiceContainer.shared.aiRuntime.chat(
                messages: item.aiMessages(for: action)
            )
            let result = try CollectedItemAIResult.parse(response.content)
            let message = try await applyAIResult(
                result,
                action: action,
                item: item,
                persist: applyResult
            )
            feedback = CollectedItemWorkflowFeedback(actionTitle: action.title, message: message, isError: false)
        } catch {
            feedback = CollectedItemWorkflowFeedback(
                actionTitle: action.title,
                message: error.localizedDescription,
                isError: true
            )
        }
    }

    func clearFeedback() {
        feedback = nil
    }

    private func execute(
        _ action: CollectedItemWorkflowAction,
        item: CollectedItem,
        shouldNavigate: Bool = true
    ) async throws -> String {
        guard ServiceContainer.isInitialized() else {
            throw CollectedItemWorkflowError.servicesUnavailable
        }
        let services = ServiceContainer.shared

        switch action {
        case .sendToAgent:
            let task = try await services.agentTaskBoardService.createTask(item.makeAgentTask())
            try await services.agentTaskBoardService.startTask(id: task.id)
            if shouldNavigate { navigateAfterWorkflow(action) }
            return "已创建并启动智能体任务「\(task.title)」"
        case .createTask:
            let task = try await services.agentTaskBoardService.createTask(item.makeAgentTask())
            if shouldNavigate { navigateAfterWorkflow(action) }
            return "已加入任务看板「\(task.title)」"
        case .createSchedule:
            let event = item.makeScheduleEvent()
            try await services.scheduleService.createEvent(event)
            if shouldNavigate { navigateAfterWorkflow(action) }
            return "已创建日程，开始时间 \(event.startAt.formatted(date: .omitted, time: .shortened))"
        case .saveToKnowledge:
            let card = try await services.knowledgeService.createCard(from: item.makeDistilledNote())
            return "已保存知识卡片「\(card.canonicalTitle.isEmpty ? item.workflowTitle : card.canonicalTitle)」"
        case .exportMarkdown:
            let destination = try selectMarkdownDestination(for: item)
            try item.workflowMarkdown.write(to: destination, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            return "已导出到 \(destination.lastPathComponent)"
        }
    }

    private func applyAIResult(
        _ result: CollectedItemAIResult,
        action: CollectedItemAIAction,
        item: CollectedItem,
        persist: (CollectedItemAIResult, CollectedItemID) async throws -> Void
    ) async throws -> String {
        switch action {
        case .generateTitle:
            guard result.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw CollectedItemAIError.emptyResult
            }
            try await persist(result, item.id)
            return "标题已更新为「\(result.title ?? "")」"
        case .summarize:
            guard result.summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw CollectedItemAIError.emptyResult
            }
            try await persist(result, item.id)
            return "摘要已生成并更新到内容详情"
        case .polish:
            guard result.polishedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw CollectedItemAIError.emptyResult
            }
            try await persist(result, item.id)
            return "正文已润色并保存"
        case .extractTodos:
            let todos = result.todos
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
            guard todos.isEmpty == false else {
                throw CollectedItemAIError.emptyResult
            }
            for todo in todos {
                _ = try await ServiceContainer.shared.agentTaskBoardService.createTask(
                    AgentTask(
                        title: todo,
                        description: "由收集项「\(item.workflowTitle)」提取\n\n\(item.workflowBody)",
                        sourceMessageId: item.id.stableValue
                    )
                )
            }
            return "已提取并创建 \(todos.count) 个待办任务"
        case .extractSchedule:
            guard result.schedule.isEmpty == false else {
                throw CollectedItemAIError.emptyResult
            }
            for draft in result.schedule {
                try await ServiceContainer.shared.scheduleService.createEvent(
                    item.makeScheduleEvent(aiDraft: draft)
                )
            }
            return "已提取并创建 \(result.schedule.count) 个日程"
        }
    }

    private func navigateAfterWorkflow(_ action: CollectedItemWorkflowAction) {
        switch action {
        case .sendToAgent, .createTask:
            AppState.shared.navigate(to: .agent)
        case .createSchedule:
            AppState.shared.navigate(to: .schedule)
        case .saveToKnowledge, .exportMarkdown:
            break
        }
    }

    private func setBatchFeedback(
        action: CollectedItemWorkflowAction,
        total: Int,
        failureMessages: [String]
    ) {
        let successCount = total - failureMessages.count
        let summary: String
        if failureMessages.isEmpty {
            summary = "已完成 \(successCount) 项"
        } else if successCount == 0 {
            summary = "全部失败：\(failureMessages.joined(separator: "；"))"
        } else {
            summary = "成功 \(successCount) 项，失败 \(failureMessages.count) 项：\(failureMessages.joined(separator: "；"))"
        }
        feedback = CollectedItemWorkflowFeedback(
            actionTitle: action.title,
            message: summary,
            isError: successCount == 0
        )
    }

    private func selectMarkdownDestination(for item: CollectedItem) throws -> URL {
        let panel = NSSavePanel()
        panel.title = "导出 Markdown"
        panel.nameFieldStringValue = "\(safeFilename(item.workflowTitle)).md"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else {
            throw CollectedItemWorkflowError.cancelled
        }
        return url.pathExtension.lowercased() == "md" ? url : url.appendingPathExtension("md")
    }

    private func selectExportDirectory() throws -> URL {
        let panel = NSOpenPanel()
        panel.title = "选择 Markdown 导出目录"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else {
            throw CollectedItemWorkflowError.cancelled
        }
        return url
    }

    private func writeMarkdown(for item: CollectedItem, to directory: URL) throws {
        let baseName = safeFilename(item.workflowTitle)
        var destination = directory.appendingPathComponent(baseName).appendingPathExtension("md")
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("md")
            suffix += 1
        }
        try item.workflowMarkdown.write(to: destination, atomically: true, encoding: .utf8)
    }

    private func safeFilename(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let parts = value.components(separatedBy: invalidCharacters)
        let sanitized = parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "AcWork-收集项" : sanitized
    }
}

private enum CollectedItemWorkflowError: LocalizedError {
    case servicesUnavailable
    case cancelled

    var errorDescription: String? {
        switch self {
        case .servicesUnavailable:
            return "AcWork 服务尚未初始化，请稍后重试"
        case .cancelled:
            return "已取消操作"
        }
    }
}

private extension CollectedItemAIAction {
    var title: String {
        switch self {
        case .generateTitle: return "自动标题"
        case .summarize: return "生成摘要"
        case .extractTodos: return "提取待办"
        case .extractSchedule: return "提取日程"
        case .polish: return "润色"
        }
    }
}

@MainActor
final class InboxCollectedItemRepository: CollectedItemRepositoryProtocol {
    private let previewScenario: AcWorkPreviewScenario?
    private let liveRepository: CollectedItemRepository

    init(
        previewScenario: AcWorkPreviewScenario?,
        liveRepository: CollectedItemRepository = CollectedItemRepository()
    ) {
        self.previewScenario = previewScenario
        self.liveRepository = liveRepository
    }

    func list(filter: CollectedItemFilter, sort: CollectedItemSort) async -> CollectedItemListResult {
        #if DEBUG
        if let previewScenario {
            let items = AcWorkPreviewData
                .inboxItems(for: previewScenario)
                .map(CollectedItem.init(sourceItem:))
            let filtered = apply(filter: filter, to: items)
            let sorted = apply(sort: sort, to: filtered)

            switch previewScenario {
            case .populated, .empty:
                return CollectedItemListResult(items: sorted)
            case .loading:
                return CollectedItemListResult(items: [])
            case .error:
                return CollectedItemListResult(items: [], partialErrors: ["AcWork Preview: 收集箱加载失败"])
            }
        }
        #endif

        return await liveRepository.list(filter: filter, sort: sort)
    }

    func pin(id: CollectedItemID) async throws { try await liveRepository.pin(id: id) }
    func unpin(id: CollectedItemID) async throws { try await liveRepository.unpin(id: id) }
    func favorite(id: CollectedItemID, isFavorite: Bool) async throws { try await liveRepository.favorite(id: id, isFavorite: isFavorite) }
    func updateTags(id: CollectedItemID, tags: [String]) async throws { try await liveRepository.updateTags(id: id, tags: tags) }
    func applyAIResult(id: CollectedItemID, result: CollectedItemAIResult) async throws -> CollectedItemID {
        try await liveRepository.applyAIResult(id: id, result: result)
    }
    func archive(id: CollectedItemID) async throws { try await liveRepository.archive(id: id) }
    func delete(id: CollectedItemID) async throws { try await liveRepository.delete(id: id) }
    func saveClipboardItemToInbox(id: CollectedItemID) async throws -> CollectedItemID { try await liveRepository.saveClipboardItemToInbox(id: id) }
    func enqueueForPaste(ids: [CollectedItemID]) { liveRepository.enqueueForPaste(ids: ids) }
    func getPasteQueueItems() -> [PasteQueue.QueueItem] { liveRepository.getPasteQueueItems() }
    func pasteNextInQueue() async throws -> ClipboardItem? { try await liveRepository.pasteNextInQueue() }
    func clearPasteQueue() { liveRepository.clearPasteQueue() }
    func removePasteQueueItem(id: String) { liveRepository.removePasteQueueItem(id: id) }
    func reorderPasteQueue(from source: Int, to destination: Int) {
        liveRepository.reorderPasteQueue(from: source, to: destination)
    }
    func clipboardMonitoringState() -> ClipboardMonitoringState { liveRepository.clipboardMonitoringState() }
    func pauseClipboardMonitoring() async { await liveRepository.pauseClipboardMonitoring() }
    func resumeClipboardMonitoring() async { await liveRepository.resumeClipboardMonitoring() }

    private func apply(filter: CollectedItemFilter, to items: [CollectedItem]) -> [CollectedItem] {
        items.filter { item in
            if filter.sources.isEmpty == false, filter.sources.contains(item.source) == false { return false }
            if filter.contentTypes.isEmpty == false, filter.contentTypes.contains(item.contentType) == false { return false }
            if filter.statuses.isEmpty == false, filter.statuses.contains(item.processingStatus) == false { return false }
            if filter.pinnedOnly, item.isPinned == false { return false }
            if filter.favoriteOnly, item.isFavorite == false { return false }
            if let query = filter.searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), query.isEmpty == false {
                return [
                    item.title,
                    item.previewText,
                    item.sourceApplication,
                    item.sourceDevice,
                    item.originalURL,
                    item.tags.joined(separator: " ")
                ]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
                .contains(query)
            }
            return true
        }
    }

    private func apply(sort: CollectedItemSort, to items: [CollectedItem]) -> [CollectedItem] {
        switch sort {
        case .newestFirst:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .pinnedFirst:
            return items.sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                return $0.createdAt > $1.createdAt
            }
        case .recentlyUpdated:
            return items.sorted { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }
        }
    }
}
