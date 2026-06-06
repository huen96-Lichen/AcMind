import Foundation
import AppKit

public struct PipelineContext: Sendable {
    public var rawContent: RawClipboardContent
    public var item: ClipboardItem?
    public var shouldIgnore: Bool = false
    public var shouldReplace: Bool = false
    public var existingItemId: String?

    public init(rawContent: RawClipboardContent) {
        self.rawContent = rawContent
    }
}

public struct RawClipboardContent: Sendable {
    public let changeCount: Int
    public let sourceApp: String?
    public let timestamp: Date
    public let textContent: String?
    public let htmlContent: String?
    public let imageData: Data?
    public let fileURLs: [String]?

    public init(
        changeCount: Int,
        sourceApp: String?,
        timestamp: Date = Date(),
        textContent: String? = nil,
        htmlContent: String? = nil,
        imageData: Data? = nil,
        fileURLs: [String]? = nil
    ) {
        self.changeCount = changeCount
        self.sourceApp = sourceApp
        self.timestamp = timestamp
        self.textContent = textContent
        self.htmlContent = htmlContent
        self.imageData = imageData
        self.fileURLs = fileURLs
    }
}
