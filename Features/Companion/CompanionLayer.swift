import SwiftUI
import AppKit

// MARK: - Companion Layer
// 随身总入口 - 管理系统级能力展示

struct CompanionLayer: View {
    @StateObject private var viewModel = CompanionLayerViewModel()

    var body: some View {
        ZStack {
            // 主要内容
            content

            // 面板覆盖层
            panelsOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            viewModel.setupNotifications()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        EmptyView()
    }

    // MARK: - Panels Overlay

    @ViewBuilder
    private var panelsOverlay: some View {
        if viewModel.activePanel != .none {
            Color.black.opacity(0.001) // 几乎透明的背景，用于捕获点击
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.closePanel()
                }
                .zIndex(1)

            panelForType(viewModel.activePanel)
                .zIndex(2)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func panelForType(_ type: CompanionPanelType) -> some View {
        switch type {
        case .voice:
            CompanionVoicePanel()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .shortcuts:
            CompanionShortcutPanel()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .capture:
            CompanionCapturePanel()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Panel Type

enum CompanionPanelType {
    case none
    case voice
    case shortcuts
    case capture
}

// MARK: - View Model

@MainActor
class CompanionLayerViewModel: ObservableObject {
    @Published var showCapsule = true
    @Published var activePanel: CompanionPanelType = .none

    func setupNotifications() {
        // 监听显示面板通知
        NotificationCenter.default.addObserver(
            forName: .companionShowVoicePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activePanel = .voice
            }
        }

        NotificationCenter.default.addObserver(
            forName: .companionShowCapturePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activePanel = .capture
            }
        }

        NotificationCenter.default.addObserver(
            forName: .companionShowShortcuts,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activePanel = .shortcuts
            }
        }

        // 监听关闭面板
        NotificationCenter.default.addObserver(
            forName: .companionClosePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activePanel = .none
            }
        }
    }

    func closePanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activePanel = .none
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let companionShowShortcuts = Notification.Name("companion.showShortcuts")
    static let companionClosePanel = Notification.Name("companion.closePanel")
}

// MARK: - Companion Layer Container
// 用于在主窗口中显示随身

struct CompanionLayerContainer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true

        // 创建 SwiftUI hosting view
        let companionView = CompanionLayer()
        let hostingView = NSHostingView(rootView: companionView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
