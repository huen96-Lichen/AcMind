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
    @EnvironmentObject private var appState: AppState
    let clipboardPinActions: ClipboardPinActions
    let workspaceDashboardRepository: (any WorkspaceDashboardRepositoryProtocol)?
    let inboxPreviewScenario: AcWorkPreviewScenario?
    @State private var showVoicePanel = false
    @State private var showCapturePanel = false
    @State private var showQuickNote = false

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
            AcSidebar()
                .frame(width: appState.sidebarCollapsed ? 84 : AppSurfaceTokens.Layout.sidebarWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
#if DEBUG
                .layoutDebugRegion("PrimarySidebarPanel")
#endif

            Divider()

            MainContent(
                selectedItem: appState.sidebarSelection,
                clipboardPinActions: clipboardPinActions,
                workspaceDashboardRepository: workspaceDashboardRepository,
                inboxPreviewScenario: inboxPreviewScenario
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
#if DEBUG
            .layoutDebugRegion("WorkbenchContent")
#endif
        }
        .coordinateSpace(name: "AcWorkWindow")
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
}

// MARK: - Main Content

struct MainContent: View {
    let selectedItem: SidebarItem
    let clipboardPinActions: ClipboardPinActions
    let workspaceDashboardRepository: (any WorkspaceDashboardRepositoryProtocol)?
    let inboxPreviewScenario: AcWorkPreviewScenario?
    @EnvironmentObject private var serviceContainer: ServiceContainer

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
                WorkspaceHomeView(
                    systemStatusService: serviceContainer.systemStatusService,
                    permissionManager: serviceContainer.permissionManager,
                    dashboardRepository: workspaceDashboardRepository
                )
                    .navigationTitle("工作台")
            case .systemStatus:
                SystemStatusView(
                    systemStatusService: serviceContainer.systemStatusService,
                    fanControlService: serviceContainer.systemFanControlService,
                    permissionManager: serviceContainer.permissionManager
                )
                    .navigationTitle("状态")
            case .agent:
                AgentDashboardView()
                    .navigationTitle("Agent")
            case .clipboard:
                InboxView(clipboardPinActions: clipboardPinActions, previewScenario: inboxPreviewScenario)
                    .navigationTitle("收集箱")
            case .inbox:
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
                SettingsView()
                    .navigationTitle("设置")
            }
        }
    }
}
