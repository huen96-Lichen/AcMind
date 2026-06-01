import Foundation
import AppKit
import AcMindKit

@MainActor
class InboxViewModel: ObservableObject {
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
    
    // MARK: - Init
    
    init(
        storage: StorageServiceProtocol? = nil,
        exportService: ExportServiceProtocol? = nil
    ) {
        let container = ServiceContainer.isInitialized() ? ServiceContainer.shared : nil
        self.storage = storage ?? container?.storageService ?? StorageService()
        self.exportService = exportService ?? container?.exportService ?? ExportService()
    }
    
    // MARK: - Load
    
    func loadItems() async {
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
            let distillService = ServiceContainer.shared.distillService
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
        AppState.shared.selectSidebarItem(.workbench)
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

            _ = try await ServiceContainer.shared.knowledgeService.createCard(from: note)
            AppState.shared.selectSidebarItem(.agent)
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
            print("Failed to compute stats: \(error)")
        }
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
