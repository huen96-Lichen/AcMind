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
    private var isExpanded = false

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
        setupScreenObserver()
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
        // 直接使用 NSHostingView，不使用自定义容器
        let capsule = NotchV2RootView(viewModel: viewModel) { [weak self] expanded in
            self?.setExpanded(expanded, animated: true)
        }
        let hosting = NSHostingView(rootView: capsule)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
        self.hostingView = hosting
        syncWindowSize(with: CompanionScreenPositioning.collapsedFrame().size)
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
        let frame = isExpanded
            ? CompanionScreenPositioning.expandedFrame(anchorFrame: CompanionScreenPositioning.collapsedFrame())
            : CompanionScreenPositioning.collapsedFrame()
        syncWindowSize(with: frame.size)
        setFrame(frame, display: true)
        hostingView?.frame = NSRect(origin: .zero, size: frame.size)
        
        print("[NotchPanel] Positioning: frame=\(frame), realWidth=\(self.frame.width), realHeight=\(self.frame.height), hasNotch=\(CompanionScreenPositioning.hasHardwareNotch())")
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        viewModel.isExpanded = expanded
        if expanded {
            viewModel.selectedPage = .overview
        }

        let targetFrame = expanded
            ? CompanionScreenPositioning.expandedFrame(anchorFrame: frame)
            : CompanionScreenPositioning.collapsedFrame()

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = expanded ? CompanionMenuBarLayout.expandDuration : CompanionMenuBarLayout.collapseDuration
                animator().setFrame(targetFrame, display: true)
            }
        } else {
            setFrame(targetFrame, display: true)
        }
        syncWindowSize(with: targetFrame.size)
        hostingView?.frame = NSRect(origin: .zero, size: targetFrame.size)
        print("[NotchPanel] setExpanded(\(expanded)): frame=\(targetFrame), realWidth=\(self.frame.width), realHeight=\(self.frame.height)")
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

    private func syncWindowSize(with size: CGSize) {
        minSize = size
        maxSize = size
        contentMinSize = size
        contentMaxSize = size
    }
}
