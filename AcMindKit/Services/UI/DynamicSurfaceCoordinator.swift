import Foundation
import Combine
import AppKit

public enum DynamicSurfaceKind: String {
    case capsule
    case continent
}

public enum DynamicSurfacePresentation: String {
    case compact
    case expanded
}

public enum DynamicSurfaceVisibilityState: String {
    case capsuleCompact
    case continentCompact
    case continentExpanded
}

public enum DynamicSurfaceDragPhase: Equatable {
    case idle
    case draggingCapsule
    case capsuleHoveringTopDock
    case capsuleDockPreview
    case draggingContinent
    case continentLeavingTopDock
    case committing
    case reverting
}

public enum DynamicSurfaceDockTarget: Equatable {
    case desktop(point: CGPoint, screenID: String)
    case topMenuBar(screenID: String)
}

@MainActor
public protocol DynamicSurfacePanelAdapter: AnyObject {
    func showCompact(on screen: NSScreen?, at point: CGPoint?, animated: Bool)
    func showExpanded(on screen: NSScreen?, at point: CGPoint?, animated: Bool)
    func hide(animated: Bool)
    func beginDragPreview()
    func updateDragPreview(mouseLocation: CGPoint, phase: DynamicSurfaceDragPhase)
    func endDragPreview()
}

public enum DynamicSurfaceTransitionReason: String {
    case startup
    case restore
    case manualCommand
    case dragCommit
    case dragRevert
    case longPress
    case capture
}

@MainActor
public final class DynamicSurfaceCoordinator: ObservableObject {
    public static let shared = DynamicSurfaceCoordinator()

    public static let topDockHotZoneHeight: CGFloat = 96
    public static let longPressDuration: TimeInterval = 0.38

    @Published public private(set) var surfaceKind: DynamicSurfaceKind = .capsule
    @Published public private(set) var presentation: DynamicSurfacePresentation = .compact
    @Published public private(set) var visibilityState: DynamicSurfaceVisibilityState = .capsuleCompact
    @Published public private(set) var dragPhase: DynamicSurfaceDragPhase = .idle
    @Published public private(set) var activeDockTarget: DynamicSurfaceDockTarget?
    @Published public private(set) var previewScreenID: String?
    @Published public private(set) var capsuleDesktopPosition: CGPoint?
    @Published public private(set) var continentTopDockScreenID: String?
    @Published public private(set) var preferredCapsuleScreenID: String?
    @Published public private(set) var preferredContinentScreenID: String?

    private var capsuleAdapter: DynamicSurfacePanelAdapter?
    private var continentAdapter: DynamicSurfacePanelAdapter?
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadPersistedState()
    }

    public func setPreferredCapsuleScreenID(_ screenID: String?) {
        preferredCapsuleScreenID = screenID
        persistState()
    }

    public func setPreferredContinentScreenID(_ screenID: String?) {
        preferredContinentScreenID = screenID
        persistState()
    }

    public func registerCapsuleAdapter(_ adapter: DynamicSurfacePanelAdapter) {
        capsuleAdapter = adapter
    }

    public func registerContinentAdapter(_ adapter: DynamicSurfacePanelAdapter) {
        continentAdapter = adapter
    }

    public func restoreLastSurface(fallback: DynamicSurfaceVisibilityState = .capsuleCompact) {
        let restoredState = visibilityState
        transition(to: restoredState, reason: .restore)
    }

    public func transition(to target: DynamicSurfaceVisibilityState, reason _: DynamicSurfaceTransitionReason) {
        dragPhase = .committing
        activeDockTarget = nil
        previewScreenID = nil

        switch target {
        case .capsuleCompact:
            surfaceKind = .capsule
            presentation = .compact
            visibilityState = .capsuleCompact

            continentAdapter?.endDragPreview()
            continentAdapter?.hide(animated: false)
            capsuleAdapter?.endDragPreview()

            let screen = screenForCapsuleDock()
            capsuleAdapter?.showCompact(on: screen, at: capsuleDesktopPosition, animated: false)

        case .continentCompact:
            surfaceKind = .continent
            presentation = .compact
            visibilityState = .continentCompact

            capsuleAdapter?.endDragPreview()
            capsuleAdapter?.hide(animated: false)
            continentAdapter?.endDragPreview()

            let screen = screenForContinentDock()
            if let screen {
                continentTopDockScreenID = Self.screenIdentifier(screen)
            }
            continentAdapter?.showCompact(on: screen, at: nil, animated: false)

        case .continentExpanded:
            surfaceKind = .continent
            presentation = .expanded
            visibilityState = .continentExpanded

            capsuleAdapter?.endDragPreview()
            capsuleAdapter?.hide(animated: false)
            continentAdapter?.endDragPreview()

            let screen = screenForContinentDock()
            if let screen {
                continentTopDockScreenID = Self.screenIdentifier(screen)
            }
            continentAdapter?.showExpanded(on: screen, at: nil, animated: false)
        }

        persistState()
        dragPhase = .idle
    }

    public func clearCapsulePositionMemory() {
        capsuleDesktopPosition = nil
        persistState()
    }

    public func clearContinentDockMemory() {
        continentTopDockScreenID = nil
        persistState()
    }

    // MARK: - Capsule Drag

    public func capsuleDragBegan(at point: CGPoint) {
        let screen = CompanionScreenPositioning.screen(for: point) ?? NSScreen.main
        let screenID = screen.map(Self.screenIdentifier)
        dragPhase = .draggingCapsule
        surfaceKind = .capsule
        presentation = .compact
        visibilityState = .capsuleCompact
        activeDockTarget = screenID.map { .desktop(point: point, screenID: $0) }
        previewScreenID = screenID

        capsuleAdapter?.beginDragPreview()
        continentAdapter?.hide(animated: false)
        capsuleAdapter?.showCompact(on: screen, at: point, animated: false)
        continentAdapter?.endDragPreview()
    }

    public func capsuleDragChanged(to point: CGPoint) {
        let screen = CompanionScreenPositioning.screen(for: point) ?? NSScreen.main
        guard let screen else { return }

        if CompanionScreenPositioning.isPointInTopDockHotZone(point, screen: screen) {
            dragPhase = .capsuleDockPreview
            surfaceKind = .capsule
            presentation = .compact
            visibilityState = .capsuleCompact
            activeDockTarget = .topMenuBar(screenID: Self.screenIdentifier(screen))
            previewScreenID = Self.screenIdentifier(screen)

            capsuleAdapter?.updateDragPreview(mouseLocation: point, phase: dragPhase)
            continentAdapter?.endDragPreview()
        } else {
            dragPhase = .draggingCapsule
            surfaceKind = .capsule
            presentation = .compact
            visibilityState = .capsuleCompact
            activeDockTarget = .desktop(point: point, screenID: Self.screenIdentifier(screen))
            previewScreenID = Self.screenIdentifier(screen)

            capsuleAdapter?.showCompact(on: screen, at: point, animated: false)
            capsuleAdapter?.updateDragPreview(mouseLocation: point, phase: dragPhase)
            continentAdapter?.endDragPreview()
            continentAdapter?.hide(animated: false)
        }
    }

    public func capsuleDragEnded(at point: CGPoint) {
        let screen = CompanionScreenPositioning.screen(for: point) ?? NSScreen.main
        guard let screen else { return }

        if CompanionScreenPositioning.isPointInTopDockHotZone(point, screen: screen) {
            continentTopDockScreenID = Self.screenIdentifier(screen)
            transition(to: .continentCompact, reason: .dragCommit)
        } else {
            capsuleDesktopPosition = point
            transition(to: .capsuleCompact, reason: .dragRevert)
        }
    }

    // MARK: - Continent Drag

    public func continentLongPressBegan(at point: CGPoint) {
        let screen = CompanionScreenPositioning.screen(for: point) ?? NSScreen.main
        let screenID = screen.map(Self.screenIdentifier)
        dragPhase = .draggingContinent
        surfaceKind = .continent
        presentation = .compact
        visibilityState = .continentCompact
        activeDockTarget = screenID.map { .topMenuBar(screenID: $0) }
        previewScreenID = screenID

        continentAdapter?.beginDragPreview()
        capsuleAdapter?.hide(animated: false)
        continentAdapter?.showCompact(on: screen, at: nil, animated: false)
    }

    public func continentDragChanged(to point: CGPoint) {
        let screen = CompanionScreenPositioning.screen(for: point) ?? NSScreen.main
        guard let screen else { return }

        if CompanionScreenPositioning.isPointInTopDockHotZone(point, screen: screen) {
            dragPhase = .draggingContinent
            surfaceKind = .continent
            presentation = .compact
            visibilityState = .continentCompact
            activeDockTarget = .topMenuBar(screenID: Self.screenIdentifier(screen))
            previewScreenID = Self.screenIdentifier(screen)

            continentAdapter?.showCompact(on: screen, at: nil, animated: false)
            continentAdapter?.updateDragPreview(mouseLocation: point, phase: dragPhase)
            capsuleAdapter?.endDragPreview()
        } else {
            dragPhase = .continentLeavingTopDock
            surfaceKind = .continent
            presentation = .compact
            visibilityState = .continentCompact
            activeDockTarget = .desktop(point: point, screenID: Self.screenIdentifier(screen))
            previewScreenID = Self.screenIdentifier(screen)

            continentAdapter?.updateDragPreview(mouseLocation: point, phase: dragPhase)
            capsuleAdapter?.endDragPreview()
        }
    }

    public func continentDragEnded(at point: CGPoint) {
        let screen = CompanionScreenPositioning.screen(for: point) ?? NSScreen.main
        guard let screen else { return }

        if CompanionScreenPositioning.isPointInTopDockHotZone(point, screen: screen) {
            continentTopDockScreenID = Self.screenIdentifier(screen)
            transition(to: .continentCompact, reason: .dragCommit)
        } else {
            capsuleDesktopPosition = point
            transition(to: .capsuleCompact, reason: .dragCommit)
        }
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        if let dict = userDefaults.dictionary(forKey: Self.capsulePositionKey),
           let x = dict["x"] as? CGFloat,
           let y = dict["y"] as? CGFloat {
            capsuleDesktopPosition = CGPoint(x: x, y: y)
        }
        continentTopDockScreenID = userDefaults.string(forKey: Self.continentScreenKey)
        preferredCapsuleScreenID = userDefaults.string(forKey: Self.preferredCapsuleScreenKey)
        preferredContinentScreenID = userDefaults.string(forKey: Self.preferredContinentScreenKey)
        let state = Self.loadPersistedVisibilityState(userDefaults: userDefaults, default: nil)
        if let state {
            visibilityState = state
            surfaceKind = Self.surfaceKind(for: state)
            presentation = Self.presentation(for: state)
        } else if continentTopDockScreenID != nil {
            visibilityState = .continentCompact
            surfaceKind = .continent
            presentation = .compact
        } else {
            visibilityState = .capsuleCompact
            surfaceKind = .capsule
            presentation = .compact
        }
    }

    private func persistState() {
        userDefaults.set(visibilityState.rawValue, forKey: Self.visibilityStateKey)
        if let point = capsuleDesktopPosition {
            userDefaults.set(["x": point.x, "y": point.y], forKey: Self.capsulePositionKey)
        } else {
            userDefaults.removeObject(forKey: Self.capsulePositionKey)
        }
        if let screenID = continentTopDockScreenID {
            userDefaults.set(screenID, forKey: Self.continentScreenKey)
        } else {
            userDefaults.removeObject(forKey: Self.continentScreenKey)
        }
        if let screenID = preferredCapsuleScreenID {
            userDefaults.set(screenID, forKey: Self.preferredCapsuleScreenKey)
        } else {
            userDefaults.removeObject(forKey: Self.preferredCapsuleScreenKey)
        }
        if let screenID = preferredContinentScreenID {
            userDefaults.set(screenID, forKey: Self.preferredContinentScreenKey)
        } else {
            userDefaults.removeObject(forKey: Self.preferredContinentScreenKey)
        }
    }

    private static let capsulePositionKey = "DesktopCapsule.position"
    private static let continentScreenKey = "DynamicSurface.continentTopDockScreenID"
    private static let preferredCapsuleScreenKey = "DynamicSurface.preferredCapsuleScreenID"
    private static let preferredContinentScreenKey = "DynamicSurface.preferredContinentScreenID"
    private static let visibilityStateKey = "DynamicSurface.visibilityState"

    // MARK: - Helpers

    private static func loadPersistedVisibilityState(userDefaults: UserDefaults, default defaultValue: DynamicSurfaceVisibilityState?) -> DynamicSurfaceVisibilityState? {
        guard let raw = userDefaults.string(forKey: visibilityStateKey),
              let state = DynamicSurfaceVisibilityState(rawValue: raw) else {
            return defaultValue
        }
        return state
    }

    private func screenForCapsuleDock() -> NSScreen? {
        if let preferredCapsuleScreenID,
           let preferredScreen = NSScreen.screens.first(where: { Self.screenIdentifier($0) == preferredCapsuleScreenID }) {
            return preferredScreen
        }
        if let point = capsuleDesktopPosition {
            return CompanionScreenPositioning.screen(for: point)
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func screenForContinentDock() -> NSScreen? {
        if let preferredContinentScreenID,
           let preferredScreen = NSScreen.screens.first(where: { Self.screenIdentifier($0) == preferredContinentScreenID }) {
            return preferredScreen
        }
        if let screenID = continentTopDockScreenID {
            return NSScreen.screens.first(where: { Self.screenIdentifier($0) == screenID }) ?? NSScreen.main ?? NSScreen.screens.first
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private static func surfaceKind(for state: DynamicSurfaceVisibilityState) -> DynamicSurfaceKind {
        switch state {
        case .capsuleCompact:
            return .capsule
        case .continentCompact, .continentExpanded:
            return .continent
        }
    }

    private static func presentation(for state: DynamicSurfaceVisibilityState) -> DynamicSurfacePresentation {
        switch state {
        case .capsuleCompact, .continentCompact:
            return .compact
        case .continentExpanded:
            return .expanded
        }
    }

    private static func screenIdentifier(_ screen: NSScreen) -> String {
        if let raw = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return raw.stringValue
        }
        return screen.localizedName
    }
}
