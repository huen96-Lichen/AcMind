import Foundation

public struct MaterialCardMetadata: Equatable, Sendable {
    public let title: String
    public let kind: String
    public let source: String
    public let timestamp: Date

    public init(title: String, kind: String, source: String, timestamp: Date) {
        self.title = title
        self.kind = kind
        self.source = source
        self.timestamp = timestamp
    }

    public var subtitle: String {
        "\(source) · \(kind)"
    }
}

public enum MaterialCardMetadataFactory {
    public static func clipboard(item: ClipboardItem) -> MaterialCardMetadata {
        MaterialCardMetadata(
            title: ClipboardCardPresentation.previewText(for: item),
            kind: item.type.displayName,
            source: item.sourceApp?.isEmpty == false ? item.sourceApp! : "未知来源",
            timestamp: item.createdAt
        )
    }

    public static func source(
        title: String?,
        kind: String,
        source: String?,
        timestamp: Date
    ) -> MaterialCardMetadata {
        MaterialCardMetadata(
            title: title?.isEmpty == false ? title! : "未命名",
            kind: kind,
            source: source?.isEmpty == false ? source! : "未知来源",
            timestamp: timestamp
        )
    }
}
