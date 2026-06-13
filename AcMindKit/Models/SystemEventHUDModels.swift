import Foundation

public enum SystemEventKind: String, CaseIterable, Codable, Sendable {
    case volume
    case brightness
    case keyboardBacklight
    case microphone
    case sayInput
    case screenshot
}

public enum SystemEventHUDPriority: Int, CaseIterable, Codable, Sendable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: SystemEventHUDPriority, rhs: SystemEventHUDPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct SystemEventHUDRequest: Sendable, Equatable {
    public var kind: SystemEventKind
    public var title: String?
    public var detail: String?
    public var progress: Double?
    public var duration: TimeInterval
    public var queuedAt: Date

    public init(
        kind: SystemEventKind,
        title: String? = nil,
        detail: String? = nil,
        progress: Double? = nil,
        duration: TimeInterval = 1.5,
        queuedAt: Date = Date()
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.progress = progress
        self.duration = duration
        self.queuedAt = queuedAt
    }

    public var priority: SystemEventHUDPriority {
        kind.hudPriority
    }
}

public extension SystemEventKind {
    var hudPriority: SystemEventHUDPriority {
        switch self {
        case .sayInput:
            return .critical
        case .screenshot:
            return .high
        case .microphone:
            return .medium
        case .volume, .brightness, .keyboardBacklight:
            return .low
        }
    }
}

public enum SystemEventHUDPolicy {
    public static func allowsReplacement(for incomingKind: SystemEventKind, sayInputLocked: Bool) -> Bool {
        guard sayInputLocked else { return true }
        return incomingKind == .sayInput
    }

    public static func shouldInterrupt(currentKind: SystemEventKind, incomingKind: SystemEventKind, sayInputLocked: Bool) -> Bool {
        guard allowsReplacement(for: incomingKind, sayInputLocked: sayInputLocked) else {
            return false
        }

        if incomingKind == currentKind {
            return true
        }

        return incomingKind.hudPriority > currentKind.hudPriority
    }

    public static func orderedPendingRequests(_ requests: [SystemEventHUDRequest]) -> [SystemEventHUDRequest] {
        requests.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.queuedAt < rhs.queuedAt
        }
    }
}
