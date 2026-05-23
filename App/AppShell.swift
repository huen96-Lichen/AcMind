import SwiftUI
import AppKit
import AcMindKit

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

struct AppShell: View {
    @ObservedObject private var appState: AppState
    @Binding var selectedItem: SidebarItem
    let serviceContainer: ServiceContainer
    let toastManager: ToastManager

    init(
        selectedItem: Binding<SidebarItem>,
        serviceContainer: ServiceContainer,
        appState: AppState,
        toastManager: ToastManager
    ) {
        self._appState = ObservedObject(wrappedValue: appState)
        self._selectedItem = selectedItem
        self.serviceContainer = serviceContainer
        self.toastManager = toastManager
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

    private var workspaceModeBinding: Binding<WorkspaceMode> {
        Binding(
            get: { appState.workspaceMode },
            set: { appState.workspaceMode = $0 }
        )
    }

    var body: some View {
        contentShell()
            .padding(.leading, AcMindSurfaceTokens.workspaceOuterPaddingLeading)
            .padding(.trailing, AcMindSurfaceTokens.workspaceOuterPadding)
            .padding(.top, AcMindSurfaceTokens.workspaceOuterPadding)
            .padding(.bottom, AcMindSurfaceTokens.workspaceOuterPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func contentShell() -> some View {
        Group {
            if appState.workspaceMode == .visible {
                HStack(alignment: .top, spacing: AcMindSurfaceTokens.primarySecondaryGap) {
                    PrimarySidebarPanel {
                        PrimaryRail(
                            primaryRailWidth: railWidthBinding,
                            workspaceMode: workspaceModeBinding,
                            selectedItem: $selectedItem,
                            onToggleSecondaryInterface: { appState.toggleSecondaryInterface() },
                            forceCompactContent: true
                        )
                            .frame(width: AcMindSurfaceTokens.sidebarInnerRailWidth)
                    }

                    SecondaryContentPanel {
                        MainContent(
                            selectedItem: selectedItem,
                            serviceContainer: serviceContainer,
                            appState: appState,
                            toastManager: toastManager
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .transition(.opacity)
            } else {
                PrimarySidebarPanel {
                    PrimaryRail(
                        primaryRailWidth: railWidthBinding,
                        workspaceMode: workspaceModeBinding,
                        selectedItem: $selectedItem,
                        onToggleSecondaryInterface: { appState.toggleSecondaryInterface() },
                        forceCompactContent: true
                    )
                    .frame(width: AcMindSurfaceTokens.sidebarInnerRailWidth)
                }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.workspaceMode)
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

private struct PrimarySidebarPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: AcMindSurfaceTokens.sidebarContainerWidth - (AcMindSurfaceTokens.sidebarContainerPadding * 2), alignment: .center)
            .padding(AcMindSurfaceTokens.sidebarContainerPadding)
            .frame(width: AcMindSurfaceTokens.sidebarContainerWidth, alignment: .center)
            .workspacePanelChrome()
    }
}

private struct SecondaryContentPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(AcMindSurfaceTokens.panelInset)
            .workspacePanelChrome()
    }
}

private struct WorkspacePanelChrome: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: AcMindSurfaceTokens.workspacePanelCornerRadius, style: .continuous)
        content
            .background(
                shape.fill(AcMindSurfaceTokens.workspacePanelSurface)
            )
            .overlay(
                shape.stroke(Color.black.opacity(AcMindSurfaceTokens.workspacePanelBorderOpacity), lineWidth: 1)
            )
            .clipShape(shape)
            .shadow(
                color: AcMindSurfaceTokens.workspacePanelShadowColor,
                radius: AcMindSurfaceTokens.workspacePanelShadowRadius,
                x: 0,
                y: AcMindSurfaceTokens.workspacePanelShadowYOffset
            )
    }
}

private extension View {
    func workspacePanelChrome() -> some View {
        modifier(WorkspacePanelChrome())
    }
}
