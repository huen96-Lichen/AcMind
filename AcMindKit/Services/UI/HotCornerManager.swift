import Foundation
import AppKit

@MainActor
public final class HotCornerManager {
    public typealias ActionExecutor = @MainActor (HotCornerAction) -> Void

    private static let logger = AcMindLogger(category: .ui)
    private let actionExecutor: ActionExecutor
    private var settings: HotCornerSettings = .defaultSettings
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var screenParametersObserver: NSObjectProtocol?
    private var pendingHoverTask: Task<Void, Never>?
    private var hoveredCorner: HotCornerPosition?
    private var hoveredScreenFrame: CGRect?
    private var triggeredCorner: HotCornerPosition?
    private var overlayWindows: [HotCornerOverlayKey: HotCornerOverlayWindow] = [:]
    public private(set) var isRunning = false

    public init(actionExecutor: @escaping ActionExecutor = { _ in }) {
        self.actionExecutor = actionExecutor
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        Self.logger.debug("Hot corner manager start")

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in
                self?.update(mouseLocation: NSEvent.mouseLocation)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in
                self?.update(mouseLocation: NSEvent.mouseLocation)
            }
            return event
        }

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshOverlayWindows()
            }
        }

        refreshOverlayWindows()
        update(mouseLocation: NSEvent.mouseLocation)
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        Self.logger.debug("Hot corner manager stop")
        pendingHoverTask?.cancel()
        pendingHoverTask = nil
        hoveredCorner = nil
        hoveredScreenFrame = nil
        triggeredCorner = nil
        clearOverlayWindows()
        removeMonitors()
    }

    public func update(settings: HotCornerSettings) {
        self.settings = settings
        Self.logger.debug("Hot corner settings updated: enabled=\(settings.isEnabled), cornerSize=\(settings.cornerSize)")
        if !settings.isEnabled {
            stop()
        } else if !isRunning {
            start()
        } else {
            refreshOverlayWindows()
        }
    }

    public func update(mouseLocation: CGPoint, screenFrames: [CGRect] = NSScreen.screens.map(\.frame)) {
        guard settings.isEnabled else {
            stop()
            return
        }

        guard let screenFrame = HotCornerGeometry.screenFrame(containing: mouseLocation, screenFrames: screenFrames),
              let corner = HotCornerGeometry.corner(at: mouseLocation, in: screenFrame, size: settings.cornerSize),
              let binding = settings.bindings[corner],
              binding.isEnabled,
              binding.action != .none else {
            resetHoverState()
            return
        }

        if hoveredCorner != corner || hoveredScreenFrame != screenFrame {
            hoveredCorner = corner
            hoveredScreenFrame = screenFrame
            triggeredCorner = nil
            scheduleTrigger(for: corner, binding: binding)
        }
    }

    private func scheduleTrigger(for corner: HotCornerPosition, binding: HotCornerBinding) {
        pendingHoverTask?.cancel()

        let delay = max(binding.hoverDelay, 0)
        pendingHoverTask = Task { [weak self] in
            let nanos = UInt64(delay * 1_000_000_000)
            if nanos > 0 {
                try? await Task.sleep(nanoseconds: nanos)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.fireIfStillHovering(corner)
            }
        }
    }

    private func fireIfStillHovering(_ corner: HotCornerPosition) {
        guard hoveredCorner == corner,
              triggeredCorner != corner,
              let binding = settings.bindings[corner],
              binding.isEnabled,
              binding.action != .none else {
            return
        }

        triggeredCorner = corner
        actionExecutor(binding.action)
    }

    private func resetHoverState() {
        pendingHoverTask?.cancel()
        pendingHoverTask = nil
        hoveredCorner = nil
        hoveredScreenFrame = nil
        triggeredCorner = nil
    }

    private func removeMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }
    }

    private func refreshOverlayWindows() {
        guard settings.isEnabled else {
            Self.logger.debug("Hot corner overlays cleared because settings are disabled")
            clearOverlayWindows()
            return
        }

        let screens = NSScreen.screens
        let desiredKeys = Set(
            screens.flatMap { screen in
                HotCornerPosition.allCases.map {
                    HotCornerOverlayKey(screenID: screenIdentifier(for: screen), corner: $0)
                }
            }
        )

        for key in overlayWindows.keys where !desiredKeys.contains(key) {
            overlayWindows[key]?.close()
            overlayWindows.removeValue(forKey: key)
        }

        for screen in screens {
            let screenID = screenIdentifier(for: screen)
            for corner in HotCornerPosition.allCases {
                let key = HotCornerOverlayKey(screenID: screenID, corner: corner)
                let frame = HotCornerGeometry.overlayFrame(for: corner, in: screen.frame, size: settings.cornerSize)

                if let window = overlayWindows[key] {
                    window.update(frame: frame)
                } else {
                    let window = HotCornerOverlayWindow(corner: corner, frame: frame)
                    overlayWindows[key] = window
                    window.orderFrontRegardless()
                }
            }
        }

        Self.logger.debug("Hot corner overlay windows refreshed: count=\(overlayWindows.count)")
    }

    private func clearOverlayWindows() {
        overlayWindows.values.forEach { $0.close() }
        overlayWindows.removeAll()
    }

    private func screenIdentifier(for screen: NSScreen) -> String {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return number.stringValue
        }
        return screen.localizedName
    }
}

public enum HotCornerGeometry {
    public static let defaultCornerSize: CGFloat = 24

    public static func corner(at point: CGPoint, in screenFrame: CGRect, size: CGFloat = defaultCornerSize) -> HotCornerPosition? {
        for corner in HotCornerPosition.allCases where contains(point: point, in: corner, screenFrame: screenFrame, size: size) {
            return corner
        }
        return nil
    }

    public static func contains(point: CGPoint, in corner: HotCornerPosition, screenFrame: CGRect, size: CGFloat = defaultCornerSize) -> Bool {
        let local = localPoint(point, in: corner, screenFrame: screenFrame)
        guard local.x >= 0, local.x <= size, local.y >= 0, local.y <= size else {
            return false
        }

        let center = CGPoint(x: size, y: size)
        let dx = local.x - center.x
        let dy = local.y - center.y
        return (dx * dx + dy * dy) >= (size * size)
    }

    public static func overlayFrame(for corner: HotCornerPosition, in screenFrame: CGRect, size: CGFloat = defaultCornerSize) -> CGRect {
        switch corner {
        case .topLeft:
            return CGRect(x: screenFrame.minX, y: screenFrame.maxY - size, width: size, height: size)
        case .topRight:
            return CGRect(x: screenFrame.maxX - size, y: screenFrame.maxY - size, width: size, height: size)
        case .bottomLeft:
            return CGRect(x: screenFrame.minX, y: screenFrame.minY, width: size, height: size)
        case .bottomRight:
            return CGRect(x: screenFrame.maxX - size, y: screenFrame.minY, width: size, height: size)
        }
    }

    public static func overlayCutoutRect(for corner: HotCornerPosition, in rect: CGRect, size: CGFloat = defaultCornerSize) -> CGRect {
        switch corner {
        case .topLeft:
            return CGRect(x: rect.maxX - size, y: rect.minY - size, width: size * 2, height: size * 2)
        case .topRight:
            return CGRect(x: rect.minX - size, y: rect.minY - size, width: size * 2, height: size * 2)
        case .bottomLeft:
            return CGRect(x: rect.maxX - size, y: rect.minY, width: size * 2, height: size * 2)
        case .bottomRight:
            return CGRect(x: rect.minX - size, y: rect.maxY - size, width: size * 2, height: size * 2)
        }
    }

    public static func screenFrame(containing point: CGPoint, screenFrames: [CGRect]) -> CGRect? {
        if let frame = screenFrames.first(where: { containsInclusive(point, in: $0) }) {
            return frame
        }

        return screenFrames.max { area(of: $0.intersection(pointFrame(point))) < area(of: $1.intersection(pointFrame(point))) }
    }

    private static func containsInclusive(_ point: CGPoint, in frame: CGRect) -> Bool {
        point.x >= frame.minX && point.x <= frame.maxX && point.y >= frame.minY && point.y <= frame.maxY
    }

    private static func localPoint(_ point: CGPoint, in corner: HotCornerPosition, screenFrame: CGRect) -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(x: point.x - screenFrame.minX, y: screenFrame.maxY - point.y)
        case .topRight:
            return CGPoint(x: screenFrame.maxX - point.x, y: screenFrame.maxY - point.y)
        case .bottomLeft:
            return CGPoint(x: point.x - screenFrame.minX, y: point.y - screenFrame.minY)
        case .bottomRight:
            return CGPoint(x: screenFrame.maxX - point.x, y: point.y - screenFrame.minY)
        }
    }

    private static func pointFrame(_ point: CGPoint) -> CGRect {
        CGRect(x: point.x, y: point.y, width: 1, height: 1)
    }

    private static func area(of rect: CGRect) -> CGFloat {
        guard !rect.isNull, !rect.isEmpty else { return 0 }
        return rect.width * rect.height
    }
}

private struct HotCornerOverlayKey: Hashable {
    let screenID: String
    let corner: HotCornerPosition
}

@MainActor
private final class HotCornerOverlayWindow: NSPanel {
    private let corner: HotCornerPosition

    init(corner: HotCornerPosition, frame: CGRect) {
        self.corner = corner
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        identifier = NSUserInterfaceItemIdentifier("acmind.hot-corner-overlay")
        configureWindow()
        installContent(frame: frame)
    }

    private func configureWindow() {
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    private func installContent(frame: CGRect) {
        let hosting = HotCornerOverlayContentView(corner: corner)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    func update(frame: CGRect) {
        setFrame(frame, display: true)
        contentView?.frame = NSRect(origin: .zero, size: frame.size)
    }
}

private final class HotCornerOverlayContentView: NSView {
    private let corner: HotCornerPosition

    init(corner: HotCornerPosition) {
        self.corner = corner
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.setFill()
        let path = NSBezierPath()
        path.appendRect(bounds)
        path.append(NSBezierPath(ovalIn: HotCornerGeometry.overlayCutoutRect(for: corner, in: bounds, size: bounds.width)))
        path.windingRule = .evenOdd
        path.fill()
    }
}

public extension Notification.Name {
    static let hotCornersDidChange = Notification.Name("AcMind.hotCornersDidChange")
}
