import Foundation
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

// MARK: - RecordingPolishMode（录音润色模式）

public enum RecordingPolishMode: String, Codable, Sendable, Hashable, CaseIterable {
    case none
    case raw
    case light
    case structured
    case formal

    public static var allCases: [RecordingPolishMode] {
        [.none, .raw, .light, .structured, .formal]
    }

    public var displayName: String {
        switch self {
        case .none: return "不润色"
        case .raw: return "原文整理"
        case .light: return "轻度润色"
        case .structured: return "结构化整理"
        case .formal: return "正式表达"
        }
    }
    
    /// 转换到语音润色层使用的 VoicePolishMode
    public var toVoicePolishMode: VoicePolishMode {
        switch self {
        case .none: return .none
        case .raw: return .raw
        case .light: return .light
        case .structured: return .structured
        case .formal: return .formal
        }
    }
}

// MARK: - ClipboardItem（剪贴板条目）

/// 剪贴板历史条目
/// 对齐迁移前的 clipboard_items 表
public struct ClipboardItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var type: ClipboardContentType
    public var content: String?
    public var textContent: String?
    public var sourceApp: String?
    public var isPinned: Bool
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        type: ClipboardContentType = .text,
        content: String? = nil,
        textContent: String? = nil,
        sourceApp: String? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.textContent = textContent
        self.sourceApp = sourceApp
        self.isPinned = isPinned
        self.createdAt = createdAt
    }
}

public enum ClipboardContentType: String, Codable, Sendable, Hashable, CaseIterable {
    case text
    case image
    case file
    case url

    public static var allCases: [ClipboardContentType] { [.text, .image, .file, .url] }

    public var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .file: return "文件"
        case .url: return "链接"
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
    
    public init?(rawValue: String) {
        switch rawValue {
        case "fullscreen": self = .fullscreen
        case "area": self = .area
        case "window": self = .window
        default: return nil
        }
    }
}

// MARK: - ShelfItem（文件架条目）

/// 文件临时架条目
/// 对齐迁移前的 shelf_items 表
public struct ShelfItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var sourceItemId: String?
    public var filePath: String?
    public var label: String?
    public var status: ShelfItemStatus
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceItemId: String? = nil,
        filePath: String? = nil,
        label: String? = nil,
        status: ShelfItemStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceItemId = sourceItemId
        self.filePath = filePath
        self.label = label
        self.status = status
        self.createdAt = createdAt
    }
}

public enum ShelfItemStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case processing
    case completed
    case failed

    public static var allCases: [ShelfItemStatus] { [.pending, .processing, .completed, .failed] }
}

// MARK: - Import Types（导入相关）

/// 导入任务
/// 对齐迁移前的 import_tasks 表
public struct ImportTask: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var sourcePath: String
    public var status: ProcessJobStatus
    public var importedCount: Int
    public var errorCount: Int
    public var error: String?
    public let createdAt: Date
    public var finishedAt: Date?

    public init(
        id: String = UUID().uuidString,
        sourcePath: String,
        status: ProcessJobStatus = .queued,
        importedCount: Int = 0,
        errorCount: Int = 0,
        error: String? = nil,
        createdAt: Date = Date(),
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.status = status
        self.importedCount = importedCount
        self.errorCount = errorCount
        self.error = error
        self.createdAt = createdAt
        self.finishedAt = finishedAt
    }
}
