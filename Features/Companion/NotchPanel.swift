import SwiftUI
import AppKit
import AcMindKit

// MARK: - Notch Panel
// 刘海面板 - 屏幕顶部菜单栏区域的胶囊入口
// 类似 BoringNotch / NotchNook 的实现方式

@MainActor
final class NotchPanel: NSPanel {
    static let shared = NotchPanel()

    private var hostingView: NSHostingView<CompanionCapsule>?

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
        let capsule = CompanionCapsule()
        let hosting = NSHostingView(rootView: capsule)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.contentView = hosting
        self.hostingView = hosting
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
        let collapsedFrame = CompanionScreenPositioning.collapsedFrame()
        setFrame(collapsedFrame, display: true)
        
        print("[NotchPanel] Positioning: frame=\(frame), hasNotch=\(CompanionScreenPositioning.hasHardwareNotch())")
    }

    // MARK: - Show / Hide

    func show() {
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
