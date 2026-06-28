import Foundation
import SwiftUI
import CoreGraphics

// MARK: - RecordingStatus（录音状态）

public enum RecordingStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case idle
    case recording
    case processing
    case error

    public static var allCases: [RecordingStatus] {
        [.idle, .recording, .processing, .error]
    }

    public var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .recording: return "录音中"
        case .processing: return "处理中"
        case .error: return "错误"
        }
    }
}

// MARK: - ClipboardItem（剪贴板条目）

/// 剪贴板历史条目
/// 对齐旧版 clipboard_items 表
public struct ClipboardItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var type: ClipboardContentType
    public var content: String?
    public var textContent: String?
    public var sourceApp: String?
    public var isPinned: Bool
    public let createdAt: Date
    public var htmlContent: String?
    public var codeLanguage: String?
    public var isSensitive: Bool
    public var tags: [String]
    public var useCount: Int
    public var visualHash: String?

    public init(
        id: String = UUID().uuidString,
        type: ClipboardContentType = .text,
        content: String? = nil,
        textContent: String? = nil,
        sourceApp: String? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        htmlContent: String? = nil,
        codeLanguage: String? = nil,
        isSensitive: Bool = false,
        tags: [String] = [],
        useCount: Int = 0,
        visualHash: String? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.textContent = textContent
        self.sourceApp = sourceApp
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.htmlContent = htmlContent
        self.codeLanguage = codeLanguage
        self.isSensitive = isSensitive
        self.tags = tags
        self.useCount = useCount
        self.visualHash = visualHash
    }
}

public enum ClipboardContentType: String, Codable, Sendable, Hashable, CaseIterable {
    case text
    case image
    case file
    case url
    case richText
    case code
    case video

    public static var allCases: [ClipboardContentType] { [.text, .image, .file, .url, .richText, .code, .video] }

    public var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .file: return "文件"
        case .url: return "链接"
        case .richText: return "富文本"
        case .code: return "代码"
        case .video: return "视频"
        }
    }

    public var icon: String {
        switch self {
        case .text: return "text.quote"
        case .image: return "photo"
        case .file: return "doc"
        case .url: return "link"
        case .richText: return "doc.richtext"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .video: return "video"
        }
    }

    public var color: Color {
        switch self {
        case .text: return .blue
        case .image: return .green
        case .file: return .orange
        case .url: return .purple
        case .richText: return .pink
        case .code: return .cyan
        case .video: return .red
        }
    }
}

public struct ClipboardFilter: Sendable, Equatable {
    public let contentType: ClipboardContentType?
    public let searchQuery: String?
    public let limit: Int?

    public init(contentType: ClipboardContentType? = nil, searchQuery: String? = nil, limit: Int? = nil) {
        self.contentType = contentType
        self.searchQuery = searchQuery
        self.limit = limit
    }
}

// MARK: - CaptureResult（采集结果）

/// 采集操作的统一返回类型
public struct CaptureResult: Sendable, Equatable {
    public let sourceItem: SourceItem
    public let assetFiles: [AssetFile]

    public init(sourceItem: SourceItem, assetFiles: [AssetFile] = []) {
        self.sourceItem = sourceItem
        self.assetFiles = assetFiles
    }
}

public enum ScreenshotMode: String, Sendable, Hashable, Equatable {
    case fullscreen = "fullscreen"
    case area = "area"
    case window = "window"
    case scroll = "scroll"

    public var displayName: String {
        switch self {
        case .fullscreen: return "全屏"
        case .area: return "区域"
        case .window: return "窗口"
        case .scroll: return "滚动"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "fullscreen": self = .fullscreen
        case "area": self = .area
        case "window": self = .window
        case "scroll": self = .scroll
        default: return nil
        }
    }
}
