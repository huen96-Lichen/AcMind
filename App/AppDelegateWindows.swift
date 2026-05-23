import SwiftUI
import AppKit
import AcMindKit

extension AppDelegate {
    // MARK: - Window Management

    func showMainWindow() {
        if mainWindowController == nil {
            guard let serviceContainer else {
                return
            }
            mainWindowController = MainWindowController(
                container: serviceContainer,
                appState: appState,
                musicService: musicService,
                toastManager: toastManager
            )
        }
        appState.ensureWorkspaceModeNotHidden()
        NSApp.activate(ignoringOtherApps: true)
        mainWindowController?.showWindow(nil)
        applyMainWindowFrameAdjustment {
            mainWindowController?.window?.setFrame(AppWindowGeometry.mainFrame(), display: true)
        }
        lastPrimaryRailWidth = appState.primaryRailWidth
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        mainWindowController?.window?.orderFrontRegardless()
        appState.mainWindowDidOpen()
    }

    func hideMainWindow() {
        mainWindowController?.close()
        appState.mainWindowDidClose()
    }

    func closeMainWindow() {
        guard let window = mainWindowController?.window else { return }
        window.performClose(nil)
        appState.mainWindowDidClose()
    }

    func minimizeMainWindow() {
        mainWindowController?.window?.miniaturize(nil)
    }

    func zoomMainWindow() {
        mainWindowController?.window?.zoom(nil)
    }

    func toggleMainWindow() {
        if mainWindowController?.window?.isVisible == true {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }

    // MARK: - Workspace Mode Window Management

    func collapseWindowToPrimaryRail(railWidth: CGFloat) {
        guard let window = mainWindowController?.window else { return }

        savedWindowFrame = window.frame
        lastPrimaryRailWidth = railWidth

        let padding: CGFloat = 32
        let collapsedShellWidth = AcMindSurfaceTokens.sidebarContainerWidth + (AcMindSurfaceTokens.workspaceOuterPadding * 2)
        let newWidth = max(railWidth + padding, collapsedShellWidth)

        applyMainWindowFrameAdjustment {
            var newFrame = window.frame
            newFrame.size.width = newWidth
            window.setFrame(newFrame, display: true)
        }
    }

    func expandWindowToFullWorkspace() {
        guard let window = mainWindowController?.window else { return }

        if let savedFrame = savedWindowFrame {
            applyMainWindowFrameAdjustment {
                window.setFrame(savedFrame, display: true)
            }
        }
        lastPrimaryRailWidth = appState.primaryRailWidth
    }

    func updateWindowForRailWidth(_ railWidth: CGFloat) {
        guard let window = mainWindowController?.window else { return }

        let previousRailWidth = lastPrimaryRailWidth
        lastPrimaryRailWidth = railWidth

        if appState.workspaceMode == .collapsed {
            let padding: CGFloat = 32
            let collapsedShellWidth = AcMindSurfaceTokens.sidebarContainerWidth + (AcMindSurfaceTokens.workspaceOuterPadding * 2)
            let newWidth = max(railWidth + padding, collapsedShellWidth)

            applyMainWindowFrameAdjustment {
                var newFrame = window.frame
                newFrame.size.width = newWidth
                window.setFrame(newFrame, display: true)
            }
            return
        }

        let delta = railWidth - previousRailWidth
        guard delta != 0 else { return }

        applyMainWindowFrameAdjustment {
            var newFrame = window.frame
            newFrame.size.width = max(newFrame.size.width + delta, ACLayout.windowMinWidth)
            window.setFrame(newFrame, display: true)
        }
    }

    func updateSavedWindowFrameOrigin(_ origin: CGPoint) {
        guard var savedWindowFrame else { return }
        savedWindowFrame.origin = origin
        self.savedWindowFrame = savedWindowFrame
    }

    private func applyMainWindowFrameAdjustment(_ block: () -> Void) {
        isAdjustingMainWindowFrame = true
        defer { isAdjustingMainWindowFrame = false }
        block()
    }

    func showLaunchWindow() {
        if launchWindowController == nil {
            launchWindowController = LaunchWindowController(appState: appState)
        }
        NSApp.activate(ignoringOtherApps: true)
        launchWindowController?.showWindow(nil)
        launchWindowController?.window?.setFrame(AppWindowGeometry.launchFrame, display: true)
        launchWindowController?.window?.makeKeyAndOrderFront(nil)
        launchWindowController?.window?.orderFrontRegardless()
    }

    func hideLaunchWindow() {
        launchWindowController?.close()
        launchWindowController = nil
    }

    // MARK: - Notch Panel

    func showNotchPanel() {
        guard notchPanelEnabled else { return }
        NSApp.activate(ignoringOtherApps: true)
        DynamicSurfaceCoordinator.shared.transition(to: .continentCompact, reason: .manualCommand)
    }

    func hideNotchPanel() {
        if DynamicSurfaceCoordinator.shared.visibilityState == .continentCompact || DynamicSurfaceCoordinator.shared.visibilityState == .continentExpanded {
            DynamicSurfaceCoordinator.shared.transition(to: .capsuleCompact, reason: .manualCommand)
        }
    }

    func toggleNotchPanel() {
        DynamicSurfaceCoordinator.shared.transition(to: .continentCompact, reason: .manualCommand)
    }

    // MARK: - Desktop Capsule

    func showDesktopCapsule() {
        guard desktopCapsuleEnabled else { return }
        NSApp.activate(ignoringOtherApps: true)
        DynamicSurfaceCoordinator.shared.transition(to: .capsuleCompact, reason: .manualCommand)
    }

    func hideDesktopCapsule() {
        if DynamicSurfaceCoordinator.shared.visibilityState == .capsuleCompact {
            DynamicSurfaceCoordinator.shared.transition(to: .continentCompact, reason: .manualCommand)
        }
    }

    func toggleDesktopCapsule() {
        guard desktopCapsuleEnabled else { return }
        DynamicSurfaceCoordinator.shared.transition(to: .capsuleCompact, reason: .manualCommand)
    }

    func restoreDynamicSurface() {
        NSApp.activate(ignoringOtherApps: true)
        let coordinator = DynamicSurfaceCoordinator.shared
        let lastState = coordinator.visibilityState
        let preferredState: DynamicSurfaceVisibilityState
        let canAutoShowCapsule = desktopCapsuleEnabled && desktopCapsuleAutoShowOnLaunch

        switch lastState {
        case .continentCompact, .continentExpanded:
            if notchPanelEnabled {
                preferredState = lastState
            } else if canAutoShowCapsule {
                preferredState = .capsuleCompact
            } else {
                return
            }
        case .capsuleCompact:
            if canAutoShowCapsule {
                preferredState = .capsuleCompact
            } else if !desktopCapsuleEnabled && notchPanelEnabled {
                preferredState = .continentCompact
            } else {
                return
            }
        }

        coordinator.transition(to: preferredState, reason: .startup)
    }
}

enum AppWindowGeometry {
    static func mainFrame() -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(
            x: 0,
            y: 0,
            width: ACLayout.windowIdealWidth,
            height: ACLayout.windowIdealHeight
        )

        let width = min(ACLayout.windowIdealWidth, max(ACLayout.windowMinWidth, screenFrame.width - 120))
        let height = min(ACLayout.windowIdealHeight, max(ACLayout.windowMinHeight, screenFrame.height - 100))
        let leftOffset: CGFloat = 200
        let x = max(screenFrame.minX + 24, screenFrame.maxX - width - leftOffset)
        let y = screenFrame.midY - (height / 2)

        return NSRect(x: x, y: y, width: width, height: height)
    }

    static let launchFrame = NSRect(x: 220, y: 180, width: 460, height: 340)
}

private extension NSWindow {
    func hideStandardWindowControls() {
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].forEach { buttonType in
            standardWindowButton(buttonType)?.isHidden = true
        }
    }
}

class MainWindowController: NSWindowController {
    private let container: ServiceContainer
    private let appState: AppState
    private let musicService: MusicService
    private let toastManager: ToastManager

    init(container: ServiceContainer, appState: AppState, musicService: MusicService, toastManager: ToastManager) {
        self.container = container
        self.appState = appState
        self.musicService = musicService
        self.toastManager = toastManager

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "AcMind"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: ACLayout.windowMinWidth, height: 300)
        window.collectionBehavior = [.managed, .moveToActiveSpace]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        let contentView = ContentView(
            serviceContainer: container,
            appState: appState,
            musicService: musicService,
            toastManager: toastManager
        )
            .environmentObject(container)

        let hostingView = NSHostingView(rootView: contentView)
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 24

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        window.contentView = containerView

        super.init(window: window)
        setupWindowDelegate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindowDelegate() {
        window?.delegate = self
    }
}

extension MainWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        appState.mainWindowDidBecomeKey()
    }

    func windowDidMove(_ notification: Notification) {
        guard appState.workspaceMode == .collapsed else { return }
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        guard appDelegate.isAdjustingMainWindowFrame == false else { return }
        guard let window = window else { return }
        appDelegate.updateSavedWindowFrameOrigin(window.frame.origin)
    }

    func windowDidResignKey(_ notification: Notification) {
        appState.mainWindowDidResignKey()
    }

    func windowWillClose(_ notification: Notification) {
        appState.mainWindowDidClose()
    }
}

class LaunchWindowController: NSWindowController {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "AcMind"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .moveToActiveSpace]
        window.level = .statusBar
        window.hideStandardWindowControls()
        window.center()
        window.orderFrontRegardless()

        let contentView = LaunchView(appState: appState)

        window.contentView = NSHostingView(rootView: contentView)

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
