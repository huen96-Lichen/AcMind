import Foundation
import AppKit

/// Shared frame-based docking rules for the desktop capsule and the companion notch panel.
public enum CompanionDockingRules {
    /// Maximum distance from the screen top before the desktop capsule should snap into the notch.
    public static let snapThreshold: CGFloat = 18

    public static func shouldDockDesktopCapsuleToNotch(frame: CGRect, screenFrame: CGRect) -> Bool {
        let distanceToTop = screenFrame.maxY - frame.maxY
        return distanceToTop <= snapThreshold
    }
}
