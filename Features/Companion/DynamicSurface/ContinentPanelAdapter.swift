import AppKit
import AcMindKit

@MainActor
final class ContinentPanelAdapter: DynamicSurfacePanelAdapter {
    private weak var panel: NotchPanel?

    @MainActor
    init(panel: NotchPanel) {
        self.panel = panel
    }

    @MainActor
    func showCompact(on screen: NSScreen?, at point: CGPoint?, animated: Bool) {
        panel?.showCompact(on: screen, at: point, animated: animated)
        panel?.alphaValue = 1.0
    }

    @MainActor
    func showExpanded(on screen: NSScreen?, at point: CGPoint?, animated: Bool) {
        panel?.showExpanded(on: screen, at: point, animated: animated)
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
        case .capsuleDockPreview, .draggingContinent:
            panel?.alphaValue = 0.86
        case .continentLeavingTopDock:
            panel?.alphaValue = 0.62
        default:
            panel?.alphaValue = 1.0
        }
    }

    @MainActor
    func endDragPreview() {
        panel?.alphaValue = 1.0
    }
}
