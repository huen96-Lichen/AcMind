import Foundation

public struct CleaningRule: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var isEnabled: Bool
    public var matchType: MatchType
    public var pattern: String
    public var action: Action
    public var replacement: String?

    public enum MatchType: String, Codable, Sendable {
        case contains
        case regex
        case appBundle
        case appName
    }

    public enum Action: String, Codable, Sendable {
        case ignore
        case clean
        case replace
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        isEnabled: Bool = true,
        matchType: MatchType,
        pattern: String,
        action: Action,
        replacement: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.matchType = matchType
        self.pattern = pattern
        self.action = action
        self.replacement = replacement
    }
}
