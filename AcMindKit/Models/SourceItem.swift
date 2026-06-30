import Foundation
import SwiftUI

// MARK: - SourceItem（核心数据实体）

/// 采集内容的统一数据模型
/// 对齐旧版 source_items 表 schema v21
public struct SourceItem: Codable, Sendable, Identifiable, Hashable, Equatable {
    public let id: String
    public var type: SourceType
    public var source: SourceOrigin
    public var status: SourceItemStatus
    public var title: String?
    public var contentPath: String?
    public var contentHash: String?
    public var previewText: String?
    public var ocrText: String?
    public var transcript: String?
    public var polishedTranscript: String?
    public var sourceApp: String?
    public var originalUrl: String?
    public var tags: [String]
    public var captureItemId: String?
    public var vaultImportPath: String?
    public var assetFileIds: [String]
    public var metadata: [String: String]
    public let createdAt: Date
    public var updatedAt: Date?

    public init(
        id: String = UUID().uuidString,
        type: SourceType = .text,
        source: SourceOrigin = .manual,
        status: SourceItemStatus = .inbox,
        title: String? = nil,
        contentPath: String? = nil,
        contentHash: String? = nil,
        previewText: String? = nil,
        ocrText: String? = nil,
        transcript: String? = nil,
        polishedTranscript: String? = nil,
        sourceApp: String? = nil,
        originalUrl: String? = nil,
        tags: [String] = [],
        captureItemId: String? = nil,
        vaultImportPath: String? = nil,
        assetFileIds: [String] = [],
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.source = source
        self.status = status
        self.title = title
        self.contentPath = contentPath
        self.contentHash = contentHash
        self.previewText = previewText
        self.ocrText = ocrText
        self.transcript = transcript
        self.polishedTranscript = polishedTranscript
        self.sourceApp = sourceApp
        self.originalUrl = originalUrl
        self.tags = tags
        self.captureItemId = captureItemId
        self.vaultImportPath = vaultImportPath
        self.assetFileIds = assetFileIds
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isAgentGenerated: Bool {
        source == .agent
    }
}

// MARK: - Collected Item Domain

public enum CollectedItemOrigin: String, Codable, Sendable, Hashable {
    case sourceItem = "source"
    case clipboardItem = "clipboard"
}

public struct CollectedItemID: Codable, Sendable, Hashable, Equatable, Identifiable, CustomStringConvertible {
    public let origin: CollectedItemOrigin
    public let rawID: String

    public var id: String { stableValue }
    public var stableValue: String { "\(origin.rawValue):\(rawID)" }
    public var description: String { stableValue }

    public init(origin: CollectedItemOrigin, rawID: String) {
        self.origin = origin
        self.rawID = rawID
    }

    public init?(stableValue: String) {
        let parts = stableValue.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let origin = CollectedItemOrigin(rawValue: parts[0]), parts[1].isEmpty == false else {
            return nil
        }
        self.init(origin: origin, rawID: parts[1])
    }
}

public enum CollectedContentType: String, Codable, Sendable, Hashable, CaseIterable {
    case text
    case link
    case image
    case file
    case code
    case richText
    case video
    case audio
    case document
    case unknown
}

public enum CollectionSource: String, Codable, Sendable, Hashable, CaseIterable {
    case clipboard
    case phoneSync
    case voice
    case screenshot
    case screenshotOCR
    case agent
    case manual
    case webpage
    case file
    case capsule
    case imported
}

public extension CollectionSource {
    var displayName: String {
        switch self {
        case .clipboard: return "剪贴板"
        case .phoneSync: return "手机同步"
        case .voice: return "语音"
        case .screenshot: return "截图"
        case .screenshotOCR: return "截图 OCR"
        case .agent: return "Agent"
        case .manual: return "手动录入"
        case .webpage: return "网页"
        case .file: return "文件"
        case .capsule: return "灵动大陆"
        case .imported: return "导入"
        }
    }
}

public enum ProcessingStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case captured
    case processing
    case refined
    case archived
    case exported
    case deleted
}

public enum CollectedContent: Codable, Sendable, Hashable, Equatable {
    case text(String?)
    case link(urlString: String?, title: String?)
    case image(assetID: String?, caption: String?)
    case file(path: String?, name: String?)
    case code(language: String?, text: String?)
    case richText(html: String?, plainText: String?)
    case video(path: String?, caption: String?)
    case audio(transcript: String?)
    case document(path: String?, preview: String?)
    case unknown(preview: String?)
}

public struct CollectedItem: Codable, Sendable, Identifiable, Hashable, Equatable {
    public let id: CollectedItemID
    public var title: String?
    public var previewText: String?
    public var content: CollectedContent
    public var contentType: CollectedContentType
    public var source: CollectionSource
    public var sourceApplication: String?
    public var sourceDevice: String?
    public var originalURL: String?
    public var assetFileIDs: [String]
    public var createdAt: Date
    public var updatedAt: Date?
    public var processingStatus: ProcessingStatus
    public var isPinned: Bool
    public var isFavorite: Bool
    public var tags: [String]
    public var projectID: String?
    public var metadata: [String: String]

    public init(
        id: CollectedItemID,
        title: String? = nil,
        previewText: String? = nil,
        content: CollectedContent,
        contentType: CollectedContentType,
        source: CollectionSource,
        sourceApplication: String? = nil,
        sourceDevice: String? = nil,
        originalURL: String? = nil,
        assetFileIDs: [String] = [],
        createdAt: Date,
        updatedAt: Date? = nil,
        processingStatus: ProcessingStatus,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        tags: [String] = [],
        projectID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.previewText = previewText
        self.content = content
        self.contentType = contentType
        self.source = source
        self.sourceApplication = sourceApplication
        self.sourceDevice = sourceDevice
        self.originalURL = originalURL
        self.assetFileIDs = assetFileIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.processingStatus = processingStatus
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.tags = tags
        self.projectID = projectID
        self.metadata = metadata
    }
}

public enum CollectedItemAIAction: String, Codable, Sendable, Hashable, CaseIterable {
    case generateTitle
    case summarize
    case extractTodos
    case extractSchedule
    case polish
}

public struct CollectedItemAIScheduleDraft: Codable, Sendable, Equatable {
    public var title: String
    public var startAt: Date
    public var endAt: Date
    public var isAllDay: Bool

    public init(title: String, startAt: Date, endAt: Date, isAllDay: Bool = false) {
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.isAllDay = isAllDay
    }
}

public struct CollectedItemAIResult: Codable, Sendable, Equatable {
    public var title: String?
    public var summary: String?
    public var polishedText: String?
    public var todos: [String]
    public var schedule: [CollectedItemAIScheduleDraft]

    public init(
        title: String? = nil,
        summary: String? = nil,
        polishedText: String? = nil,
        todos: [String] = [],
        schedule: [CollectedItemAIScheduleDraft] = []
    ) {
        self.title = title
        self.summary = summary
        self.polishedText = polishedText
        self.todos = todos
        self.schedule = schedule
    }

    public static func parse(_ response: String) throws -> CollectedItemAIResult {
        let json = extractJSON(from: response)
        guard let data = json.data(using: .utf8) else {
            throw CollectedItemAIError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(CollectedItemAIResult.self, from: data)
        } catch {
            throw CollectedItemAIError.invalidResponse
        }
    }

    private static func extractJSON(from response: String) -> String {
        if let start = response.firstIndex(of: "{"), let end = response.lastIndex(of: "}") {
            return String(response[start...end])
        }
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum CollectedItemAIError: LocalizedError, Equatable {
    case invalidResponse
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "AI 返回格式无法解析"
        case .emptyResult:
            return "AI 没有生成可应用的结果"
        }
    }
}

public extension CollectedItem {
    var canOpenDesktopPin: Bool {
        source == .screenshot || source == .screenshotOCR
    }

    var workflowTitle: String {
        let candidate = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let candidate, candidate.isEmpty == false {
            return candidate
        }
        return "\(contentType.workflowDisplayName)收集项"
    }

    var workflowBody: String {
        let candidates = [previewText, content.workflowText, originalURL]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false }) ?? "无正文"
    }

    func makeAgentTask() -> AgentTask {
        AgentTask(
            title: workflowTitle,
            description: workflowDescription,
            sourceMessageId: id.stableValue
        )
    }

    func makeScheduleEvent(referenceDate: Date = Date(), calendar: Calendar = .current) -> ScheduleEvent {
        let currentMinute = calendar.component(.minute, from: referenceDate)
        let roundedStart = calendar.nextDate(
            after: referenceDate,
            matching: DateComponents(minute: currentMinute < 30 ? 30 : 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? referenceDate.addingTimeInterval(30 * 60)
        let end = calendar.date(byAdding: .minute, value: 30, to: roundedStart) ?? roundedStart.addingTimeInterval(30 * 60)

        return ScheduleEvent(
            id: UUID().uuidString,
            title: workflowTitle,
            description: workflowDescription,
            categoryId: "acmind",
            startAt: roundedStart,
            endAt: end,
            isAllDay: false,
            status: .todo,
            priority: .medium,
            tag: tags.first
        )
    }

    func makeScheduleEvent(aiDraft: CollectedItemAIScheduleDraft) -> ScheduleEvent {
        let endAt = aiDraft.endAt > aiDraft.startAt
            ? aiDraft.endAt
            : aiDraft.startAt.addingTimeInterval(30 * 60)
        return ScheduleEvent(
            id: UUID().uuidString,
            title: aiDraft.title,
            description: "由收集项「\(workflowTitle)」提取",
            categoryId: "acmind",
            startAt: aiDraft.startAt,
            endAt: endAt,
            isAllDay: aiDraft.isAllDay,
            status: .todo,
            priority: .medium,
            tag: tags.first
        )
    }

    func makeDistilledNote() -> DistilledNote {
        DistilledNote(
            sourceItemId: id.stableValue,
            title: workflowTitle,
            summary: workflowBody,
            category: source.workflowDisplayName,
            tags: tags,
            documentType: contentType.rawValue,
            contentMarkdown: workflowMarkdown
        )
    }

    var workflowMarkdown: String {
        var lines = [
            "# \(workflowTitle)",
            "",
            "> 来源：\(source.workflowDisplayName) · \(createdAt.formatted(date: .abbreviated, time: .shortened))",
            ""
        ]

        if tags.isEmpty == false {
            lines.append("标签：\(tags.map { "#\($0)" }.joined(separator: " "))")
            lines.append("")
        }

        lines.append(workflowBody)

        if let originalURL, originalURL.isEmpty == false, workflowBody != originalURL {
            lines.append("")
            lines.append("[查看原始链接](\(originalURL))")
        }

        return lines.joined(separator: "\n")
    }

    func aiMessages(for action: CollectedItemAIAction, referenceDate: Date = Date()) -> [ChatMessage] {
        let formatter = ISO8601DateFormatter()
        let actionInstruction: String
        switch action {
        case .generateTitle:
            actionInstruction = "生成一个准确、简洁、不超过 24 个汉字的标题，只填写 title。"
        case .summarize:
            actionInstruction = "生成不超过 120 个汉字的摘要，只填写 summary。"
        case .extractTodos:
            actionInstruction = "提取明确可执行的待办事项，填写 todos；没有待办则返回空数组。"
        case .extractSchedule:
            actionInstruction = "提取有明确时间或可合理安排的日程，填写 schedule。缺少结束时间时默认持续 30 分钟。"
        case .polish:
            actionInstruction = "在不改变事实和语气的前提下润色正文，填写 polishedText。"
        }

        let systemPrompt = """
        你是 AcWork 收集箱的结构化处理器。\(actionInstruction)
        当前时间：\(formatter.string(from: referenceDate))
        严格返回 JSON，不要 Markdown 代码块或解释。必须使用以下完整结构，未使用字段填 null 或空数组：
        {"title":null,"summary":null,"polishedText":null,"todos":[],"schedule":[{"title":"标题","startAt":"ISO-8601","endAt":"ISO-8601","isAllDay":false}]}
        """
        let userPrompt = """
        标题：\(workflowTitle)
        来源：\(source.workflowDisplayName)
        标签：\(tags.joined(separator: "、"))
        正文：
        \(workflowBody)
        """

        return [
            ChatMessage(sessionId: "collected-item-ai", role: .system, content: systemPrompt),
            ChatMessage(sessionId: "collected-item-ai", role: .user, content: userPrompt)
        ]
    }

    private var workflowDescription: String {
        var parts = [workflowBody]
        if let originalURL, originalURL.isEmpty == false, workflowBody != originalURL {
            parts.append("原始链接：\(originalURL)")
        }
        if tags.isEmpty == false {
            parts.append("标签：\(tags.joined(separator: "、"))")
        }
        parts.append("来源：\(source.workflowDisplayName)")
        return parts.joined(separator: "\n\n")
    }

    init(sourceItem item: SourceItem) {
        let contentType = CollectedContentType(sourceType: item.type, originalURL: item.originalUrl, metadata: item.metadata)
        self.init(
            id: CollectedItemID(origin: .sourceItem, rawID: item.id),
            title: item.title,
            previewText: item.previewText ?? item.transcript ?? item.ocrText,
            content: CollectedContent(sourceItem: item, contentType: contentType),
            contentType: contentType,
            source: CollectionSource(sourceItem: item),
            sourceApplication: item.sourceApp,
            sourceDevice: item.metadata["sourceDevice"],
            originalURL: item.originalUrl,
            assetFileIDs: item.assetFileIds,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            processingStatus: ProcessingStatus(sourceStatus: item.status),
            isPinned: item.metadata["isPinned"] == "true",
            isFavorite: item.metadata["isFavorite"] == "true",
            tags: item.tags,
            projectID: item.metadata["projectID"],
            metadata: item.metadata
        )
    }

    init(clipboardItem item: ClipboardItem) {
        let contentType = CollectedContentType(clipboardType: item.type)
        var metadata: [String: String] = [:]
        metadata["useCount"] = "\(item.useCount)"
        metadata["isSensitive"] = item.isSensitive ? "true" : "false"
        metadata["visualHash"] = item.visualHash
        metadata["codeLanguage"] = item.codeLanguage

        self.init(
            id: CollectedItemID(origin: .clipboardItem, rawID: item.id),
            title: CollectedItem.clipboardTitle(for: item),
            previewText: item.textContent ?? item.content,
            content: CollectedContent(clipboardItem: item),
            contentType: contentType,
            source: CollectionSource(clipboardItem: item),
            sourceApplication: item.sourceApp,
            sourceDevice: item.sourceApp == "iPhone" ? "iPhone" : nil,
            originalURL: item.type == .url ? item.content : nil,
            assetFileIDs: item.type == .image ? item.content.map { [$0] } ?? [] : [],
            createdAt: item.createdAt,
            updatedAt: nil,
            processingStatus: .pending,
            isPinned: item.isPinned,
            isFavorite: false,
            tags: item.tags,
            projectID: nil,
            metadata: metadata
        )
    }

    private static func clipboardTitle(for item: ClipboardItem) -> String? {
        if item.type == .code, let language = item.codeLanguage {
            return "\(language) 代码片段"
        }
        if item.type == .url {
            return item.textContent ?? item.content
        }
        if let text = item.textContent ?? item.content, text.isEmpty == false {
            return String(text.prefix(50))
        }
        return item.type.displayName
    }
}

private extension CollectedContent {
    var workflowText: String? {
        switch self {
        case .text(let text):
            return text
        case .link(let urlString, let title):
            return title ?? urlString
        case .image(_, let caption), .video(_, let caption):
            return caption
        case .file(let path, let name):
            return name ?? path
        case .code(_, let text):
            return text
        case .richText(_, let plainText):
            return plainText
        case .audio(let transcript):
            return transcript
        case .document(let path, let preview):
            return preview ?? path
        case .unknown(let preview):
            return preview
        }
    }
}

private extension CollectedContentType {
    var workflowDisplayName: String {
        switch self {
        case .text: return "文本"
        case .link: return "链接"
        case .image: return "图片"
        case .file: return "文件"
        case .code: return "代码"
        case .richText: return "富文本"
        case .video: return "视频"
        case .audio: return "音频"
        case .document: return "文档"
        case .unknown: return "内容"
        }
    }
}

private extension CollectionSource {
    var workflowDisplayName: String {
        switch self {
        case .clipboard: return "剪贴板"
        case .phoneSync: return "手机同步"
        case .voice: return "语音"
        case .screenshot: return "截图"
        case .screenshotOCR: return "截图 OCR"
        case .agent: return "Agent"
        case .manual: return "手动录入"
        case .webpage: return "网页"
        case .file: return "文件"
        case .capsule: return "胶囊"
        case .imported: return "导入"
        }
    }
}

public extension SourceItem {
    init(clipboardItem item: ClipboardItem) {
        let sourceType: SourceType
        let originalURL: String?
        let assetFileIDs: [String]
        var metadata: [String: String] = [
            "clipboardSourceApp": item.sourceApp ?? "",
            "clipboardTimestamp": ISO8601DateFormatter().string(from: item.createdAt),
            "originClipboardItemID": item.id,
            "contentKind": item.type.rawValue
        ]

        switch item.type {
        case .text, .richText, .code:
            sourceType = .text
            originalURL = nil
            assetFileIDs = []
        case .image:
            sourceType = .image
            originalURL = nil
            assetFileIDs = item.content.map { [$0] } ?? []
        case .file:
            sourceType = .unknownFile
            originalURL = nil
            assetFileIDs = []
        case .url:
            sourceType = .webpage
            originalURL = item.content
            assetFileIDs = []
        case .video:
            sourceType = .video
            originalURL = nil
            assetFileIDs = []
        }

        metadata["htmlContent"] = item.htmlContent
        metadata["language"] = item.codeLanguage
        metadata["sourceDevice"] = item.sourceApp == "iPhone" ? "iPhone" : nil

        self.init(
            type: sourceType,
            source: .clipboard,
            status: .captured,
            title: CollectedItem(clipboardItem: item).title,
            contentPath: item.type == .file || item.type == .video ? item.content : nil,
            previewText: item.textContent ?? item.content,
            sourceApp: item.sourceApp,
            originalUrl: originalURL,
            tags: item.tags,
            assetFileIds: assetFileIDs,
            metadata: metadata,
            createdAt: item.createdAt
        )
    }

    init(collectedItem item: CollectedItem) {
        self.init(
            id: item.id.stableValue,
            type: SourceType(collectedContentType: item.contentType),
            source: SourceOrigin(collectionSource: item.source),
            status: item.processingStatus.sourceItemStatus,
            title: item.title,
            contentPath: item.compatibilityContentPath,
            previewText: item.previewText,
            ocrText: item.metadata["ocrText"],
            transcript: item.metadata["transcript"],
            sourceApp: item.sourceApplication,
            originalUrl: item.originalURL,
            tags: item.tags,
            assetFileIds: item.assetFileIDs,
            metadata: item.metadata.merging([
                "collectedItemID": item.id.stableValue,
                "collectedOrigin": item.id.origin.rawValue,
                "sourceDevice": item.sourceDevice ?? ""
            ]) { current, _ in current },
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
    }
}

private extension CollectedItem {
    var compatibilityContentPath: String? {
        switch content {
        case .file(let path, _), .video(let path, _), .document(let path, _):
            return path
        default:
            return nil
        }
    }
}

public extension SourceType {
    init(collectedContentType: CollectedContentType) {
        switch collectedContentType {
        case .text, .code, .richText:
            self = .text
        case .link:
            self = .webpage
        case .image:
            self = .image
        case .file, .unknown:
            self = .unknownFile
        case .video:
            self = .video
        case .audio:
            self = .audio
        case .document:
            self = .pdf
        }
    }
}

public extension SourceOrigin {
    init(collectionSource: CollectionSource) {
        switch collectionSource {
        case .clipboard, .phoneSync:
            self = .clipboard
        case .voice:
            self = .voice
        case .screenshot:
            self = .screenshot
        case .screenshotOCR:
            self = .screenshotOCR
        case .agent:
            self = .agent
        case .manual:
            self = .manual
        case .webpage:
            self = .webpage
        case .file:
            self = .file
        case .capsule:
            self = .capsule
        case .imported:
            self = .imported
        }
    }
}

// MARK: - SourceItem 枚举

public enum SourceType: String, Codable, Sendable, Hashable, CaseIterable {
    case text
    case image
    case audio
    case video
    case pdf
    case docx
    case screenshot
    case webpage
    case unknownFile

    public static var allCases: [SourceType] {
        [.text, .image, .audio, .video, .pdf, .docx, .screenshot, .webpage, .unknownFile]
    }

    public var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .audio: return "音频"
        case .video: return "视频"
        case .pdf: return "PDF"
        case .docx: return "文档"
        case .screenshot: return "截图"
        case .webpage: return "网页"
        case .unknownFile: return "文件"
        }
    }

    public var iconName: String {
        switch self {
        case .text: return "text.quote"
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .pdf: return "doc.richtext"
        case .docx: return "doc"
        case .screenshot: return "camera.viewfinder"
        case .webpage: return "globe"
        case .unknownFile: return "doc.questionmark"
        }
    }

    public var color: Color {
        switch self {
        case .text: return .blue
        case .image: return .green
        case .audio: return .orange
        case .video: return .purple
        case .pdf: return .red
        case .docx: return .cyan
        case .screenshot: return .pink
        case .webpage: return .indigo
        case .unknownFile: return .gray
        }
    }

    public var bgColor: Color {
        color.opacity(0.15)
    }

    public static func inferred(fromFileURL url: URL) -> SourceType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff":
            return .image
        case "pdf":
            return .pdf
        case "docx", "doc":
            return .docx
        case "txt", "md", "markdown":
            return .text
        default:
            return .unknownFile
        }
    }
}

public enum SourceOrigin: String, Codable, Sendable, Hashable, CaseIterable {
    case manual
    case clipboard
    case agent
    case screenshot
    case screenshotOCR
    case webpage
    case file
    case voice
    case capsule
    case imported

    public static var allCases: [SourceOrigin] {
        [.manual, .clipboard, .agent, .screenshot, .screenshotOCR, .webpage, .file, .voice, .capsule, .imported]
    }

    public var displayName: String {
        switch self {
        case .manual: return "手动输入"
        case .clipboard: return "剪贴板"
        case .agent: return "Agent"
        case .screenshot: return "截图"
        case .screenshotOCR: return "截图 OCR"
        case .webpage: return "网页"
        case .file: return "文件"
        case .voice: return "语音"
        case .capsule: return "胶囊"
        case .imported: return "导入"
        }
    }

    public var displayLabel: String {
        displayName
    }
}

public enum SourceItemStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case inbox
    case pending
    case capturing
    case captured
    case parsing
    case parsed
    case distilling
    case distilled
    case exporting
    case exported
    case archived
    case deleted

    public static var allCases: [SourceItemStatus] {
        [.inbox, .pending, .capturing, .captured, .parsing, .parsed,
         .distilling, .distilled, .exporting, .exported, .archived, .deleted]
    }

    public var displayName: String {
        switch self {
        case .inbox: return "收集箱"
        case .pending: return "待处理"
        case .capturing: return "采集中"
        case .captured: return "已采集"
        case .parsing: return "解析中"
        case .parsed: return "已解析"
        case .distilling: return "蒸馏中"
        case .distilled: return "已蒸馏"
        case .exporting: return "导出中"
        case .exported: return "已导出"
        case .archived: return "已归档"
        case .deleted: return "已删除"
        }
    }

    public var displayLabel: String {
        displayName
    }

    public var tagColor: Color {
        switch self {
        case .inbox: return .blue
        case .pending: return .orange
        case .capturing: return .cyan
        case .captured: return .green
        case .parsing: return .purple
        case .parsed: return .teal
        case .distilling: return .indigo
        case .distilled: return .mint
        case .exporting: return .pink
        case .exported: return .green
        case .archived: return .gray
        case .deleted: return .red
        }
    }

    public var tagBgColor: Color {
        tagColor.opacity(0.15)
    }

    /// 是否为终态
    public var isTerminal: Bool {
        switch self {
        case .distilled, .exported, .archived, .deleted: return true
        default: return false
        }
    }
}

public extension CollectedContentType {
    init(sourceType: SourceType, originalURL: String?, metadata: [String: String]) {
        if metadata["contentKind"] == "code" || metadata["language"] != nil {
            self = .code
            return
        }
        if metadata["contentKind"] == "richText" {
            self = .richText
            return
        }
        if originalURL?.isEmpty == false || sourceType == .webpage {
            self = .link
            return
        }

        switch sourceType {
        case .text:
            self = .text
        case .image, .screenshot:
            self = .image
        case .audio:
            self = .audio
        case .video:
            self = .video
        case .pdf, .docx:
            self = .document
        case .webpage:
            self = .link
        case .unknownFile:
            self = .file
        }
    }

    init(clipboardType: ClipboardContentType) {
        switch clipboardType {
        case .text: self = .text
        case .image: self = .image
        case .file: self = .file
        case .url: self = .link
        case .richText: self = .richText
        case .code: self = .code
        case .video: self = .video
        }
    }
}

public extension CollectionSource {
    init(sourceItem item: SourceItem) {
        if item.source == .screenshot {
            self = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? .screenshotOCR
                : .screenshot
            return
        }

        self.init(sourceOrigin: item.source, metadata: item.metadata)
    }

    init(sourceOrigin: SourceOrigin, metadata: [String: String]) {
        if metadata["sourceDevice"] == "iPhone" || metadata["sourceKind"] == "phoneSync" {
            self = .phoneSync
            return
        }

        switch sourceOrigin {
        case .manual:
            self = .manual
        case .clipboard:
            self = .clipboard
        case .agent:
            self = .agent
        case .screenshot:
            self = .screenshot
        case .screenshotOCR:
            self = .screenshotOCR
        case .webpage:
            self = .webpage
        case .file:
            self = .file
        case .voice:
            self = .voice
        case .capsule:
            self = .capsule
        case .imported:
            self = .imported
        }
    }

    init(clipboardItem item: ClipboardItem) {
        if item.sourceApp == "iPhone" {
            self = .phoneSync
        } else {
            self = .clipboard
        }
    }
}

public extension ProcessingStatus {
    init(sourceStatus: SourceItemStatus) {
        switch sourceStatus {
        case .inbox, .pending, .captured:
            self = .pending
        case .capturing, .parsing, .distilling, .exporting:
            self = .processing
        case .parsed:
            self = .captured
        case .distilled:
            self = .refined
        case .archived:
            self = .archived
        case .exported:
            self = .exported
        case .deleted:
            self = .deleted
        }
    }

    var sourceItemStatus: SourceItemStatus {
        switch self {
        case .pending:
            return .pending
        case .captured:
            return .captured
        case .processing:
            return .parsing
        case .refined:
            return .distilled
        case .archived:
            return .archived
        case .exported:
            return .exported
        case .deleted:
            return .deleted
        }
    }
}

public extension CollectedContent {
    init(sourceItem item: SourceItem, contentType: CollectedContentType) {
        let preview = item.previewText ?? item.transcript ?? item.ocrText
        switch contentType {
        case .text:
            self = .text(preview)
        case .link:
            self = .link(urlString: item.originalUrl, title: item.title)
        case .image:
            self = .image(assetID: item.assetFileIds.first, caption: preview)
        case .file:
            self = .file(path: item.contentPath, name: item.title)
        case .code:
            self = .code(language: item.metadata["language"], text: preview)
        case .richText:
            self = .richText(html: item.metadata["htmlContent"], plainText: preview)
        case .video:
            self = .video(path: item.contentPath, caption: preview)
        case .audio:
            self = .audio(transcript: item.transcript ?? preview)
        case .document:
            self = .document(path: item.contentPath, preview: preview)
        case .unknown:
            self = .unknown(preview: preview)
        }
    }

    init(clipboardItem item: ClipboardItem) {
        switch item.type {
        case .text:
            self = .text(item.textContent ?? item.content)
        case .image:
            self = .image(assetID: item.content, caption: item.textContent)
        case .file:
            self = .file(path: item.content, name: item.textContent)
        case .url:
            self = .link(urlString: item.content, title: item.textContent)
        case .richText:
            self = .richText(html: item.htmlContent ?? item.content, plainText: item.textContent)
        case .code:
            self = .code(language: item.codeLanguage, text: item.textContent ?? item.content)
        case .video:
            self = .video(path: item.content, caption: item.textContent)
        }
    }
}
