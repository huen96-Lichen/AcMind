import Foundation

public enum HotCornerPosition: String, Codable, CaseIterable, Sendable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .topLeft: return "左上角"
        case .topRight: return "右上角"
        case .bottomLeft: return "左下角"
        case .bottomRight: return "右下角"
        }
    }
}

public enum HotCornerAction: Codable, Hashable, Sendable, Equatable {
    case none
    case openApp(bundleIdentifier: String)
    case openURL(urlString: String)
    case toggleFeature(featureIdentifier: String)
    case openInternalRoute(routeIdentifier: String)
    case showPanel(panelIdentifier: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case bundleIdentifier
        case urlString
        case featureIdentifier
        case routeIdentifier
        case panelIdentifier
    }

    private enum Kind: String, Codable {
        case none
        case openApp
        case openURL
        case toggleFeature
        case openInternalRoute
        case showPanel
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.none, forKey: .kind)
        case let .openApp(bundleIdentifier):
            try container.encode(Kind.openApp, forKey: .kind)
            try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        case let .openURL(urlString):
            try container.encode(Kind.openURL, forKey: .kind)
            try container.encode(urlString, forKey: .urlString)
        case let .toggleFeature(featureIdentifier):
            try container.encode(Kind.toggleFeature, forKey: .kind)
            try container.encode(featureIdentifier, forKey: .featureIdentifier)
        case let .openInternalRoute(routeIdentifier):
            try container.encode(Kind.openInternalRoute, forKey: .kind)
            try container.encode(routeIdentifier, forKey: .routeIdentifier)
        case let .showPanel(panelIdentifier):
            try container.encode(Kind.showPanel, forKey: .kind)
            try container.encode(panelIdentifier, forKey: .panelIdentifier)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .none:
            self = .none
        case .openApp:
            self = .openApp(bundleIdentifier: try container.decode(String.self, forKey: .bundleIdentifier))
        case .openURL:
            self = .openURL(urlString: try container.decode(String.self, forKey: .urlString))
        case .toggleFeature:
            self = .toggleFeature(featureIdentifier: try container.decode(String.self, forKey: .featureIdentifier))
        case .openInternalRoute:
            self = .openInternalRoute(routeIdentifier: try container.decode(String.self, forKey: .routeIdentifier))
        case .showPanel:
            self = .showPanel(panelIdentifier: try container.decode(String.self, forKey: .panelIdentifier))
        }
    }
}

public struct HotCornerBinding: Codable, Hashable, Sendable, Equatable {
    public var isEnabled: Bool
    public var hoverDelay: TimeInterval
    public var action: HotCornerAction

    public init(
        isEnabled: Bool = true,
        hoverDelay: TimeInterval = 1.5,
        action: HotCornerAction = .none
    ) {
        self.isEnabled = isEnabled
        self.hoverDelay = hoverDelay
        self.action = action
    }
}

public struct HotCornerSettings: Codable, Hashable, Sendable, Equatable {
    public var isEnabled: Bool
    public var cornerSize: CGFloat
    public var bindings: [HotCornerPosition: HotCornerBinding]

    public init(
        isEnabled: Bool = true,
        cornerSize: CGFloat = 24,
        bindings: [HotCornerPosition: HotCornerBinding] = HotCornerSettings.defaultBindings()
    ) {
        self.isEnabled = isEnabled
        self.cornerSize = cornerSize
        self.bindings = bindings
    }

    public static func defaultBindings() -> [HotCornerPosition: HotCornerBinding] {
        [
            .topLeft: HotCornerBinding(),
            .topRight: HotCornerBinding(),
            .bottomLeft: HotCornerBinding(),
            .bottomRight: HotCornerBinding()
        ]
    }

    public static var defaultSettings: HotCornerSettings {
        HotCornerSettings()
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case cornerSize
        case bindings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        cornerSize = try container.decodeIfPresent(CGFloat.self, forKey: .cornerSize) ?? 24
        bindings = try container.decodeIfPresent([HotCornerPosition: HotCornerBinding].self, forKey: .bindings) ?? HotCornerSettings.defaultBindings()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(cornerSize, forKey: .cornerSize)
        try container.encode(bindings, forKey: .bindings)
    }
}
