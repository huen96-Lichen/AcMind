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
    private static let logger = AcMindLogger(category: .clipboard)
    
    // MARK: - Dependencies
    
    private let storage: StorageServiceProtocol
    private let assetStore: AssetStore
    private let settingsDefaults: UserDefaults
    private let pipeline: ClipboardPipeline
    private let cleaningRulesStore: CleaningRulesStore
    private lazy var transientPaster: TransientPaster = {
        TransientPaster(
            pauseMonitoring: { [weak self] in await self?.pauseWatching() },
            resumeMonitoring: { [weak self] in await self?.resumeWatching() }
        )
    }()
    private let pasteQueue = PasteQueue()
    private let focusManager = FocusManager()
    
    // MARK: - State
    
    private nonisolated(unsafe) var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var items: [ClipboardItem] = []
    private var isWatching = false
    private var isPaused = false

    public var itemPublisher: AnyPublisher<ClipboardItem, Never> {
        pipeline.distribution.itemCaptured.eraseToAnyPublisher()
    }

    var isWatchingActiveForTesting: Bool { isWatching }
    var isWatchingPausedForTesting: Bool { isPaused }
    
    // MARK: - Constants
    
    private let maxHistoryItems = 100
    private let pollInterval: TimeInterval = 0.5
    
    // MARK: - Initialization
    
    public init(
        storage: StorageServiceProtocol? = nil,
        assetStore: AssetStore? = nil,
        settingsDefaults: UserDefaults = .standard
    ) {
        let resolvedStorage = storage ?? StorageService()
        let resolvedAssetStore = assetStore ?? AssetStore()
        let resolvedCleaningRulesStore = CleaningRulesStore(storage: resolvedStorage)
        self.storage = resolvedStorage
        self.assetStore = resolvedAssetStore
        self.settingsDefaults = settingsDefaults
        self.cleaningRulesStore = resolvedCleaningRulesStore
        self.pipeline = ClipboardPipeline(
            assetStore: resolvedAssetStore,
            storage: resolvedStorage,
            cleaningRulesEvaluator: { [resolvedCleaningRulesStore] text, sourceApp in
                switch resolvedCleaningRulesStore.evaluate(text: text, sourceApp: sourceApp) {
                case .ignore:
                    return .ignore
                case .clean(let cleanedText):
                    return .clean(cleanedText)
                case .pass:
                    return .pass
                }
            }
        )
    }
    
    // MARK: - Lifecycle
    
    public func startWatching() async {
        guard !isWatching else { return }

        await cleaningRulesStore.loadRules()
        await loadHistory()
        
        // 启动轮询
        await startPollingTimer()
        
        isWatching = true
        isPaused = false
    }
    
    public func stopWatching() async {
        await stopPollingTimer()
        isWatching = false
        isPaused = false
    }
    
    public func pauseWatching() async {
        guard isWatching else { return }
        isPaused = true
        await stopPollingTimer()
    }
    
    public func resumeWatching() async {
        guard isWatching else { return }
        isPaused = false
        // 重置 changeCount 避免暂停期间的变化被处理
        lastChangeCount = NSPasteboard.general.changeCount
        await startPollingTimer()
    }
    
    // MARK: - Clipboard Monitoring
    
    private func checkClipboard() async {
        guard !isPaused else { return }
        guard shouldCaptureAutomatically else { return }

        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        let sourceApp = await getFrontmostAppName()

        var textContent: String?
        var htmlContent: String?
        var imageData: Data?
        var fileURLs: [String]?

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            fileURLs = urls.map { $0.path }
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage], let image = images.first {
            imageData = image.tiffRepresentation
        }

        htmlContent = pasteboard.string(forType: NSPasteboard.PasteboardType("public.html"))

        textContent = pasteboard.string(forType: .string)

        let raw = RawClipboardContent(
            changeCount: currentChangeCount,
            sourceApp: sourceApp,
            textContent: textContent,
            htmlContent: htmlContent,
            imageData: imageData,
            fileURLs: fileURLs
        )

        var context = PipelineContext(rawContent: raw)

        do {
            try await pipeline.process(&context)
        } catch {
            Self.logger.error("Pipeline error: \(error)")
            return
        }

        guard !context.shouldIgnore, let item = context.item else { return }

        items.insert(item, at: 0)
        trimHistory()
    }
    
    private func getFrontmostAppName() async -> String? {
        await MainActor.run {
            NSWorkspace.shared.frontmostApplication?.localizedName
        }
    }

    private var shouldCaptureAutomatically: Bool {
        let preferences = SettingsLocalPreferences.loadOrDefault(from: settingsDefaults)
        return Self.shouldCaptureAutomatically(
            captureOnlyWhenAppActive: preferences.captureOnlyWhenAppActive,
            isAppActive: NSApp.isActive
        )
    }

    nonisolated static func shouldCaptureAutomatically(captureOnlyWhenAppActive: Bool, isAppActive: Bool) -> Bool {
        guard captureOnlyWhenAppActive else { return true }
        return isAppActive
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
        do {
            items = try await storage.listClipboardItems(limit: maxHistoryItems)
            pipeline.validation.rebuildHashes(from: Array(items.prefix(50)))
        } catch {
            Self.logger.error("加载剪贴板历史失败: \(error)")
            items = []
        }
    }

    private func deleteItemFromDatabase(id: String) async throws {
        try await storage.deleteClipboardItem(id: id)
    }

    private func startPollingTimer() async {
        await MainActor.run {
            guard self.timer == nil else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.pollInterval, repeats: true) { _ in
                Task { await self.checkClipboard() }
            }
        }
    }

    private func stopPollingTimer() async {
        await MainActor.run {
            self.timer?.invalidate()
            self.timer = nil
        }
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
        try? await storage.updateClipboardItem(items[0])
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
        try? await storage.updateClipboardItem(items[pinnedCount])
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
        let pinnedItems = items.filter { $0.isPinned }
        let itemsToDelete = items.filter { !$0.isPinned }

        for item in itemsToDelete where item.type == .image {
            if let assetId = item.content {
                try? await assetStore.deleteAsset(id: assetId)
            }
        }

        for item in itemsToDelete {
            try? await storage.deleteClipboardItem(id: item.id)
        }

        items = pinnedItems
        pipeline.validation.clearHashes()
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

        case .richText:
            sourceType = .text
            assetIds = []
            previewText = item.textContent
            title = previewText.map { String($0.prefix(50)) }

        case .code:
            sourceType = .text
            assetIds = []
            previewText = item.textContent
            title = "[\(item.codeLanguage ?? "代码")] " + (previewText.map { String($0.prefix(40)) } ?? "")

        case .video:
            sourceType = .unknownFile
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

        case .richText:
            if let html = item.htmlContent ?? item.content {
                pasteboard.setString(html, forType: NSPasteboard.PasteboardType("public.html"))
                if let text = item.textContent {
                    pasteboard.setString(text, forType: .string)
                }
            }

        case .code:
            if let text = item.textContent ?? item.content {
                pasteboard.setString(text, forType: .string)
            }

        case .image:
            if let assetId = item.content {
                if let asset = try? await assetStore.getAsset(id: assetId),
                   let image = assetStore.loadImage(asset: asset) {
                    pasteboard.writeObjects([image])
                }
            }

        case .file:
            if let paths = item.content?.split(separator: "\n").map(String.init) {
                let urls = paths.map { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            }

        case .video:
            if let text = item.textContent ?? item.content {
                pasteboard.setString(text, forType: .string)
            }
        }

        let hash = pipeline.validation.computeHash(for: item)
        pipeline.validation.recordPasteHash(hash)

        lastChangeCount = pasteboard.changeCount
    }
    
    public func copyText(_ text: String) async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let tempItem = ClipboardItem(type: .text, content: text, textContent: text)
        let hash = pipeline.validation.computeHash(for: tempItem)
        pipeline.validation.recordPasteHash(hash)
        lastChangeCount = pasteboard.changeCount
    }
    
    // MARK: - Transient Paste
    
    public func pasteTransiently(id: String) async throws {
        guard let item = items.first(where: { $0.id == id }) else {
            throw ClipboardError.itemNotFound
        }
        focusManager.saveCurrentFocus()
        await transientPaster.pasteTransiently(item, assetStore: assetStore)
        focusManager.restoreFocus()
    }
    
    // MARK: - Sequential Paste Queue
    
    public func enqueueForSequentialPaste(ids: [String]) {
        pasteQueue.enqueueBatch(clipboardItemIds: ids)
    }
    
    public func pasteNextInQueue() async throws -> ClipboardItem? {
        guard let queueItem = pasteQueue.dequeue() else { return nil }
        guard let item = items.first(where: { $0.id == queueItem.clipboardItemId }) else { return nil }
        
        focusManager.saveCurrentFocus()
        try await copyItem(id: item.id)
        simulatePasteKeystroke()
        focusManager.restoreFocus()
        
        return item
    }
    
    public func getQueueItems() -> [PasteQueue.QueueItem] {
        pasteQueue.items
    }
    
    public func clearPasteQueue() {
        pasteQueue.clear()
    }
    
    public func removeQueueItem(id: String) {
        pasteQueue.remove(id: id)
    }
    
    public func reorderQueue(from source: Int, to destination: Int) {
        pasteQueue.moveItem(from: source, to: destination)
    }
    
    private func simulatePasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Cleaning Rules

    public func getCleaningRules() -> [CleaningRule] {
        cleaningRulesStore.getRules()
    }

    public func addCleaningRule(_ rule: CleaningRule) async {
        await cleaningRulesStore.addRule(rule)
    }

    public func updateCleaningRule(_ rule: CleaningRule) async {
        await cleaningRulesStore.updateRule(rule)
    }

    public func deleteCleaningRule(id: String) async {
        await cleaningRulesStore.deleteRule(id: id)
    }

    public func toggleCleaningRule(id: String) async {
        await cleaningRulesStore.toggleRule(id: id)
    }

    // MARK: - Tags

    public func createTag(name: String, color: String) async throws -> ClipboardTag {
        let tag = ClipboardTag(name: name, color: color)
        try await storage.insertClipboardTag(tag)
        return tag
    }

    public func listTags() async throws -> [ClipboardTag] {
        try await storage.listClipboardTags()
    }

    public func deleteTag(id: String) async throws {
        try await storage.deleteClipboardTag(id: id)
    }

    public func addTagToItem(itemId: String, tagName: String) async throws {
        try await storage.addTagToClipboardItem(itemId: itemId, tagName: tagName)
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            if !items[index].tags.contains(tagName) {
                items[index].tags.append(tagName)
            }
        }
    }

    public func removeTagFromItem(itemId: String, tagName: String) async throws {
        try await storage.removeTagFromClipboardItem(itemId: itemId, tagName: tagName)
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].tags.removeAll { $0 == tagName }
        }
    }

    public func listItemsByTag(_ tagName: String) async throws -> [ClipboardItem] {
        try await storage.listClipboardItemsByTag(tagName, limit: nil)
    }

    // MARK: - Stats

    public func getStats() async -> ClipboardStats {
        let totalCount = items.count
        let pinnedCount = items.filter { $0.isPinned }.count
        let textCount = items.filter { $0.type == .text }.count
        let imageCount = items.filter { $0.type == .image }.count
        let fileCount = items.filter { $0.type == .file }.count
        let urlCount = items.filter { $0.type == .url }.count
        let richTextCount = items.filter { $0.type == .richText }.count
        let codeCount = items.filter { $0.type == .code }.count
        let videoCount = items.filter { $0.type == .video }.count
        let queueCount = pasteQueue.count

        return ClipboardStats(
            totalCount: totalCount,
            pinnedCount: pinnedCount,
            textCount: textCount,
            imageCount: imageCount,
            fileCount: fileCount,
            urlCount: urlCount,
            richTextCount: richTextCount,
            codeCount: codeCount,
            videoCount: videoCount,
            queueCount: queueCount
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
    public let richTextCount: Int
    public let codeCount: Int
    public let videoCount: Int
    public let queueCount: Int

    public init(
        totalCount: Int = 0,
        pinnedCount: Int = 0,
        textCount: Int = 0,
        imageCount: Int = 0,
        fileCount: Int = 0,
        urlCount: Int = 0,
        richTextCount: Int = 0,
        codeCount: Int = 0,
        videoCount: Int = 0,
        queueCount: Int = 0
    ) {
        self.totalCount = totalCount
        self.pinnedCount = pinnedCount
        self.textCount = textCount
        self.imageCount = imageCount
        self.fileCount = fileCount
        self.urlCount = urlCount
        self.richTextCount = richTextCount
        self.codeCount = codeCount
        self.videoCount = videoCount
        self.queueCount = queueCount
    }
}
