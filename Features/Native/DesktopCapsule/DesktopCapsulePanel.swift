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
    private static var _shared: DesktopCapsulePanel?

    static var shared: DesktopCapsulePanel {
        guard let shared = _shared else {
            fatalError("DesktopCapsulePanel.shared accessed before configuration")
        }
        return shared
    }

    static func configureShared(container: ServiceContainer) {
        _shared = DesktopCapsulePanel(container: container)
    }

    private let viewModel: DesktopCapsuleViewModel
    private var hostingView: NSHostingView<DesktopCapsuleView>?
    private var contentContainerView: NSView?

    init(container: ServiceContainer) {
        self.viewModel = DesktopCapsuleViewModel(container: container)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: DesktopCapsuleLayoutMetrics.collapsedDiameter, height: DesktopCapsuleLayoutMetrics.height),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        setupPanel()
        setupContentView()
        DynamicSurfaceCoordinator.shared.registerCapsuleAdapter(CapsulePanelAdapter(panel: self))
    }

    private func setupPanel() {
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isMovableByWindowBackground = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
    }

    private func setupContentView() {
        let containerView = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: DesktopCapsuleLayoutMetrics.collapsedDiameter,
            height: DesktopCapsuleLayoutMetrics.height
        ))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        let contentView = DesktopCapsuleView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: contentView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        containerView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: containerView.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        hostingView = hosting
        contentContainerView = containerView
        self.contentView = containerView
    }

    // MARK: - Public Methods

    func show(at position: CGPoint? = nil) {
        if let position = position {
            setFrameOrigin(position)
        } else {
            centerOnScreen()
        }
        viewModel.setExpanded(false)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    func showCollapsed(on screen: NSScreen? = nil, at point: CGPoint? = nil, animated: Bool = true) {
        viewModel.setExpanded(false)
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first

        if let point {
            let frame = CompanionScreenPositioning.centeredFrame(at: point, size: CGSize(width: DesktopCapsuleLayoutMetrics.collapsedDiameter, height: DesktopCapsuleLayoutMetrics.height), screen: targetScreen)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = CompanionMenuBarLayout.surfaceMorphDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    animator().setFrame(frame, display: true)
                }
            } else {
                setFrame(frame, display: true, animate: false)
            }
        } else if let screen = targetScreen {
            let frame = CompanionScreenPositioning.centeredFrame(at: CGPoint(x: screen.frame.midX, y: screen.frame.midY), size: CGSize(width: DesktopCapsuleLayoutMetrics.collapsedDiameter, height: DesktopCapsuleLayoutMetrics.height), screen: screen)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = CompanionMenuBarLayout.surfaceMorphDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    animator().setFrame(frame, display: true)
                }
            } else {
                setFrame(frame, display: true, animate: false)
            }
        } else if !isVisible {
            centerOnScreen()
        }

        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    func hide() {
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
        let x = screenFrame.midX - DesktopCapsuleLayoutMetrics.collapsedDiameter / 2
        let y = screenFrame.midY - DesktopCapsuleLayoutMetrics.height / 2
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
        return screenFrame.contains(CGPoint(
            x: position.x + DesktopCapsuleLayoutMetrics.collapsedDiameter / 2,
            y: position.y + DesktopCapsuleLayoutMetrics.height / 2
        ))
    }

    // MARK: - Resize

    func resizeToExpanded(width: CGFloat) {
        resizeMaintainingLeadingEdge(to: NSSize(width: width, height: DesktopCapsuleLayoutMetrics.height), animated: true)
    }

    func resizeToCollapsed() {
        resizeMaintainingLeadingEdge(to: NSSize(width: DesktopCapsuleLayoutMetrics.collapsedDiameter, height: DesktopCapsuleLayoutMetrics.height), animated: true)
    }

    func moveCollapsed(to point: CGPoint, screen: NSScreen? = nil, animated: Bool = false) {
        let frame = CompanionScreenPositioning.centeredFrame(at: point, size: CGSize(width: DesktopCapsuleLayoutMetrics.collapsedDiameter, height: DesktopCapsuleLayoutMetrics.height), screen: screen ?? NSScreen.main ?? NSScreen.screens.first)
        setFrame(frame, display: true, animate: animated)
    }

    private func resizeMaintainingLeadingEdge(to size: NSSize, animated: Bool) {
        var newFrame = frame
        newFrame.size = size
        newFrame.origin.x = frame.minX
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = CompanionMenuBarLayout.surfaceMorphDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true, animate: false)
        }
    }
}

// MARK: - Desktop Capsule View

struct DesktopCapsuleView: View {
    @ObservedObject var viewModel: DesktopCapsuleViewModel
    @ObservedObject private var coordinator = DynamicSurfaceCoordinator.shared
    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        let capsuleWidth = viewModel.isExpanded ? viewModel.expandedWidth : DesktopCapsuleLayoutMetrics.collapsedDiameter
        let contentRailWidth = viewModel.isExpanded ? max(0, capsuleWidth - DesktopCapsuleLayoutMetrics.contentLeadingInset) : 0

        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Capsule().stroke(Color.black.opacity(viewModel.isExpanded ? 0.04 : 0.0), lineWidth: 1)
                )
                .overlay(
                    Capsule()
                        .fill(Color.accentColor.opacity(viewModel.isHoverEmphasized ? 0.06 : 0.0))
                )

            capsuleContentRail
                .frame(width: contentRailWidth, height: DesktopCapsuleLayoutMetrics.height, alignment: .leading)
                .padding(.leading, DesktopCapsuleLayoutMetrics.contentLeadingInset)
                .opacity(viewModel.isExpanded ? 1 : 0)
                .allowsHitTesting(viewModel.isExpanded)
                .clipped()

            capsuleIconButton
                .onTapGesture {
                    guard coordinator.dragPhase == .idle, isDragging == false else { return }
                    viewModel.toggleExpand()
                }
                .gesture(capsuleDragGesture)
                .zIndex(1)
        }
        .frame(width: capsuleWidth, height: DesktopCapsuleLayoutMetrics.height, alignment: .leading)
        .contentShape(Capsule())
        .onHover { hovering in
            viewModel.setPanelHovered(hovering)
        }
        .onAppear {
            viewModel.loadSettings()
        }
    }

    // MARK: - Icon

    private var capsuleIconButton: some View {
        ZStack {
            Circle()
                .fill(viewModel.isExpanded ? Color.accentColor.opacity(0.10) : Color(NSColor.windowBackgroundColor))
                .frame(width: DesktopCapsuleLayoutMetrics.collapsedDiameter - 10, height: DesktopCapsuleLayoutMetrics.collapsedDiameter - 10)
                .shadow(
                    color: .black.opacity(viewModel.isExpanded ? 0.0 : 0.04),
                    radius: viewModel.isExpanded ? 0 : 2,
                    x: 0,
                    y: viewModel.isExpanded ? 0 : 1
                )

            if coordinator.dragPhase == .capsuleDockPreview {
                Circle()
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 2)
                    .frame(width: 48, height: 48)
                    .opacity(0.9)
            }

            Image(systemName: "brain.head.profile")
                .font(.system(size: viewModel.isExpanded ? 13.5 : 18, weight: .medium))
                .foregroundStyle(viewModel.isExpanded ? Color.accentColor : (isHovered ? Color.accentColor : .primary))
        }
        .frame(width: DesktopCapsuleLayoutMetrics.collapsedDiameter, height: DesktopCapsuleLayoutMetrics.height)
        .contentShape(Circle())
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

    // MARK: - Expanded Content

    private var capsuleContentRail: some View {
        HStack(spacing: DesktopCapsuleLayoutMetrics.actionSlotSpacing) {
            HStack(spacing: 0) {
                ForEach(viewModel.enabledActions) { action in
                    CapsuleActionSlotView(
                        action: action,
                        isExecuting: viewModel.executingAction == action.type
                    ) {
                        viewModel.executeAction(action.type)
                    }
                    .frame(width: DesktopCapsuleLayoutMetrics.actionSlotWidth, height: DesktopCapsuleLayoutMetrics.height)
                }
            }
            .padding(.leading, DesktopCapsuleLayoutMetrics.sidePadding)

            Menu {
                ForEach(CapsuleActionType.allCases) { type in
                    Button(action: { viewModel.executeAction(type) }) {
                        Label(type.defaultTitle, systemImage: type.defaultIcon)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 24, height: 24)
                    .frame(width: DesktopCapsuleLayoutMetrics.menuSlotWidth, height: DesktopCapsuleLayoutMetrics.height)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.trailing, DesktopCapsuleLayoutMetrics.contentTrailingInset)
        }
        .frame(height: DesktopCapsuleLayoutMetrics.height, alignment: .leading)
        .clipShape(Capsule())
    }

    private var capsuleDragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { _ in
                let mouseLocation = NSEvent.mouseLocation
                if coordinator.dragPhase == .idle {
                    coordinator.capsuleDragBegan(at: mouseLocation)
                    isDragging = true
                }
                coordinator.capsuleDragChanged(to: mouseLocation)
                viewModel.isExpanded = false
                viewModel.isHoveringPanel = true
                DesktopCapsulePanel.shared.moveCollapsed(to: mouseLocation, animated: false)
            }
            .onEnded { _ in
                let mouseLocation = NSEvent.mouseLocation
                coordinator.capsuleDragEnded(at: mouseLocation)
                isDragging = false
                viewModel.isHoveringPanel = false
            }
    }
}

// MARK: - Capsule Action Slot View

struct CapsuleActionSlotView: View {
    let action: CapsuleActionConfig
    let isExecuting: Bool
    let actionHandler: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: actionHandler) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? action.type.defaultColor.opacity(0.15) : Color.clear)
                    .frame(width: 36, height: 36)

                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: action.type.defaultIcon)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(isHovered ? action.type.defaultColor : .primary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(action.type.defaultTitle)
    }
}
