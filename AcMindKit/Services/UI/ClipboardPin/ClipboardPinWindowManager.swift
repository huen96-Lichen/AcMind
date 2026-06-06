import AppKit
import Combine
import SwiftUI

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
        print("[ClipboardPin] manager show item=\(item.id) windows=\(windows.count) preferredDisplayFrame=\(String(describing: preferredDisplayFrame))")
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
            "AcMind Clipboard Pin Diagnostics",
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
    static let styleMask: NSWindow.StyleMask = [.borderless, .hudWindow, .fullSizeContentView, .nonactivatingPanel]
    static let alwaysOnTopLevel: NSWindow.Level = .screenSaver
    static let fallbackLevel: NSWindow.Level = .floating
    static let reassertionDelays: [TimeInterval] = [0.05, 0.20, 0.60]

    static func collectionBehavior(isAlwaysOnTop: Bool) -> NSWindow.CollectionBehavior {
        isAlwaysOnTop
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary, .moveToActiveSpace]
            : [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }
}

final class ClipboardPinPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override var canBecomeMain: Bool { true }
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
        print("[ClipboardPin] reveal item=\(item.id) visible=\(window.isVisible) frame=\(window.frame) level=\(window.level.rawValue) displayFrame=\(displayFrame)")
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
        applyWindowLevel()
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
        window.alphaValue = 1
        if activateApp, NSApp.isActive == false {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window.isVisible else { return }
            self.applyWindowLevel()
            self.window.orderFrontRegardless()
            self.window.makeKeyAndOrderFront(nil)
        }
    }

    private func configureWindow() {
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.04)
        window.isOpaque = false
        window.hasShadow = true
        window.animationBehavior = .utilityWindow
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
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
            onClose: { [weak self] in self?.close() }
        )

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = CGRect(origin: .zero, size: viewModel.preferredWindowSize)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
    }

    private func bindViewModel() {
        viewModel.$preferredWindowSize
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] size in
                self?.resizeWindow(to: size)
            }
            .store(in: &cancellables)
    }

    private func resizeWindow(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let targetFrame = Self.anchoredFrame(
            for: size,
            in: displayFrame
        )
        window.setFrame(targetFrame, display: true, animate: true)
        window.contentView?.frame = CGRect(origin: .zero, size: size)
    }

    private func positionWindow() {
        let size = viewModel.preferredWindowSize
        window.setFrame(Self.anchoredFrame(for: size, in: displayFrame), display: true)
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

    func windowDidResignKey(_ notification: Notification) {
        guard viewModel.isAlwaysOnTop else { return }
        DispatchQueue.main.async { [weak self] in
            self?.reassertAlwaysOnTop()
        }
    }

    func windowDidResignMain(_ notification: Notification) {
        guard viewModel.isAlwaysOnTop else { return }
        DispatchQueue.main.async { [weak self] in
            self?.reassertAlwaysOnTop()
        }
    }
}

@MainActor
final class ClipboardPinWindowViewModel: ObservableObject {
    let item: ClipboardItem
    let assetStore: AssetStore
    private let displayFrame: CGRect

    @Published var loadedImage: NSImage?
    @Published var preferredWindowSize: CGSize
    @Published var isAlwaysOnTop: Bool = true

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

    private func loadContent() {
        guard item.type == .image, let assetId = item.content else { return }
        Task { [weak self] in
            guard let self else { return }
            guard let asset = try? await assetStore.getAsset(id: assetId) else { return }
            let maxPixelSize = max(displayFrame.width * 1.5, displayFrame.height * 1.5)
            guard let image = assetStore.loadImage(asset: asset, maxPixelSize: maxPixelSize) else { return }
            await MainActor.run {
                self.loadedImage = image
                self.preferredWindowSize = ClipboardPinWindowSizing.imageWindowSize(for: image.size, displayFrame: self.displayFrame)
            }
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
            return ClipboardPinWindowSizing.textWindowSize(for: item.textContent ?? item.content ?? "", displayFrame: displayFrame)
        }
    }
}

private struct ClipboardPinWindowView: View {
    @ObservedObject var viewModel: ClipboardPinWindowViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.18)

            content
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.97))
                .shadow(color: Color(white: 0, opacity: 0.16), radius: 18, x: 0, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(minWidth: 280, minHeight: 160)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: viewModel.typeIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(viewModel.item.type.color)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.item.type.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .lineLimit(1)

                Text("\(viewModel.sourceLabel) · \(viewModel.timestampText)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color(white: 0, opacity: 0.04)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .help("关闭")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                if let image = viewModel.loadedImage {
                    imageCard(image)
                } else {
                    textCard(viewModel.displayText)
                }
            }
            .padding(12)
        }
    }

    private func textCard(_ text: String) -> some View {
        Text(text.isEmpty ? "无内容" : text)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(Color(nsColor: .labelColor))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.58))
            )
    }

    private func imageCard(_ image: NSImage) -> some View {
        return Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: min(360, viewModel.preferredWindowSize.height - 132))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0, opacity: 0.035))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(white: 1, opacity: 0.12), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}
