import AppKit
import SwiftUI
import AcMindKit

@MainActor
final class DesktopCornerHintOverlayManager {
    static let cornerSize: CGFloat = 12
    static let cornerRadius: CGFloat = 12

    private let settingsProvider: () -> CornerTriggerSettings
    private var currentSettings: CornerTriggerSettings
    private var panelsByDisplayID: [String: DesktopCornerHintPanel] = [:]
    private var settingsObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var isRunning = false

    init(settingsProvider: @escaping () -> CornerTriggerSettings = { CornerTriggerSettingsStore.load() }) {
        self.settingsProvider = settingsProvider
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
                self?.refresh()
            }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncPanels()
            }
        }

        refresh()
    }

    func stop() {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
            self.settingsObserver = nil
        }

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }

        panelsByDisplayID.values.forEach { $0.close() }
        panelsByDisplayID.removeAll()
        isRunning = false
    }

    func refresh() {
        currentSettings = settingsProvider()
        syncPanels()
    }

    private func syncPanels() {
        let shouldShowHints = currentSettings.isEnabled
        let enabledCornerCount = currentSettings.orderedCorners.filter { $0.assignment.isEnabled }.count

        guard shouldShowHints, enabledCornerCount > 0 else {
            panelsByDisplayID.values.forEach { $0.close() }
            panelsByDisplayID.removeAll()
            return
        }

        let targetScreens = NSScreen.screens.filter { currentSettings.desktopHintDisplayEnabled(on: $0) }
        let targetDisplayIDs = Set(targetScreens.map(\.displayID))

        let removableDisplayIDs = panelsByDisplayID.keys.filter { !targetDisplayIDs.contains($0) }
        for displayID in removableDisplayIDs {
            panelsByDisplayID[displayID]?.close()
            panelsByDisplayID.removeValue(forKey: displayID)
        }

        for screen in targetScreens {
            let displayID = screen.displayID
            let panel = panelsByDisplayID[displayID] ?? DesktopCornerHintPanel(screen: screen)
            panel.update(screen: screen, settings: currentSettings)
            panelsByDisplayID[displayID] = panel
            panel.orderFrontRegardless()
        }
    }
}

private final class DesktopCornerHintPanel: NSPanel {
    private var hostingView: NSHostingView<DesktopCornerHintScreenView>?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        setupContentView(screen: screen, settings: CornerTriggerSettingsStore.load())
    }

    private func configurePanel() {
        level = .statusBar
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        ignoresMouseEvents = true
    }

    private func setupContentView(screen: NSScreen, settings: CornerTriggerSettings) {
        let hosting = NSHostingView(
            rootView: DesktopCornerHintScreenView(
                settings: settings,
                cornerSize: DesktopCornerHintOverlayManager.cornerSize,
                cornerRadius: DesktopCornerHintOverlayManager.cornerRadius
            )
        )
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        let containerView = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.addSubview(hosting)
        contentView = containerView

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: containerView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        hostingView = hosting
        setFrame(screen.frame, display: false)
    }

    func update(screen: NSScreen, settings: CornerTriggerSettings) {
        setFrame(screen.frame, display: true)
        hostingView?.rootView = DesktopCornerHintScreenView(
            settings: settings,
            cornerSize: DesktopCornerHintOverlayManager.cornerSize,
            cornerRadius: DesktopCornerHintOverlayManager.cornerRadius
        )
    }
}

private struct DesktopCornerHintScreenView: View {
    let settings: CornerTriggerSettings
    let cornerSize: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { _ in
            ZStack {
                cornerMarker(for: .topLeft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                cornerMarker(for: .topRight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                cornerMarker(for: .bottomLeft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                cornerMarker(for: .bottomRight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
    }

    @ViewBuilder
    private func cornerMarker(for corner: ScreenCorner) -> some View {
        if settings[corner].isEnabled {
            InverseCornerTile(corner: corner, size: cornerSize, radius: cornerRadius)
        }
    }
}

private struct InverseCornerTile: View {
    let corner: ScreenCorner
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        CornerMaskShape(corner: corner, radius: radius)
            .fill(Color.black, style: FillStyle(antialiased: true))
            .frame(width: size, height: size)
    }
}

private struct CornerMaskShape: Shape {
    let corner: ScreenCorner
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let base = topLeftMask(in: rect)

        switch corner {
        case .topLeft:
            return base
        case .topRight:
            return base.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.width, ty: 0))
        case .bottomLeft:
            return base.applying(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.height))
        case .bottomRight:
            return base.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: rect.width, ty: rect.height))
        }
    }

    private func topLeftMask(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(rect.width, rect.height, radius)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(-180),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
