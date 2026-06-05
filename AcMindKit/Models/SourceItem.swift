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
    case webpage
    case file
    case voice
    case capsule
    case imported

    public static var allCases: [SourceOrigin] {
        [.manual, .clipboard, .agent, .screenshot, .webpage, .file, .voice, .capsule, .imported]
    }

    public var displayName: String {
        switch self {
        case .manual: return "手动输入"
        case .clipboard: return "剪贴板"
        case .agent: return "Agent"
        case .screenshot: return "截图"
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
