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

    private var viewModel: NotchV2ViewModel!
    private weak var desktopCapsuleController: DesktopCapsulePanelControlling?
    private var serviceContainer: ServiceContainer?
    private var hostingView: NSHostingView<AnyView>?
    private var pendingDockDecision: DispatchWorkItem?
    private var lastKnownScreenFrame: CGRect?
    private var lastAppliedFrame: CGRect?
    private var displaySettingsObserver: NSObjectProtocol?
    private var screenRecordingMonitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.desktopCapsuleController = nil
        // 初始尺寸，后续会根据内容自适应
        super.init(
            contentRect: CompanionScreenPositioning.collapsedFrame(),
            styleMask: [.nonactivatingPanel, .hudWindow, .borderless],
            backing: .buffered,
            defer: false
        )

        setupPanel()
        setupScreenObserver()
        setupDisplaySettingsObserver()
        setupScreenRecordingMonitor()
    }

    func connect(desktopCapsuleController: DesktopCapsulePanelControlling) {
        self.desktopCapsuleController = desktopCapsuleController
    }

    func connect(serviceContainer: ServiceContainer) {
        self.serviceContainer = serviceContainer
        if viewModel == nil {
            viewModel = NotchV2ViewModel(
                panelController: self,
                batteryService: serviceContainer.batteryService,
                systemEventCenter: serviceContainer.systemEventCenter,
                musicService: serviceContainer.musicService
            )
            setupContentView()
            setupViewModelBindings()
        }
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

    }

    // MARK: - Content View

    private func setupContentView() {
        let capsule = NotchV2RootView(viewModel: viewModel) { [weak self] expanded in
            if expanded {
                self?.viewModel.requestOpen(page: self?.viewModel.effectiveSelectedPage ?? .overview)
            } else {
                self?.viewModel.requestCompact()
            }
        }
        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.translatesAutoresizingMaskIntoConstraints = true
        let rootView = serviceContainer.map { AnyView(capsule.environmentObject($0)) } ?? AnyView(capsule)
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        self.contentView = container
        self.hostingView = hosting
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
        syncScreenRecordingMonitor()
    }

    private func syncScreenRecordingMonitor(with settings: CompanionDisplaySettings? = nil) {
        let settings = settings ?? CompanionDisplaySettingsStore.load()
        let shouldMonitor = isVisible && settings.isEnabled && settings.hideWhenScreenRecording

        if shouldMonitor {
            guard screenRecordingMonitorTimer == nil else { return }
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.evaluateVisibilityPolicies()
                }
            }
            screenRecordingMonitorTimer = timer
            RunLoop.main.add(timer, forMode: .common)
            return
        }

        screenRecordingMonitorTimer?.invalidate()
        screenRecordingMonitorTimer = nil
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
        applyWindowFrame(frame)
        lastKnownScreenFrame = screenFrame
        
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
        desktopCapsuleController?.hide()
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
        desktopCapsuleController?.hide()
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
        desktopCapsuleController?.hide()
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
        desktopCapsuleController?.show(at: capsuleOrigin)
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

    private func applyWindowFrame(_ frame: CGRect) {
        guard lastAppliedFrame != frame else {
            return
        }

        lastAppliedFrame = frame
        setFrame(frame, display: true)
    }

    private func applyDisplaySettings(_ settings: CompanionDisplaySettings) {
        collectionBehavior = settings.collectionBehavior
        if settings.isEnabled == false {
            orderOut(nil)
        }
        syncScreenRecordingMonitor(with: settings)
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
        syncScreenRecordingMonitor(with: settings)
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
        case .compact, .collapsing, .transientHUD:
            isMovableByWindowBackground = true
        case .expanding, .expanded, .blockedClose:
            isMovableByWindowBackground = false
        }

        let screenFrame = lastKnownScreenFrame ?? currentScreenFrame()
        let targetFrame = state.targetFrameIsExpanded
            ? CompanionScreenPositioning.expandedFrame(on: screenFrame)
            : CompanionScreenPositioning.collapsedFrame(on: screenFrame)

        if lastAppliedFrame != targetFrame {
            setFrame(targetFrame, display: true)
            lastAppliedFrame = targetFrame
        } else {
            applyWindowFrame(targetFrame)
        }
        lastKnownScreenFrame = screenFrame
        if isVisible == false {
            makeKeyAndOrderFront(nil)
            orderFrontRegardless()
        }
        syncScreenRecordingMonitor(with: settings)
    }
}

@MainActor
protocol NotchPanelControlling: AnyObject {
    func hide()
    func showCompact(on screen: NSScreen?)
}

extension NotchPanel: NotchPanelControlling {}

extension NotchPanel: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        scheduleDockDecision()
    }
}
