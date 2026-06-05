import CoreGraphics
import Foundation

public enum ClipboardCardPresentation {
    public static func thumbnailHeight(for item: ClipboardItem) -> CGFloat {
        item.type == .image ? ContentCardPresentation.thumbnailHeight : 0
    }

    public static func previewLineLimit(for item: ClipboardItem) -> Int {
        switch item.type {
        case .image:
            return 1
        case .text:
            return 2
        case .file, .url:
            return 2
        }
    }

    public static func previewText(for item: ClipboardItem) -> String {
        if item.type == .image {
            if let text = item.textContent, text.isEmpty == false {
                return text
            }
            return "图片"
        }

        if let text = item.textContent, text.isEmpty == false {
            return text
        }
        if let content = item.content, content.isEmpty == false {
            return content
        }
        return "无内容"
    }

    public static func subtitleText(for item: ClipboardItem) -> String {
        let source = item.sourceApp?.isEmpty == false ? item.sourceApp! : "未知来源"
        return "\(source) · \(item.type.displayName)"
    }

    public static func pinFeedbackTitle(isPinned: Bool) -> String {
        isPinned ? "已固定" : "Pin"
    }
}

public enum ContentCardPresentation {
    public static let cornerRadius: CGFloat = 18
    public static let cardMinHeight: CGFloat = 274
    public static let imageCardMinHeight: CGFloat = 274
    public static let previewRadius: CGFloat = 16
    public static let cardSpacing: CGFloat = 12
    public static let innerPadding: CGFloat = 14
    public static let headerMinHeight: CGFloat = 34
    public static let thumbnailHeight: CGFloat = 140
    public static let textPreviewHeight: CGFloat = 140
    public static let metadataHeight: CGFloat = 24
    public static let materialMetadataMinHeight: CGFloat = 48
    public static let compactHeaderBudget: CGFloat = 34
    public static let compactFooterBudget: CGFloat = 18

    public static func previewHeight(for type: SourceType, text: String) -> CGFloat {
        switch type {
        case .image, .screenshot:
            return thumbnailHeight
        case .text:
            return dynamicTextPreviewHeight(text, base: textPreviewHeight, ceiling: 188)
        case .audio:
            return dynamicTextPreviewHeight(text, base: thumbnailHeight, ceiling: 176)
        case .video:
            return dynamicTextPreviewHeight(text, base: 132, ceiling: 164)
        case .pdf, .docx, .unknownFile:
            return dynamicTextPreviewHeight(text, base: 144, ceiling: 176)
        case .webpage:
            return dynamicTextPreviewHeight(text, base: 140, ceiling: 168)
        }
    }

    public static func cardHeight(for type: SourceType, text: String) -> CGFloat {
        let previewHeight = previewHeight(for: type, text: text)
        let fixedChrome = innerPadding * 2 + headerMinHeight + cardSpacing * 2 + materialMetadataMinHeight
        return max(cardMinHeight, previewHeight + fixedChrome)
    }

    public static func previewHeight(for type: ClipboardContentType, text: String) -> CGFloat {
        previewHeight(for: type.sourceTypeEquivalent, text: text)
    }

    public static func cardHeight(for type: ClipboardContentType, text: String) -> CGFloat {
        cardHeight(for: type.sourceTypeEquivalent, text: text)
    }

    private static func dynamicTextPreviewHeight(_ text: String, base: CGFloat, ceiling: CGFloat) -> CGFloat {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return base }

        let newlineCount = normalized.reduce(into: 0) { count, character in
            if character == "\n" { count += 1 }
        }
        let lengthBuckets = min(4, normalized.count / 60)
        let lineBuckets = min(4, newlineCount)
        let extraBuckets = max(lengthBuckets, lineBuckets)
        let extraHeight = CGFloat(extraBuckets) * 12
        return min(ceiling, max(base, base + extraHeight))
    }
}

public extension ClipboardContentType {
    var sourceTypeEquivalent: SourceType {
        switch self {
        case .image:
            return .image
        case .text:
            return .text
        case .file:
            return .unknownFile
        case .url:
            return .webpage
        }
    }
}
