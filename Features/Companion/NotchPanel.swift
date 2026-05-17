import SwiftUI
import AppKit
import AcMindKit

// MARK: - Notch Panel
// 刘海面板 - 屏幕顶部菜单栏区域的胶囊入口
// 类似 BoringNotch / NotchNook 的实现方式

@MainActor
final class NotchPanel: NSPanel {
    static let shared = NotchPanel()

    private let viewModel = NotchV2ViewModel()
    private var hostingView: NSHostingView<NotchV2RootView>?
    private var contentContainerView: NSView?
    private var isExpanded = false

    private init() {
        // 初始尺寸，后续会根据内容自适应
        super.init(
            contentRect: CompanionScreenPositioning.collapsedFrame(on: NSScreen.main),
            styleMask: [.nonactivatingPanel, .hudWindow, .borderless],
            backing: .buffered,
            defer: false
        )

        setupPanel()
        setupContentView()
        setupScreenObserver()
        DynamicSurfaceCoordinator.shared.registerContinentAdapter(ContinentPanelAdapter(panel: self))
    }

    // MARK: - Panel Setup

    private func setupPanel() {
        // 使用统一的窗口配置
        CompanionScreenPositioning.configureWindowLevel(self)
        
        // 额外配置
        self.isMovableByWindowBackground = false  // 固定在顶部，不允许拖拽
        self.acceptsMouseMovedEvents = true
        self.becomesKeyOnlyIfNeeded = false
        self.animationBehavior = .utilityWindow

        // 关键：不忽略鼠标事件，让窗口接收所有事件
        self.ignoresMouseEvents = false

        print("[NotchPanel] setupPanel completed, level: \(level.rawValue)")
    }

    // MARK: - Content View

    private func setupContentView() {
        let containerView = NSView(frame: CompanionScreenPositioning.collapsedFrame(on: NSScreen.main))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        let capsule = NotchV2RootView(viewModel: viewModel) { [weak self] expanded in
            self?.setExpanded(expanded, animated: true)
        }
        let hosting = NSHostingView(rootView: capsule)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        containerView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: containerView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        self.contentView = containerView
        self.hostingView = hosting
        self.contentContainerView = containerView
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

    @objc private func handleScreenParametersChanged(_ notification: Notification) {
        positionAtTopCenter()
    }

    // MARK: - Positioning

    /// 将面板定位到屏幕顶部菜单栏区域
    func positionAtTopCenter() {
        let currentFrame = self.frame
        let screen = CompanionScreenPositioning.screen(for: CGPoint(x: currentFrame.midX, y: currentFrame.midY))
        let frame = isExpanded
            ? CompanionScreenPositioning.expandedFrame(centeredOnX: currentFrame.midX, on: screen)
            : CompanionScreenPositioning.collapsedFrame(centeredOnX: currentFrame.midX, on: screen)
        setFrame(frame, display: true)
        
        print("[NotchPanel] Positioning: frame=\(frame), realWidth=\(self.frame.width), realHeight=\(self.frame.height), hasNotch=\(CompanionScreenPositioning.hasHardwareNotch())")
    }

    func showCompact(on screen: NSScreen? = nil, at point: CGPoint? = nil, animated: Bool = true) {
        viewModel.isExpanded = false
        isExpanded = false

        let frame: CGRect
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        if let point {
            frame = CompanionScreenPositioning.collapsedFrame(on: targetScreen ?? CompanionScreenPositioning.screen(for: point))
        } else {
            frame = CompanionScreenPositioning.collapsedFrame(on: targetScreen)
        }

        setFrame(frame, display: true)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    func showExpanded(on screen: NSScreen? = nil, at point: CGPoint? = nil, animated: Bool = true) {
        showCompact(on: screen, at: point, animated: animated)
        setExpanded(true, animated: animated)
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        viewModel.isExpanded = expanded
        if expanded {
            viewModel.selectedPage = .overview
        }

        let screen = CompanionScreenPositioning.screen(for: CGPoint(x: frame.midX, y: frame.midY))
        let targetFrame = expanded
            ? CompanionScreenPositioning.expandedFrame(centeredOnX: frame.midX, on: screen)
            : CompanionScreenPositioning.collapsedFrame(centeredOnX: frame.midX, on: screen)

        setFrame(targetFrame, display: true)
        print("[NotchPanel] setExpanded(\(expanded)): frame=\(targetFrame), realWidth=\(self.frame.width), realHeight=\(self.frame.height)")
    }

    func moveCompact(to point: CGPoint, on screen: NSScreen? = nil, animated: Bool = false) {
        let targetScreen = screen ?? CompanionScreenPositioning.screen(for: point) ?? NSScreen.main ?? NSScreen.screens.first
        let frame = CompanionScreenPositioning.collapsedFrame(centeredOnX: targetScreen?.frame.midX ?? point.x, on: targetScreen)
        setFrame(frame, display: true)
    }

    // MARK: - Show / Hide

    func show() {
        viewModel.isExpanded = true
        viewModel.selectedPage = .overview
        isExpanded = true
        positionAtTopCenter()
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        print("[NotchPanel] show() called, isVisible: \(isVisible), frame: \(frame)")
    }

    func hide() {
        orderOut(nil)
        print("[NotchPanel] hide() called")
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

}
