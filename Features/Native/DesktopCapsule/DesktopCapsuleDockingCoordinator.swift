import AppKit
import Foundation
import AcMindKit

@MainActor
final class DesktopCapsuleDockingCoordinator {
    static let shared = DesktopCapsuleDockingCoordinator()

    func handleWindowMoved(_ panel: DesktopCapsulePanel) {
        guard panel.isVisible, let screen = panel.screen ?? NSScreen.main else { return }

        guard CompanionDockingRules.shouldDockDesktopCapsuleToNotch(
            frame: panel.frame,
            screenFrame: screen.visibleFrame
        ) else { return }

        panel.dockToNotch()
        DispatchQueue.main.async {
            NotchPanel.shared.showCompact(on: screen)
        }
    }
}
