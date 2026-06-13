import Foundation
import SwiftUI
import Combine
import AcMindKit

// MARK: - Clipboard View Model

/// 剪贴板视图模型
/// 职责：
/// 1. 管理剪贴板历史列表状态
/// 2. 处理用户操作（pin/unpin/删除/复制/保存到 Inbox）
/// 3. 提供过滤和搜索功能
/// 4. 监听剪贴板服务变化
@MainActor
public final class ClipboardViewModel: ObservableObject {
    private static let logger = AcMindLogger(category: .clipboard)
    
    // MARK: - Dependencies
    
    private let clipboardService: ClipboardServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    
    @Published public var items: [ClipboardItem] = []
    @Published public var filteredItems: [ClipboardItem] = []
    @Published public var searchQuery: String = "" {
        didSet { applyFilter() }
    }
    @Published public var selectedType: ClipboardContentType? = nil {
        didSet { applyFilter() }
    }
    @Published public var availableTags: [ClipboardTag] = []
    @Published public var selectedTag: String? = nil {
        didSet { applyFilter() }
    }
    
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showError = false
    
    @Published public var stats: ClipboardStats = ClipboardStats()
    @Published public var isWatching = false
    
    // MARK: - Initialization

    public init(clipboardService: ClipboardServiceProtocol? = nil) {
        self.clipboardService = clipboardService ?? ClipboardService()

        clipboardService?.itemPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newItem in
                guard let self else { return }
                let pinnedCount = self.items.filter { $0.isPinned }.count
                self.items.insert(newItem, at: pinnedCount)
                self.applyFilter()
                Task { await self.updateStats() }
            }
            .store(in: &cancellables)

        Task {
            await loadItems()
            await updateStats()
        }
    }
    
    // MARK: - Load
    
    public func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            items = try await clipboardService.listItems(filter: nil)
            applyFilter()
            await loadTags()
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    private func applyFilter() {
        var result = items

        if let type = selectedType {
            result = result.filter { $0.type == type }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { item in
                let text = item.textContent?.lowercased() ?? ""
                let content = item.content?.lowercased() ?? ""
                let sourceApp = item.sourceApp?.lowercased() ?? ""
                return text.contains(query) || content.contains(query) || sourceApp.contains(query)
            }
        }

        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        result.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }

        filteredItems = result
    }
    
    // MARK: - Actions
    
    public func pinItem(id: String) async {
        do {
            try await clipboardService.pinItem(id: id)
            await loadItems()
            await updateStats()
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    public func unpinItem(id: String) async {
        do {
            try await clipboardService.unpinItem(id: id)
            await loadItems()
            await updateStats()
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    public func deleteItem(id: String) async {
        do {
            try await clipboardService.deleteItem(id: id)
            await loadItems()
            await updateStats()
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    public func copyItem(id: String) async {
        do {
            try await clipboardService.copyItem(id: id)
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    public func copyText(_ text: String) async {
        await clipboardService.copyText(text)
    }
    
    public func saveToInbox(id: String) async {
        do {
            let sourceItem = try await clipboardService.saveToInbox(id: id)
            Self.logger.info("Saved to Inbox: \(sourceItem.id)")
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    public func clearHistory() async {
        do {
            try await clipboardService.clearHistory()
            await loadItems()
            await updateStats()
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Watching Control
    
    public func startWatching() async {
        await clipboardService.startWatching()
        isWatching = true
    }
    
    public func stopWatching() async {
        await clipboardService.stopWatching()
        isWatching = false
    }
    
    public func pauseWatching() async {
        await clipboardService.pauseWatching()
    }
    
    public func resumeWatching() async {
        await clipboardService.resumeWatching()
    }
    
    // MARK: - Stats
    
    public func updateStats() async {
        stats = await clipboardService.getStats()
    }
    
    // MARK: - Error Handling
    
    private func emitError(message: String) {
        errorMessage = message
        showError = true
    }
    
    public func clearError() {
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Tags
    
    public func loadTags() async {
        do {
            availableTags = try await clipboardService.listTags()
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    public func createTag(name: String, color: String) async {
        do {
            let tag = try await clipboardService.createTag(name: name, color: color)
            availableTags.append(tag)
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    public func addTagToItem(itemId: String, tagName: String) async {
        do {
            try await clipboardService.addTagToItem(itemId: itemId, tagName: tagName)
            await loadItems()
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    public func removeTagFromItem(itemId: String, tagName: String) async {
        do {
            try await clipboardService.removeTagFromItem(itemId: itemId, tagName: tagName)
            await loadItems()
        } catch {
            emitError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Paste Queue
    
    public func enqueueForSequentialPaste(ids: [String]) {
        clipboardService.enqueueForSequentialPaste(ids: ids)
    }
    
    public func pasteNextInQueue() async -> ClipboardItem? {
        do {
            return try await clipboardService.pasteNextInQueue()
        } catch {
            emitError(message: error.localizedDescription)
            return nil
        }
    }
    
    public func getQueueItems() -> [PasteQueue.QueueItem] {
        clipboardService.getQueueItems()
    }
    
    public func clearPasteQueue() async {
        clipboardService.clearPasteQueue()
    }
    
    public func removeQueueItem(id: String) {
        clipboardService.removeQueueItem(id: id)
    }
    
    // MARK: - Helpers
    
    public func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    public func previewText(for item: ClipboardItem) -> String {
        item.textContent ?? item.content ?? ""
    }
    
    public func typeIcon(for type: ClipboardContentType) -> String {
        type.icon
    }

    public func typeColor(for type: ClipboardContentType) -> Color {
        type.color
    }
}
