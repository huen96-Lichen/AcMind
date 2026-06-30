import SwiftUI
import AcMindKit

@MainActor
struct ClipboardPinActions {
    let showItem: (ClipboardItem) -> Void
    let showAll: () -> Void
    let hideAll: () -> Void
    let closeAll: () -> Void
    let copyDiagnostics: () -> Void
}

// MARK: - Content View
// AcWork 主应用框架

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState
    let clipboardPinActions: ClipboardPinActions
    let workspaceDashboardRepository: (any WorkspaceDashboardRepositoryProtocol)?
    let inboxPreviewScenario: AcWorkPreviewScenario?
    @State private var showVoicePanel = false
    @State private var showCapturePanel = false
    @State private var showQuickNote = false
#if DEBUG
    @AppStorage("useWorkbenchV2") private var useWorkbenchV2 = WorkbenchV2Routing.defaultUseWorkbenchV2
#endif

    init(
        clipboardPinActions: ClipboardPinActions,
        workspaceDashboardRepository: (any WorkspaceDashboardRepositoryProtocol)? = nil,
        inboxPreviewScenario: AcWorkPreviewScenario? = nil
    ) {
        self.clipboardPinActions = clipboardPinActions
        self.workspaceDashboardRepository = workspaceDashboardRepository
        self.inboxPreviewScenario = inboxPreviewScenario
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(
                    width: appState.sidebarCollapsed
                        ? AppSurfaceTokens.Layout.sidebarCollapsedWidth
                        : AppSurfaceTokens.Layout.sidebarWidth
                )
                .layoutPriority(1)
                .zIndex(2)
#if DEBUG
                .layoutDebugRegion("PrimarySidebarPanel")
#endif

            Divider()
                .zIndex(1)

            MainContent(
                selectedItem: appState.sidebarSelection,
                clipboardPinActions: clipboardPinActions,
                workspaceDashboardRepository: workspaceDashboardRepository,
                inboxPreviewScenario: inboxPreviewScenario
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .modifier(MainContentClippingModifier(isEnabled: shouldClipMainContent))
#if DEBUG
            .layoutDebugRegion("WorkbenchContent")
#endif
        }
        .coordinateSpace(name: "AcWorkWindow")
        .overlayPreferenceValue(SidebarRailTooltipPreferenceKey.self) { tooltip in
            GeometryReader { proxy in
                if let tooltip {
                    let rect = proxy[tooltip.anchor]
                    let tooltipX = max(
                        rect.maxX + 10,
                        AppSurfaceTokens.Layout.sidebarCollapsedWidth + 8
                    )
                    SidebarRailTooltip(item: tooltip.item, isSelected: tooltip.isSelected)
                        .offset(
                            x: tooltipX,
                            y: rect.midY - 16 + SidebarRailTooltipLayout.yOffset(
                                for: rect,
                                viewportHeight: proxy.size.height
                            )
                        )
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.97, anchor: .leading))
                        )
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.12)
                                : .spring(response: 0.24, dampingFraction: 0.90),
                            value: rect.midY
                        )
                        .zIndex(20)
                }
            }
            .allowsHitTesting(false)
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.12)
                : .spring(response: 0.28, dampingFraction: 0.88),
            value: appState.sidebarCollapsed
        )
#if DEBUG
        .layoutDebugRegion("AppShell")
#endif
#if DEBUG
        .onPreferenceChange(LayoutMeasurementPreferenceKey.self) { measurements in
            LayoutDebugStore.shared.update(measurements)
        }
        .overlay {
            if LayoutDebugStore.shared.isOverlayVisible {
                LayoutDebugOverlay(measurements: LayoutDebugStore.shared.measurements)
                    .allowsHitTesting(false)
            }
        }
#endif
        .frame(
            minWidth: AppWindowGeometry.minimumContentSize.width,
            maxWidth: .infinity,
            minHeight: AppWindowGeometry.minimumContentSize.height,
            maxHeight: .infinity
        )
        .background(AppSurfaceBackdrop())
        .sheet(isPresented: $showVoicePanel) {
            CompanionVoicePanel()
        }
        .sheet(isPresented: $showCapturePanel) {
            CompanionCapturePanel()
        }
        .sheet(isPresented: $showQuickNote) {
            QuickNotePanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowAgent)) { _ in
            appState.navigate(to: .agent)
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowInbox)) { _ in
            appState.navigateToInbox()
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowSchedule)) { _ in
            appState.navigate(to: .schedule)
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowVoicePanel)) { _ in
            guard SettingsLocalPreferences.isVoiceInputEnabled() else {
                appState.showError(.serviceUnavailable("说入法输入已在设置中关闭"))
                return
            }
            showVoicePanel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowCapturePanel)) { _ in
            showCapturePanel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowQuickNote)) { _ in
            showQuickNote = true
        }
    }

    private var shouldClipMainContent: Bool {
#if DEBUG
        return appState.sidebarSelection != .home || useWorkbenchV2 == false
#else
        return true
#endif
    }
}

private struct MainContentClippingModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.clipped()
        } else {
            content
        }
    }
}

// MARK: - Main Content

struct MainContent: View {
    let selectedItem: SidebarItem
    let clipboardPinActions: ClipboardPinActions
    let workspaceDashboardRepository: (any WorkspaceDashboardRepositoryProtocol)?
    let inboxPreviewScenario: AcWorkPreviewScenario?
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @StateObject private var workbenchV2HeroBackgroundStore = WorkbenchV2HeroBackgroundStore()
#if DEBUG
    @AppStorage("useWorkbenchV2") private var useWorkbenchV2 = WorkbenchV2Routing.defaultUseWorkbenchV2
#else
    private let useWorkbenchV2 = false
#endif

    init(
        selectedItem: SidebarItem,
        clipboardPinActions: ClipboardPinActions,
        workspaceDashboardRepository: (any WorkspaceDashboardRepositoryProtocol)? = nil,
        inboxPreviewScenario: AcWorkPreviewScenario? = nil
    ) {
        self.selectedItem = selectedItem
        self.clipboardPinActions = clipboardPinActions
        self.workspaceDashboardRepository = workspaceDashboardRepository
        self.inboxPreviewScenario = inboxPreviewScenario
    }

    var body: some View {
        Group {
            switch selectedItem {
            case .home:
                let dashboardRepository = workspaceDashboardRepository ?? LiveWorkspaceDashboardRepository(
                    appState: AppState.shared,
                    systemStatusService: serviceContainer.systemStatusService,
                    storageService: serviceContainer.storageService,
                    scheduleService: serviceContainer.scheduleService,
                    agentTaskBoardService: serviceContainer.agentTaskBoardService
                )
                if useWorkbenchV2 {
                    WorkbenchV2LiveView(
                        repository: dashboardRepository,
                        heroBackgroundStore: workbenchV2HeroBackgroundStore
                    )
                        .navigationTitle("工作台")
                } else {
                    WorkspaceHomeView(
                        systemStatusService: serviceContainer.systemStatusService,
                        permissionManager: serviceContainer.permissionManager,
                        settingsService: serviceContainer.settingsService,
                        storageService: serviceContainer.storageService,
                        scheduleService: serviceContainer.scheduleService,
                        agentTaskBoardService: serviceContainer.agentTaskBoardService,
                        dashboardRepository: dashboardRepository
                    )
                        .navigationTitle("工作台")
                }
            case .systemStatus:
                SystemStatusView(
                    systemStatusService: serviceContainer.systemStatusService,
                    fanControlService: serviceContainer.systemFanControlService,
                    permissionManager: serviceContainer.permissionManager
                )
                    .navigationTitle("状态")
            case .agent:
                AgentDashboardView()
                    .navigationTitle("智能体")
            case .clipboard:
                InboxView(clipboardPinActions: clipboardPinActions)
                    .navigationTitle("收集箱")
            case .inbox:
                InboxView(clipboardPinActions: clipboardPinActions, previewScenario: inboxPreviewScenario)
                    .navigationTitle("收集箱")
            case .screenshot:
                ScreenshotWorkspaceView(clipboardPinActions: clipboardPinActions)
                    .navigationTitle("截图工作区")
            case .screenshotHistory:
                InboxView(clipboardPinActions: clipboardPinActions, previewScenario: inboxPreviewScenario)
                    .navigationTitle("收集箱")
            case .schedule:
                ScheduleDashboardView()
                    .navigationTitle("日程")
            case .workbench:
                ToolsView()
                    .navigationTitle("工具台")
            case .dynamicContinent:
                DynamicContinentConfigView()
                    .navigationTitle("灵动大陆")
            case .voiceEntry:
                VoiceEntryView()
                    .navigationTitle("说入法设置")
            case .modelManagement:
                ModelManagementPanel()
                    .navigationTitle("模型")
            case .settings:
                SettingsView(cloudSyncService: serviceContainer.cloudSyncService)
                    .navigationTitle("设置")
            }
        }
    }
}
