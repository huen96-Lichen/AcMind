import Foundation
import AppKit
import AcMindKit

@MainActor
public final class ClipboardViewModel: ObservableObject {
    @Published public var items: [ClipboardItem] = []
    @Published public var searchText: String = ""
    @Published public var selectedType: ClipboardContentType?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var showError: Bool = false

    private let clipboardService: ClipboardServiceProtocol
    private let storage: StorageServiceProtocol
    private let toastManager: ToastManager

    public init(
        container: ServiceContainer,
        clipboardService: ClipboardServiceProtocol? = nil,
        storage: StorageServiceProtocol? = nil,
        toastManager: ToastManager
    ) {
        self.clipboardService = clipboardService ?? container.clipboardService
        self.storage = storage ?? container.storageService
        self.toastManager = toastManager
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let filter = ClipboardFilter(
                contentType: selectedType,
                searchQuery: searchText.isEmpty ? nil : searchText,
                limit: 200
            )
            items = try await clipboardService.listItems(filter: filter)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    public func refresh() async {
        await load()
    }

    public func saveCurrentClipboard() async {
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let type: ClipboardContentType = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") ? .url : classifyText(trimmed)
            let item = ClipboardItem(
                type: type,
                content: trimmed,
                textContent: trimmed,
                sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName
            )
            do {
                try await storage.insertClipboardItem(item)
                await load()
                toastManager.show(.success, "已保存当前剪贴板")
            } catch {
                errorMessage = "保存失败: \(error.localizedDescription)"
                showError = true
                toastManager.show(.error, error.localizedDescription)
            }
            return
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], let first = urls.first {
            let item = ClipboardItem(
                type: .file,
                content: first.path,
                textContent: first.lastPathComponent,
                sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName
            )
            do {
                try await storage.insertClipboardItem(item)
                await load()
                toastManager.show(.success, "文件已保存到剪贴板历史")
            } catch {
                errorMessage = "保存失败: \(error.localizedDescription)"
                showError = true
                toastManager.show(.error, error.localizedDescription)
            }
            return
        }

        errorMessage = "剪贴板里没有可用内容"
        showError = true
        toastManager.show(.warning, "剪贴板里没有可用内容")
    }

    public func copyItem(_ item: ClipboardItem) async {
        let text = item.textContent ?? item.content ?? ""
        guard !text.isEmpty else {
            errorMessage = "没有可复制的内容"
            showError = true
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        toastManager.show(.success, "已复制到剪贴板")
    }

    public func togglePinned(_ item: ClipboardItem) async {
        do {
            if item.isPinned {
                try await clipboardService.unpinItem(id: item.id)
            } else {
                try await clipboardService.pinItem(id: item.id)
            }
            await load()
            toastManager.show(.success, item.isPinned ? "已取消收藏" : "已收藏")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            toastManager.show(.error, error.localizedDescription)
        }
    }

    public func delete(_ item: ClipboardItem) async {
        do {
            try await clipboardService.deleteItem(id: item.id)
            await load()
            toastManager.show(.success, "已删除记录")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            toastManager.show(.error, error.localizedDescription)
        }
    }

    public func clearAll() async {
        do {
            try await clipboardService.clearHistory()
            await load()
            toastManager.show(.success, "已清空历史")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            toastManager.show(.error, error.localizedDescription)
        }
    }

    public var filteredItems: [ClipboardItem] {
        items.filter { item in
            guard let selectedType else { return true }
            return item.type == selectedType
        }
    }

    public var groupedItems: [String: [ClipboardItem]] {
        let filtered = searchText.isEmpty
            ? filteredItems
            : filteredItems.filter { item in
                let haystack = [item.textContent, item.content, item.sourceApp].compactMap { $0 }.joined(separator: " ")
                return haystack.localizedCaseInsensitiveContains(searchText)
            }

        let grouped = Dictionary(grouping: filtered) { item in
            Calendar.current.isDateInToday(item.createdAt) ? "今天" : Calendar.current.isDateInYesterday(item.createdAt) ? "昨天" : "更早"
        }

        return grouped
    }

    public var stats: (total: Int, text: Int, image: Int, file: Int, url: Int, starred: Int) {
        let items = self.items
        return (
            total: items.count,
            text: items.filter { $0.type == .text }.count,
            image: items.filter { $0.type == .image }.count,
            file: items.filter { $0.type == .file }.count,
            url: items.filter { $0.type == .url }.count,
            starred: items.filter { $0.isPinned }.count
        )
    }

    private func classifyText(_ text: String) -> ClipboardContentType {
        let lower = text.lowercased()
        if lower.contains("function ") || lower.contains("const ") || lower.contains("import ") || lower.contains("class ") || text.contains("{") || text.contains("}") {
            return .text
        }
        if text.contains("/") || text.contains("\\") || lower.contains(".txt") || lower.contains(".md") {
            return .file
        }
        return .text
    }
}
