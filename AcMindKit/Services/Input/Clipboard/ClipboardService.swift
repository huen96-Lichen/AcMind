import Foundation
import AppKit
import Combine

// MARK: - Clipboard Service

/// 剪贴板服务实现
/// 职责：
/// 1. 监听系统剪贴板变化（轮询机制）
/// 2. 去重和内容识别（文本/图片/文件/URL）
/// 3. 历史条目管理（pin/unpin/删除/过滤）
/// 4. 保存到 Inbox 形成 SourceItem
/// 5. 复制回写到系统剪贴板
@MainActor
public final class ClipboardService: ClipboardServiceProtocol {
    
    // MARK: - Dependencies
    
    private let storage: StorageServiceProtocol
    private let assetStore: AssetStore
    
    // MARK: - State
    
    private nonisolated(unsafe) var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var items: [ClipboardItem] = []
    private var isWatching = false
    private var isPaused = false
    
    /// 最近处理的剪贴板内容哈希，用于去重
    private var recentHashes: [String] = []
    private let maxRecentHashes = 50
    
    // MARK: - Constants
    
    private let maxHistoryItems = 100
    private let pollInterval: TimeInterval = 0.5
    
    // MARK: - Initialization
    
    public init(
        storage: StorageServiceProtocol? = nil,
        assetStore: AssetStore? = nil
    ) {
        self.storage = storage ?? StorageService()
        self.assetStore = assetStore ?? AssetStore()
    }
    
    // MARK: - Lifecycle
    
    public func startWatching() async {
        guard !isWatching else { return }
        
        // 加载历史记录
        await loadHistory()
        
        // 启动轮询
        await MainActor.run {
            self.timer = Timer.scheduledTimer(withTimeInterval: self.pollInterval, repeats: true) { _ in
                Task { await self.checkClipboard() }
            }
        }
        
        isWatching = true
        isPaused = false
    }
    
    public func stopWatching() async {
        await MainActor.run {
            timer?.invalidate()
            timer = nil
        }
        isWatching = false
    }
    
    public func pauseWatching() async {
        isPaused = true
    }
    
    public func resumeWatching() async {
        isPaused = false
        // 重置 changeCount 避免暂停期间的变化被处理
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    // MARK: - Clipboard Monitoring
    
    private func checkClipboard() async {
        guard !isPaused else { return }
        
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        // 获取前台应用名称
        let sourceApp = await getFrontmostAppName()
        
        // 尝试创建剪贴板条目
        if let item = await createItem(from: pasteboard, sourceApp: sourceApp) {
            // 检查是否重复
            let itemHash = hashForItem(item)
            guard !recentHashes.contains(itemHash) else { return }
            
            // 添加到历史
            items.insert(item, at: 0)
            
            // 更新去重缓存
            recentHashes.insert(itemHash, at: 0)
            if recentHashes.count > maxRecentHashes {
                recentHashes = Array(recentHashes.prefix(maxRecentHashes))
            }
            
            // 限制历史数量
            trimHistory()
            
            // 持久化到数据库
            try? await saveItemToDatabase(item)
        }
    }
    
    private func createItem(from pasteboard: NSPasteboard, sourceApp: String?) async -> ClipboardItem? {
        // 1. 检查图片
        if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            return await createImageItem(image: image, sourceApp: sourceApp)
        }
        
        // 2. 检查文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           !urls.isEmpty {
            return createFileItem(urls: urls, sourceApp: sourceApp)
        }
        
        // 3. 检查普通 URL（字符串形式）
        if let string = pasteboard.string(forType: .string) {
            // 检查是否是 URL
            if let url = URL(string: string),
               url.scheme?.hasPrefix("http") == true {
                return ClipboardItem(
                    type: .url,
                    content: string,
                    textContent: string,
                    sourceApp: sourceApp
                )
            }
            
            // 普通文本
            return ClipboardItem(
                type: .text,
                content: string,
                textContent: string,
                sourceApp: sourceApp
            )
        }
        
        return nil
    }
    
    private func createImageItem(image: NSImage, sourceApp: String?) async -> ClipboardItem? {
        do {
            let assetFile = try await assetStore.saveImage(
                image,
                fileName: "clipboard_\(Date().timeIntervalSince1970).png"
            )
            
            return ClipboardItem(
                type: .image,
                content: assetFile.id,
                textContent: "[图片] \(assetFile.fileName)",
                sourceApp: sourceApp
            )
        } catch {
            print("Failed to save clipboard image: \(error)")
            return nil
        }
    }
    
    private func createFileItem(urls: [URL], sourceApp: String?) -> ClipboardItem? {
        let paths = urls.map { $0.path }
        let content = paths.joined(separator: "\n")
        let preview = paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        
        return ClipboardItem(
            type: .file,
            content: content,
            textContent: "[文件] \(preview)",
            sourceApp: sourceApp
        )
    }
    
    private func getFrontmostAppName() async -> String? {
        await MainActor.run {
            NSWorkspace.shared.frontmostApplication?.localizedName
        }
    }
    
    private func hashForItem(_ item: ClipboardItem) -> String {
        // 使用内容哈希进行去重
        let content = item.content ?? item.textContent ?? ""
        return "\(item.type.rawValue)_\(content.prefix(100))"
    }
    
    private func trimHistory() {
        // 保留 pinned 项，限制总数
        let pinnedItems = items.filter { $0.isPinned }
        let unpinnedItems = items.filter { !$0.isPinned }
        
        let maxUnpinned = maxHistoryItems - pinnedItems.count
        let trimmedUnpinned = Array(unpinnedItems.prefix(max(maxUnpinned, 0)))
        
        // 按时间排序：pinned 在前，然后 unpinned
        items = pinnedItems.sorted { $0.createdAt > $1.createdAt } + trimmedUnpinned
    }
    
    // MARK: - Persistence
    
    private func loadHistory() async {
        // 从数据库加载历史记录
        // 这里简化处理，实际应该查询 clipboard_items 表
        // items = try? await storage.listClipboardItems()
    }
    
    private func saveItemToDatabase(_ item: ClipboardItem) async throws {
        // 保存到数据库
        // try await storage.insertClipboardItem(item)
    }
    
    private func deleteItemFromDatabase(id: String) async throws {
        // try await storage.deleteClipboardItem(id: id)
    }
    
    // MARK: - Query
    
    public func listItems(filter: ClipboardFilter?) async throws -> [ClipboardItem] {
        var result = items
        
        // 应用类型过滤
        if let contentType = filter?.contentType {
            result = result.filter { $0.type == contentType }
        }
        
        // 应用搜索过滤
        if let query = filter?.searchQuery?.lowercased(), !query.isEmpty {
            result = result.filter { item in
                let text = item.textContent?.lowercased() ?? ""
                let content = item.content?.lowercased() ?? ""
                return text.contains(query) || content.contains(query)
            }
        }
        
        // 应用数量限制
        if let limit = filter?.limit {
            result = Array(result.prefix(limit))
        }
        
        return result
    }
    
    public func getItem(id: String) async -> ClipboardItem? {
        items.first { $0.id == id }
    }
    
    // MARK: - Pin/Unpin
    
    public func pinItem(id: String) async throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw ClipboardError.itemNotFound
        }
        
        items[index].isPinned = true
        
        // 重新排序：pinned 在前
        let item = items.remove(at: index)
        items.insert(item, at: 0)
        
        // 持久化
        try? await saveItemToDatabase(items[0])
    }
    
    public func unpinItem(id: String) async throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw ClipboardError.itemNotFound
        }
        
        items[index].isPinned = false
        
        // 重新排序：移到 unpinned 区域
        let item = items.remove(at: index)
        let pinnedCount = items.filter { $0.isPinned }.count
        items.insert(item, at: pinnedCount)
        
        // 持久化
        try? await saveItemToDatabase(items[pinnedCount])
    }
    
    // MARK: - Delete
    
    public func deleteItem(id: String) async throws {
        guard let item = items.first(where: { $0.id == id }) else {
            throw ClipboardError.itemNotFound
        }
        
        // 如果是图片类型，删除关联的 asset
        if item.type == .image, let assetId = item.content {
            try? await assetStore.deleteAsset(id: assetId)
        }
        
        items.removeAll { $0.id == id }
        try? await deleteItemFromDatabase(id: id)
    }
    
    public func clearHistory() async throws {
        // 只保留 pinned 项
        let pinnedItems = items.filter { $0.isPinned }
        let itemsToDelete = items.filter { !$0.isPinned }
        
        // 删除关联的 assets
        for item in itemsToDelete where item.type == .image {
            if let assetId = item.content {
                try? await assetStore.deleteAsset(id: assetId)
            }
        }
        
        items = pinnedItems
        
        // 清空去重缓存
        recentHashes.removeAll()
        
        // 从数据库删除
        // try? await storage.clearClipboardHistory(keepingPinned: true)
    }
    
    // MARK: - Save to Inbox
    
    public func saveToInbox(id: String) async throws -> SourceItem {
        guard let item = items.first(where: { $0.id == id }) else {
            throw ClipboardError.itemNotFound
        }
        
        let sourceType: SourceType
        let assetIds: [String]
        let previewText: String?
        let title: String?
        
        switch item.type {
        case .text:
            sourceType = .text
            assetIds = []
            previewText = item.textContent
            title = previewText.map { String($0.prefix(50)) }
            
        case .image:
            sourceType = .image
            assetIds = item.content.map { [$0] } ?? []
            previewText = item.textContent
            title = previewText
            
        case .file:
            sourceType = .unknownFile
            assetIds = []
            previewText = item.textContent
            title = previewText.map { String($0.prefix(50)) }
            
        case .url:
            sourceType = .webpage
            assetIds = []
            previewText = item.textContent
            title = previewText
        }
        
        let sourceItem = SourceItem(
            type: sourceType,
            source: .clipboard,
            status: .captured,
            title: title,
            previewText: previewText,
            originalUrl: item.type == .url ? item.content : nil,
            assetFileIds: assetIds,
            metadata: [
                "clipboardSourceApp": item.sourceApp ?? "",
                "clipboardTimestamp": ISO8601DateFormatter().string(from: item.createdAt)
            ]
        )
        
        try await storage.insertSourceItem(sourceItem)
        return sourceItem
    }
    
    // MARK: - Copy to Clipboard
    
    public func copyItem(id: String) async throws {
        guard let item = items.first(where: { $0.id == id }) else {
            throw ClipboardError.itemNotFound
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .url:
            if let text = item.textContent ?? item.content {
                pasteboard.setString(text, forType: .string)
            }
            
            case .image:
            if let assetId = item.content {
                if let asset = try? await assetStore.getAsset(id: assetId),
                   let image = await assetStore.loadImage(asset: asset) {
                    pasteboard.writeObjects([image])
                }
            }
            
        case .file:
            if let paths = item.content?.split(separator: "\n").map(String.init) {
                let urls = paths.map { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            }
        }
        
        // 更新最后处理的 changeCount，避免重复捕获自己写入的内容
        lastChangeCount = pasteboard.changeCount
    }
    
    public func copyText(_ text: String) async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }
    
    // MARK: - Stats
    
    public func getStats() async -> ClipboardStats {
        let totalCount = items.count
        let pinnedCount = items.filter { $0.isPinned }.count
        let textCount = items.filter { $0.type == .text }.count
        let imageCount = items.filter { $0.type == .image }.count
        let fileCount = items.filter { $0.type == .file }.count
        let urlCount = items.filter { $0.type == .url }.count
        
        return ClipboardStats(
            totalCount: totalCount,
            pinnedCount: pinnedCount,
            textCount: textCount,
            imageCount: imageCount,
            fileCount: fileCount,
            urlCount: urlCount
        )
    }
}

// MARK: - Errors

public enum ClipboardError: Error, LocalizedError {
    case itemNotFound
    case invalidContent
    case saveFailed(Error)
    case copyFailed
    
    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "剪贴板条目未找到"
        case .invalidContent:
            return "无效的剪贴板内容"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        case .copyFailed:
            return "复制到剪贴板失败"
        }
    }
}

// MARK: - Stats

public struct ClipboardStats: Sendable, Equatable {
    public let totalCount: Int
    public let pinnedCount: Int
    public let textCount: Int
    public let imageCount: Int
    public let fileCount: Int
    public let urlCount: Int
    
    public init(
        totalCount: Int = 0,
        pinnedCount: Int = 0,
        textCount: Int = 0,
        imageCount: Int = 0,
        fileCount: Int = 0,
        urlCount: Int = 0
    ) {
        self.totalCount = totalCount
        self.pinnedCount = pinnedCount
        self.textCount = textCount
        self.imageCount = imageCount
        self.fileCount = fileCount
        self.urlCount = urlCount
    }
}
