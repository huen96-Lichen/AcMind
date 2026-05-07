import Foundation
import SwiftUI
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
    
    // MARK: - Dependencies
    
    private let clipboardService: ClipboardServiceProtocol
    
    // MARK: - Published Properties
    
    @Published public var items: [ClipboardItem] = []
    @Published public var filteredItems: [ClipboardItem] = []
    @Published public var searchQuery: String = "" {
        didSet { applyFilter() }
    }
    @Published public var selectedType: ClipboardContentType? = nil {
        didSet { applyFilter() }
    }
    
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showError = false
    
    @Published public var stats: ClipboardStats = ClipboardStats()
    @Published public var isWatching = false
    
    // MARK: - Initialization
    
    public init(clipboardService: ClipboardServiceProtocol? = nil) {
        self.clipboardService = clipboardService ?? ServiceContainer.shared.clipboardService
        
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
            let filter = ClipboardFilter(
                contentType: selectedType,
                searchQuery: searchQuery.isEmpty ? nil : searchQuery,
                limit: nil
            )
            items = try await clipboardService.listItems(filter: nil)
            applyFilter()
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    private func applyFilter() {
        var result = items
        
        // 类型过滤
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        
        // 搜索过滤
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { item in
                let text = item.textContent?.lowercased() ?? ""
                let content = item.content?.lowercased() ?? ""
                let sourceApp = item.sourceApp?.lowercased() ?? ""
                return text.contains(query) || content.contains(query) || sourceApp.contains(query)
            }
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
            showError(message: error.localizedDescription)
        }
    }
    
    public func unpinItem(id: String) async {
        do {
            try await clipboardService.unpinItem(id: id)
            await loadItems()
            await updateStats()
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    public func deleteItem(id: String) async {
        do {
            try await clipboardService.deleteItem(id: id)
            await loadItems()
            await updateStats()
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    public func copyItem(id: String) async {
        do {
            try await clipboardService.copyItem(id: id)
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    public func copyText(_ text: String) async {
        if let service = clipboardService as? ClipboardService {
            await service.copyText(text)
        }
    }
    
    public func saveToInbox(id: String) async {
        do {
            let sourceItem = try await clipboardService.saveToInbox(id: id)
            print("Saved to Inbox: \(sourceItem.id)")
            // 可以在这里发送通知或回调
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    public func clearHistory() async {
        do {
            try await clipboardService.clearHistory()
            await loadItems()
            await updateStats()
        } catch {
            showError(message: error.localizedDescription)
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
        if let service = clipboardService as? ClipboardService {
            await service.pauseWatching()
        }
    }
    
    public func resumeWatching() async {
        if let service = clipboardService as? ClipboardService {
            await service.resumeWatching()
        }
    }
    
    // MARK: - Stats
    
    public func updateStats() async {
        if let service = clipboardService as? ClipboardService {
            stats = await service.getStats()
        }
    }
    
    // MARK: - Error Handling
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    public func clearError() {
        errorMessage = nil
        showError = false
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
        switch type {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "doc"
        case .url: return "link"
        }
    }
    
    public func typeColor(for type: ClipboardContentType) -> Color {
        switch type {
        case .text: return .blue
        case .image: return .green
        case .file: return .orange
        case .url: return .purple
        }
    }
}
