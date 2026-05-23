import Foundation
import AppKit

// MARK: - Screen Corner

public enum ScreenCorner: String, Codable, CaseIterable, Sendable, Identifiable {
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

    public var shortName: String {
        switch self {
        case .topLeft: return "左上"
        case .topRight: return "右上"
        case .bottomLeft: return "左下"
        case .bottomRight: return "右下"
        }
    }

    public var isTopEdge: Bool {
        self == .topLeft || self == .topRight
    }

    public var isLeftEdge: Bool {
        self == .topLeft || self == .bottomLeft
    }

    public static func corner(for point: CGPoint, in screenFrame: CGRect, hotZoneSize: CGFloat = 28) -> ScreenCorner? {
        let effectiveHotZone = max(12, min(hotZoneSize, min(screenFrame.width, screenFrame.height) * 0.35))

        let left = screenFrame.minX
        let right = screenFrame.maxX
        let bottom = screenFrame.minY
        let top = screenFrame.maxY

        let isNearLeft = point.x <= left + effectiveHotZone
        let isNearRight = point.x >= right - effectiveHotZone
        let isNearTop = point.y >= top - effectiveHotZone
        let isNearBottom = point.y <= bottom + effectiveHotZone

        if isNearLeft && isNearTop { return .topLeft }
        if isNearRight && isNearTop { return .topRight }
        if isNearLeft && isNearBottom { return .bottomLeft }
        if isNearRight && isNearBottom { return .bottomRight }
        return nil
    }

    public static func roundedCorner(
        for point: CGPoint,
        in screenFrame: CGRect,
        radius: CGFloat = 28
    ) -> ScreenCorner? {
        let effectiveRadius = max(8, min(radius, min(screenFrame.width, screenFrame.height) * 0.35))
        let candidates: [(ScreenCorner, CGPoint)] = [
            (.topLeft, CGPoint(x: screenFrame.minX, y: screenFrame.maxY)),
            (.topRight, CGPoint(x: screenFrame.maxX, y: screenFrame.maxY)),
            (.bottomLeft, CGPoint(x: screenFrame.minX, y: screenFrame.minY)),
            (.bottomRight, CGPoint(x: screenFrame.maxX, y: screenFrame.minY))
        ]

        for (corner, center) in candidates {
            let dx = point.x - center.x
            let dy = point.y - center.y
            if dx * dx + dy * dy <= effectiveRadius * effectiveRadius {
                return corner
            }
        }

        return nil
    }
}

// MARK: - Corner Trigger Target

public enum CornerTriggerTargetKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case builtInFeature
    case application

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .builtInFeature: return "内置功能"
        case .application: return "打开应用"
        }
    }
}

public enum CornerBuiltInAction: String, Codable, CaseIterable, Sendable, Identifiable {
    case showMainWindow
    case showDynamicSurface
    case showAgent
    case showInbox
    case showClipboard
    case showSchedule
    case showWorkbench
    case showCompanion
    case showConfiguration
    case captureScreenshot
    case showQuickNote
    case showVoicePanel

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .showMainWindow: return "显示主窗口"
        case .showDynamicSurface: return "打开灵动胶囊/大陆"
        case .showAgent: return "打开 Agent"
        case .showInbox: return "打开收集箱"
        case .showClipboard: return "打开剪贴板"
        case .showSchedule: return "打开日程"
        case .showWorkbench: return "打开工作台"
        case .showCompanion: return "打开说入法"
        case .showConfiguration: return "打开配置"
        case .captureScreenshot: return "截图"
        case .showQuickNote: return "快速文本"
        case .showVoicePanel: return "语音面板"
        }
    }
}

public struct CornerTriggerTarget: Codable, Equatable, Sendable {
    public var kind: CornerTriggerTargetKind
    public var builtInAction: CornerBuiltInAction?
    public var applicationName: String?
    public var applicationBundleIdentifier: String?
    public var applicationURL: URL?

    public init(
        kind: CornerTriggerTargetKind,
        builtInAction: CornerBuiltInAction? = nil,
        applicationName: String? = nil,
        applicationBundleIdentifier: String? = nil,
        applicationURL: URL? = nil
    ) {
        self.kind = kind
        self.builtInAction = builtInAction
        self.applicationName = applicationName
        self.applicationBundleIdentifier = applicationBundleIdentifier
        self.applicationURL = applicationURL
    }

    public static func builtIn(_ action: CornerBuiltInAction) -> CornerTriggerTarget {
        CornerTriggerTarget(kind: .builtInFeature, builtInAction: action)
    }

    public static func application(
        name: String,
        bundleIdentifier: String? = nil,
        url: URL? = nil
    ) -> CornerTriggerTarget {
        CornerTriggerTarget(
            kind: .application,
            applicationName: name,
            applicationBundleIdentifier: bundleIdentifier,
            applicationURL: url
        )
    }

    public var displayName: String {
        switch kind {
        case .builtInFeature:
            return builtInAction?.displayName ?? "未配置"
        case .application:
            if let applicationName, applicationName.isEmpty == false {
                return applicationName
            }
            if let applicationURL {
                return applicationURL.deletingPathExtension().lastPathComponent
            }
            return "未选择应用"
        }
    }
}

// MARK: - Corner Trigger Assignment

public struct CornerTriggerAssignment: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var target: CornerTriggerTarget

    public init(isEnabled: Bool = false, target: CornerTriggerTarget) {
        self.isEnabled = isEnabled
        self.target = target
    }

    public static func `default`(for corner: ScreenCorner) -> CornerTriggerAssignment {
        switch corner {
        case .topLeft:
            return CornerTriggerAssignment(isEnabled: false, target: .builtIn(.showDynamicSurface))
        case .topRight:
            return CornerTriggerAssignment(isEnabled: false, target: .builtIn(.showAgent))
        case .bottomLeft:
            return CornerTriggerAssignment(isEnabled: false, target: .builtIn(.captureScreenshot))
        case .bottomRight:
            return CornerTriggerAssignment(isEnabled: false, target: .builtIn(.showConfiguration))
        }
    }
}

// MARK: - Corner Trigger Settings

public struct CornerTriggerSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var corners: [ScreenCorner: CornerTriggerAssignment]
    public var desktopHintDisplayIDs: Set<String>

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case corners
        case desktopHintDisplayIDs
    }

    public init(
        isEnabled: Bool = false,
        corners: [ScreenCorner: CornerTriggerAssignment]? = nil,
        desktopHintDisplayIDs: Set<String>? = nil
    ) {
        self.isEnabled = isEnabled
        self.corners = corners ?? CornerTriggerSettings.defaultCorners
        self.desktopHintDisplayIDs = desktopHintDisplayIDs ?? CornerTriggerSettings.defaultDesktopHintDisplayIDs
    }

    public static var `default`: CornerTriggerSettings {
        CornerTriggerSettings()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        corners = try container.decodeIfPresent([ScreenCorner: CornerTriggerAssignment].self, forKey: .corners) ?? CornerTriggerSettings.defaultCorners
        desktopHintDisplayIDs = try container.decodeIfPresent(Set<String>.self, forKey: .desktopHintDisplayIDs) ?? CornerTriggerSettings.defaultDesktopHintDisplayIDs
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(corners, forKey: .corners)
        try container.encode(desktopHintDisplayIDs, forKey: .desktopHintDisplayIDs)
    }

    public subscript(corner: ScreenCorner) -> CornerTriggerAssignment {
        get {
            corners[corner] ?? .default(for: corner)
        }
        set {
            corners[corner] = newValue
        }
    }

    public var orderedCorners: [(corner: ScreenCorner, assignment: CornerTriggerAssignment)] {
        ScreenCorner.allCases.map { ($0, self[$0]) }
    }

    static var defaultCorners: [ScreenCorner: CornerTriggerAssignment] {
        Dictionary(uniqueKeysWithValues: ScreenCorner.allCases.map { ($0, .default(for: $0)) })
    }

    static var defaultDesktopHintDisplayIDs: Set<String> {
        Set(NSScreen.screens.map(displayIdentifier(for:)))
    }

    public func desktopHintDisplayEnabled(on screen: NSScreen) -> Bool {
        desktopHintDisplayIDs.contains(Self.displayIdentifier(for: screen))
    }

    private static func displayIdentifier(for screen: NSScreen) -> String {
        if let raw = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return raw.stringValue
        }
        return screen.localizedName
    }
}

// MARK: - Corner Trigger Storage

public enum CornerTriggerSettingsStore {
    public static let settingsDidChange = Notification.Name("AcMind.cornerTriggerSettingsDidChange")
    public static let storageKey = "AcMind.cornerTriggerSettings"

    public static func load(default defaultValue: CornerTriggerSettings = .default, userDefaults: UserDefaults = .standard) -> CornerTriggerSettings {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(CornerTriggerSettings.self, from: data) else {
            return defaultValue
        }
        return decoded
    }

    public static func save(_ settings: CornerTriggerSettings, userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: storageKey)
        NotificationCenter.default.post(name: settingsDidChange, object: nil)
    }
}
