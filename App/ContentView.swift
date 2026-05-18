import SwiftUI
import AcMindKit
import struct AcMindKit.KeyboardShortcut

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var state: NSVisualEffectView.State = .active
    var backgroundAlpha: CGFloat = 1.0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.alphaValue = backgroundAlpha
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.alphaValue = backgroundAlpha
    }
}

struct ContentView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var voiceSession = CompanionVoiceSessionController.shared
    @State private var showQuickNote = false

    var body: some View {
        AppShell(selectedItem: $appState.sidebarSelection)
            .sheet(isPresented: $voiceSession.isPresented) {
                CompanionVoicePanel()
                    .transition(.scale.combined(with: .opacity))
            }
            .sheet(isPresented: $showQuickNote) {
                QuickNotePanel()
                    .transition(.scale.combined(with: .opacity))
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowAgent)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    appState.selectSidebarItem(.agent)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowInbox)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    appState.selectSidebarItem(.inbox)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowSchedule)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    appState.selectSidebarItem(.schedule)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowVoicePanel)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    voiceSession.present(autoStart: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowCapturePanel)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    voiceSession.present(autoStart: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowQuickNote)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showQuickNote = true
                }
            }
    }
}

// MARK: - AppShell

struct AppShell: View {
    @Binding var selectedItem: SidebarItem
    @ObservedObject private var appState = AppState.shared

    init(selectedItem: Binding<SidebarItem>) {
        self._selectedItem = selectedItem
    }

    private var railWidth: CGFloat {
        appState.primaryRailWidth
    }

    private var railWidthBinding: Binding<CGFloat> {
        Binding(
            get: { appState.primaryRailWidth },
            set: { appState.setPrimaryRailWidth($0) }
        )
    }

    var body: some View {
        ZStack {
            Color.clear
            contentShell.padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .onAppear {
            appState.ensureWorkspaceModeNotHidden()
        }
        .onChange(of: appState.workspaceMode) {
            handleWorkspaceModeChange(appState.workspaceMode)
        }
        .onChange(of: appState.primaryRailWidth) {
            if appState.workspaceMode == .visible {
                notifyWindowResize()
            }
        }
    }

    private var contentShell: some View {
        Group {
            if appState.workspaceMode == .visible {
                HStack(spacing: 16) {
                    railFrame
                    mainFrame
                }
                .transition(.opacity)
            } else {
                railFrame
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.workspaceMode)
    }

    private var railFrame: some View {
        PrimaryRail(
            primaryRailWidth: railWidthBinding,
            workspaceMode: $appState.workspaceMode,
            selectedItem: $selectedItem,
            onToggleSecondaryInterface: { appState.toggleSecondaryInterface() }
        )
        .frame(width: railWidth)
        .frame(maxHeight: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.94),
                            Color.white.opacity(0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
    }

    private var mainFrame: some View {
        MainContent(selectedItem: selectedItem)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.90),
                            Color.white.opacity(0.80)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.75),
                            Color.black.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    private func handleWorkspaceModeChange(_ mode: WorkspaceMode) {
        switch mode {
        case .hidden:
            Task { @MainActor in
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    appDelegate.hideMainWindow()
                }
            }
        case .collapsed:
            notifyWindowCollapse()
        case .visible:
            notifyWindowExpand()
        }
    }

    private func notifyWindowCollapse() {
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.workspaceCollapsed"),
            object: nil,
            userInfo: ["railWidth": railWidth]
        )
    }

    private func notifyWindowExpand() {
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.workspaceExpanded"),
            object: nil
        )
    }

    private func notifyWindowResize() {
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.workspaceRailWidthChanged"),
            object: nil,
            userInfo: ["railWidth": railWidth]
        )
    }
}

// MARK: - Traffic Light Area

struct TrafficLightArea: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(acHex: "#FF5F56"))
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color(acHex: "#FFBD2E"))
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color(acHex: "#28C840"))
                .frame(width: 12, height: 12)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Primary Rail

struct PrimaryRail: View {
    @Binding var primaryRailWidth: CGFloat
    @Binding var workspaceMode: WorkspaceMode
    @Binding var selectedItem: SidebarItem

    let onToggleSecondaryInterface: () -> Void

    @State private var hoveredItem: SidebarItem?
    @State private var hoveredFooter = false
    @State private var hoverResizeHandle = false
    @State private var dragAnchorWidth: CGFloat?

    private var showsLabels: Bool {
        primaryRailWidth >= 148
    }

    private var isSecondaryOpen: Bool {
        workspaceMode == .visible
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                TrafficLightArea()
                .padding(.top, 4)

                appMark
                    .padding(.top, 8)

                navItems

                Spacer(minLength: 0)

                bottomControls
            }
            .padding(.vertical, 8)

            resizeHandle
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(acHex: "#F5F6F8"))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ACColors.border.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - App Mark

    private var appMark: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ACColors.accentBlue.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(ACColors.accentBlue)
                    )

                if showsLabels {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AcMind")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ACColors.primaryText)
                            .lineLimit(1)

                        Text("灵动设置")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ACColors.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: ACLayout.primaryRailBrandHeight + 12)
            .padding(.horizontal, 14)

            Divider()
                .overlay(ACColors.border.opacity(0.72))
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    // MARK: - Nav Items

    private var navItems: some View {
        VStack(spacing: 4) {
            ForEach(SidebarItem.primaryNavItems) { item in
                PrimaryNavItem(
                    item: item,
                    isSelected: selectedItem == item,
                    showsLabels: showsLabels,
                    isHovered: hoveredItem == item
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedItem = item
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredItem = hovering ? item : nil
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 4) {
            Divider()
                .background(ACColors.divider)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            workspaceFooter

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    onToggleSecondaryInterface()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isSecondaryOpen ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ACColors.secondaryText)
                        .frame(width: 24, height: 24)

                    if showsLabels {
                        Text(isSecondaryOpen ? "二级界面关闭" : "二级界面打开")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ACColors.tertiaryText)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity, alignment: showsLabels ? .leading : .center)
                .padding(.horizontal, showsLabels ? 12 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hoveredFooter ? ACColors.softFill : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredFooter = hovering
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var workspaceFooter: some View {
        HStack(spacing: 6) {
            if showsLabels {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ACColors.tertiaryText)
                    .lineLimit(1)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }

            Spacer(minLength: 8)

            Text(showsLabels ? appVersionDisplay : appVersionShortDisplay)
                .font(.system(size: showsLabels ? 10.5 : 10, weight: .semibold))
                .foregroundStyle(ACColors.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: ACLayout.primaryRailDragHandleWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragAnchorWidth == nil {
                            dragAnchorWidth = primaryRailWidth
                        }
                        guard let dragAnchorWidth else { return }
                        let nextWidth = dragAnchorWidth + value.translation.width
                        primaryRailWidth = min(max(nextWidth, ACLayout.primaryRailCompact), ACLayout.primaryRailMaxWidth)
                    }
                    .onEnded { _ in
                        dragAnchorWidth = nil
                    }
            )
            .onHover { hovering in
                hoverResizeHandle = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .overlay(alignment: .center) {
                Capsule()
                    .fill(hoverResizeHandle ? ACColors.accentBlue.opacity(0.28) : ACColors.border.opacity(0.42))
                    .frame(width: 3, height: 42)
            }
            .padding(.trailing, 1)
    }

    private var appVersionShortDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.1"
        return "v\(version)"
    }

    private var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) · build \(build)"
    }

    private var statusColor: Color {
        switch workspaceMode {
        case .visible: return ACColors.accentGreen
        case .collapsed: return ACColors.accentYellow
        case .hidden: return ACColors.accentRed
        }
    }

    private var statusText: String {
        switch workspaceMode {
        case .visible: return "二级界面打开"
        case .collapsed: return "二级界面关闭"
        case .hidden: return "前台已隐藏"
        }
    }
}

// MARK: - Primary Nav Item

struct PrimaryNavItem: View {
    let item: SidebarItem
    let isSelected: Bool
    let showsLabels: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? .white : (isHovered ? ACColors.primaryText : ACColors.secondaryText))
                .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.02 : 1.0))

            if showsLabels {
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : ACColors.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
        }
        .frame(
            width: showsLabels ? nil : 48,
            height: 48,
            alignment: showsLabels ? .leading : .center
        )
        .padding(.horizontal, showsLabels ? 12 : 0)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? ACColors.accentBlue : (isHovered ? ACColors.softFill : Color.clear))
        )
        .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        .shadow(
            color: isSelected ? ACColors.accentBlue.opacity(0.3) : Color.clear,
            radius: isSelected ? 4 : 0,
            x: 0,
            y: 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
    }
}

// MARK: - Main Content

struct MainContent: View {
    let selectedItem: SidebarItem

    var body: some View {
        Group {
            switch selectedItem {
            case .agent:
                AgentWorkspaceView()
            case .dynamicSurface:
                DynamicSurfaceSettingsView()
            case .inbox:
                InboxWorkspaceView()
            case .clipboard:
                ClipboardWorkspaceView()
            case .schedule:
                ScheduleDashboardView()
            case .workbench:
                WorkbenchView()
            case .tools:
                ToolsView()
            case .companion:
                CompanionView()
            case .settings:
                SettingsSuiteView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        ))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedItem)
        .background(ACColors.pageBackground)
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.cardRadius, style: .continuous)
                .stroke(ACColors.border.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 6)
    }
}
