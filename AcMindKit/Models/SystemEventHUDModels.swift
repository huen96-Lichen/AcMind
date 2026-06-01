import Foundation

public enum SystemEventKind: String, CaseIterable, Codable, Sendable {
    case volume
    case brightness
    case keyboardBacklight
    case microphone
    case sayInput
    case screenshot
}

public enum SystemEventHUDPolicy {
    public static func allowsReplacement(for incomingKind: SystemEventKind, sayInputLocked: Bool) -> Bool {
        guard sayInputLocked else { return true }
        return incomingKind == .sayInput
    }
}
