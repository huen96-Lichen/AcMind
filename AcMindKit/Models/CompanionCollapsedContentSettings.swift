import Foundation

public enum CompanionCollapsedContentMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case currentStatus
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .currentStatus: return "当前状态"
        case .custom: return "自定义内容"
        }
    }
}

public struct CompanionCollapsedContentSettings: Codable, Equatable, Sendable {
    public var mode: CompanionCollapsedContentMode
    public var customLabel: String
    public var customTitle: String
    public var customSubtitle: String
    public var customSymbol: String

    public init(
        mode: CompanionCollapsedContentMode = .currentStatus,
        customLabel: String = "当前状态",
        customTitle: String = "待命",
        customSubtitle: String = "可自定义展示内容",
        customSymbol: String = "sparkles"
    ) {
        self.mode = mode
        self.customLabel = customLabel
        self.customTitle = customTitle
        self.customSubtitle = customSubtitle
        self.customSymbol = customSymbol
    }

    public static let `default` = CompanionCollapsedContentSettings()
}

public enum CompanionCollapsedContentStorage {
    public static let key = "AppSettings.companionCollapsedContent"
}

public extension Notification.Name {
    static let companionCollapsedContentSettingsChanged = Notification.Name("companion.collapsedContentSettingsChanged")
}
