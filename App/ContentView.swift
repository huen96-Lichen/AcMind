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

    private let compactRailWidth: CGFloat = 88
    private let expandedRailWidth: CGFloat = 220

    init(selectedItem: Binding<SidebarItem>) {
        self._selectedItem = selectedItem
    }

    private var railWidth: CGFloat {
        appState.primaryRailMode == .compact ? compactRailWidth : expandedRailWidth
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
        .onChange(of: appState.primaryRailMode) {
            if appState.workspaceMode == .collapsed {
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
            primaryRailMode: $appState.primaryRailMode,
            workspaceMode: $appState.workspaceMode,
            selectedItem: $selectedItem,
            onCloseForeground: { appState.handleCloseForeground() },
            onCollapseWorkspace: { appState.handleCollapseWorkspace() },
            onExpandWorkspace: { appState.handleExpandWorkspace() }
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
    let onCloseForeground: () -> Void
    let onCollapseWorkspace: () -> Void
    let onExpandWorkspace: () -> Void

    @State private var hoveredDot: TrafficDot?

    private enum TrafficDot {
        case close, collapse, expand
    }

    var body: some View {
        HStack(spacing: 8) {
            dotButton(
                color: Color(acHex: "#FF5F56"),
                hoverIcon: "xmark",
                dot: .close,
                action: onCloseForeground
            )
            dotButton(
                color: Color(acHex: "#FFBD2E"),
                hoverIcon: "minus",
                dot: .collapse,
                action: onCollapseWorkspace
            )
            dotButton(
                color: Color(acHex: "#28C840"),
                hoverIcon: "arrow.up.left.and.arrow.down.right",
                dot: .expand,
                action: onExpandWorkspace
            )
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }

    private func dotButton(color: Color, hoverIcon: String, dot: TrafficDot, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)

                if hoveredDot == dot {
                    Image(systemName: hoverIcon)
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
            }
            .frame(width: 20, height: 20)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredDot = hovering ? dot : nil
            }
        }
    }
}

// MARK: - Primary Rail

struct PrimaryRail: View {
    @Binding var primaryRailMode: PrimaryRailMode
    @Binding var workspaceMode: WorkspaceMode
    @Binding var selectedItem: SidebarItem

    let onCloseForeground: () -> Void
    let onCollapseWorkspace: () -> Void
    let onExpandWorkspace: () -> Void

    @State private var hoveredItem: SidebarItem?
    @State private var hoveredArrow = false

    private var isExpanded: Bool {
        primaryRailMode == .expanded
    }

    var body: some View {
        VStack(spacing: 0) {
            TrafficLightArea(
                onCloseForeground: onCloseForeground,
                onCollapseWorkspace: onCollapseWorkspace,
                onExpandWorkspace: onExpandWorkspace
            )
            .padding(.top, 4)

            appMark
                .padding(.top, 8)
                .padding(.bottom, 4)

            navItems

            Spacer(minLength: 0)

            bottomControls
        }
        .padding(.vertical, 8)
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
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(ACColors.accentBlue)
                .frame(width: 24, height: 24)

            if isExpanded {
                Text("AcMind")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(1)
            }
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
        .padding(.horizontal, isExpanded ? 16 : 0)
    }

    // MARK: - Nav Items

    private var navItems: some View {
        VStack(spacing: 4) {
            ForEach(SidebarItem.primaryNavItems) { item in
                PrimaryNavItem(
                    item: item,
                    isSelected: selectedItem == item,
                    isExpanded: isExpanded,
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
                    primaryRailMode = isExpanded ? .compact : .expanded
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.left" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ACColors.secondaryText)
                        .frame(width: 24, height: 24)

                    if isExpanded {
                        Text(isExpanded ? "收起" : "展开")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ACColors.tertiaryText)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
                .padding(.horizontal, isExpanded ? 12 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hoveredArrow ? ACColors.softFill : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredArrow = hovering
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var workspaceFooter: some View {
        HStack(spacing: 6) {
            if isExpanded {
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

            Text(isExpanded ? appVersionDisplay : appVersionShortDisplay)
                .font(.system(size: isExpanded ? 10.5 : 10, weight: .semibold))
                .foregroundStyle(ACColors.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
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
        case .visible: return "工作区展开"
        case .collapsed: return "最小工作台"
        case .hidden: return "前台已隐藏"
        }
    }
}

// MARK: - Primary Nav Item

struct PrimaryNavItem: View {
    let item: SidebarItem
    let isSelected: Bool
    let isExpanded: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? .white : (isHovered ? ACColors.primaryText : ACColors.secondaryText))
                .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.02 : 1.0))

            if isExpanded {
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : ACColors.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
        }
        .frame(
            width: isExpanded ? nil : 48,
            height: 48,
            alignment: isExpanded ? .leading : .center
        )
        .padding(.horizontal, isExpanded ? 12 : 0)
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
