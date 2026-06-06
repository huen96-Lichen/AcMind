import SwiftUI
import AppKit
import AcMindKit

// MARK: - Desktop Capsule Panel

/// 桌面快捷胶囊 - 独立悬浮窗口
/// 功能：
/// 1. 默认圆形图标，点击展开为胶囊形状
/// 2. 用户自定义功能快捷入口
/// 3. 支持拖拽，位置记忆
final class DesktopCapsulePanel: NSPanel {
    static let shared = DesktopCapsulePanel()

    private var hostingView: NSHostingView<DesktopCapsuleView>?
    private var isDockedToNotch = false
    private weak var notchController: NotchPanelControlling?
    private var dockingCoordinator: DesktopCapsuleDockingCoordinator?

    private init() {
        self.notchController = nil
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 42, height: 42),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        setupPanel()
        setupContentView()
    }

    func connect(notchController: NotchPanelControlling) {
        self.notchController = notchController
    }

    func connect(dockingCoordinator: DesktopCapsuleDockingCoordinator) {
        self.dockingCoordinator = dockingCoordinator
    }

    private func setupPanel() {
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.delegate = self
    }

    private func setupContentView() {
        let viewModel = DesktopCapsuleViewModel(panelController: self)
        let contentView = DesktopCapsuleView(viewModel: viewModel)
        hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
    }

    // MARK: - Public Methods

    func show(at position: CGPoint? = nil) {
        isDockedToNotch = false
        alphaValue = 1
        notchController?.hide()
        if let position = position {
            setFrameOrigin(position)
        } else {
            centerOnScreen()
        }
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    func hide() {
        isDockedToNotch = false
        alphaValue = 1
        orderOut(nil)
    }

    func dockToNotch() {
        guard isVisible, isDockedToNotch == false else { return }

        isDockedToNotch = true
        alphaValue = 0
        orderOut(nil)
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Position

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - 21
        let y = screenFrame.midY - 21
        setFrameOrigin(CGPoint(x: x, y: y))
    }

    func savePosition() {
        let position = frame.origin
        // 保存到 UserDefaults
        UserDefaults.standard.set(
            ["x": position.x, "y": position.y],
            forKey: "DesktopCapsule.position"
        )
    }

    func restorePosition() {
        guard let dict = UserDefaults.standard.dictionary(forKey: "DesktopCapsule.position"),
              let x = dict["x"] as? CGFloat,
              let y = dict["y"] as? CGFloat else {
            centerOnScreen()
            return
        }

        // 验证位置是否在屏幕范围内
        let position = CGPoint(x: x, y: y)
        if isValidPosition(position) {
            setFrameOrigin(position)
        } else {
            centerOnScreen()
        }
    }

    private func isValidPosition(_ position: CGPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let screenFrame = screen.visibleFrame
        return screenFrame.contains(CGPoint(x: position.x + 21, y: position.y + 21))
    }

    // MARK: - Resize

    func resizeToExpanded(width: CGFloat) {
        let height: CGFloat = 42
        var newFrame = frame
        newFrame.size = NSSize(width: width, height: height)
        newFrame.origin.x = frame.midX - width / 2
        setFrame(newFrame, display: true, animate: true)
    }

    func resizeToCollapsed() {
        let size = NSSize(width: 42, height: 42)
        var newFrame = frame
        newFrame.size = size
        newFrame.origin.x = frame.midX - 21
        setFrame(newFrame, display: true, animate: true)
    }
}

@MainActor
protocol DesktopCapsulePanelControlling: AnyObject {
    func show(at position: CGPoint?)
    func hide()
    func resizeToExpanded(width: CGFloat)
    func resizeToCollapsed()
}

extension DesktopCapsulePanel: DesktopCapsulePanelControlling {}

    extension DesktopCapsulePanel: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        dockingCoordinator?.handleWindowMoved(self)
    }
}

// MARK: - Desktop Capsule View

struct DesktopCapsuleView: View {
    @ObservedObject var viewModel: DesktopCapsuleViewModel
    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        ZStack {
            if viewModel.isExpanded {
                expandedCapsule
                    .transition(.scale(scale: 0.8, anchor: .center).combined(with: .opacity))
            } else {
                collapsedCircle
                    .transition(.scale(scale: 0.8, anchor: .center).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: viewModel.isExpanded)
        .onAppear {
            viewModel.loadSettings()
        }
    }

    // MARK: - Collapsed Circle

    private var collapsedCircle: some View {
        Button(action: { viewModel.toggleExpand() }) {
            ZStack {
                Circle()
                    .fill(AppSurfaceTokens.background)
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isHovered ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.primaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 42, height: 42)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("设置") {
                viewModel.openSettings()
            }
            Divider()
            Button("退出") {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Expanded Capsule

    private var expandedCapsule: some View {
        HStack(spacing: 0) {
            Button(action: { viewModel.toggleExpand() }) {
                ZStack {
                    Circle()
                        .fill(AppSurfaceTokens.accentBlue.opacity(0.1))
                        .frame(width: 33, height: 33)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 4.5)

            HStack(spacing: 3) {
                ForEach(viewModel.enabledActions) { action in
                    CapsuleActionButtonView(
                        action: action,
                        isExecuting: viewModel.executingAction == action.type
                    ) {
                        viewModel.executeAction(action.type)
                    }
                }
            }
            .padding(.horizontal, 6)

            Menu {
                ForEach(CapsuleActionType.allCases) { type in
                    Button(action: { viewModel.executeAction(type) }) {
                        Label(type.defaultTitle, systemImage: type.defaultIcon)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .frame(width: 24, height: 33)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.trailing, 4.5)
        }
        .frame(height: 42)
        .background(
            Capsule()
                .fill(AppSurfaceTokens.background)
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
        )
        .onHover { hovering in
            viewModel.isHoveringPanel = hovering
            if !hovering && !viewModel.isExecuting {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !viewModel.isHoveringPanel && !viewModel.isExecuting {
                        viewModel.collapse()
                    }
                }
            }
        }
    }
}

// MARK: - Capsule Action Button View

struct CapsuleActionButtonView: View {
    let action: CapsuleActionConfig
    let isExecuting: Bool
    let actionHandler: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: actionHandler) {
            ZStack {
                Circle()
                    .fill(isHovered ? action.type.defaultColor.opacity(0.15) : Color.clear)
                    .frame(width: 30, height: 30)

                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 15, height: 15)
                } else {
                    Image(systemName: action.type.defaultIcon)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(isHovered ? action.type.defaultColor : AppSurfaceTokens.primaryText)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 33, height: 33)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(action.type.defaultTitle)
    }
}
