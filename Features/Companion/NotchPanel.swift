import SwiftUI
import AppKit
import CoreGraphics
import Combine
import AcMindKit

// MARK: - Notch Panel
// 刘海面板 - 屏幕顶部菜单栏区域的胶囊入口
// 类似 BoringNotch / NotchNook 的实现方式

@MainActor
final class NotchPanel: NSPanel {
    static let shared = NotchPanel()

    private let viewModel = NotchV2ViewModel()
    private var hostingView: NSHostingView<NotchV2RootView>?
    private var pendingDockDecision: DispatchWorkItem?
    private var lastKnownScreenFrame: CGRect?
    private var displaySettingsObserver: NSObjectProtocol?
    private var screenRecordingMonitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 初始尺寸，后续会根据内容自适应
        super.init(
            contentRect: CompanionScreenPositioning.collapsedFrame(),
            styleMask: [.nonactivatingPanel, .hudWindow, .borderless],
            backing: .buffered,
            defer: false
        )

        setupPanel()
        setupContentView()
        setupViewModelBindings()
        setupScreenObserver()
        setupDisplaySettingsObserver()
        setupScreenRecordingMonitor()
    }

    // MARK: - Panel Setup

    private func setupPanel() {
        // 使用统一的窗口配置
        CompanionScreenPositioning.configureWindowLevel(self)
        applyDisplaySettings(CompanionDisplaySettingsStore.load())
        
        // 额外配置：仅收缩态允许拖拽，展开态禁用背景拖动
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true
        self.becomesKeyOnlyIfNeeded = false
        self.animationBehavior = .utilityWindow
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true

        // 关键：不忽略鼠标事件，让窗口接收所有事件
        self.ignoresMouseEvents = false
        self.delegate = self

        print("[NotchPanel] setupPanel completed, level: \(level.rawValue)")
    }

    // MARK: - Content View

    private func setupContentView() {
        // 直接使用 NSHostingView，不使用自定义容器
        let capsule = NotchV2RootView(viewModel: viewModel) { [weak self] expanded in
            if expanded {
                self?.viewModel.requestOpen(page: self?.viewModel.effectiveSelectedPage ?? .overview)
            } else {
                self?.viewModel.requestCompact()
            }
        }
        let hosting = NSHostingView(rootView: capsule)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
        self.hostingView = hosting
        syncWindowSize(with: CompanionScreenPositioning.collapsedFrame().size)
    }

    private func setupViewModelBindings() {
        viewModel.$presentationState
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.applyPresentationState(state, animated: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - Screen Observer

    private func setupScreenObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func setupDisplaySettingsObserver() {
        displaySettingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.applyDisplaySettings(CompanionDisplaySettingsStore.load())
            }
        }
    }

    private func setupScreenRecordingMonitor() {
        screenRecordingMonitorTimer?.invalidate()
        screenRecordingMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateVisibilityPolicies()
            }
        }
        RunLoop.main.add(screenRecordingMonitorTimer!, forMode: .common)
    }

    @objc private func handleScreenParametersChanged(_ notification: Notification) {
        positionAtTopCenter()
    }

    // MARK: - Positioning

    /// 将面板定位到屏幕顶部菜单栏区域
    func positionAtTopCenter(using screenFrame: CGRect? = nil) {
        let settings = CompanionDisplaySettingsStore.load()
        guard settings.isEnabled else {
            hide()
            return
        }
        applyDisplaySettings(settings)
        guard shouldRemainVisible(for: settings) else {
            hide()
            return
        }
        let screenFrame = screenFrame ?? currentScreenFrame()
        let frame = viewModel.presentationState.isExpandedVisual
            ? CompanionScreenPositioning.expandedFrame(on: screenFrame)
            : CompanionScreenPositioning.collapsedFrame(on: screenFrame)
        syncWindowSize(with: frame.size)
        setFrame(frame, display: true)
        hostingView?.frame = NSRect(origin: .zero, size: frame.size)
        lastKnownScreenFrame = screenFrame
        
        print("[NotchPanel] Positioning: frame=\(frame), realWidth=\(self.frame.width), realHeight=\(self.frame.height), hasNotch=\(CompanionScreenPositioning.hasHardwareNotch())")
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        if expanded {
            viewModel.requestOpen(page: viewModel.effectiveSelectedPage)
        } else {
            viewModel.requestCompact()
        }
    }

    // MARK: - Show / Hide

    func show(on screen: NSScreen? = nil) {
        let settings = CompanionDisplaySettingsStore.load()
        guard settings.isEnabled else {
            hide()
            return
        }
        guard shouldRemainVisible(for: settings) else {
            hide()
            return
        }
        DesktopCapsulePanel.shared.hide()
        applyDisplaySettings(settings)
        let screenFrame = screen?.frame ?? lastKnownScreenFrame ?? currentScreenFrame()
        lastKnownScreenFrame = screenFrame
        viewModel.requestOpen(page: .overview)
    }

    func show(page: NotchV2Page, on screen: NSScreen? = nil) {
        let settings = CompanionDisplaySettingsStore.load()
        guard settings.isEnabled else {
            hide()
            return
        }
        let screenFrame = screen?.frame ?? lastKnownScreenFrame ?? currentScreenFrame()
        lastKnownScreenFrame = screenFrame
        DesktopCapsulePanel.shared.hide()
        applyDisplaySettings(settings)
        viewModel.requestOpen(page: page)
    }

    func showCompact(on screen: NSScreen? = nil) {
        let settings = CompanionDisplaySettingsStore.load()
        guard settings.isEnabled else {
            hide()
            return
        }
        let screenFrame = screen?.frame ?? lastKnownScreenFrame ?? currentScreenFrame()
        lastKnownScreenFrame = screenFrame
        DesktopCapsulePanel.shared.hide()
        applyDisplaySettings(settings)
        viewModel.requestCompact()
    }

    func hide() {
        viewModel.requestHide()
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func scheduleDockDecision() {
        guard viewModel.presentationState.isExpandedVisual == false else { return }
        pendingDockDecision?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.evaluateDockingAfterMove()
        }
        pendingDockDecision = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func evaluateDockingAfterMove() {
        guard isVisible else { return }

        let screenFrame = currentScreenFrame()
        lastKnownScreenFrame = screenFrame

        if CompanionDockingRules.shouldDockDesktopCapsuleToNotch(frame: frame, screenFrame: screenFrame) {
            positionAtTopCenter(using: screenFrame)
            return
        }

        dockToDesktopCapsule()
    }

    private func dockToDesktopCapsule() {
        let capsuleOrigin = CGPoint(
            x: frame.midX - 21,
            y: frame.midY - 21
        )

        hide()
        DesktopCapsulePanel.shared.show(at: capsuleOrigin)
        print("[NotchPanel] dockToDesktopCapsule() called, capsuleOrigin=\(capsuleOrigin)")
    }

    private func currentScreenFrame() -> CGRect {
        let screens = NSScreen.screens.map(\.frame)
        if let selected = CompanionScreenPositioning.preferredScreenFrame(for: frame, screenFrames: screens) {
            return selected
        }
        if let cached = lastKnownScreenFrame {
            return cached
        }
        return NSScreen.main?.frame ?? frame
    }

    private func syncWindowSize(with size: CGSize) {
        minSize = size
        maxSize = size
        contentMinSize = size
        contentMaxSize = size
    }

    private func applyDisplaySettings(_ settings: CompanionDisplaySettings) {
        collectionBehavior = settings.collectionBehavior
        if settings.isEnabled == false {
            orderOut(nil)
        }
    }

    private func evaluateVisibilityPolicies() {
        let settings = CompanionDisplaySettingsStore.load()
        applyDisplaySettings(settings)

        guard settings.isEnabled else {
            if isVisible {
                orderOut(nil)
            }
            return
        }

        if shouldRemainVisible(for: settings) == false, isVisible {
            orderOut(nil)
        }
    }

    private func shouldRemainVisible(for settings: CompanionDisplaySettings) -> Bool {
        if settings.hideWhenScreenRecording && isScreenRecordingActive() {
            return false
        }
        return true
    }

    private func isScreenRecordingActive() -> Bool {
        typealias CGDisplayIsCapturedFunction = @convention(c) (CGDirectDisplayID) -> Int32

        guard
            let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
            let symbol = dlsym(handle, "CGDisplayIsCaptured")
        else {
            return false
        }

        let function = unsafeBitCast(symbol, to: CGDisplayIsCapturedFunction.self)
        return function(CGMainDisplayID()) != 0
    }

    private func applyPresentationState(_ state: NotchPresentationState, animated: Bool) {
        let settings = CompanionDisplaySettingsStore.load()
        guard settings.isEnabled else {
            orderOut(nil)
            return
        }
        guard shouldRemainVisible(for: settings) || state == .hidden else {
            orderOut(nil)
            return
        }

        switch state {
        case .hidden:
            orderOut(nil)
            return
        case .compact, .transientHUD:
            isMovableByWindowBackground = true
        case .open, .blockedClose:
            isMovableByWindowBackground = false
        }

        let screenFrame = lastKnownScreenFrame ?? currentScreenFrame()
        let targetFrame = state.isExpandedVisual
            ? CompanionScreenPositioning.expandedFrame(on: screenFrame)
            : CompanionScreenPositioning.collapsedFrame(on: screenFrame)

        if animated, isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = state.isExpandedVisual ? NotchV2DesignTokens.windowExpandDuration : NotchV2DesignTokens.windowCollapseDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().setFrame(targetFrame, display: true)
            }
        } else {
            setFrame(targetFrame, display: true)
        }

        syncWindowSize(with: targetFrame.size)
        hostingView?.frame = NSRect(origin: .zero, size: targetFrame.size)
        lastKnownScreenFrame = screenFrame
        if isVisible == false {
            makeKeyAndOrderFront(nil)
            orderFrontRegardless()
        }
    }
}

extension NotchPanel: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        scheduleDockDecision()
    }
}
