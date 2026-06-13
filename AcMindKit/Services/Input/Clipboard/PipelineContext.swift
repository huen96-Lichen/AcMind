import Foundation
import AppKit

public enum InputChainSource: String, Codable, Sendable, Equatable {
    case clipboard
    case recordingHotkey
}

public enum InputChainPhase: String, Codable, Sendable, Equatable {
    case idle
    case processing
    case listening
    case ignored
    case succeeded
    case failed
}

public struct InputChainStatusSnapshot: Codable, Sendable, Equatable {
    public let source: InputChainSource
    public let phase: InputChainPhase
    public let stepLabel: String
    public let detail: String
    public let activeControlCount: Int
    public let nextActionTitle: String?
    public let lastErrorMessage: String?
    public let updatedAt: Date

    public init(
        source: InputChainSource,
        phase: InputChainPhase,
        stepLabel: String,
        detail: String,
        activeControlCount: Int = 0,
        nextActionTitle: String? = nil,
        lastErrorMessage: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.source = source
        self.phase = phase
        self.stepLabel = stepLabel
        self.detail = detail
        self.activeControlCount = activeControlCount
        self.nextActionTitle = nextActionTitle
        self.lastErrorMessage = lastErrorMessage
        self.updatedAt = updatedAt
    }
}

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
