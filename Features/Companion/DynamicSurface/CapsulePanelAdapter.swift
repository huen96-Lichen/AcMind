import AppKit
import AcMindKit

@MainActor
final class CapsulePanelAdapter: DynamicSurfacePanelAdapter {
    private weak var panel: DesktopCapsulePanel?

    @MainActor
    init(panel: DesktopCapsulePanel) {
        self.panel = panel
    }

    @MainActor
    func showCompact(on screen: NSScreen?, at point: CGPoint?, animated: Bool) {
        if let point {
            panel?.showCollapsed(on: screen, at: point, animated: animated)
        } else {
            panel?.showCollapsed(on: screen, at: nil, animated: animated)
        }
        panel?.alphaValue = 1.0
    }

    @MainActor
    func showExpanded(on screen: NSScreen?, at point: CGPoint?, animated: Bool) {
        panel?.showCollapsed(on: screen, at: point, animated: false)
        panel?.alphaValue = 1.0
    }

    @MainActor
    func hide(animated: Bool) {
        if animated {
            panel?.animator().alphaValue = 0
        }
        panel?.hide()
        panel?.alphaValue = 1.0
    }

    @MainActor
    func beginDragPreview() {
        panel?.alphaValue = 0.72
    }

    @MainActor
    func updateDragPreview(mouseLocation: CGPoint, phase: DynamicSurfaceDragPhase) {
        switch phase {
        case .capsuleDockPreview, .continentLeavingTopDock:
            panel?.alphaValue = 0.52
        case .draggingCapsule, .draggingContinent:
            panel?.alphaValue = 0.9
        default:
            panel?.alphaValue = 1.0
        }
    }

    @MainActor
    func endDragPreview() {
        panel?.alphaValue = 1.0
    }
}
