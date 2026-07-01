import SwiftUI
import AppKit
import AcMindKit
import struct AcMindKit.KeyboardShortcut

// MARK: - App Delegate

/// 应用生命周期和窗口管理
/// 职责：
/// 1. 应用启动和退出生命周期
/// 2. 主窗口和胶囊窗口管理
/// 3. 状态栏菜单
/// 4. 全局快捷键和系统服务
/// 5. 通知处理
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Windows

    var launchWindowController: LaunchWindowController?
    var mainWindowController: MainWindowController?
    var capsuleWindowController: CapsuleWindowController?
    private var oobeWindowController: OOBEWindowController?
    private var clipboardPinWindowManager: ClipboardPinWindowManager?
    private var screenshotPreviewWindow: NSWindow?
    private var screenshotPreviewSession: ScreenshotPreviewSession?
    private let placeholderWindowPruner = PlaceholderWindowPruner()
#if DEBUG
    private var toolWorkspacePreviewWindow: NSWindow?
    private var settingsPreviewWindow: NSWindow?
    private var productPanelPreviewWindow: NSWindow?
    private var agentPreviewWindow: NSWindow?
    private var systemStatusPreviewWindow: NSWindow?
    private var systemStatusPreviewService: SystemStatusService?
#endif

    // MARK: - Notch Panel

    private var notchPanelEnabled: Bool {
        // 从设置读取，默认启用
        if UserDefaults.standard.object(forKey: "AppSettings.notchPanelEnabled") != nil {
            return UserDefaults.standard.bool(forKey: "AppSettings.notchPanelEnabled")
        }
        return true // 默认启用
    }

    // MARK: - Desktop Capsule

    private var desktopCapsuleEnabled: Bool {
        // 从设置读取
        if let data = UserDefaults.standard.data(forKey: "AppSettings.desktopCapsule"),
           let settings = try? JSONDecoder().decode(DesktopCapsuleSettings.self, from: data) {
            return settings.isEnabled
        }
        return true // 默认启用
    }

    // MARK: - Status Bar

    private var statusItem: NSStatusItem?

    // MARK: - State

    private let appState = AppState.shared
    private var serviceContainer: ServiceContainer?
    private var hotCornerManager: HotCornerManager?
    private var fnKeyMonitor: FnKeyHoldMonitor?
    private var registeredGlobalShortcuts: [KeyboardShortcut] = []
    private var registeredCompanionShortcuts: [AcMindKeyboardShortcut] = []
    private var registeredVoiceShortcut: KeyboardShortcut?
    private var isCompanionRuntimeEnabled = true
    private var isTerminating = false
    private var hasStartedStartupFlow = false
    private let logger = AcMindLogger(category: .lifecycle)
    private lazy var notchPanelController = NotchPanel.shared
    private lazy var desktopCapsuleController = DesktopCapsulePanel.shared

    private var permissionManager: PermissionManager? {
        serviceContainer?.permissionManager
    }

    private var storageService: StorageServiceProtocol? {
        serviceContainer?.storageService
    }

    private var captureService: CaptureServiceProtocol? {
        serviceContainer?.captureService
    }

    private var clipboardService: ClipboardServiceProtocol? {
        serviceContainer?.clipboardService
    }

    private var settingsService: SettingsServiceProtocol? {
        serviceContainer?.settingsService
    }

    private var assetStore: AssetStore? {
        serviceContainer?.assetStore
    }

    override init() {
        super.init()
        Task { @MainActor [weak self] in
            self?.beginStartupFlow()
        }
    }

    private func configureTransparentWindow(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
    }

#if DEBUG
    private func auditExportsDirectory(named subdirectory: String) throws -> URL {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind", isDirectory: true)
            .appendingPathComponent("AuditExports", isDirectory: true)
        let exportDirectory = baseDirectory.appendingPathComponent(subdirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        return exportDirectory
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func workbenchV2FixtureBackgroundURL() -> URL {
        repositoryRootURL()
            .appendingPathComponent("Resources/Assets.xcassets/WorkbenchHeroOcean.imageset/workbench-hero-ocean.jpg")
    }
#endif

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        beginStartupFlow()
    }

    private func beginStartupFlow() {
        guard hasStartedStartupFlow == false else { return }
        hasStartedStartupFlow = true

#if DEBUG
        if let debugCommand = DebugPreviewLaunchCommand.resolve() {
            handleDebugPreviewLaunch(debugCommand)
            return
        }
#endif
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        applyApplicationIcon()
        setupStatusBar()
        setupNotifications()
        showLaunchWindow()

        // 初始化服务容器
        Task {
            do {
                let container = try await ServiceContainer.setup()
                await MainActor.run {
                    self.serviceContainer = container
                    self.appState.bindServiceContainerState(container)
                    self.connectCompanionPanels()
                    self.hideLaunchWindow()
                    if self.clipboardPinWindowManager == nil {
                        self.clipboardPinWindowManager = ClipboardPinWindowManager(assetStore: self.assetStore ?? AssetStore())
                    }
                    
                    // 检查是否需要显示 OOBE
                    if !UserDefaults.standard.bool(forKey: OOBEWindowController.completionDefaultsKey) {
                        self.showOOBE()
                    } else {
                        self.showMainWindow()
                        self.applyInitialOpenRouteIfNeeded()
                        // 启动时只展示一个随身形态，避免大陆与胶囊同时出现
                        if self.notchPanelEnabled {
                            self.showNotchPanel()
                        } else if self.desktopCapsuleEnabled {
                            self.showDesktopCapsule()
                        }
                        self.setupCompanionRuntime()
                        self.setupFnKeyMonitor()
                        self.setupGlobalShortcuts()
                        self.setupHotCorners()
                    }
                }
            } catch {
                await MainActor.run {
                    appState.showError(AppError.initializationFailed(error))
                }
            }
        }
    }

    private func connectCompanionPanels() {
        guard let serviceContainer else { return }
        let notchPanel = NotchPanel.shared
        let desktopCapsulePanel = DesktopCapsulePanel.shared
        let dockingCoordinator = DesktopCapsuleDockingCoordinator(notchController: notchPanel)
        notchPanel.connect(desktopCapsuleController: desktopCapsulePanel)
        notchPanel.connect(serviceContainer: serviceContainer)
        desktopCapsulePanel.connect(dockingCoordinator: dockingCoordinator)
        desktopCapsulePanel.connect(notchController: notchPanel)
    }

    private func applyInitialOpenRouteIfNeeded() {
        guard let route = ProcessInfo.processInfo.arguments.compactMap(Self.initialOpenRoute(from:)).first else {
            return
        }

        switch route {
        case .home:
            appState.navigate(to: .home)
        case .inbox:
            appState.navigate(to: .inbox)
        case .phoneSync:
            appState.selectInboxWorkspace("phoneSync")
        case .screenshotHistory:
            appState.selectInboxWorkspace("screenshotHistory")
        case .agent:
            appState.navigate(to: .agent)
        case .clipboard:
            appState.navigate(to: .clipboard)
        case .screenshot:
            appState.navigate(to: .screenshot)
        case .schedule:
            appState.navigate(to: .schedule)
        case .workbench:
            appState.navigate(to: .workbench)
        case .workbenchApiTest:
            appState.navigate(to: .workbench, workbenchToolRoute: .apiTest)
        case .workbenchWebDigest:
            appState.navigate(to: .workbench, workbenchToolRoute: .webDigest)
        case .workbenchJsonFormatter:
            appState.navigate(to: .workbench, workbenchToolRoute: .jsonFormatter)
        case .workbenchOcr:
            appState.navigate(to: .workbench, workbenchToolRoute: .ocr)
        case .dynamicContinent:
            appState.navigate(to: .dynamicContinent)
        case .systemStatus:
            appState.navigate(to: .systemStatus)
        case .voiceEntry:
            appState.navigate(to: .voiceEntry)
        case .modelManagement:
            appState.navigate(to: .modelManagement)
        case .settings:
            appState.navigate(to: .settings)
        case .settingsGeneral:
            appState.navigate(to: .settings, settingsCategory: .general)
        case .settingsCompanion:
            appState.navigate(to: .settings, settingsCategory: .companion)
        case .settingsAiModels:
            appState.navigate(to: .settings, settingsCategory: .aiModels)
        case .settingsDataKnowledge:
            appState.navigate(to: .settings, settingsCategory: .dataKnowledge)
        case .settingsCaptureInput:
            appState.navigate(to: .settings, settingsCategory: .captureInput)
        case .settingsSecurity:
            appState.navigate(to: .settings, settingsCategory: .security)
        case .settingsAbout:
            appState.navigate(to: .settings, settingsCategory: .about)
        }
    }

    private static func initialOpenRoute(from argument: String) -> InitialOpenRoute? {
        guard argument.hasPrefix("--acwork-open=") else { return nil }
        let value = String(argument.dropFirst("--acwork-open=".count))
        return InitialOpenRoute.parse(value)
    }

    private enum InitialOpenRoute: String {
        case home
        case inbox
        case phoneSync
        case screenshotHistory
        case agent
        case clipboard
        case screenshot
        case schedule
        case workbench
        case workbenchApiTest
        case workbenchWebDigest
        case workbenchJsonFormatter
        case workbenchOcr
        case dynamicContinent
        case systemStatus
        case voiceEntry
        case modelManagement
        case settings
        case settingsGeneral
        case settingsCompanion
        case settingsAiModels
        case settingsDataKnowledge
        case settingsCaptureInput
        case settingsSecurity
        case settingsAbout

        static func parse(_ value: String) -> InitialOpenRoute? {
            switch value {
            case "home":
                return .home
            case "inbox":
                return .inbox
            case "phoneSync", "phone-sync":
                return .phoneSync
            case "screenshotHistory", "screenshot-history":
                return .screenshotHistory
            case "agent":
                return .agent
            case "clipboard":
                return .clipboard
            case "screenshot":
                return .screenshot
            case "schedule":
                return .schedule
            case "workbench":
                return .workbench
            case "workbenchApiTest", "workbench-api-test":
                return .workbenchApiTest
            case "workbenchWebDigest", "workbench-web-digest":
                return .workbenchWebDigest
            case "workbenchJsonFormatter", "workbench-json-formatter":
                return .workbenchJsonFormatter
            case "workbenchOcr", "workbench-ocr":
                return .workbenchOcr
            case "dynamicContinent", "dynamic-continent":
                return .dynamicContinent
            case "systemStatus", "system-status":
                return .systemStatus
            case "voiceEntry", "voice-entry":
                return .voiceEntry
            case "modelManagement", "model-management":
                return .modelManagement
            case "settings":
                return .settings
            case "settingsGeneral", "settings-general":
                return .settingsGeneral
            case "settingsCompanion", "settings-companion":
                return .settingsCompanion
            case "settingsAiModels", "settings-ai-models":
                return .settingsAiModels
            case "settingsDataKnowledge", "settings-data-knowledge":
                return .settingsDataKnowledge
            case "settingsCaptureInput", "settings-capture-input":
                return .settingsCaptureInput
            case "settingsSecurity", "settings-security":
                return .settingsSecurity
            case "settingsAbout", "settings-about":
                return .settingsAbout
            default:
                return InitialOpenRoute(rawValue: value)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        placeholderWindowPruner.stop()
        AudioMuteGuard.shared.forceRestore()

        // 清理资源
        Task {
            await MainActor.run {
                self.hotCornerManager?.stop()
                self.hotCornerManager = nil
            }
            await serviceContainer?.shutdown()
        }

        // 停止监听
        fnKeyMonitor?.stop()
        fnKeyMonitor = nil
        Task { HeadphoneMonitor.shared.disable() }
        clipboardPinWindowManager?.closeAll()
        NotificationCenter.default.removeObserver(self)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        schedulePlaceholderWindowPrune()
        setupHotCorners()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
            if notchPanelEnabled {
                showNotchPanel()
            } else if desktopCapsuleEnabled {
                showDesktopCapsule()
            }
        }
        return true
    }

    // MARK: - Window Management

    func showMainWindow() {
        guard let serviceContainer else {
            logger.warning("主窗口请求早于服务初始化完成，继续显示启动窗口", file: "AppDelegate")
            showLaunchWindow()
            return
        }

        if mainWindowController == nil {
            mainWindowController = MainWindowController(
                restoreWindowPosition: shouldRestoreWindowPosition,
                clipboardPinActions: clipboardPinActions,
                serviceContainer: serviceContainer
            )
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindowController?.showWindow(nil)
        mainWindowController?.enforceMinimumContentSize()
        mainWindowController?.ensureVisibleOnScreenIfNeeded()
        if shouldRestoreWindowPosition == false {
            mainWindowController?.window?.setFrame(
                MainWindowController.frameRect(forContentSize: AppWindowGeometry.defaultFrame.size, origin: AppWindowGeometry.defaultFrame.origin, styleMask: mainWindowController?.window?.styleMask),
                display: true
            )
        }
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        mainWindowController?.window?.orderFrontRegardless()
        prunePlaceholderWindows()
        schedulePlaceholderWindowPrune()
        appState.mainWindowDidOpen()
    }

    func hideMainWindow() {
        mainWindowController?.close()
        mainWindowController = nil
        appState.mainWindowDidClose()
    }

    private func placeholderWindowPruneContext() -> PlaceholderWindowPruneContext {
        PlaceholderWindowPruneContext(
            mainWindow: mainWindowController?.window,
            launchWindow: launchWindowController?.window,
            excludedWindows: [
                notchPanelController,
                desktopCapsuleController
            ]
        )
    }

    private func prunePlaceholderWindows() {
        placeholderWindowPruner.prune(context: placeholderWindowPruneContext())
    }

    private func schedulePlaceholderWindowPrune() {
        placeholderWindowPruner.schedule { [weak self] in
            guard let self, self.isTerminating == false else { return .empty }
            return self.placeholderWindowPruneContext()
        }
    }

    func toggleMainWindow() {
        if mainWindowController?.window?.isVisible == true {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }

    func showCapsuleWindow() {
        // 历史入口统一转到最新的桌面灵动胶囊，避免再弹出旧版窗口
        showDesktopCapsule()
    }

    func showVoicePanel() {
        guard isCompanionRuntimeEnabled else {
            return
        }
        guard SettingsLocalPreferences.isVoiceInputEnabled() else {
            appState.showError(.serviceUnavailable("说入法输入已在设置中关闭"))
            return
        }

        showMainWindow()
        NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
    }

#if DEBUG
    private func handleDebugPreviewLaunch(_ command: DebugPreviewLaunchCommand) {
        switch command {
        case let .settings(options):
            if let exportPath = options.exportPath {
                runTerminatingDebugExport(
                    prefix: "SettingsPreviewExport",
                    startMessage: "starting settings preview export",
                    successMessage: "settings preview export finished",
                    failureMessage: "Failed to export settings preview"
                ) {
                    try exportSettingsPreviewImage(to: exportPath, options: options)
                }
                return
            }
            showSettingsPreviewWindow(options: options)

        case .acworkExportScreenshots:
            runTerminatingDebugExport(
                prefix: "AcWorkExport",
                startMessage: "starting screenshot export",
                successMessage: "screenshot export finished",
                failureMessage: "Failed to export AcWork screenshots"
            ) {
                print("[AcWorkExport] building preview container")
                try DebugAcWorkAuditExporter.exportPhaseOneScreenshots(
                    outputDirectory: auditExportsDirectory(named: "acwork-phase1"),
                    serviceContainer: ServiceContainer.preview()
                )
            }

        case .acworkLayoutAudit:
            runTerminatingDebugExport(
                prefix: "AcWorkAudit",
                startMessage: "starting layout audit export",
                successMessage: "layout audit export finished",
                failureMessage: "Failed to export AcWork layout audit"
            ) {
                try DebugAcWorkAuditExporter.exportLayoutAudit(
                    outputDirectory: auditExportsDirectory(named: "audit"),
                    serviceContainer: ServiceContainer.preview()
                )
            }

        case .workbenchV2Audit:
            runTerminatingDebugExport(
                prefix: "AcWorkV2Audit",
                startMessage: "starting workbench V2 audit export",
                successMessage: "workbench V2 audit export finished",
                failureMessage: "Failed to export Workbench V2 audit"
            ) {
                try DebugWorkbenchV2AuditExporter.exportLayoutAudit(
                    outputDirectory: auditExportsDirectory(named: "workbench-v17"),
                    selectedBackgroundURL: workbenchV2FixtureBackgroundURL()
                )
            }

        case .workbenchV2BackgroundVerify:
            runTerminatingDebugExport(
                prefix: "AcWorkV2Background",
                startMessage: "starting background persistence verification",
                successMessage: "background persistence verification finished",
                failureMessage: "Failed to export Workbench V2 background verification"
            ) {
                try DebugWorkbenchV2AuditExporter.exportBackgroundVerification(
                    outputDirectory: auditExportsDirectory(named: "workbench-v17"),
                    selectedBackgroundURL: workbenchV2FixtureBackgroundURL()
                )
            }

        case .companionSixPagesExport:
            runTerminatingDebugExport(
                prefix: "CompanionExport",
                startMessage: "starting companion export",
                successMessage: "companion export finished",
                failureMessage: "Failed to export companion screenshots"
            ) {
                try DebugCompanionScreenshotExporter.exportSixPageScreenshots(
                    outputDirectory: auditExportsDirectory(named: "companion-unification"),
                    serviceContainer: ServiceContainer.preview()
                )
            }

        case let .toolWorkspace(options):
            showToolWorkspacePreviewWindow(options: options)

        case let .productPanel(options):
            showProductPanelPreviewWindow(options: options)

        case let .agent(options):
            if let exportPath = options.exportPath {
                let terminatingRunner = runTerminatingDebugExport
                terminatingRunner(
                    "AgentPreviewExport",
                    "starting agent preview export",
                    "agent preview export finished",
                    "Failed to export agent preview"
                ) {
                    try exportAgentPreviewImage(to: exportPath, options: options)
                }
                return
            }
            showAgentPreviewWindow(options: options)

        case let .systemStatus(options):
            showSystemStatusPreviewWindow(options: options)
        }
    }

    private func runTerminatingDebugExport(
        prefix: String,
        startMessage: String,
        successMessage: String,
        failureMessage: String,
        operation: () throws -> Void
    ) {
        print("[\(prefix)] \(startMessage)")
        do {
            try operation()
            print("[\(prefix)] \(successMessage)")
        } catch {
            logger.error("\(failureMessage): \(error.localizedDescription)", file: "AppDelegate")
            print("[\(prefix)] export failed: \(error.localizedDescription)")
        }
        NSApp.terminate(nil)
    }

    private func makeSettingsPreviewContentView(contentWidth: CGFloat, contentHeight: CGFloat) -> NSHostingView<AnyView> {
        let rootView = AnyView(
            SettingsView(
                initialCategory: .security,
                initialSearchQuery: "权限"
            )
            .preferredColorScheme(.dark)
            .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView
    }

    private func exportSettingsPreviewImage(to path: String, options: SettingsPreviewLaunchOptions) throws {
        let contentWidth = options.contentWidth
        let contentHeight: CGFloat = 900
        let hostingView = makeSettingsPreviewContentView(contentWidth: contentWidth, contentHeight: contentHeight)
        try DebugScreenshotRenderer.exportHostingView(
            hostingView,
            to: URL(fileURLWithPath: path),
            errorDomain: "SettingsPreviewExport",
            logPrefix: "SettingsPreviewExport"
        )
    }

    private func showSettingsPreviewWindow(options: SettingsPreviewLaunchOptions) {
        let contentWidth = options.contentWidth
        let contentHeight: CGFloat = 900

        if settingsPreviewWindow == nil {
            let contentView = makeSettingsPreviewContentView(contentWidth: contentWidth, contentHeight: contentHeight)
            let window = DebugPreviewWindowFactory.makeWindow(
                title: "设置面板",
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                contentView: contentView
            )
            DebugPreviewWindowFactory.show(window)
            settingsPreviewWindow = window
        }
    }

    private func showToolWorkspacePreviewWindow(options: ToolWorkspacePreviewLaunchOptions) {
        let contentWidth = options.contentWidth
        let contentHeight = options.contentHeight

        if toolWorkspacePreviewWindow == nil {
            let contentView = NSHostingView(
                rootView: ToolWorkspacePreviewRoot()
                    .preferredColorScheme(.dark)
            )
            let window = DebugPreviewWindowFactory.makeWindow(
                title: "工具台面板",
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                contentView: contentView
            )
            DebugPreviewWindowFactory.show(window)
            toolWorkspacePreviewWindow = window
        }
    }

    private func showProductPanelPreviewWindow(options: ProductPanelPreviewLaunchOptions) {
        let contentWidth = options.contentWidth
        let contentHeight = options.contentHeight

        if productPanelPreviewWindow == nil {
            let contentView = NSHostingView(
                rootView: ProductPanelPreviewSample()
                    .preferredColorScheme(.dark)
            )
            let window = DebugPreviewWindowFactory.makeWindow(
                title: "产品面板",
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                contentView: contentView
            )
            DebugPreviewWindowFactory.show(window)
            productPanelPreviewWindow = window
        }
    }

    private func makeAgentPreviewContentView(options: AgentPreviewLaunchOptions) -> NSHostingView<AnyView> {
        let contentWidth = options.contentWidth
        let contentHeight = options.contentHeight
        let rootView = AnyView(
            AgentDashboardView(
                viewModel: DebugAgentPreviewSample.makeViewModel(),
                selectedSidebarItem: options.sidebarSelection,
                showRightPanel: false,
                previewSidebarSelection: nil,
                shouldLoadDashboardData: false
            )
            .preferredColorScheme(.light)
            .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView
    }

    private func exportAgentPreviewImage(to path: String, options: AgentPreviewLaunchOptions) throws {
        try DebugScreenshotRenderer.exportHostingView(
            makeAgentPreviewContentView(options: options),
            to: URL(fileURLWithPath: path),
            errorDomain: "AgentPreviewExport",
            logPrefix: "AgentPreviewExport"
        )
    }

    private func showAgentPreviewWindow(options: AgentPreviewLaunchOptions) {
        let contentWidth = options.contentWidth
        let contentHeight = options.contentHeight

        if agentPreviewWindow == nil {
            let contentView = makeAgentPreviewContentView(options: options)
            let window = DebugPreviewWindowFactory.makeWindow(
                title: "智能体面板",
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                contentView: contentView
            )
            DebugPreviewWindowFactory.show(window)
            agentPreviewWindow = window
        }
    }

    private func showSystemStatusPreviewWindow(options: SystemStatusPreviewLaunchOptions) {
        let contentWidth = options.contentWidth
        let contentHeight = options.contentHeight

        if systemStatusPreviewWindow == nil {
            let service = SystemStatusService()
            systemStatusPreviewService = service
            service.start()

            let contentView = NSHostingView(
                rootView: SystemStatusView(
                    systemStatusService: service,
                    fanControlService: SystemFanControlService()
                )
                    .preferredColorScheme(.dark)
            )
            let window = DebugPreviewWindowFactory.makeWindow(
                title: "系统状态面板",
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                contentView: contentView
            )
            DebugPreviewWindowFactory.show(window)
            systemStatusPreviewWindow = window
        }
    }
#endif

    func showLaunchWindow() {
        if launchWindowController == nil {
            launchWindowController = LaunchWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        launchWindowController?.showWindow(nil)
        launchWindowController?.window?.setFrame(AppWindowGeometry.launchFrame, display: true)
        launchWindowController?.window?.makeKeyAndOrderFront(nil)
        launchWindowController?.window?.orderFrontRegardless()
    }

    func hideLaunchWindow() {
        launchWindowController?.close()
        launchWindowController = nil
    }

    func hideCapsuleWindow() {
        hideDesktopCapsule()
    }

    // MARK: - Notch Panel

    func showNotchPanel() {
        // 启动和回到应用时，优先让灵动大陆保持可见的主内容态，
        // 避免只露出一个过小的收起态，让用户误以为它“消失”了。
        notchPanelController.show(page: .overview)
    }

    func showNotchPanel(page: NotchV2Page) {
        notchPanelController.show(page: page)
    }

    func hideNotchPanel() {
        notchPanelController.hide()
    }

    func toggleNotchPanel() {
        notchPanelController.toggle()
    }

    // MARK: - Desktop Capsule

    func showDesktopCapsule() {
        desktopCapsuleController.restorePosition()
        desktopCapsuleController.show()
    }

    func showScreenshotOptionsPanel() {
        CapsulePanel.shared.show()
        NotificationCenter.default.post(name: Notification.Name("AcMind.showScreenshotOptions"), object: nil)
    }

    func hideDesktopCapsule() {
        desktopCapsuleController.hide()
    }

    func toggleDesktopCapsule() {
        desktopCapsuleController.toggle()
    }

    // MARK: - Clipboard Pin Windows

    func showClipboardPinWindow(item: ClipboardItem) {
        guard isTerminating == false else { return }
        if clipboardPinWindowManager == nil {
            let assetStore = self.assetStore ?? AssetStore()
            clipboardPinWindowManager = ClipboardPinWindowManager(assetStore: assetStore)
        }
        clipboardPinWindowManager?.show(item: item)
    }

    func showClipboardPinWindow(captureResult: CaptureResult) {
        let item = ClipboardItem.pinItem(from: captureResult)
        showClipboardPinWindow(item: item)
    }

    func showClipboardPinWindow(collectedItem: CollectedItem) {
        guard collectedItem.canOpenDesktopPin else { return }
        Task { [weak self] in
            await self?.showClipboardPinWindow(collectedItem: collectedItem)
        }
    }

    private func showClipboardPinWindow(collectedItem: CollectedItem) async {
        guard let assetStore else {
            await MainActor.run {
                appState.showError(.serviceUnavailable("资产存储不可用"))
            }
            return
        }

        do {
            let sourceItem = SourceItem(collectedItem: collectedItem)
            let assetFiles = try await assetStore.getAssetsForSourceItem(sourceItemId: collectedItem.id.rawID)
            let result = CaptureResult(sourceItem: sourceItem, assetFiles: assetFiles)

            await MainActor.run {
                self.showClipboardPinWindow(captureResult: result)
            }
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    func hideClipboardPinWindows() {
        #if DEBUG
        logger.debug("ClipboardPin hide all request", file: "AppDelegate")
        #endif
        clipboardPinWindowManager?.hideAll()
    }

    func showClipboardPinWindows() {
        #if DEBUG
        logger.debug("ClipboardPin show all request", file: "AppDelegate")
        #endif
        clipboardPinWindowManager?.showAll()
    }

    func closeClipboardPinWindows() {
        #if DEBUG
        logger.debug("ClipboardPin close all request", file: "AppDelegate")
        #endif
        clipboardPinWindowManager?.closeAll()
    }

    func clipboardPinWindowCount() -> Int {
        clipboardPinWindowManager?.openWindowCount ?? 0
    }

    func clipboardPinWindowSnapshots() -> [ClipboardPinWindowSnapshot] {
        clipboardPinWindowManager?.windowSnapshots ?? []
    }

    func copyClipboardPinDiagnosticsToPasteboard() {
        let diagnostics = clipboardPinWindowManager?.diagnosticsReport() ?? "AcWork 剪贴板固定诊断\n窗口数量：0\n当前没有打开的固定窗口。"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
    }

    private var clipboardPinActions: ClipboardPinActions {
        ClipboardPinActions(
            showItem: { [weak self] item in
                self?.showClipboardPinWindow(item: item)
            },
            showAll: { [weak self] in
                self?.showClipboardPinWindows()
            },
            hideAll: { [weak self] in
                self?.hideClipboardPinWindows()
            },
            closeAll: { [weak self] in
                self?.closeClipboardPinWindows()
            },
            copyDiagnostics: { [weak self] in
                self?.copyClipboardPinDiagnosticsToPasteboard()
            }
        )
    }

    // MARK: - OOBE

    func showOOBE() {
        let permissionManager = self.permissionManager ?? PermissionManager()
        let settingsService = self.settingsService ?? SettingsService()
        let oobeController = OOBEWindowController(
            permissionManager: permissionManager,
            settingsService: settingsService
        )
        oobeWindowController = oobeController
        oobeController.onFinish = { [weak self] engine, polishMode in
            // OOBE 完成后显示主界面
            self?.showMainWindow()
            if self?.notchPanelEnabled == true {
                self?.showNotchPanel()
            } else if self?.desktopCapsuleEnabled == true {
                self?.showDesktopCapsule()
            }
            self?.setupCompanionRuntime()
            self?.setupFnKeyMonitor()
            self?.setupGlobalShortcuts()
            self?.setupHotCorners()
            self?.oobeWindowController = nil
        }
        oobeController.onClose = { [weak self] in
            // 如果用户关闭了 OOBE，也显示主界面
            self?.showMainWindow()
            if self?.notchPanelEnabled == true {
                self?.showNotchPanel()
            } else if self?.desktopCapsuleEnabled == true {
                self?.showDesktopCapsule()
            }
            self?.setupCompanionRuntime()
            self?.setupFnKeyMonitor()
            self?.setupGlobalShortcuts()
            self?.setupHotCorners()
            self?.oobeWindowController = nil
        }
        oobeController.showWindow()
    }

    // MARK: - Status Bar

    private func applicationIconImage() -> NSImage? {
        NSImage(named: "AppIcon") ?? NSApp.applicationIconImage
    }

    private func statusBarIconImage() -> NSImage? {
        guard let sourceImage = applicationIconImage() else { return nil }
        let targetSize = NSSize(width: 18, height: 18)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        let sourceRect = NSRect(origin: .zero, size: sourceImage.size)
        let targetRect = NSRect(origin: .zero, size: targetSize)
        sourceImage.draw(in: targetRect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
        image.isTemplate = false
        return image
    }

    private func applyApplicationIcon() {
        guard let image = applicationIconImage() else { return }
        NSApp.applicationIconImage = image
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = statusBarIconImage()
        }

        setupStatusBarMenu()
    }

    private func setupStatusBarMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "立即截图", action: #selector(showScreenshotOptionsFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "显示主窗口", action: #selector(showMainWindowFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "显示灵动胶囊", action: #selector(toggleDesktopCapsuleFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let pinMenu = NSMenu(title: "剪贴板固定")
        pinMenu.addItem(NSMenuItem(title: "全部显示固定窗口", action: #selector(showClipboardPinWindowsFromMenu), keyEquivalent: ""))
        pinMenu.addItem(NSMenuItem(title: "全部隐藏固定窗口", action: #selector(hideClipboardPinWindowsFromMenu), keyEquivalent: ""))
        pinMenu.addItem(NSMenuItem(title: "全部关闭固定窗口", action: #selector(closeClipboardPinWindowsFromMenu), keyEquivalent: ""))
        pinMenu.addItem(NSMenuItem.separator())
        pinMenu.addItem(NSMenuItem(title: "复制固定诊断信息", action: #selector(copyClipboardPinDiagnosticsFromMenu), keyEquivalent: ""))
        let pinMenuItem = NSMenuItem(title: "剪贴板固定", action: nil, keyEquivalent: "")
        pinMenuItem.submenu = pinMenu
        menu.addItem(pinMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 快速操作
        let captureMenu = NSMenu(title: "截图")
        let screenshotMenu = NSMenu(title: "截图")
        screenshotMenu.addItem(NSMenuItem(title: "全屏截图", action: #selector(captureFullscreenScreenshot), keyEquivalent: ""))
        screenshotMenu.addItem(NSMenuItem(title: "区域截图", action: #selector(captureAreaScreenshot), keyEquivalent: ""))
        screenshotMenu.addItem(NSMenuItem(title: "窗口截图", action: #selector(captureWindowScreenshot), keyEquivalent: ""))
        screenshotMenu.addItem(NSMenuItem.separator())
        screenshotMenu.addItem(NSMenuItem(title: "滚动截图", action: #selector(captureScrollingScreenshotFromMenu), keyEquivalent: ""))
        captureMenu.addItem(NSMenuItem(title: "立即截图", action: #selector(showScreenshotOptionsFromMenu), keyEquivalent: ""))
        captureMenu.addItem(NSMenuItem.separator())
        let screenshotItem = NSMenuItem(title: "截图", action: nil, keyEquivalent: "")
        screenshotItem.submenu = screenshotMenu
        captureMenu.addItem(screenshotItem)
        captureMenu.addItem(NSMenuItem(title: "截图历史", action: #selector(showScreenshotHistoryFromMenu), keyEquivalent: ""))
        captureMenu.addItem(NSMenuItem(title: "继续处理最近一次截图", action: #selector(openLatestScreenshotPreviewFromMenu), keyEquivalent: ""))
        captureMenu.addItem(NSMenuItem(title: "胶囊输入", action: #selector(showCapsuleFromMenu), keyEquivalent: ""))
        let captureItem = NSMenuItem(title: "截图", action: nil, keyEquivalent: "")
        captureItem.submenu = captureMenu
        menu.addItem(captureItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // 前台激活时刷新权限状态
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidResignActive(_:)),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureNotification(_:)),
            name: Notification.Name("AcMind.captureScreenshot"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettingsNotification(_:)),
            name: Notification.Name("AcMind.openSettings"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenHomeNotification(_:)),
            name: Notification.Name("AcMind.openHome"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipboardNotification(_:)),
            name: Notification.Name("AcMind.captureClipboard"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextNotification(_:)),
            name: Notification.Name("AcMind.captureText"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceNotification(_:)),
            name: Notification.Name("AcMind.captureVoice"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInlineToastNotification(_:)),
            name: .acmindInlineToastRequested,
            object: nil
        )

        // 监听刘海面板导航通知 - 打开主窗口并切换路由
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotchNavigate(_:)),
            name: .companionShowSchedule,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotchNavigate(_:)),
            name: .companionShowInbox,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotchNavigate(_:)),
            name: .companionShowAgent,
            object: nil
        )

        // 监听截图完成通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureCompleted(_:)),
            name: Notification.Name("AcMind.captureCompleted"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeleteSourceItem(_:)),
            name: .acmindDeleteSourceItem,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGlobalShortcut(_:)),
            name: .acmindGlobalShortcutTriggered,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotCornersDidChange(_:)),
            name: .hotCornersDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsDidChange(_:)),
            name: .settingsDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCompanionConfigurationDidChange(_:)),
            name: .companionConfigurationDidChange,
            object: nil
        )
    }

    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        // App 回到前台时刷新所有权限状态
        Task {
            logger.info("App did become active, refreshing permissions", file: "AppDelegate")
            await permissionManager?.refreshAll()
            await updateClipboardCapturePolicy(isAppActive: true)
        }
    }

    @objc private func handleAppDidResignActive(_ notification: Notification) {
        Task {
            await updateClipboardCapturePolicy(isAppActive: false)
        }
    }

    @objc private func handleNotchNavigate(_ notification: Notification) {
        switch notification.name {
        case .companionShowSchedule:
            showPreferredSurface(for: .schedule)
        case .companionShowInbox:
            showPreferredSurface(for: .inbox)
        case .companionShowAgent:
            showPreferredSurface(for: .agent)
        default:
            break
        }
    }

    @objc private func handleCaptureCompleted(_ notification: Notification) {
        // 截图完成后发送通知给刘海面板
        NotificationCenter.default.post(
            name: .companionCaptureSuccess,
            object: notification.object
        )

        if let captureResult = notification.object as? CaptureResult {
            let settings = SettingsLocalPreferences.loadOrDefault()
            if settings.companionCaptureOpenDetailAfterCapture {
                Task { @MainActor in
                    self.appState.pendingInboxDetailSourceItemID = captureResult.sourceItem.id
                    self.showPreferredSurface(for: .inbox)
                }
            }
        }

        Task {
            await sendCaptureCompletedNotificationIfNeeded(notification)
        }
    }

    private func sendCaptureCompletedNotificationIfNeeded(_ notification: Notification) async {
        guard let captureResult = notification.object as? CaptureResult else {
            return
        }

        let settings = SettingsLocalPreferences.loadOrDefault()
        guard settings.companionCaptureShowNotification else { return }
        await AppNotificationService.notifyTaskCompleted(
            title: "采集已完成",
            body: captureResult.sourceItem.title ?? "已保存到收集箱",
            settings: AppNotificationSettings(
                notificationsEnabled: settings.notificationsEnabled,
                taskCompletedNotificationsEnabled: settings.taskCompletedNotificationsEnabled
            )
        )
    }

    @objc private func handleDeleteSourceItem(_ notification: Notification) {
        guard let itemID = notification.object as? String else { return }

        Task {
            do {
                try await storageService?.deleteSourceItem(id: itemID)
            } catch {
                await MainActor.run {
                    appState.showError(.serviceUnavailable("删除收集项"))
                }
                logger.error("删除收集项失败: \(error.localizedDescription)", file: "AppDelegate")
            }
        }
    }

    @objc private func handleCaptureNotification(_ notification: Notification) {
        Task {
            // 解析截图模式
            var mode: ScreenshotMode = .fullscreen
            if let userInfo = notification.object as? [String: Any],
               let modeString = userInfo["mode"] as? String,
               let capturedMode = ScreenshotMode(rawValue: modeString) {
                mode = capturedMode
            }
            await performCapture(mode: mode)
        }
    }

    @objc private func handleClipboardNotification(_ notification: Notification) {
        Task {
            await performClipboardCapture()
        }
    }

    @objc private func handleTextNotification(_ notification: Notification) {
        if let text = notification.object as? String {
            Task {
                await performTextCapture(text)
            }
        }
    }

    @objc private func handleVoiceNotification(_ notification: Notification) {
        Task {
            await MainActor.run {
                self.showVoicePanel()
            }
        }
    }

    @objc private func handleInlineToastNotification(_ notification: Notification) {
        let title = (notification.userInfo?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = (notification.userInfo?["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let styleRaw = notification.userInfo?["style"] as? String

        let messageParts = [title, body].compactMap { value -> String? in
            guard let value, value.isEmpty == false else { return nil }
            return value
        }

        let message = messageParts.joined(separator: " · ")
        guard message.isEmpty == false else { return }

        let toastType: NotchToastType
        switch AppInlineNotificationStyle(rawValue: styleRaw ?? "") ?? .info {
        case .success: toastType = .success
        case .error: toastType = .error
        case .warning: toastType = .warning
        case .info: toastType = .info
        }

        ToastManager.shared.show(toastType, message)
    }

    @objc private func handleHotCornersDidChange(_ notification: Notification) {
        refreshHotCorners()
    }

    @objc private func handleCompanionShortcutConfigChanged(_ notification: Notification) {
        setupCompanionShortcuts()
    }

    @objc private func handleSettingsDidChange(_ notification: Notification) {
        setupGlobalShortcuts()
        Task {
            await updateClipboardCapturePolicy(isAppActive: NSApp.isActive)
        }
    }

    @objc private func handleCompanionConfigurationDidChange(_ notification: Notification) {
        setupCompanionRuntime()
    }

    // MARK: - Global Shortcuts

    private func setupHotCorners() {
        guard let settingsService else {
            logger.debug("Hot corner setup skipped because settings service is unavailable", file: "AppDelegate")
            hotCornerManager?.stop()
            hotCornerManager = nil
            return
        }

        if hotCornerManager == nil {
            logger.debug("Creating hot corner manager", file: "AppDelegate")
            hotCornerManager = HotCornerManager(actionExecutor: { [weak self] action in
                self?.performHotCornerAction(action)
            })
        }

        refreshHotCorners(from: settingsService)
    }

    private func refreshHotCorners() {
        guard let settingsService else {
            logger.debug("Hot corner refresh skipped because settings service is unavailable", file: "AppDelegate")
            hotCornerManager?.stop()
            hotCornerManager = nil
            return
        }

        refreshHotCorners(from: settingsService)
    }

    private func refreshHotCorners(from hotCornerStore: SettingsServiceProtocol) {
        Task { [weak self] in
            let settings = await hotCornerStore.getHotCornerSettings()
            await MainActor.run {
                self?.logger.debug("Applying hot corner settings: enabled=\(settings.isEnabled), cornerSize=\(settings.cornerSize)", file: "AppDelegate")
                self?.hotCornerManager?.update(settings: settings)
            }
        }
    }

    private func setupGlobalShortcuts() {
        Task { [weak self] in
            guard let self else { return }
            await self.refreshGlobalShortcuts()
        }
    }

    private func refreshGlobalShortcuts() async {
        guard let settingsService else { return }

        for shortcut in registeredGlobalShortcuts {
            try? await settingsService.unregisterShortcut(shortcut)
        }
        registeredGlobalShortcuts.removeAll()

        for item in SidebarItem.shortcutItems {
            guard let shortcut = item.shortcut else { continue }

            do {
                try await settingsService.registerShortcut(shortcut) {
                    NotificationCenter.default.post(
                        name: .acmindGlobalShortcutTriggered,
                        object: item.rawValue
                    )
                }
                registeredGlobalShortcuts.append(shortcut)
            } catch {
                logger.error("注册全局快捷键失败: \(item.displayName) - \(error.localizedDescription)", file: "AppDelegate")
            }
        }

        let appSettings = await settingsService.getSettings()
        if let hotkeyString = appSettings.captureScreenshotHotkey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hotkeyString.isEmpty,
           let shortcut = KeyboardShortcut(displayString: hotkeyString) {
            do {
                try await settingsService.registerShortcut(shortcut) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.captureScreenshot()
                    }
                }
                registeredGlobalShortcuts.append(shortcut)
            } catch {
                logger.error("注册截图热键失败: \(hotkeyString) - \(error.localizedDescription)", file: "AppDelegate")
            }
        }
    }

    private func setupCompanionShortcuts() {
        Task { [weak self] in
            guard let self else { return }
            await self.refreshCompanionShortcuts()
        }
    }

    private func setupCompanionRuntime() {
        Task { [weak self] in
            guard let self else { return }
            await self.refreshCompanionRuntime()
        }
    }

    private func refreshCompanionRuntime() async {
        guard let storageService else { return }

        let configuration = await CompanionConfigurationStore.load(from: storageService)
        isCompanionRuntimeEnabled = configuration.companionEnabled

        await refreshCompanionShortcuts()
        setupFnKeyMonitor()
        setupHeadphoneMonitor()

        if !configuration.voiceShortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            registerVoiceShortcut(configuration.voiceShortcut)
        }
    }

    private func refreshCompanionShortcuts() async {
        guard let storageService, let settingsService else { return }

        for shortcut in registeredCompanionShortcuts {
            try? await settingsService.unregisterShortcut(shortcut)
        }
        registeredCompanionShortcuts.removeAll()

        guard isCompanionRuntimeEnabled else { return }

        let shortcuts = await loadCompanionShortcuts(from: storageService)

        for shortcutConfig in shortcuts where shortcutConfig.isEnabled {
            guard let shortcut = AcMindKeyboardShortcut(displayString: shortcutConfig.shortcut) else {
                continue
            }

            do {
                try await settingsService.registerShortcut(shortcut) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.triggerCompanionShortcut(action: shortcutConfig.action)
                    }
                }
                registeredCompanionShortcuts.append(shortcut)
            } catch {
                logger.error("注册随身快捷键失败: \(shortcutConfig.action) - \(error.localizedDescription)", file: "AppDelegate")
            }
        }
    }

    func registerVoiceShortcut(_ shortcutString: String) {
        guard !shortcutString.isEmpty, let shortcut = KeyboardShortcut(displayString: shortcutString) else { return }
        guard let settingsService else { return }
        Task {
            if let old = registeredVoiceShortcut {
                try? await settingsService.unregisterShortcut(old)
            }
            do {
                try await settingsService.registerShortcut(shortcut) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.showVoicePanel()
                    }
                }
                registeredVoiceShortcut = shortcut
            } catch {
                logger.error("注册语音快捷键失败: \(shortcutString) - \(error.localizedDescription)", file: "AppDelegate")
                ToastManager.shared.show(.error, "语音快捷键注册失败，请检查快捷键是否与其他应用冲突")
            }
        }
    }

    func unregisterVoiceShortcut(_ shortcutString: String) {
        guard !shortcutString.isEmpty, let shortcut = KeyboardShortcut(displayString: shortcutString) else { return }
        guard let settingsService else { return }
        Task {
            try? await settingsService.unregisterShortcut(shortcut)
            if registeredVoiceShortcut?.displayString == shortcutString {
                registeredVoiceShortcut = nil
            }
        }
    }

    private func updateClipboardCapturePolicy(isAppActive: Bool) async {
        guard let clipboardService else { return }

        let preferences = SettingsLocalPreferences.loadOrDefault()
        guard preferences.captureOnlyWhenAppActive else { return }

        if isAppActive {
            await clipboardService.resumeWatching()
        } else {
            await clipboardService.pauseWatching()
        }
    }

    private func loadCompanionShortcuts(from storageService: StorageServiceProtocol) async -> [CompanionShortcut] {
        guard let raw = try? await storageService.getSetting(key: "companion.shortcuts.v1"),
              let data = raw.data(using: .utf8),
              let shortcuts = try? JSONDecoder().decode([CompanionShortcut].self, from: data) else {
            return CompanionShortcut.defaultShortcuts
        }
        return shortcuts
    }

    private func triggerCompanionShortcut(action: String) {
        guard isCompanionRuntimeEnabled else {
            return
        }
        switch action {
        case "说入法":
            showVoicePanel()
        case "快速收集":
            NotificationCenter.default.post(name: .companionShowCapturePanel, object: nil)
        case "截图捕获":
            NotificationCenter.default.post(name: Notification.Name("AcMind.captureScreenshot"), object: nil)
        case "打开智能体":
            appState.navigate(to: .agent)
            showMainWindow()
        case "今日日程":
            appState.navigate(to: .schedule)
            showMainWindow()
        default:
            break
        }
    }

    private func setupFnKeyMonitor() {
        guard isCompanionRuntimeEnabled else {
            fnKeyMonitor?.stop()
            fnKeyMonitor = nil
            return
        }
        guard fnKeyMonitor == nil else { return }
        let monitor = FnKeyHoldMonitor()
        monitor.onFnPressBegan = { [weak self] in
            guard self?.isCompanionRuntimeEnabled == true else { return }
            guard SettingsLocalPreferences.isVoiceInputEnabled() else { return }
            self?.showVoicePanel()
        }
        monitor.onFnPressEnded = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if self.mainWindowController?.window?.isVisible == true {
                    NotificationCenter.default.post(name: .companionVoiceFinishRequested, object: nil)
                }
            }
        }
        monitor.start()
        fnKeyMonitor = monitor
    }

    private func setupHeadphoneMonitor() {
        guard isCompanionRuntimeEnabled else {
            HeadphoneMonitor.shared.disable()
            return
        }
        Task {
            HeadphoneMonitor.shared.enable(
                onSingleTap: { @Sendable in
                    Task { @MainActor in
                        guard self.isCompanionRuntimeEnabled else { return }
                        NotificationCenter.default.post(name: .headphoneSingleTap, object: nil)
                    }
                    return true
                },
                onDoubleTap: { @Sendable in
                    Task { @MainActor in
                        guard self.isCompanionRuntimeEnabled else { return }
                        NotificationCenter.default.post(name: .headphoneDoubleTap, object: nil)
                    }
                },
                onLongPressStart: { @Sendable in
                    Task { @MainActor in
                        guard self.isCompanionRuntimeEnabled else { return }
                        NotificationCenter.default.post(name: .headphoneLongPressStart, object: nil)
                    }
                },
                onLongPressEnd: { @Sendable in
                    Task { @MainActor in
                        guard self.isCompanionRuntimeEnabled else { return }
                        NotificationCenter.default.post(name: .headphoneLongPressEnd, object: nil)
                    }
                }
            )
        }
    }

    // MARK: - Actions

    @objc private func showMainWindowFromMenu() {
        showMainWindow()
    }

    @objc private func showCapsuleFromMenu() {
        showCapsuleWindow()
    }

    @objc private func toggleDesktopCapsuleFromMenu() {
        toggleDesktopCapsule()
    }

    @objc private func showClipboardPinWindowsFromMenu() {
        showClipboardPinWindows()
    }

    @objc private func hideClipboardPinWindowsFromMenu() {
        hideClipboardPinWindows()
    }

    @objc private func closeClipboardPinWindowsFromMenu() {
        closeClipboardPinWindows()
    }

    @objc private func copyClipboardPinDiagnosticsFromMenu() {
        copyClipboardPinDiagnosticsToPasteboard()
    }

    private func performHotCornerAction(_ action: HotCornerAction) {
        switch action {
        case .none:
            break
        case let .openApp(bundleIdentifier):
            openApplication(bundleIdentifier: bundleIdentifier)
        case let .openURL(urlString):
            openURL(urlString)
        case let .toggleFeature(featureIdentifier):
            toggleFeature(identifier: featureIdentifier)
        case let .openInternalRoute(routeIdentifier):
            openInternalRoute(routeIdentifier)
        case let .showPanel(panelIdentifier):
            showPanel(identifier: panelIdentifier)
        }
    }

    private func openApplication(bundleIdentifier: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            logger.warning("未找到应用: \(bundleIdentifier)", file: "AppDelegate")
            return
        }

        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                self.logger.error("打开应用失败: \(error.localizedDescription)", file: "AppDelegate")
            }
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            logger.warning("无效 URL: \(urlString)", file: "AppDelegate")
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func toggleFeature(identifier: String) {
        switch identifier {
        case SidebarItem.dynamicContinent.rawValue:
            showPreferredSurface(for: .dynamicContinent)
        case SidebarItem.systemStatus.rawValue:
            showPreferredSurface(for: .systemStatus)
        case SidebarItem.voiceEntry.rawValue:
            showPreferredSurface(for: .voiceEntry)
        case SidebarItem.agent.rawValue:
            showPreferredSurface(for: .agent)
        case SidebarItem.schedule.rawValue:
            showPreferredSurface(for: .schedule)
        case "notchPanel":
            toggleNotchPanel()
        case "desktopCapsule":
            toggleDesktopCapsule()
        case "mainWindow":
            toggleMainWindow()
        default:
            logger.warning("未知功能: \(identifier)", file: "AppDelegate")
        }
    }

    private func openInternalRoute(_ routeIdentifier: String) {
        if routeIdentifier == "phoneSync" {
            appState.selectInboxWorkspace("phoneSync")
            showMainWindow()
            return
        }

        if let item = SidebarItem(rawValue: routeIdentifier) {
            showPreferredSurface(for: item)
        } else {
            logger.warning("未知内部路由: \(routeIdentifier)", file: "AppDelegate")
            showPreferredSurface(for: .home)
        }
    }

    private func showPanel(identifier: String) {
        switch identifier {
        case "notchPanel":
            showNotchPanel(page: .overview)
        case "desktopCapsule":
            showDesktopCapsule()
        default:
            openInternalRoute(identifier)
        }
    }

    private func showPreferredSurface(for item: SidebarItem) {
        switch item {
        case .dynamicContinent:
            if notchPanelEnabled {
                showNotchPanel(page: .overview)
            } else {
                appState.navigate(to: .dynamicContinent)
                showMainWindow()
            }
        case .agent:
            if notchPanelEnabled {
                showNotchPanel(page: .agent)
            } else {
                appState.navigate(to: .agent)
                showMainWindow()
            }
        case .schedule:
            if notchPanelEnabled {
                showNotchPanel(page: .schedule)
            } else {
                appState.navigate(to: .schedule)
                showMainWindow()
            }
        case .systemStatus:
            appState.navigate(to: .systemStatus)
            showMainWindow()
        case .voiceEntry:
            appState.navigate(to: .voiceEntry)
            showMainWindow()
        default:
            appState.navigate(to: item)
            showMainWindow()
        }
    }

    @objc func showSystemStatus() {
        appState.navigate(to: .systemStatus)
        showMainWindow()
    }

    @objc func captureAreaScreenshot() {
        guard SettingsLocalPreferences.isCaptureScreenshotEnabled() else {
            appState.showError(.serviceUnavailable("截图捕获已在设置中关闭"))
            return
        }

        Task {
            await performCapture(mode: .area)
        }
    }

    func showQuickNotePanel() {
        NotificationCenter.default.post(name: .companionShowQuickNote, object: nil)
    }

    func showAboutPanel() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    func toggleMainWindowFullScreen() {
        guard let window = mainWindowController?.window else { return }
        window.toggleFullScreen(nil)
    }

    func openSettingsWindow(category: SettingsCategory? = nil) {
        if let category {
            appState.navigate(to: .settings, settingsCategory: category)
            showMainWindow()
        } else {
            notchPanelController.show(page: .settings)
        }
    }

    @objc private func showSettings() {
        appState.navigate(to: .settings)
        showMainWindow()
    }

    @objc private func captureFullscreenScreenshot() {
        guard SettingsLocalPreferences.isCaptureScreenshotEnabled() else {
            appState.showError(.serviceUnavailable("截图捕获已在设置中关闭"))
            return
        }

        Task {
            await performCapture(mode: .fullscreen)
        }
    }

    @objc private func handleOpenHomeNotification(_ notification: Notification) {
        appState.navigate(to: .home)
        showMainWindow()
    }

    @objc private func handleOpenSettingsNotification(_ notification: Notification) {
        if let category = notification.userInfo?["category"] as? SettingsCategory {
            openSettingsWindow(category: category)
        } else {
            showSettings()
        }
    }

    @objc private func handleGlobalShortcut(_ notification: Notification) {
        guard let rawValue = notification.object as? String,
              let item = SidebarItem(rawValue: rawValue) else { return }

        showPreferredSurface(for: item)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Capture Operations

    @objc private func captureScreenshot() {
        captureFullscreenScreenshot()
    }

    @objc private func showScreenshotOptionsFromMenu() {
        showScreenshotOptionsPanel()
    }

    @objc private func captureWindowScreenshot() {
        guard SettingsLocalPreferences.isCaptureScreenshotEnabled() else {
            appState.showError(.serviceUnavailable("截图捕获已在设置中关闭"))
            return
        }

        Task {
            await performCapture(mode: .window)
        }
    }

    private func performCapture(mode: ScreenshotMode) async {
        guard !isTerminating else { return }
        guard let captureService else { return }

        do {
            let result = try await captureService.captureScreenshot(mode: mode)
            
            // 获取截图图片用于预览
            var previewImage: NSImage?
            if let assetId = result.sourceItem.assetFileIds.first,
               let asset = try? await assetStore?.getAsset(id: assetId) {
                previewImage = NSImage(contentsOfFile: asset.filePath)
            }
            
            // 显示截图预览窗口
            await MainActor.run {
                showScreenshotPreview(
                    image: previewImage,
                    result: result
                )
            }
            
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    @objc private func captureScrollingScreenshotFromMenu() {
        guard SettingsLocalPreferences.isCaptureScreenshotEnabled() else {
            appState.showError(.serviceUnavailable("截图捕获已在设置中关闭"))
            return
        }

        Task {
            await performScrollingCapture()
        }
    }

    @objc private func showScreenshotHistoryFromMenu() {
        appState.selectInboxWorkspace("screenshotHistory")
        showMainWindow()
    }

    @objc func openLatestScreenshotPreviewFromMenu() {
        Task { [weak self] in
            await self?.openLatestScreenshotPreview()
        }
    }

    @objc func openLatestScreenshotPinWindowFromMenu() {
        Task { [weak self] in
            await self?.openLatestScreenshotPinWindow()
        }
    }

    private func openLatestScreenshotPreview() async {
        guard let storageService else {
            await MainActor.run {
                appState.showError(.serviceUnavailable("存储服务不可用"))
            }
            return
        }

        do {
            let items = try await storageService.listSourceItems(filter: SourceItemFilter(type: .screenshot, limit: 1))
            guard let latest = items.first else {
                await MainActor.run {
                    appState.showError(.serviceUnavailable("没有可查看的截图"))
                }
                return
            }

            let assets = latest.assetFileIds.isEmpty
                ? []
                : try await assetStore?.getAssetsForSourceItem(sourceItemId: latest.id) ?? []
            let image = assets.first.flatMap { NSImage(contentsOfFile: $0.filePath) }
            let result = CaptureResult(sourceItem: latest, assetFiles: assets)

            await MainActor.run {
                showScreenshotPreview(image: image, result: result)
            }
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    private func openLatestScreenshotPinWindow() async {
        guard let storageService else {
            await MainActor.run {
                appState.showError(.serviceUnavailable("存储服务不可用"))
            }
            return
        }

        do {
            let items = try await storageService.listSourceItems(filter: SourceItemFilter(type: .screenshot, limit: 1))
            guard let latest = items.first else {
                await MainActor.run {
                    appState.showError(.serviceUnavailable("没有可固定的截图"))
                }
                return
            }

            let assets = latest.assetFileIds.isEmpty
                ? []
                : try await assetStore?.getAssetsForSourceItem(sourceItemId: latest.id) ?? []
            let result = CaptureResult(sourceItem: latest, assetFiles: assets)

            await MainActor.run {
                showClipboardPinWindow(captureResult: result)
            }
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    private func performScrollingCapture() async {
        guard !isTerminating else { return }
        guard let captureService else { return }

        do {
            let result = try await captureService.captureScrollingScreenshot()

            var previewImage: NSImage?
            if let assetId = result.sourceItem.assetFileIds.first,
               let asset = try? await assetStore?.getAsset(id: assetId) {
                previewImage = NSImage(contentsOfFile: asset.filePath)
            }

            await MainActor.run {
                showScreenshotPreview(
                    image: previewImage,
                    result: result
                )
            }
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }
    
    private func showScreenshotPreview(image: NSImage?, result: CaptureResult) {
        let localPreferences = SettingsLocalPreferences.loadOrDefault()
        let selectedPreset = screenshotPreset(for: result, preferences: localPreferences)
            ?? CaptureService.activeScreenshotPreset(from: localPreferences)
        let presetName = screenshotPresetName(for: result) ?? selectedPreset.name
        let defaultAction = screenshotPresetOutputAction(for: result) ?? selectedPreset.defaultOutputAction
        let screenshotMode = screenshotMode(for: result) ?? .fullscreen

        // 创建预览窗口
        let previewWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        screenshotPreviewWindow = previewWindow
        screenshotPreviewSession = ScreenshotPreviewSession(result: result)
        previewWindow.title = "截图工作区"
        previewWindow.delegate = self
        configureTransparentWindow(previewWindow)
        previewWindow.center()
        
        // 创建预览视图
        let previewView = ScreenshotPreviewView(
            image: image,
            captureResult: result,
            presetName: presetName,
            onSave: { [weak self] in
                self?.handleScreenshotSave(result: result)
            },
            onCopy: { [weak self] in
                self?.copyScreenshotToPasteboard(result: result, image: image)
            },
            onReveal: { [weak self] in
                self?.markScreenshotPreviewKept(result: result)
                self?.revealScreenshotInFinder(result: result)
            },
            onPin: { [weak self] in
                self?.markScreenshotPreviewKept(result: result)
                self?.showClipboardPinWindow(captureResult: result)
            },
            onOpenInPreview: { [weak self] in
                self?.markScreenshotPreviewKept(result: result)
                self?.openScreenshotInPreview(result: result)
            },
            onOpenHistory: { [weak self] in
                guard let self else { return }
                self.markScreenshotPreviewKept(result: result)
                self.appState.selectInboxWorkspace("screenshotHistory")
                self.showMainWindow()
            },
            onRetake: { [weak self] in
                self?.discardScreenshotPreviewIfNeeded(result: result)
                self?.screenshotPreviewWindow?.close()
                self?.screenshotPreviewWindow = nil
                self?.retakeScreenshot(mode: screenshotMode)
            },
            defaultAction: defaultAction,
            onDismiss: { [weak self] in
                self?.screenshotPreviewWindow?.close()
                self?.screenshotPreviewWindow = nil
            }
        )
        previewWindow.contentView = NSHostingView(rootView: previewView)
        
        // 显示窗口
        previewWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleScreenshotSave(result: CaptureResult) {
        markScreenshotPreviewKept(result: result)
        NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
    }

    private func markScreenshotPreviewKept(result: CaptureResult) {
        guard screenshotPreviewSession?.result.sourceItem.id == result.sourceItem.id else { return }
        screenshotPreviewSession?.shouldDiscardOnClose = false
    }

    private func retakeScreenshot(mode: ScreenshotMode) {
        switch mode {
        case .scroll:
            captureScrollingScreenshotFromMenu()
        case .fullscreen:
            captureFullscreenScreenshot()
        case .area:
            captureAreaScreenshot()
        case .window:
            captureWindowScreenshot()
        }
    }

    private func screenshotMode(for result: CaptureResult) -> ScreenshotMode? {
        guard let rawValue = result.sourceItem.metadata[CaptureService.screenshotModeMetadataKey] else { return nil }
        return ScreenshotMode(rawValue: rawValue)
    }

    private func screenshotPreset(for result: CaptureResult, preferences: SettingsLocalPreferences) -> ScreenshotPreset? {
        guard let presetID = result.sourceItem.metadata[CaptureService.screenshotPresetIDMetadataKey] else {
            return preferences.screenshotPresets.first(where: { $0.id == preferences.selectedScreenshotPresetID })
        }

        return preferences.screenshotPresets.first(where: { $0.id == presetID })
    }

    private func screenshotPresetName(for result: CaptureResult) -> String? {
        guard let value = result.sourceItem.metadata[CaptureService.screenshotPresetNameMetadataKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }
        return value
    }

    private func screenshotPresetOutputAction(for result: CaptureResult) -> ScreenshotPresetOutputAction? {
        guard let rawValue = result.sourceItem.metadata[CaptureService.screenshotPresetOutputActionMetadataKey] else {
            return nil
        }
        return ScreenshotPresetOutputAction(rawValue: rawValue)
    }

    private func copyScreenshotToPasteboard(result: CaptureResult, image: NSImage?) {
        let resolvedImage = image ?? result.assetFiles.first.flatMap { NSImage(contentsOfFile: $0.filePath) }

        guard let resolvedImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([resolvedImage])
    }

    private func revealScreenshotInFinder(result: CaptureResult) {
        guard let asset = result.assetFiles.first else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: asset.filePath)])
    }

    private func openScreenshotInPreview(result: CaptureResult) {
        guard let asset = result.assetFiles.first else {
            return
        }
        let url = URL(fileURLWithPath: asset.filePath)
        NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"), configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    private func discardScreenshotPreviewIfNeeded(result: CaptureResult? = nil) {
        guard let session = screenshotPreviewSession else { return }
        if let result, session.result.sourceItem.id != result.sourceItem.id { return }

        screenshotPreviewSession = nil
        guard session.shouldDiscardOnClose else { return }

        Task { [weak self] in
            guard let self else { return }
            for asset in session.result.assetFiles {
                try? await self.assetStore?.deleteAsset(id: asset.id)
            }
            try? await self.storageService?.deleteSourceItem(id: session.result.sourceItem.id)
        }
    }

    private func performClipboardCapture() async {
        guard !isTerminating else { return }
        guard let captureService else { return }

        do {
            if let result = try await captureService.captureFromClipboard() {
                NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
            }
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    private func performTextCapture(_ text: String) async {
        guard !isTerminating else { return }
        guard let captureService else { return }

        do {
            let result = try await captureService.captureFromManualText(text)
            NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    private func performVoiceCapture() async {
        guard !isTerminating else { return }
        guard let captureService else { return }

        do {
            let result = try await captureService.captureFromVoice()
            NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }
}

// MARK: - Fn Key Monitor

final class FnKeyHoldMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isFnPressed = false

    var onFnPressBegan: (() -> Void)?
    var onFnPressEnded: (() -> Void)?

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        isFnPressed = false
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == 63 else { return }

        let pressed = event.modifierFlags.contains(.function)
        guard pressed != isFnPressed else { return }
        isFnPressed = pressed

        if pressed {
            onFnPressBegan?()
        } else {
            onFnPressEnded?()
        }
    }
}

extension Notification.Name {
    static let headphoneSingleTap = Notification.Name("headphone.singleTap")
    static let headphoneDoubleTap = Notification.Name("headphone.doubleTap")
    static let headphoneLongPressStart = Notification.Name("headphone.longPressStart")
    static let headphoneLongPressEnd = Notification.Name("headphone.longPressEnd")
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == screenshotPreviewWindow {
            discardScreenshotPreviewIfNeeded()
            screenshotPreviewWindow = nil
        }
    }
}

// MARK: - Screenshot Preview View

private struct ScreenshotPreviewSession {
    let result: CaptureResult
    var shouldDiscardOnClose = true
}

struct ScreenshotPreviewView: View {
    let image: NSImage?
    let captureResult: CaptureResult
    let presetName: String
    let onSave: () -> Void
    let onCopy: () -> Void
    let onReveal: () -> Void
    let onPin: () -> Void
    let onOpenInPreview: () -> Void
    let onOpenHistory: () -> Void
    let onRetake: () -> Void
    let defaultAction: ScreenshotPresetOutputAction
    let onDismiss: () -> Void
    
    @State private var imageSize: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Button("关闭") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                if let size = imageSizeString {
                    Text(size)
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Label("预设：\(presetName)", systemImage: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppSurfaceTokens.cardBackgroundSoft)
                        )

                    secondaryActionButton(label: "重新截取") {
                        onRetake()
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                    secondaryActionButton(label: secondaryCopyLabel) {
                        onCopy()
                    }
                    .keyboardShortcut("c", modifiers: [.command])

                    secondaryActionButton(label: secondaryPinLabel) {
                        onPin()
                    }
                    .keyboardShortcut("p", modifiers: [.command])

                    secondaryActionButton(label: "在系统预览中打开") {
                        onOpenInPreview()
                    }
                    .keyboardShortcut("o", modifiers: [.command])

                    Button("查看历史") {
                        onOpenHistory()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("h", modifiers: [.command])

                    Button("在访达中显示") {
                        onReveal()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                }

                primaryActionButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
            )

            HStack(spacing: 8) {
                Label("回车默认：\(defaultAction.displayName)", systemImage: "return")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Spacer(minLength: 0)

                Text("默认动作会优先执行，其他操作可从右侧按钮切换。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            
            // 预览区域
            if let image = image {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .onAppear {
                            imageSize = image.size
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Text("截图已保存")
                        .font(.headline)
                    Text("可在收集箱中查看")
                        .font(.subheadline)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppSurfaceTokens.sidebarBackground)
            }
        }
        .background(AppSurfaceBackdrop())
    }
    
    private var imageSizeString: String? {
        guard imageSize.width > 0 && imageSize.height > 0 else { return nil }
        return String(format: "%.0f x %.0f px", imageSize.width, imageSize.height)
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch defaultAction {
        case .saveToInbox:
            Button("保存到收集箱") {
                onSave()
                onDismiss()
            }
            .keyboardShortcut(.return)
            .keyboardShortcut("s", modifiers: [.command])
            .buttonStyle(.borderedProminent)
        case .copyToClipboard:
            Button("复制到剪贴板") {
                onCopy()
            }
            .keyboardShortcut(.return)
            .keyboardShortcut("c", modifiers: [.command])
            .buttonStyle(.borderedProminent)
        case .pinToDesktop:
            Button("固定到桌面") {
                onPin()
            }
            .keyboardShortcut(.return)
            .keyboardShortcut("p", modifiers: [.command])
            .buttonStyle(.borderedProminent)
        }
    }

    private var secondaryCopyLabel: String {
        defaultAction == .copyToClipboard ? "复制到剪贴板" : "复制"
    }

    private var secondaryPinLabel: String {
        defaultAction == .pinToDesktop ? "固定到桌面" : "固定到桌面"
    }

    private func secondaryActionButton(label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
    }
    
}

// MARK: - Main Window Controller

class MainWindowController: NSWindowController {
    private var didEnforceInitialSize = false

    convenience init(restoreWindowPosition: Bool, clipboardPinActions: ClipboardPinActions, serviceContainer: ServiceContainer) {
        let mainFrame = AppWindowGeometry.defaultFrame
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: mainFrame.width, height: mainFrame.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = AcWorkBrand.displayName
        window.contentMinSize = AppWindowGeometry.minimumContentSize
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.managed, .moveToActiveSpace]
        if restoreWindowPosition {
            window.setFrameAutosaveName("MainWindow")
        }

        // 设置内容视图
        let contentView = ContentView(clipboardPinActions: clipboardPinActions)
            .environmentObject(AppState.shared)
            .environmentObject(serviceContainer)

        window.contentView = NSHostingView(rootView: contentView)

        self.init(window: window)

        setupWindowDelegate()
    }

    private func setupWindowDelegate() {
        window?.delegate = self
    }

    private func enforceInitialWindowSizeIfNeeded() {
        guard didEnforceInitialSize == false else { return }
        didEnforceInitialSize = true

        guard window != nil else { return }
        enforceMinimumContentSize()
    }

    func enforceMinimumContentSize() {
        guard let window else { return }
        let currentSize = window.contentLayoutRect.size
        let targetSize = AppWindowGeometry.clampedContentSize(for: currentSize)
        guard targetSize != currentSize else { return }
        window.setFrame(Self.frameRect(forContentSize: targetSize, origin: window.frame.origin, styleMask: window.styleMask), display: true)
    }

    func ensureVisibleOnScreenIfNeeded() {
        guard let window else { return }
        let frame = window.frame
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first
        let targetFrame = targetScreen?.visibleFrame ?? .zero
        guard targetFrame.intersects(frame) == false else {
            return
        }

        let centeredOrigin = NSPoint(
            x: targetFrame.midX - frame.width / 2,
            y: targetFrame.midY - frame.height / 2
        )
        window.setFrame(Self.frameRect(forContentSize: window.contentLayoutRect.size, origin: centeredOrigin, styleMask: window.styleMask), display: true)
    }

    static func frameRect(forContentSize contentSize: NSSize, origin: NSPoint, styleMask: NSWindow.StyleMask?) -> NSRect {
        let resolvedStyleMask = styleMask ?? [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        var frameRect = NSWindow.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize), styleMask: resolvedStyleMask)
        frameRect.origin = origin
        return frameRect
    }
}

extension MainWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        enforceInitialWindowSizeIfNeeded()
        AppState.shared.mainWindowDidBecomeKey()
    }

    func windowDidResignKey(_ notification: Notification) {
        AppState.shared.mainWindowDidResignKey()
    }

    func windowWillClose(_ notification: Notification) {
        AppState.shared.mainWindowDidClose()
    }
}

private extension AppDelegate {
    var shouldRestoreWindowPosition: Bool {
        SettingsLocalPreferences.loadOrDefault().restoreWindowPosition
    }
}

// MARK: - Capsule Window Controller

class CapsuleWindowController: NSWindowController {
    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 60),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )

        window.title = "\(AcWorkBrand.displayName) Capsule"
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // 设置内容视图
        let contentView = CapsuleContentView()
        window.contentView = NSHostingView(rootView: contentView)

        self.init(window: window)

        setupWindowDelegate()
    }

    private func setupWindowDelegate() {
        window?.delegate = self
    }
}

// MARK: - Launch Window Controller

class LaunchWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // 避免被占位窗清理器误判为“空白启动壳”
        window.title = "\(AcWorkBrand.displayName) 启动中"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .moveToActiveSpace]
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear

        let contentView = LaunchView()
            .environmentObject(AppState.shared)

        window.contentView = NSHostingView(rootView: contentView)
        window.center()

        self.init(window: window)
    }
}

// MARK: - Window Geometry

enum AppWindowGeometry {
    static let defaultFrame = NSRect(x: 120, y: 120, width: 1500, height: 920)
    static let minimumContentSize = NSSize(width: 1180, height: 720)
    static let launchFrame = NSRect(x: 220, y: 180, width: 460, height: 340)
    static let capsuleFrame = NSRect(x: 320, y: 260, width: 400, height: 60)

    static func clampedContentSize(for contentSize: NSSize) -> NSSize {
        NSSize(
            width: max(contentSize.width, minimumContentSize.width),
            height: max(contentSize.height, minimumContentSize.height)
        )
    }
}

struct AuditWindowFrame: Codable, Equatable {
    let width: Int
    let height: Int
}

struct AuditComponentFrame: Codable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

struct AuditRuntimeFrames: Codable, Equatable {
    let window: AuditWindowFrame
    let components: [AuditComponentFrame]
}

struct WorkbenchV2RuntimeLayoutSnapshot: Codable, Equatable {
    let name: String
    let window: AuditWindowFrame
    let components: [AuditComponentFrame]
}

struct WorkbenchV2RuntimeFrames: Codable, Equatable {
    let layouts: [WorkbenchV2RuntimeLayoutSnapshot]
}

struct WorkbenchV2CurrentFocusLayoutSnapshot: Codable, Equatable {
    let name: String
    let window: AuditWindowFrame
    let components: [AuditComponentFrame]
}

struct WorkbenchV2CurrentFocusFrames: Codable, Equatable {
    let layouts: [WorkbenchV2CurrentFocusLayoutSnapshot]
}

extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension CapsuleWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        AppState.shared.capsuleWindowDidClose()
    }
}

extension Notification.Name {
    static let acmindDeleteSourceItem = Notification.Name("AcMind.deleteSourceItem")
    static let acmindGlobalShortcutTriggered = Notification.Name("AcMind.globalShortcutTriggered")
}
