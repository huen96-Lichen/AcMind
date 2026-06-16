import AppKit
import Combine
import SwiftUI

private let clipboardPinLogger = AcMindLogger(category: .capture)

@MainActor
public final class ClipboardPinWindowManager {
    private struct NotificationObserver {
        let center: NotificationCenter
        let token: NSObjectProtocol
    }

    private struct ManagedWindow {
        let controller: ClipboardPinWindowController
        var alwaysOnTop: Bool
    }

    private let assetStore: AssetStore
    private var windows: [String: ManagedWindow] = [:]
    private var notificationObservers: [NotificationObserver] = []
    private var reassertionTimer: DispatchSourceTimer?

    public init(assetStore: AssetStore) {
        self.assetStore = assetStore
        installReassertionObservers()
    }

    deinit {
        reassertionTimer?.cancel()
        for observer in notificationObservers {
            observer.center.removeObserver(observer.token)
        }
    }

    public func show(item: ClipboardItem, preferredDisplayFrame: CGRect? = nil) {
        #if DEBUG
        clipboardPinLogger.info("[ClipboardPin] manager show item=\(item.id) windows=\(windows.count) preferredDisplayFrame=\(String(describing: preferredDisplayFrame))")
        #endif
        if let existing = windows[item.id] {
            existing.controller.setAlwaysOnTop(true)
            existing.controller.reveal()
            scheduleReassertion()
            updateKeepAliveTimer()
            notifyWindowStateChanged()
            return
        }

        let controller = ClipboardPinWindowController(
            item: item,
            assetStore: assetStore,
            preferredDisplayFrame: preferredDisplayFrame,
            onClose: { [weak self] in
                self?.windows.removeValue(forKey: item.id)
                self?.updateKeepAliveTimer()
                self?.notifyWindowStateChanged()
            },
            onToggleAlwaysOnTop: { [weak self] in
                self?.toggleAlwaysOnTop(for: item.id)
            }
        )

        windows[item.id] = ManagedWindow(controller: controller, alwaysOnTop: true)
        controller.setAlwaysOnTop(true)
        controller.reveal()
        scheduleReassertion()
        updateKeepAliveTimer()
        notifyWindowStateChanged()
    }

    public func hideAll() {
        for entry in windows.values {
            entry.controller.hide()
        }
        updateKeepAliveTimer()
        notifyWindowStateChanged()
    }

    public func showAll() {
        for entry in windows.values {
            entry.controller.reveal()
        }
        scheduleReassertion()
        updateKeepAliveTimer()
        notifyWindowStateChanged()
    }

    public func closeAll() {
        let currentIds = Array(windows.keys)
        for id in currentIds {
            windows[id]?.controller.close()
        }
        windows.removeAll()
        updateKeepAliveTimer()
        notifyWindowStateChanged()
    }

    public func toggleAlwaysOnTop(for itemId: String) {
        guard var entry = windows[itemId] else { return }
        entry.alwaysOnTop.toggle()
        entry.controller.setAlwaysOnTop(entry.alwaysOnTop)
        windows[itemId] = entry
        if entry.alwaysOnTop {
            scheduleReassertion()
        }
        updateKeepAliveTimer()
        notifyWindowStateChanged()
    }

    public func isShowing(itemId: String) -> Bool {
        windows[itemId]?.controller.isVisible == true
    }

    public var openWindowCount: Int {
        windows.count
    }

    public var windowSnapshots: [ClipboardPinWindowSnapshot] {
        windows.values.map { $0.controller.snapshot }
    }

    nonisolated static func shouldKeepAlive(using snapshots: [ClipboardPinWindowSnapshot]) -> Bool {
        snapshots.contains { snapshot in
            snapshot.isAlwaysOnTop && snapshot.isVisible
        }
    }

    public func diagnosticsReport(generatedAt: Date = Date()) -> String {
        Self.diagnosticsReport(from: windowSnapshots, generatedAt: generatedAt)
    }

    nonisolated static func diagnosticsReport(from snapshots: [ClipboardPinWindowSnapshot], generatedAt: Date = Date()) -> String {
        let expectedLevel = snapshots.first?.expectedAlwaysOnTopLevelRawValue ?? ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue
        let visibleCount = snapshots.filter(\.isVisible).count
        let alwaysOnTopCount = snapshots.filter(\.isAlwaysOnTop).count
        let expectedLevelCount = snapshots.filter(\.isAtExpectedAlwaysOnTopLevel).count
        let keepAliveEligibleCount = snapshots.filter { $0.isAlwaysOnTop && $0.isVisible }.count
        let unstableCount = snapshots.filter { $0.diagnosticReason != "ok" }.count
        let reasonCounts = Dictionary(grouping: snapshots, by: \.diagnosticReason)
            .mapValues(\.count)
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .map { "\($0.key)=\($0.value)" }
        let summary = [
            "AcWork Clipboard Pin Diagnostics",
            "Window Count: \(snapshots.count)",
            "Visible Count: \(visibleCount)",
            "Always-On-Top Count: \(alwaysOnTopCount)",
            "At Expected Level: \(expectedLevelCount)",
            "Keep-Alive Eligible Count: \(keepAliveEligibleCount)",
            "Keep-Alive Active: \(keepAliveEligibleCount > 0)",
            "Unstable Window Count: \(unstableCount)",
            "Reason Summary: \(reasonCounts.isEmpty ? "none" : reasonCounts.joined(separator: ", "))",
            "Expected Always-On-Top Level: \(expectedLevel)",
            "Generated At: \(generatedAt.formatted(date: .abbreviated, time: .standard))"
        ]

        guard snapshots.isEmpty == false else {
            return (summary + ["No open pin windows."]).joined(separator: "\n")
        }

        let sortedSnapshots = snapshots.sorted { lhs, rhs in
            if lhs.diagnosticPriority == rhs.diagnosticPriority {
                return lhs.itemId < rhs.itemId
            }
            return lhs.diagnosticPriority > rhs.diagnosticPriority
        }

        let entries = sortedSnapshots.enumerated().map { index, snapshot in
            let status = snapshot.isAtExpectedAlwaysOnTopLevel ? "ok" : "mismatch"
            return [
                "#\(index + 1)",
                "item=\(snapshot.itemId)",
                "status=\(status)",
                "reason=\(snapshot.diagnosticReason)",
                "visible=\(snapshot.isVisible)",
                "alwaysOnTop=\(snapshot.isAlwaysOnTop)",
                "level=\(snapshot.levelRawValue)",
                "expectedLevel=\(snapshot.expectedAlwaysOnTopLevelRawValue)",
                "matchesExpected=\(snapshot.isAtExpectedAlwaysOnTopLevel)",
                "frame=\(snapshot.frame.debugDescription)",
                "screen=\(snapshot.screenFrame?.debugDescription ?? "nil")",
                "display=\(snapshot.displayFrame.debugDescription)"
            ].joined(separator: " ")
        }

        return (summary + entries).joined(separator: "\n")
    }

    private func notifyWindowStateChanged() {
        NotificationCenter.default.post(name: .acmindClipboardPinWindowsChanged, object: nil)
    }

    private func installReassertionObservers() {
        let notificationCenter = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        notificationObservers.append(
            NotificationObserver(
                center: workspaceCenter,
                token: workspaceCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.reassertVisibleAlwaysOnTopWindows()
                    }
                }
            )
        )

        notificationObservers.append(
            NotificationObserver(
                center: workspaceCenter,
                token: workspaceCenter.addObserver(
                    forName: NSWorkspace.activeSpaceDidChangeNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.reassertVisibleAlwaysOnTopWindows()
                    }
                }
            )
        )

        notificationObservers.append(
            NotificationObserver(
                center: notificationCenter,
                token: notificationCenter.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.reassertVisibleAlwaysOnTopWindows()
                    }
                }
            )
        )

        notificationObservers.append(
            NotificationObserver(
                center: notificationCenter,
                token: notificationCenter.addObserver(
                    forName: NSApplication.didChangeOcclusionStateNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.reassertVisibleAlwaysOnTopWindows()
                    }
                }
            )
        )

        notificationObservers.append(
            NotificationObserver(
                center: notificationCenter,
                token: notificationCenter.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.reassertVisibleAlwaysOnTopWindows()
                    }
                }
            )
        )
    }

    private func updateKeepAliveTimer() {
        let shouldKeepAlive = Self.shouldKeepAlive(using: windowSnapshots)
        if shouldKeepAlive {
            guard reassertionTimer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + 1.0, repeating: 1.25, leeway: .milliseconds(120))
            timer.setEventHandler { [weak self] in
                self?.reassertVisibleAlwaysOnTopWindows()
            }
            timer.resume()
            reassertionTimer = timer
        } else {
            reassertionTimer?.cancel()
            reassertionTimer = nil
        }
    }

    private func scheduleReassertion() {
        for delay in ClipboardPinWindowPresentation.reassertionDelays {
            Task { @MainActor [weak self] in
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                self?.reassertVisibleAlwaysOnTopWindows()
            }
        }
    }

    private func reassertVisibleAlwaysOnTopWindows() {
        for entry in windows.values where entry.alwaysOnTop {
            entry.controller.reassertAlwaysOnTop()
        }
    }
}

enum ClipboardPinWindowPresentation {
    static let styleMask: NSWindow.StyleMask = [.borderless, .hudWindow, .fullSizeContentView, .nonactivatingPanel, .resizable]
    static let alwaysOnTopLevel: NSWindow.Level = .screenSaver
    static let fallbackLevel: NSWindow.Level = .floating
    static let reassertionDelays: [TimeInterval] = [0.05, 0.20, 0.60]

    static func collectionBehavior(isAlwaysOnTop: Bool) -> NSWindow.CollectionBehavior {
        isAlwaysOnTop
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
            : [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }
}

final class ClipboardPinPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ClipboardPinWindowController: NSObject, NSWindowDelegate {
    private let item: ClipboardItem
    private var displayFrame: CGRect
    private let onClose: () -> Void
    private let onToggleAlwaysOnTop: () -> Void
    private let viewModel: ClipboardPinWindowViewModel
    private let window: NSPanel
    private var cancellables = Set<AnyCancellable>()

    init(
        item: ClipboardItem,
        assetStore: AssetStore,
        preferredDisplayFrame: CGRect? = nil,
        onClose: @escaping () -> Void,
        onToggleAlwaysOnTop: @escaping () -> Void
    ) {
        self.item = item
        self.displayFrame = preferredDisplayFrame ?? Self.activeDisplayFrame()
        self.onClose = onClose
        self.onToggleAlwaysOnTop = onToggleAlwaysOnTop
        self.viewModel = ClipboardPinWindowViewModel(item: item, assetStore: assetStore, displayFrame: displayFrame)

        let frame = CGRect(origin: .zero, size: viewModel.preferredWindowSize)
        self.window = ClipboardPinPanel(
            contentRect: frame,
            styleMask: ClipboardPinWindowPresentation.styleMask,
            backing: .buffered,
            defer: false
        )

        super.init()

        configureWindow()
        configureContentView()
        bindViewModel()
        positionWindow()
    }

    var isVisible: Bool {
        window.isVisible
    }

    var snapshot: ClipboardPinWindowSnapshot {
        ClipboardPinWindowSnapshot(
            itemId: item.id,
            isVisible: window.isVisible,
            isAlwaysOnTop: viewModel.isAlwaysOnTop,
            levelRawValue: window.level.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: window.frame,
            screenFrame: window.screen?.visibleFrame,
            displayFrame: displayFrame
        )
    }

    func reveal() {
        #if DEBUG
        clipboardPinLogger.info("[ClipboardPin] reveal item=\(item.id) visible=\(window.isVisible) frame=\(window.frame) level=\(window.level.rawValue) displayFrame=\(displayFrame)")
        #endif
        bringToFront(activateApp: true)
    }

    func reassertAlwaysOnTop() {
        guard viewModel.isAlwaysOnTop, window.isVisible else { return }
        bringToFront(activateApp: false)
    }

    func hide() {
        window.orderOut(nil)
    }

    func close() {
        window.close()
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        viewModel.isAlwaysOnTop = enabled
        if enabled {
            bringToFront(activateApp: true)
        } else {
            applyWindowLevel()
        }
    }

    private func applyWindowLevel() {
        window.level = viewModel.isAlwaysOnTop ? ClipboardPinWindowPresentation.alwaysOnTopLevel : ClipboardPinWindowPresentation.fallbackLevel
        window.collectionBehavior = ClipboardPinWindowPresentation.collectionBehavior(isAlwaysOnTop: viewModel.isAlwaysOnTop)
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
    }

    private func bringToFront(activateApp: Bool) {
        refreshDisplayFrame()
        applyWindowLevel()
        window.isFloatingPanel = true
        window.alphaValue = 1
        if activateApp, NSApp.isActive == false {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window.isVisible else { return }
            self.applyWindowLevel()
            self.window.makeKeyAndOrderFront(nil)
            self.window.orderFrontRegardless()
        }
    }

    private func configureWindow() {
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // Keep resize-handle drags from being captured as window-move gestures.
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.04)
        window.isOpaque = false
        window.hasShadow = true
        window.animationBehavior = .utilityWindow
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.level = ClipboardPinWindowPresentation.alwaysOnTopLevel
        window.collectionBehavior = ClipboardPinWindowPresentation.collectionBehavior(isAlwaysOnTop: true)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.hidesOnDeactivate = false
    }

    private func configureContentView() {
        let rootView = ClipboardPinWindowView(
            viewModel: viewModel,
            onClose: { [weak self] in self?.close() },
            onToggleAlwaysOnTop: { [weak self] in self?.onToggleAlwaysOnTop() },
            onToggleExpandedSize: { [weak self] in self?.viewModel.toggleExpandedSize() },
            onBeginCustomResize: { [weak self] in
                self?.viewModel.shouldAnimateResize = false
            },
            onEndCustomResize: { [weak self] in
                self?.viewModel.shouldAnimateResize = true
            },
            onResize: { [weak self] delta in
                self?.viewModel.resize(by: delta)
            }
        )

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = CGRect(origin: .zero, size: viewModel.preferredWindowSize)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
    }

    private func bindViewModel() {
        viewModel.$preferredWindowSize
            .removeDuplicates()
            .sink { [weak self] size in
                self?.resizeWindow(to: size)
            }
            .store(in: &cancellables)
    }

    private func resizeWindow(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        refreshDisplayFrame()
        let targetFrame = Self.anchoredFrame(
            for: size,
            in: displayFrame
        )
        window.setFrame(targetFrame, display: true, animate: viewModel.shouldAnimateResize)
        window.contentView?.frame = CGRect(origin: .zero, size: size)
    }

    private func positionWindow() {
        refreshDisplayFrame()
        let size = viewModel.preferredWindowSize
        window.setFrame(Self.anchoredFrame(for: size, in: displayFrame), display: true)
    }

    private func refreshDisplayFrame() {
        let updatedFrame = window.screen?.visibleFrame ?? Self.activeDisplayFrame()
        guard updatedFrame.isNull == false, updatedFrame.isEmpty == false else { return }
        displayFrame = updatedFrame
        viewModel.updateDisplayFrame(updatedFrame)
    }

    private static func anchoredFrame(for size: CGSize, in displayFrame: CGRect) -> CGRect {
        let margin: CGFloat = 24
        let origin = CGPoint(
            x: max(displayFrame.minX + margin, displayFrame.maxX - size.width - margin),
            y: max(displayFrame.minY + margin, displayFrame.maxY - size.height - margin)
        )
        return CGRect(origin: origin, size: size)
    }

    private static func activeDisplayFrame() -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.visibleFrame, false) || NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screen.visibleFrame
        }
        if let clipboardWindow = NSApp.windows.first(where: { $0.isVisible && $0.title.contains("剪贴板 & 手机同步") }) {
            return clipboardWindow.screen?.visibleFrame ?? clipboardWindow.frame
        }
        if let screen = NSApp.keyWindow?.screen ?? NSApp.mainWindow?.screen {
            return screen.visibleFrame
        }
        return NSScreen.main?.visibleFrame ?? NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

}

struct ClipboardPinStructuredTextContent: Equatable {
    struct DetailRow: Equatable {
        let label: String
        let value: String
    }

    let title: String
    let metaLine: String?
    let detailRows: [DetailRow]
    let fallbackBody: String?
}

@MainActor
final class ClipboardPinWindowViewModel: ObservableObject {
    let item: ClipboardItem
    let assetStore: AssetStore
    private var displayFrame: CGRect

    @Published var loadedImage: NSImage?
    @Published var preferredWindowSize: CGSize
    @Published var isAlwaysOnTop: Bool = true
    var shouldAnimateResize: Bool = true
    private var didApplyManualResize = false
    private var previousWindowSizeBeforeExpand: CGSize?

    init(item: ClipboardItem, assetStore: AssetStore, displayFrame: CGRect) {
        self.item = item
        self.assetStore = assetStore
        self.displayFrame = displayFrame
        let baseSize = Self.initialSize(for: item, displayFrame: displayFrame)
        self.preferredWindowSize = baseSize
        loadContent()
    }

    var displayText: String {
        if let text = item.textContent, text.isEmpty == false {
            return text
        }
        if let content = item.content, content.isEmpty == false {
            return content
        }
        return "无内容"
    }

    var sourceLabel: String {
        if let source = item.sourceApp, source.isEmpty == false {
            return source
        }
        return "未知来源"
    }

    var titleText: String {
        switch item.type {
        case .image:
            return "图片剪贴板"
        case .text:
            return "文本剪贴板"
        case .file:
            return "文件剪贴板"
        case .url:
            return "链接剪贴板"
        case .richText:
            return "富文本剪贴板"
        case .code:
            return "代码剪贴板"
        case .video:
            return "视频剪贴板"
        }
    }

    var typeLabel: String {
        switch item.type {
        case .image:
            return "图片"
        case .text:
            return "文本"
        case .file:
            return "文件"
        case .url:
            return "链接"
        case .richText:
            return "富文本"
        case .code:
            return "代码"
        case .video:
            return "视频"
        }
    }

    var typeIcon: String {
        item.type.icon
    }

    var timestampText: String {
        item.createdAt.formatted(date: .omitted, time: .shortened)
    }

    var sourceAndTimeText: String {
        "\(sourceLabel) · \(timestampText)"
    }

    var timestampAndDetailText: String {
        [timestampText, contentDetailText]
            .compactMap { value in
                guard let value, value.isEmpty == false else { return nil }
                return value
            }
            .joined(separator: " · ")
    }

    var contentDetailText: String? {
        switch item.type {
        case .image:
            if let image = loadedImage {
                return "\(Int(image.size.width)) × \(Int(image.size.height))"
            }
            return "图片加载中"
        case .text, .url, .richText, .code:
            let length = displayText.count
            return "\(length) 字"
        case .file:
            let lines = displayText.split(separator: "\n", omittingEmptySubsequences: false).count
            return "\(lines) 个路径"
        case .video:
            return "视频"
        }
    }

    var structuredTextContent: ClipboardPinStructuredTextContent? {
        Self.parseStructuredTextContent(from: displayText)
    }

    private func loadContent() {
        guard item.type == .image || item.type == .video, let assetId = item.content else { return }
        Task { [weak self] in
            guard let self else { return }
            guard let asset = try? await assetStore.getAsset(id: assetId) else { return }
            let maxPixelSize = max(displayFrame.width * 1.5, displayFrame.height * 1.5)
            guard let image = assetStore.loadImage(asset: asset, maxPixelSize: maxPixelSize) else { return }
            await MainActor.run {
                self.loadedImage = image
                if self.didApplyManualResize == false {
                    self.preferredWindowSize = ClipboardPinWindowSizing.imageWindowSize(for: image.size, displayFrame: self.displayFrame)
                }
            }
        }
    }

    func updateDisplayFrame(_ frame: CGRect) {
        guard frame.isNull == false, frame.isEmpty == false else { return }
        displayFrame = frame
    }

    func resize(by delta: CGSize) {
        didApplyManualResize = true
        previousWindowSizeBeforeExpand = nil
        shouldAnimateResize = false
        let proposed = CGSize(
            width: preferredWindowSize.width + delta.width,
            height: preferredWindowSize.height + delta.height
        )
        preferredWindowSize = ClipboardPinWindowSizing.manualResizeWindowSize(
            proposed,
            itemType: item.type,
            displayFrame: displayFrame,
            imageSize: loadedImage?.size
        )
        #if DEBUG
        clipboardPinLogger.info("[ClipboardPin] resize item=\(item.id) delta=\(delta) proposed=\(proposed) clamped=\(preferredWindowSize)")
        #endif
    }

    func toggleExpandedSize() {
        didApplyManualResize = true
        shouldAnimateResize = true
        let expanded = ClipboardPinWindowSizing.expandedPresetWindowSize(
            for: item.type,
            displayFrame: displayFrame,
            imageSize: loadedImage?.size
        )

        if Self.isClose(preferredWindowSize, expanded), let previousWindowSizeBeforeExpand {
            preferredWindowSize = ClipboardPinWindowSizing.manualResizeWindowSize(
                previousWindowSizeBeforeExpand,
                itemType: item.type,
                displayFrame: displayFrame,
                imageSize: loadedImage?.size
            )
            self.previousWindowSizeBeforeExpand = nil
        } else {
            previousWindowSizeBeforeExpand = preferredWindowSize
            preferredWindowSize = expanded
        }
    }

    private static func initialSize(for item: ClipboardItem, displayFrame: CGRect) -> CGSize {
        switch item.type {
        case .image:
            return CGSize(
                width: min(ClipboardPinWindowSizing.maxWindowWidth, max(ClipboardPinWindowSizing.minimumWindowWidth, displayFrame.width * 0.30)),
                height: 260
            )
        default:
            let content = item.textContent ?? item.content ?? ""
            if let structured = parseStructuredTextContent(from: content) {
                return structuredTextWindowSize(for: structured, displayFrame: displayFrame)
            }
            return ClipboardPinWindowSizing.textWindowSize(for: content, displayFrame: displayFrame)
        }
    }

    private nonisolated static func isClose(_ lhs: CGSize, _ rhs: CGSize, tolerance: CGFloat = 2) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }

    private nonisolated static func structuredTextWindowSize(
        for content: ClipboardPinStructuredTextContent,
        displayFrame: CGRect
    ) -> CGSize {
        let rowCount = CGFloat(content.detailRows.count)
        let fallbackLines = CGFloat(content.fallbackBody?.split(separator: "\n").count ?? 0)
        let width = min(
            ClipboardPinWindowSizing.maxWindowWidth,
            max(360, displayFrame.width * 0.34)
        )
        let estimatedHeight = 188 + rowCount * 38 + fallbackLines * 22
        let maxHeight = min(
            ClipboardPinWindowSizing.maxContentHeight + ClipboardPinWindowSizing.chromeHeight + 72,
            displayFrame.height * 0.72
        )

        return CGSize(
            width: round(max(ClipboardPinWindowSizing.minimumWindowWidth, width)),
            height: round(min(maxHeight, max(220, estimatedHeight)))
        )
    }

    nonisolated static func parseStructuredTextContent(from text: String) -> ClipboardPinStructuredTextContent? {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.isEmpty == false else { return nil }

        let rawLines = normalizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard rawLines.isEmpty == false else { return nil }

        let title = rawLines[0]
        var metaLine: String?
        var detailRows: [ClipboardPinStructuredTextContent.DetailRow] = []
        var trailingBody: [String] = []

        for (index, line) in rawLines.enumerated() {
            if index == 0 { continue }

            if let row = parseDetailRow(from: line) {
                detailRows.append(row)
                continue
            }

            if metaLine == nil, let compactMeta = compactMetaLine(from: line) {
                metaLine = compactMeta
                continue
            }

            trailingBody.append(line)
        }

        let fallbackBody = trailingBody.isEmpty ? nil : trailingBody.joined(separator: "\n")
        guard detailRows.isEmpty == false || metaLine != nil else { return nil }
        return ClipboardPinStructuredTextContent(
            title: title,
            metaLine: metaLine,
            detailRows: detailRows,
            fallbackBody: fallbackBody
        )
    }

    private nonisolated static func parseDetailRow(from line: String) -> ClipboardPinStructuredTextContent.DetailRow? {
        let separators = ["：", ":"]
        guard let separator = separators.first(where: { line.contains($0) }) else { return nil }
        let components = line.components(separatedBy: separator)
        guard components.count >= 2 else { return nil }

        let rawLabel = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = components.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.isEmpty == false else { return nil }

        let normalizedLabel = normalizedDetailLabel(from: rawLabel)
        guard let normalizedLabel else { return nil }

        let normalizedValue = normalizedDetailValue(rawValue, label: normalizedLabel, originalLabel: rawLabel)
        return .init(label: normalizedLabel, value: normalizedValue)
    }

    private nonisolated static func compactMetaLine(from line: String) -> String? {
        guard line.contains("：") == false, line.contains(":") == false else { return nil }
        let pieces = line
            .split(whereSeparator: { $0.isWhitespace || $0 == "·" || $0 == "•" || $0 == "|" })
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard pieces.count >= 2, pieces.count <= 6 else { return nil }
        return pieces.joined(separator: " · ")
    }

    private nonisolated static func normalizedDetailLabel(from rawLabel: String) -> String? {
        let compact = rawLabel.replacingOccurrences(of: " ", with: "")
        if compact.contains("工作机") || compact.contains("设备") {
            return "工作机"
        }
        if compact.contains("时长") {
            return "时长"
        }
        if compact.contains("收入") || compact.contains("薪资") {
            return "收入"
        }
        return nil
    }

    private nonisolated static func normalizedDetailValue(_ rawValue: String, label: String, originalLabel: String) -> String {
        var value = rawValue
            .replacingOccurrences(of: "/", with: " / ")
            .replacingOccurrences(of: "／", with: " / ")
            .replacingOccurrences(of: "9-10K", with: "9–10K")
            .replacingOccurrences(of: " - ", with: "–")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)

        if label == "时长", originalLabel.contains("日均"), value.contains("/ ") == false, value.contains(" / ") == false {
            value += " / 日"
        }
        if label == "收入", originalLabel.contains("月均"), value.contains("/ ") == false, value.contains(" / ") == false {
            value += " / 月"
        }

        return value
    }
}

private enum PinCardToken {
    static let cardRadius: CGFloat = 24
    static let contentRadius: CGFloat = 18
    static let outerPadding: CGFloat = 16
    static let overlayHeight: CGFloat = 34
    static let overlayRadius: CGFloat = 17
    static let overlayHPadding: CGFloat = 12
    static let overlayVPadding: CGFloat = 7
    static let typeIconSize: CGFloat = 36
    static let typeIconRadius: CGFloat = 12
}

private struct ClipboardPinWindowView: View {
    @ObservedObject var viewModel: ClipboardPinWindowViewModel
    let onClose: () -> Void
    let onToggleAlwaysOnTop: () -> Void
    let onToggleExpandedSize: () -> Void
    let onBeginCustomResize: () -> Void
    let onEndCustomResize: () -> Void
    let onResize: (CGSize) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                metaBadge
                closeButton
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            content
                .overlay(alignment: .bottomTrailing) {
                    resizeHandle
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
        }
        .background(
            RoundedRectangle(cornerRadius: PinCardToken.cardRadius, style: .continuous)
                .fill(Color(red: 0.984, green: 0.986, blue: 0.991).opacity(0.98))
                .shadow(color: Color(white: 0, opacity: 0.08), radius: 24, x: 0, y: 12)
        )
        .clipShape(RoundedRectangle(cornerRadius: PinCardToken.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PinCardToken.cardRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
        )
        .frame(minWidth: 280, minHeight: 160)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if viewModel.item.type == .video {
                videoCard(previewImage: viewModel.loadedImage)
            } else if let image = viewModel.loadedImage, viewModel.item.type == .image {
                imageCard(image)
            } else {
                textCard
            }
        }
    }

    private var typeBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PinCardToken.typeIconRadius, style: .continuous)
                .fill(.thinMaterial)

            Image(systemName: viewModel.typeIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(typeAccentColor)
        }
        .frame(width: PinCardToken.typeIconSize, height: PinCardToken.typeIconSize)
        .overlay(
            RoundedRectangle(cornerRadius: PinCardToken.typeIconRadius, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .help("关闭")
    }

    private var textCard: some View {
        ZStack(alignment: .bottomLeading) {
            ScrollView(.vertical, showsIndicators: false) {
                textContentSurface
                    .padding(PinCardToken.outerPadding)
                    .padding(.bottom, 24)
            }

            typeBadge
                .padding(PinCardToken.outerPadding)
        }
    }

    private func imageCard(_ image: NSImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: min(420, viewModel.preferredWindowSize.height - 54))
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: PinCardToken.contentRadius, style: .continuous))
                .overlay(
                RoundedRectangle(cornerRadius: PinCardToken.contentRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            HStack(alignment: .bottom, spacing: 12) {
                HStack(alignment: .bottom, spacing: 10) {
                    typeBadge
                    if viewModel.item.type == .video {
                        mediaPlayBadge
                    }
                }
            }
            .padding(18)
        }
        .padding(PinCardToken.outerPadding)
    }

    private func videoCard(previewImage: NSImage?) -> some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                if let previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.88),
                            Color(red: 0.16, green: 0.17, blue: 0.20),
                            Color.black.opacity(0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 10) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.92))

                        Text("视频内容")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: min(420, viewModel.preferredWindowSize.height - 54))
            .background(Color.black.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: PinCardToken.contentRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PinCardToken.contentRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )

            HStack(alignment: .bottom, spacing: 12) {
                HStack(alignment: .bottom, spacing: 10) {
                    typeBadge
                    mediaPlayBadge
                }
            }
            .padding(18)
        }
        .padding(PinCardToken.outerPadding)
    }

    private var textContentSurface: some View {
        HStack(alignment: .top, spacing: 18) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(typeAccentColor)
                .frame(width: 4)
                .padding(.vertical, 14)

            if let structured = viewModel.structuredTextContent {
                structuredTextContent(structured)
            } else {
                fallbackTextContent(viewModel.displayText)
            }
        }
        .padding(.vertical, 24)
        .padding(.leading, 24)
        .padding(.trailing, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PinCardToken.contentRadius, style: .continuous)
                .fill(Color(red: 0.976, green: 0.979, blue: 0.987).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PinCardToken.contentRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }

    private func structuredTextContent(_ content: ClipboardPinStructuredTextContent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(content.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let metaLine = content.metaLine {
                Text(metaLine)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if content.detailRows.isEmpty == false {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 1)
                    .padding(.top, 14)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(content.detailRows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .firstTextBaseline, spacing: 18) {
                            Text(row.label)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                .frame(width: 76, alignment: .leading)

                            Text(row.value)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(nsColor: .labelColor))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            if let fallbackBody = content.fallbackBody, fallbackBody.isEmpty == false {
                Text(fallbackBody)
                    .font(.system(size: 14))
                    .lineSpacing(2)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.top, content.detailRows.isEmpty ? 14 : 16)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fallbackTextContent(_ text: String) -> some View {
        Text(text.isEmpty ? "无内容" : text)
            .font(.system(size: 15, weight: .regular))
            .lineSpacing(3)
            .foregroundStyle(Color(nsColor: .labelColor))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediaPlayBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(viewModel.contentDetailText ?? "播放")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .frame(height: PinCardToken.overlayHeight)
        .background(Color.black.opacity(0.32))
        .clipShape(Capsule(style: .continuous))
    }

    private var metaBadge: some View {
        HStack(spacing: 12) {
            Text(viewModel.sourceAndTimeText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .lineLimit(1)

            Rectangle()
                .fill(Color.black.opacity(0.14))
                .frame(width: 1, height: 18)

            Button(action: onToggleAlwaysOnTop) {
                Image(systemName: viewModel.isAlwaysOnTop ? "pin.fill" : "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            .help(viewModel.isAlwaysOnTop ? "取消置顶" : "固定到桌面顶端")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, PinCardToken.overlayVPadding)
        .frame(minHeight: PinCardToken.overlayHeight)
        .background(.thinMaterial)
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        )
    }

    private var typeAccentColor: Color {
        switch viewModel.item.type {
        case .image, .video:
            return Color(red: 108 / 255, green: 92 / 255, blue: 1.0)
        case .richText, .text:
            return Color(red: 92 / 255, green: 104 / 255, blue: 1.0)
        default:
            return viewModel.item.type.color
        }
    }

    private var resizeHandle: some View {
        ResizeHandle(
            onToggleExpandedSize: onToggleExpandedSize,
            onBeginCustomResize: onBeginCustomResize,
            onEndCustomResize: onEndCustomResize,
            onDrag: { delta in
                onResize(delta)
            }
        )
        .help("点按切换大小，长按后拖动自定义大小")
    }
}

private struct ResizeHandle: View {
    let onToggleExpandedSize: () -> Void
    let onBeginCustomResize: () -> Void
    let onEndCustomResize: () -> Void
    let onDrag: (CGSize) -> Void
    @State private var lastTranslation: CGSize = .zero
    @State private var isCustomResizing = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .padding(5)
        }
        .frame(width: 40, height: 40, alignment: .bottomTrailing)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.26), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard isCustomResizing == false else { return }
            onToggleExpandedSize()
        }
        .gesture(resizeGesture)
    }

    private var resizeGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.22, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    if isCustomResizing == false {
                        isCustomResizing = true
                        lastTranslation = .zero
                        onBeginCustomResize()
                    }
                case .second(true, let drag?):
                    if isCustomResizing == false {
                        isCustomResizing = true
                        onBeginCustomResize()
                    }
                    let delta = CGSize(
                        width: drag.translation.width - lastTranslation.width,
                        height: drag.translation.height - lastTranslation.height
                    )
                    lastTranslation = drag.translation
                    guard delta.width != 0 || delta.height != 0 else { return }
                    #if DEBUG
                    clipboardPinLogger.info("[ClipboardPin] resize gesture translation=\(drag.translation) delta=\(delta)")
                    #endif
                    onDrag(delta)
                default:
                    break
                }
            }
            .onEnded { _ in
                lastTranslation = .zero
                if isCustomResizing {
                    onEndCustomResize()
                }
                isCustomResizing = false
            }
    }
}
