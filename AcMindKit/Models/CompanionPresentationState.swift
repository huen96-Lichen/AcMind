import Foundation

public enum CompanionPresentationState: Equatable, Sendable {
    case hidden
    case compact
    case expanding
    case expanded
    case collapsing
    case blockedClose
    case transientHUD

    public var isExpandedVisual: Bool {
        switch self {
        case .expanding, .expanded, .blockedClose:
            return true
        case .hidden, .compact, .collapsing, .transientHUD:
            return false
        }
    }

    public var targetFrameIsExpanded: Bool {
        isExpandedVisual
    }

    public var animationDuration: TimeInterval {
        switch self {
        case .hidden:
            return 0.15
        case .compact:
            return 0.24
        case .expanding, .expanded:
            return 0.32
        case .collapsing:
            return 0.24
        case .blockedClose:
            return 0.18
        case .transientHUD:
            return 0.2
        }
    }
}

public typealias NotchPresentationState = CompanionPresentationState
