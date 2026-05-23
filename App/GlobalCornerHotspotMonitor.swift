import AppKit
import AcMindKit

@MainActor
final class GlobalCornerHotspotMonitor {
    private let hotZoneSize: CGFloat = 28
    private let triggerDelay: TimeInterval = 1.5
    private let settingsProvider: () -> CornerTriggerSettings
    private let actionHandler: (CornerTriggerTarget) -> Void

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var settingsObserver: NSObjectProtocol?
    private var currentSettings: CornerTriggerSettings
    private var activeCorner: ScreenCorner?
    private var pendingCorner: ScreenCorner?
    private var triggerTask: Task<Void, Never>?
    private var isRunning = false

    init(
        settingsProvider: @escaping () -> CornerTriggerSettings = { CornerTriggerSettingsStore.load() },
        actionHandler: @escaping (CornerTriggerTarget) -> Void
    ) {
        self.settingsProvider = settingsProvider
        self.actionHandler = actionHandler
        self.currentSettings = settingsProvider()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        currentSettings = settingsProvider()

        settingsObserver = NotificationCenter.default.addObserver(
            forName: CornerTriggerSettingsStore.settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentSettings = self?.settingsProvider() ?? .default
            }
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMouseActivity()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseActivity()
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
            self.settingsObserver = nil
        }

        triggerTask?.cancel()
        triggerTask = nil
        pendingCorner = nil
        activeCorner = nil
        isRunning = false
    }

    private func handleMouseActivity() {
        guard currentSettings.isEnabled else {
            resetHotspotState()
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            resetHotspotState()
            return
        }

        guard let corner = ScreenCorner.roundedCorner(for: mouseLocation, in: screen.frame, radius: hotZoneSize) else {
            resetHotspotState()
            return
        }

        guard currentSettings[corner].isEnabled else {
            activeCorner = nil
            pendingCorner = nil
            triggerTask?.cancel()
            triggerTask = nil
            return
        }

        guard corner != activeCorner, corner != pendingCorner else {
            return
        }

        pendingCorner = corner
        triggerTask?.cancel()
        let delay = triggerDelay
        triggerTask = Task { [weak self, corner] in
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run {
                self?.triggerIfStillHovering(corner)
            }
        }
    }

    private func resetHotspotState() {
        activeCorner = nil
        pendingCorner = nil
        triggerTask?.cancel()
        triggerTask = nil
    }

    private func triggerIfStillHovering(_ corner: ScreenCorner) {
        guard pendingCorner == corner, currentSettings.isEnabled else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }),
            ScreenCorner.roundedCorner(for: mouseLocation, in: screen.frame, radius: hotZoneSize) == corner
        else {
            resetHotspotState()
            return
        }

        let assignment = currentSettings[corner]
        guard assignment.isEnabled else { return }

        activeCorner = corner
        pendingCorner = nil
        triggerTask = nil

        switch assignment.target.kind {
        case .builtInFeature:
            actionHandler(assignment.target)
        case .application:
            actionHandler(assignment.target)
        }
    }
}
