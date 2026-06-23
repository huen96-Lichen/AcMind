import SwiftUI
import AppKit
import ApplicationServices
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
    private var placeholderWindowPruneTask: Task<Void, Never>?
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

    private func configureTransparentWindow(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--settings-preview") {
            if let exportPath = settingsPreviewExportPath() {
                do {
                    try exportSettingsPreviewImage(to: exportPath)
                } catch {
                    logger.error("Failed to export settings preview: \(error.localizedDescription)", file: "AppDelegate")
                }
                NSApp.terminate(nil)
                return
            }
            showSettingsPreviewWindow()
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--acwork-export-screenshots") {
            print("[AcWorkExport] starting screenshot export")
            do {
                print("[AcWorkExport] building preview container")
                try exportAcWorkPhaseOneScreenshots(serviceContainer: ServiceContainer.preview())
                print("[AcWorkExport] screenshot export finished")
            } catch {
                logger.error("Failed to export AcWork screenshots: \(error.localizedDescription)", file: "AppDelegate")
                print("[AcWorkExport] export failed: \(error.localizedDescription)")
            }
            NSApp.terminate(nil)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--acwork-layout-audit") {
            print("[AcWorkAudit] starting layout audit export")
            do {
                try exportAcWorkLayoutAudit(serviceContainer: ServiceContainer.preview())
                print("[AcWorkAudit] layout audit export finished")
            } catch {
                logger.error("Failed to export AcWork layout audit: \(error.localizedDescription)", file: "AppDelegate")
                print("[AcWorkAudit] export failed: \(error.localizedDescription)")
            }
            NSApp.terminate(nil)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--acwork-workbench-v2-audit") {
            print("[AcWorkV2Audit] starting workbench V2 audit export")
            do {
                try exportWorkbenchV2LayoutAudit()
                print("[AcWorkV2Audit] workbench V2 audit export finished")
            } catch {
                logger.error("Failed to export Workbench V2 audit: \(error.localizedDescription)", file: "AppDelegate")
                print("[AcWorkV2Audit] export failed: \(error.localizedDescription)")
            }
            NSApp.terminate(nil)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--acwork-workbench-v2-background-verify") {
            print("[AcWorkV2Background] starting background persistence verification")
            do {
                try exportWorkbenchV2BackgroundVerification()
                print("[AcWorkV2Background] background persistence verification finished")
            } catch {
                logger.error("Failed to export Workbench V2 background verification: \(error.localizedDescription)", file: "AppDelegate")
                print("[AcWorkV2Background] export failed: \(error.localizedDescription)")
            }
            NSApp.terminate(nil)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--companion-six-pages-export") {
            print("[CompanionExport] starting companion export")
            do {
                try exportCompanionSixPageScreenshots(serviceContainer: ServiceContainer.preview())
                print("[CompanionExport] companion export finished")
            } catch {
                logger.error("Failed to export companion screenshots: \(error.localizedDescription)", file: "AppDelegate")
                print("[CompanionExport] export failed: \(error.localizedDescription)")
            }
            NSApp.terminate(nil)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--tool-workspace-preview") {
            showToolWorkspacePreviewWindow()
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--product-panel-preview") {
            showProductPanelPreviewWindow()
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--agent-preview") {
            showAgentPreviewWindow()
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--system-status-preview") {
            showSystemStatusPreviewWindow()
            return
        }
#endif
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        applyApplicationIcon()
        setupStatusBar()
        setupNotifications()

        // 初始化服务容器
        Task {
            do {
                let container = try await ServiceContainer.setup()
                await MainActor.run {
                    self.serviceContainer = container
                    self.appState.bindServiceContainerState(container)
                    self.connectCompanionPanels()
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
        case .agent:
            appState.navigate(to: .agent)
        case .schedule:
            appState.navigate(to: .schedule)
        case .systemStatus:
            appState.navigate(to: .systemStatus)
        case .settings:
            appState.navigate(to: .settings)
        }
    }

    private static func initialOpenRoute(from argument: String) -> InitialOpenRoute? {
        guard argument.hasPrefix("--acwork-open=") else { return nil }
        let value = String(argument.dropFirst("--acwork-open=".count))
        return InitialOpenRoute(rawValue: value)
    }

    private enum InitialOpenRoute: String {
        case home
        case inbox
        case agent
        case schedule
        case systemStatus
        case settings
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        placeholderWindowPruneTask?.cancel()
        placeholderWindowPruneTask = nil
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
        if mainWindowController == nil {
            mainWindowController = MainWindowController(
                restoreWindowPosition: shouldRestoreWindowPosition,
                clipboardPinActions: clipboardPinActions,
                serviceContainer: serviceContainer ?? ServiceContainer.preview()
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

    private func prunePlaceholderWindows() {
        let mainWindow = mainWindowController?.window
        let launchWindow = launchWindowController?.window

        for window in NSApp.windows {
            let title = window.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard window !== mainWindow, window !== launchWindow, window !== notchPanelController, window !== desktopCapsuleController else { continue }
            guard window.level < .statusBar else { continue }
            let isSmallLaunchShell = window.frame.width <= 520 && window.frame.height <= 420
            let isThinPlaceholder = window.frame.width >= 800 && window.frame.height <= 120
            let isBlankAuxiliaryWindow =
                title.isEmpty &&
                window.frame.width >= 500 && window.frame.width <= 540 &&
                window.frame.height >= 280 && window.frame.height <= 320
            let shouldClosePlaceholder =
                (title.isEmpty && isSmallLaunchShell) ||
                ([AcWorkBrand.displayName, AcWorkBrand.legacyInternalName].contains(title) && isSmallLaunchShell) ||
                ((title.isEmpty || [AcWorkBrand.displayName, AcWorkBrand.legacyInternalName].contains(title)) && isThinPlaceholder) ||
                isBlankAuxiliaryWindow
            guard shouldClosePlaceholder else { continue }
            window.orderOut(nil)
            window.close()
        }

        prunePlaceholderAXWindows()
    }

    private func prunePlaceholderAXWindows() {
        let appElement = AXUIElementCreateApplication(pid_t(ProcessInfo.processInfo.processIdentifier))
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }

        for window in windows {
            var titleValue: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let title = (titleValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            var sizeValue: CFTypeRef?
            let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
            var windowSize = CGSize.zero
            if sizeResult == .success, let sizeValue, CFGetTypeID(sizeValue) == AXValueGetTypeID() {
                let axValue = unsafeDowncast(sizeValue as AnyObject, to: AXValue.self)
                AXValueGetValue(axValue, .cgSize, &windowSize)
            }

            guard windowSize.width > 64 || windowSize.height > 64 else { continue }

            let isCompanionCollapsedWindow =
                windowSize.width >= CompanionMenuBarLayout.collapsedMinWidth &&
                windowSize.width <= CompanionMenuBarLayout.collapsedMaxWidth &&
                windowSize.height >= CompanionMenuBarLayout.collapsedMinHeight &&
                windowSize.height <= CompanionMenuBarLayout.collapsedMaxHeight
            let isDesktopCapsuleWindow = windowSize.width <= 60 && windowSize.height <= 60
            if isCompanionCollapsedWindow || isDesktopCapsuleWindow {
                continue
            }

            let isSmallLaunchShell = windowSize.width <= 520 && windowSize.height <= 420
            let isThinPlaceholder = windowSize.width >= 800 && windowSize.height <= 120
            let isBlankAuxiliaryWindow =
                title.isEmpty &&
                windowSize.width >= 500 && windowSize.width <= 540 &&
                windowSize.height >= 280 && windowSize.height <= 320
            let shouldClosePlaceholder =
                (title.isEmpty && isSmallLaunchShell) ||
                ([AcWorkBrand.displayName, AcWorkBrand.legacyInternalName].contains(title) && isSmallLaunchShell) ||
                ((title.isEmpty || [AcWorkBrand.displayName, AcWorkBrand.legacyInternalName].contains(title)) && isThinPlaceholder) ||
                isBlankAuxiliaryWindow
            guard shouldClosePlaceholder else { continue }

            if titleResult == .success || sizeResult == .success {
                var closeButtonValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButtonValue) == .success,
                   let closeButtonValue,
                   CFGetTypeID(closeButtonValue) == AXUIElementGetTypeID() {
                    let closeButton = unsafeDowncast(closeButtonValue as AnyObject, to: AXUIElement.self)
                    AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
                }
            }
        }
    }

    private func schedulePlaceholderWindowPrune() {
        guard placeholderWindowPruneTask == nil else { return }
        placeholderWindowPruneTask = Task { @MainActor in
            while isTerminating == false && Task.isCancelled == false {
                self.prunePlaceholderWindows()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
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
    private func settingsPreviewExportPath() -> String? {
        ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--settings-preview-export=") })
            .map { String($0.dropFirst("--settings-preview-export=".count)) }
    }

    private func settingsPreviewContentWidth() -> CGFloat {
        ProcessInfo.processInfo.arguments.contains("--settings-preview-narrow") ? 880 : 1280
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

    private func exportSettingsPreviewImage(to path: String) throws {
        let contentWidth = settingsPreviewContentWidth()
        let contentHeight: CGFloat = 900
        let hostingView = makeSettingsPreviewContentView(contentWidth: contentWidth, contentHeight: contentHeight)
        let bounds = hostingView.bounds
        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: bounds) else {
            throw NSError(domain: "SettingsPreviewExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap representation"])
        }
        hostingView.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SettingsPreviewExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG representation"])
        }
        try data.write(to: URL(fileURLWithPath: path))
    }

    private func showSettingsPreviewWindow() {
        let contentWidth = settingsPreviewContentWidth()
        let contentHeight: CGFloat = 900

        if settingsPreviewWindow == nil {
            let contentView = makeSettingsPreviewContentView(contentWidth: contentWidth, contentHeight: contentHeight)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings Preview"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            self.configureTransparentWindow(window)
            window.contentView = contentView
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            settingsPreviewWindow = window
        }
    }

    private func exportAcWorkPhaseOneScreenshots(serviceContainer: ServiceContainer) throws {
        let outputDirectory = URL(fileURLWithPath: "/Volumes/White Atlas/03_Projects/AcMind/docs/screenshots/acwork-phase1")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        print("[AcWorkExport] output directory ready: \(outputDirectory.path)")

        let appState = AppState.shared
        let pinActions = previewClipboardPinActions()
        let largeSize = NSSize(width: 1500, height: 920)
        let compactSize = NSSize(width: 1180, height: 720)

        if let single = screenshotExportSelection() {
            try exportSelectedScreenshot(
                single,
                outputDirectory: outputDirectory,
                largeSize: largeSize,
                compactSize: compactSize,
                appState: appState,
                serviceContainer: serviceContainer,
                pinActions: pinActions
            )
            return
        }

        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1500x920-workspace-populated.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1500x920-inbox-list.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1500x920-inbox-grid.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .inbox,
            viewMode: "grid"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1500x920-clipboard.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .clipboard,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1180x720-workspace.png"),
            size: compactSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1180x720-inbox.png"),
            size: compactSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1180x720-clipboard.png"),
            size: compactSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .clipboard,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("workspace-loading.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loading),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("workspace-empty.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .empty),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("workspace-error.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .error(message: "工作台加载失败")),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("inbox-loading.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .loading,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("inbox-empty.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .empty,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("inbox-error.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .error,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
    }

    private func exportAcWorkLayoutAudit(serviceContainer: ServiceContainer) throws {
        let outputDirectory = URL(fileURLWithPath: "/Volumes/White Atlas/03_Projects/AcMind/docs/audit")
        let screenshotsDirectory = outputDirectory.appendingPathComponent("screenshots")
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        print("[AcWorkAudit] output directory ready: \(outputDirectory.path)")

        let appState = AppState.shared
        let pinActions = previewClipboardPinActions()
        let sizes: [(name: String, size: NSSize)] = [
            ("min", AppWindowGeometry.minimumContentSize),
            ("default", AppWindowGeometry.defaultFrame.size),
            ("1440x960", NSSize(width: 1440, height: 960)),
            ("1728x1117", NSSize(width: 1728, height: 1117))
        ]

        var runtimeFrames = AuditRuntimeFrames(window: AuditWindowFrame(width: 1440, height: 960), components: [])

        for entry in sizes {
            let normalPath = screenshotsDirectory.appendingPathComponent("workbench-\(entry.name)-normal.png")
            let debugPath = screenshotsDirectory.appendingPathComponent("workbench-\(entry.name)-debug.png")

            try exportContentViewScreenshot(
                normalPath,
                size: entry.size,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil,
                showLayoutDebugOverlay: false
            )

            try exportContentViewScreenshot(
                debugPath,
                size: entry.size,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil,
                showLayoutDebugOverlay: true
            )

#if DEBUG
            if entry.name == "1440x960" {
                runtimeFrames = AuditRuntimeFrames(
                    window: AuditWindowFrame(width: Int(entry.size.width), height: Int(entry.size.height)),
                    components: LayoutDebugStore.shared.measurements.map {
                        AuditComponentFrame(
                            name: $0.name,
                            x: Int($0.frame.minX),
                            y: Int($0.frame.minY),
                            width: Int($0.frame.width),
                            height: Int($0.frame.height)
                        )
                    }
                )
            }
#endif
        }

#if DEBUG
        let jsonURL = outputDirectory.appendingPathComponent("AcWork_Workbench_Runtime_Frames.json")
        let data = try JSONEncoder.prettyPrinted.encode(runtimeFrames)
        try data.write(to: jsonURL)
        print("[AcWorkAudit] wrote \(jsonURL.path)")
#endif
    }

    private func screenshotExportSelection() -> String? {
        ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--acwork-export-screenshot=") })
            .map { String($0.dropFirst("--acwork-export-screenshot=".count)) }
    }

    private func exportSelectedScreenshot(
        _ selection: String,
        outputDirectory: URL,
        largeSize: NSSize,
        compactSize: NSSize,
        appState: AppState,
        serviceContainer: ServiceContainer,
        pinActions: ClipboardPinActions
    ) throws {
        switch selection {
        case "workspace-populated":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1500x920-workspace-populated.png"),
                size: largeSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil
            )
        case "inbox-list":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1500x920-inbox-list.png"),
                size: largeSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .inbox,
                viewMode: "list"
            )
        case "inbox-grid":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1500x920-inbox-grid.png"),
                size: largeSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .inbox,
                viewMode: "grid"
            )
        case "clipboard":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1500x920-clipboard.png"),
                size: largeSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .clipboard,
                viewMode: "list"
            )
        case "workspace":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1180x720-workspace.png"),
                size: compactSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil
            )
        case "inbox":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1180x720-inbox.png"),
                size: compactSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .inbox,
                viewMode: "list"
            )
        default:
            throw NSError(domain: "AcWorkScreenshotExport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown screenshot selection: \(selection)"])
        }
    }

    private struct CompanionScreenshotSpec {
        let page: NotchV2Page
        let fileName: String
        let title: String
    }

    private func exportCompanionSixPageScreenshots(serviceContainer: ServiceContainer) throws {
        let outputDirectory = URL(fileURLWithPath: "/Users/lichen/Desktop/AcMind/docs/screenshots/companion-unification")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        print("[CompanionExport] output directory ready: \(outputDirectory.path)")

        let specs: [CompanionScreenshotSpec] = [
            .init(page: .overview, fileName: "companion-local-880x300.png", title: "本机"),
            .init(page: .launcher, fileName: "companion-launcher-880x300.png", title: "启动器"),
            .init(page: .music, fileName: "companion-music-880x300.png", title: "音乐"),
            .init(page: .agent, fileName: "companion-ai-880x300.png", title: "AI"),
            .init(page: .systemStatus, fileName: "companion-status-880x300.png", title: "状态"),
            .init(page: .settings, fileName: "companion-settings-880x300.png", title: "设置")
        ]

        var exportedImages: [(title: String, image: NSImage)] = []

        for spec in specs {
            let image = try renderCompanionScreenshot(
                page: spec.page,
                serviceContainer: serviceContainer
            )
            let outputURL = outputDirectory.appendingPathComponent(spec.fileName)
            try write(image: image, to: outputURL)
            exportedImages.append((title: spec.title, image: image))
            print("[CompanionExport] wrote \(outputURL.lastPathComponent)")
        }

        let contactSheetURL = outputDirectory.appendingPathComponent("companion-six-pages-contact-sheet.png")
        let sheet = try composeContactSheet(images: exportedImages)
        try write(image: sheet, to: contactSheetURL)
        print("[CompanionExport] wrote \(contactSheetURL.lastPathComponent)")
    }

    private func renderCompanionScreenshot(page: NotchV2Page, serviceContainer: ServiceContainer) throws -> NSImage {
        let panelController = CompanionScreenshotPanelController()
        let viewModel = NotchV2ViewModel(
            panelController: panelController,
            batteryService: serviceContainer.batteryService,
            systemStatusService: serviceContainer.systemStatusService,
            systemEventCenter: serviceContainer.systemEventCenter,
            musicService: serviceContainer.musicService
        )
        viewModel.updateDisplaySettings { settings in
            settings.enabledDynamicModules = Set(DynamicContinentModuleID.allCases)
            settings.dynamicModuleOrder = DynamicContinentModuleID.allCases
            settings.overviewVisibleModules = Set(DynamicContinentModuleID.allCases)
            settings.collapsedVisibleContents = Set(CompanionRuntimeContentID.allCases)
            settings.collapsedVisibleContentOrder = CompanionRuntimeContentID.allCases
            settings.primarySurfaceContents = Set(CompanionRuntimeContentID.allCases)
            settings.primarySurfaceContentOrder = CompanionRuntimeContentID.allCases
            settings.enabledSystemEventKinds = Set(SystemEventKind.allCases)
        }
        viewModel.selectedPage = page
        viewModel.presentationState = .expanded
        viewModel.isExpanded = true

        let rootView = NotchV2RootView(viewModel: viewModel)
            .environmentObject(serviceContainer)
            .preferredColorScheme(.dark)
            .frame(
                width: CompanionLayoutTokens.expandedWindowWidth,
                height: CompanionLayoutTokens.expandedWindowHeight,
                alignment: .topLeading
            )

        let hostingView = NSHostingView(rootView: AnyView(rootView))
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: CompanionLayoutTokens.expandedWindowWidth, height: CompanionLayoutTokens.expandedWindowHeight)
        )
        hostingView.layoutSubtreeIfNeeded()
        return try renderImage(from: hostingView)
    }

    private func renderImage(from hostingView: NSHostingView<AnyView>) throws -> NSImage {
        let bounds = hostingView.bounds
        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: bounds) else {
            throw NSError(domain: "CompanionExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap representation"])
        }
        hostingView.cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    private func write(image: NSImage, to url: URL) throws {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "CompanionExport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
        }
        try data.write(to: url)
    }

    private func composeContactSheet(images: [(title: String, image: NSImage)]) throws -> NSImage {
        let columns = 3
        let rows = 2
        let tileWidth: CGFloat = CompanionLayoutTokens.expandedWindowWidth
        let tileHeight: CGFloat = CompanionLayoutTokens.expandedWindowHeight
        let titleBandHeight: CGFloat = 24
        let padding: CGFloat = 16
        let gutter: CGFloat = 14
        let sheetWidth = padding * 2 + CGFloat(columns) * tileWidth + CGFloat(columns - 1) * gutter
        let sheetHeight = padding * 2 + CGFloat(rows) * (tileHeight + titleBandHeight) + CGFloat(rows - 1) * gutter
        let canvas = NSImage(size: NSSize(width: sheetWidth, height: sheetHeight))

        canvas.lockFocus()
        defer { canvas.unlockFocus() }

        NSColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight)).fill()

        let titleFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let labelFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        let labelColor = NSColor.white.withAlphaComponent(0.88)

        for (index, item) in images.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = padding + CGFloat(column) * (tileWidth + gutter)
            let y = sheetHeight - padding - CGFloat(row + 1) * (tileHeight + titleBandHeight) - CGFloat(row) * gutter

            let labelRect = NSRect(x: x, y: y + tileHeight + 4, width: tileWidth, height: 18)
            let labelStyle = NSMutableParagraphStyle()
            labelStyle.alignment = .left
            let attributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: labelColor,
                .paragraphStyle: labelStyle
            ]
            item.title.draw(in: labelRect, withAttributes: attributes)

            let imageRect = NSRect(x: x, y: y, width: tileWidth, height: tileHeight)
            item.image.draw(in: imageRect)

            let captionRect = NSRect(x: x, y: y + tileHeight - 18, width: tileWidth, height: 16)
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: NSColor.white.withAlphaComponent(0.6)
            ]
            "880 × 300".draw(in: captionRect, withAttributes: captionAttributes)
        }

        return canvas
    }

    @MainActor
    private final class CompanionScreenshotPanelController: NotchPanelControlling {
        func hide() {}
        func showCompact(on screen: NSScreen?) {}
    }

    private func exportContentViewScreenshot(
        _ path: URL,
        size: NSSize,
        appState: AppState,
        container: ServiceContainer,
        pinActions: ClipboardPinActions,
        workspaceRepository: any WorkspaceDashboardRepositoryProtocol,
        inboxScenario: AcWorkPreviewScenario,
        sidebarSelection: SidebarItem,
        viewMode: String?,
        showLayoutDebugOverlay: Bool = false
    ) throws {
        appState.sidebarSelection = sidebarSelection
        appState.sidebarCollapsed = false
        appState.isAppReady = true
        appState.initializationPhase = .completed
        appState.mainWindowState = .normal
        appState.inboxWorkspaceSelection = "all"
        print("[AcWorkExport] rendering \(path.lastPathComponent) at \(Int(size.width))x\(Int(size.height))")

        let defaults = UserDefaults.standard
        defaults.set(viewMode ?? "grid", forKey: "acwork.inbox.viewMode")
        defaults.set("standard", forKey: "acwork.inbox.density")

        let rootView = ContentView(
            clipboardPinActions: pinActions,
            workspaceDashboardRepository: workspaceRepository,
            inboxPreviewScenario: inboxScenario
        )
        .environmentObject(appState)
        .environmentObject(container)
        .preferredColorScheme(.light)

        #if DEBUG
        LayoutDebugStore.shared.isOverlayVisible = showLayoutDebugOverlay
        defer { LayoutDebugStore.shared.isOverlayVisible = false }
        #endif

        let hostingView = NSHostingView(rootView: AnyView(rootView))
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw NSError(domain: "AcWorkScreenshotExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap representation"])
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AcWorkScreenshotExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG representation"])
        }
        try data.write(to: path)
        print("[AcWorkExport] wrote \(path.lastPathComponent)")
    }

    private func exportWorkbenchV2LayoutAudit() throws {
        let outputDirectory = URL(fileURLWithPath: "/Volumes/White Atlas/03_Projects/AcMind/docs/refactor/workbench-v17")
        let screenshotsDirectory = outputDirectory.appendingPathComponent("screenshots")
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        print("[AcWorkV2Audit] output directory ready: \(outputDirectory.path)")

        let selectedBackgroundURL = URL(fileURLWithPath: "/Volumes/White Atlas/03_Projects/AcMind/临时/DSCF0251.jpg")
        guard FileManager.default.fileExists(atPath: selectedBackgroundURL.path) else {
            throw NSError(domain: "AcWorkWorkbenchV2Audit", code: 20, userInfo: [NSLocalizedDescriptionKey: "Missing hero background image at \(selectedBackgroundURL.path)"])
        }
        let heroBackgroundStore = WorkbenchV2HeroBackgroundStore()
        heroBackgroundStore.resetToDefaultBackground()

        let layouts: [(name: String, size: NSSize, data: WorkbenchV2MockData)] = [
            ("default", NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight), .preview()),
            ("compact", NSSize(width: WorkbenchV2Metrics.minimumWindowWidth, height: WorkbenchV2Metrics.minimumWindowHeight), .compactWarning())
        ]

        var snapshots: [WorkbenchV2RuntimeLayoutSnapshot] = []
        var currentFocusSnapshots: [WorkbenchV2CurrentFocusLayoutSnapshot] = []
        var validationSummaries: [String] = []
        var currentFocusValidationSummaries: [String] = []
        var defaultCurrentFocusFrame: AuditComponentFrame?
        var pixelValidationSummaries: [String] = []

        let beforeBackgroundPath = screenshotsDirectory.appendingPathComponent("background-before-1500x888.png")
        try exportStandaloneViewScreenshot(
            beforeBackgroundPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight),
            showLayoutDebugOverlay: false
        ) {
            WorkbenchV2View(
                mockData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: heroBackgroundStore
            )
        }

        try heroBackgroundStore.setBackground(from: selectedBackgroundURL)
        let afterBackgroundPath = screenshotsDirectory.appendingPathComponent("background-after-1500x888.png")
        try exportStandaloneViewScreenshot(
            afterBackgroundPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight),
            showLayoutDebugOverlay: false
        ) {
            WorkbenchV2View(
                mockData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: heroBackgroundStore
            )
        }

        for entry in layouts {
            #if DEBUG
            LayoutDebugStore.shared.update([])
            #endif

            let normalPath = screenshotsDirectory.appendingPathComponent("swiftui-\(Int(entry.size.width))x\(Int(entry.size.height)).png")
            let debugPath = screenshotsDirectory.appendingPathComponent("swiftui-\(Int(entry.size.width))x\(Int(entry.size.height))-debug.png")

#if DEBUG
            LayoutDebugStore.shared.update([])
#endif
            try exportStandaloneViewScreenshot(
                normalPath,
                size: entry.size,
                showLayoutDebugOverlay: false
            ) {
                WorkbenchV2View(
                    mockData: entry.data,
                    debugOverlayEnabled: true,
                    heroBackgroundStore: heroBackgroundStore
                )
            }

#if DEBUG
            LayoutDebugStore.shared.update([])
#endif
            try exportStandaloneViewScreenshot(
                debugPath,
                size: entry.size,
                showLayoutDebugOverlay: true
            ) {
                WorkbenchV2View(
                    mockData: entry.data,
                    debugOverlayEnabled: true,
                    heroBackgroundStore: heroBackgroundStore
                )
            }

#if DEBUG
            let frames = LayoutDebugStore.shared.measurements.map {
                AuditComponentFrame(
                    name: $0.name,
                    x: Int($0.frame.minX),
                    y: Int($0.frame.minY),
                    width: Int($0.frame.width),
                    height: Int($0.frame.height)
                )
            }
            let validation = try validateWorkbenchV2Frames(
                layoutName: entry.name,
                frames: frames,
                contentSize: entry.size
            )
            print("[AcWorkV2Audit] validation result for \(entry.name):\n\(validation)")
            validationSummaries.append(validation)
            let currentFocusFrames = frames.filter { $0.name.hasPrefix("CurrentFocus") }
            if let cardFrame = frames.first(where: { $0.name == "CurrentFocusCard" }) {
                if entry.name == "default" {
                    defaultCurrentFocusFrame = cardFrame
                }
                let currentFocusValidation = try validateCurrentFocusFrames(
                    layoutName: entry.name,
                    cardFrame: cardFrame,
                    frames: currentFocusFrames,
                    contentSize: entry.size
                )
                print("[AcWorkV2Audit] current focus validation result for \(entry.name):\n\(currentFocusValidation)")
                currentFocusValidationSummaries.append(currentFocusValidation)
            }
            currentFocusSnapshots.append(
                WorkbenchV2CurrentFocusLayoutSnapshot(
                    name: entry.name,
                    window: AuditWindowFrame(width: Int(entry.size.width), height: Int(entry.size.height)),
                    components: currentFocusFrames
                )
            )
            snapshots.append(
                WorkbenchV2RuntimeLayoutSnapshot(
                    name: entry.name,
                    window: AuditWindowFrame(width: Int(entry.size.width), height: Int(entry.size.height)),
                    components: frames
                )
            )
#endif
        }

        let restoredStore = WorkbenchV2HeroBackgroundStore()
        let restoredBackgroundPath = screenshotsDirectory.appendingPathComponent("background-restored-1500x888.png")
        try exportStandaloneViewScreenshot(
            restoredBackgroundPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight),
            showLayoutDebugOverlay: false
        ) {
            WorkbenchV2View(
                mockData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: restoredStore
            )
        }

        let persistedBackgroundPath = restoredStore.backgroundPath
        if persistedBackgroundPath.isEmpty == false {
            try? FileManager.default.removeItem(atPath: persistedBackgroundPath)
        }
        let fallbackStore = WorkbenchV2HeroBackgroundStore()
        let fallbackBackgroundPath = screenshotsDirectory.appendingPathComponent("background-fallback-1500x888.png")
        try exportStandaloneViewScreenshot(
            fallbackBackgroundPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight),
            showLayoutDebugOverlay: false
        ) {
            WorkbenchV2View(
                mockData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: fallbackStore
            )
        }

#if DEBUG
        if let defaultCurrentFocusFrame {
            let pixelValidation = try validateWorkbenchV2BackgroundPixels(
                cardFrame: defaultCurrentFocusFrame,
                baselinePath: beforeBackgroundPath,
                comparisonPaths: [
                    afterBackgroundPath,
                    restoredBackgroundPath,
                    fallbackBackgroundPath
                ]
            )
            print("[AcWorkV2Audit] background pixel validation result:\n\(pixelValidation)")
            pixelValidationSummaries.append(pixelValidation)
        }

        let jsonURL = outputDirectory.appendingPathComponent("WorkbenchV17_Frames.json")
        let data = try JSONEncoder.prettyPrinted.encode(WorkbenchV2RuntimeFrames(layouts: snapshots))
        try data.write(to: jsonURL)
        print("[AcWorkV2Audit] wrote \(jsonURL.path)")

        let currentFocusJSONURL = outputDirectory.appendingPathComponent("WorkbenchV17_CurrentFocus_Frames.json")
        let currentFocusData = try JSONEncoder.prettyPrinted.encode(WorkbenchV2CurrentFocusFrames(layouts: currentFocusSnapshots))
        try currentFocusData.write(to: currentFocusJSONURL)
        print("[AcWorkV2Audit] wrote \(currentFocusJSONURL.path)")

        let validationURL = outputDirectory.appendingPathComponent("WorkbenchV17_Validation.txt")
        let validationReport = (validationSummaries + currentFocusValidationSummaries + pixelValidationSummaries).joined(separator: "\n\n")
        try validationReport.write(to: validationURL, atomically: true, encoding: .utf8)
        print("[AcWorkV2Audit] wrote \(validationURL.path)")
#endif
    }

    private func exportWorkbenchV2BackgroundVerification() throws {
        let outputDirectory = URL(fileURLWithPath: "/Volumes/White Atlas/03_Projects/AcMind/docs/refactor/workbench-v17")
        let screenshotsDirectory = outputDirectory.appendingPathComponent("screenshots")
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)

        let selectedBackgroundURL = URL(fileURLWithPath: "/Volumes/White Atlas/03_Projects/AcMind/临时/DSCF0251.jpg")
        guard FileManager.default.fileExists(atPath: selectedBackgroundURL.path) else {
            throw NSError(domain: "AcWorkWorkbenchV2BackgroundVerification", code: 20, userInfo: [NSLocalizedDescriptionKey: "Missing hero background image at \(selectedBackgroundURL.path)"])
        }

        let stage = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--acwork-workbench-v2-background-stage=") })
        let stageValue = stage.flatMap { String($0.dropFirst("--acwork-workbench-v2-background-stage=".count)) } ?? "restore"

        let heroBackgroundStore = WorkbenchV2HeroBackgroundStore()
        if stageValue == "seed" {
            heroBackgroundStore.resetToDefaultBackground()
            try heroBackgroundStore.setBackground(from: selectedBackgroundURL)
        }

        let exportedName: String
        switch stageValue {
        case "seed":
            exportedName = "background-selected-1500x888.png"
        case "fallback":
            exportedName = "background-fallback-1500x888.png"
        default:
            exportedName = "background-restored-1500x888.png"
        }

        let exportPath = screenshotsDirectory.appendingPathComponent(exportedName)
        try exportStandaloneViewScreenshot(
            exportPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight),
            showLayoutDebugOverlay: false
        ) {
            WorkbenchV2View(
                mockData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: heroBackgroundStore
            )
        }

        let reportURL = outputDirectory.appendingPathComponent("WorkbenchV17_BackgroundPersistence.txt")
        let persistedPath = heroBackgroundStore.backgroundPath.isEmpty ? "(empty)" : heroBackgroundStore.backgroundPath
        let fileExists = heroBackgroundStore.backgroundPath.isEmpty == false && FileManager.default.fileExists(atPath: heroBackgroundStore.backgroundPath)
        let fallbackBehavior = fileExists ? "restored selected background" : "fell back to generated default background"
        let report = [
            "[background verification]",
            "stage=\(stageValue)",
            "userDefaultsKey=WorkbenchV2.heroBackgroundPath",
            "persistedPath=\(persistedPath)",
            "fileExists=\(fileExists)",
            "fallbackBehavior=\(fallbackBehavior)",
            "selectedBackgroundSource=\(selectedBackgroundURL.path)"
        ].joined(separator: "\n")
        try report.write(to: reportURL, atomically: true, encoding: .utf8)
        print("[AcWorkV2Background] wrote \(exportPath.lastPathComponent)")
        print("[AcWorkV2Background] wrote \(reportURL.path)")
        print("[AcWorkV2Background] persistedPath=\(persistedPath)")
        print("[AcWorkV2Background] fallbackBehavior=\(fallbackBehavior)")
    }

    private func exportStandaloneViewScreenshot<V: View>(
        _ path: URL,
        size: NSSize,
        showLayoutDebugOverlay: Bool = false,
        @ViewBuilder rootView: () -> V
    ) throws {
#if DEBUG
        LayoutDebugStore.shared.isOverlayVisible = showLayoutDebugOverlay
        defer { LayoutDebugStore.shared.isOverlayVisible = false }
#endif

        let hostingView = NSHostingView(rootView: AnyView(rootView().preferredColorScheme(.light)))
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw NSError(domain: "AcWorkScreenshotExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap representation"])
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AcWorkScreenshotExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG representation"])
        }
        try data.write(to: path)
        print("[AcWorkV2Audit] wrote \(path.lastPathComponent)")
    }

    #if DEBUG
    private func validateWorkbenchV2Frames(
        layoutName: String,
        frames: [AuditComponentFrame],
        contentSize: NSSize
    ) throws -> String {
        let trackedOrder: [String] = [
            "WorkbenchHeader",
            "CurrentFocusCard",
            "TodayOverviewPanel",
            "PendingItemsCard",
            "RecentCollectionCard",
            "QuickActionsCard",
            "ActivityTrendCard",
            "DeviceStatusBar"
        ]
        let trackedFrames = trackedOrder.compactMap { name in
            frames.first(where: { $0.name == name })
        }
        let missingNames = trackedOrder.filter { name in frames.contains(where: { $0.name == name }) == false }
        if missingNames.isEmpty == false {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): missing tracked frames: \(missingNames.joined(separator: ", "))"]
            )
        }
        let duplicates = Dictionary(grouping: trackedFrames, by: \.name).filter { $1.count > 1 }
        if duplicates.isEmpty == false {
            let duplicateList = duplicates.keys.sorted().joined(separator: ", ")
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): duplicated tracked frames: \(duplicateList)"]
            )
        }

        func rect(for frame: AuditComponentFrame) -> CGRect {
            CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
        }

        var reportLines: [String] = ["[\(layoutName)] frame audit"]
        var violations: [String] = []

        for frame in trackedFrames {
            let frameRect = rect(for: frame)
            let boundsOk = frameRect.maxX <= contentSize.width && frameRect.maxY <= contentSize.height
            if boundsOk == false {
                violations.append("\(frame.name) exceeds bounds \(Int(contentSize.width))x\(Int(contentSize.height))")
            }
            reportLines.append(
                "\(frame.name): x=\(frame.x) y=\(frame.y) w=\(frame.width) h=\(frame.height) maxX=\(Int(frameRect.maxX)) maxY=\(Int(frameRect.maxY)) bounds=\(boundsOk ? "PASS" : "FAIL")"
            )
        }

        for lhsIndex in trackedFrames.indices {
            let lhs = trackedFrames[lhsIndex]
            let lhsRect = rect(for: lhs)
            guard lhsIndex + 1 < trackedFrames.count else { continue }
            for rhsIndex in (lhsIndex + 1)..<trackedFrames.count {
                let rhs = trackedFrames[rhsIndex]
                let rhsRect = rect(for: rhs)
                let intersection = lhsRect.intersection(rhsRect)
                let intersects = lhsRect.intersects(rhsRect)
                let pairName = "\(lhs.name) × \(rhs.name)"
                let intersectionText = intersection.isNull
                    ? "null"
                    : "x=\(Int(intersection.minX)) y=\(Int(intersection.minY)) w=\(Int(intersection.width)) h=\(Int(intersection.height))"
                reportLines.append("\(pairName): \(intersects ? "FAIL" : "PASS")")
                reportLines.append("  A: x=\(lhs.x) y=\(lhs.y) w=\(lhs.width) h=\(lhs.height)")
                reportLines.append("  B: x=\(rhs.x) y=\(rhs.y) w=\(rhs.width) h=\(rhs.height)")
                reportLines.append("  intersection: \(intersectionText)")
                if intersects {
                    violations.append("\(pairName) intersects")
                }
            }
        }

        let today = trackedFrames.first(where: { $0.name == "TodayOverviewPanel" })
        let quick = trackedFrames.first(where: { $0.name == "QuickActionsCard" })
        let trend = trackedFrames.first(where: { $0.name == "ActivityTrendCard" })
        let footer = trackedFrames.first(where: { $0.name == "DeviceStatusBar" })
        let currentFocus = trackedFrames.first(where: { $0.name == "CurrentFocusCard" })
        let pending = trackedFrames.first(where: { $0.name == "PendingItemsCard" })
        let recent = trackedFrames.first(where: { $0.name == "RecentCollectionCard" })

        if let today, let quick, rect(for: today).maxY > rect(for: quick).minY {
            violations.append("TodayOverviewPanel.maxY exceeds QuickActionsCard.minY")
        }
        if let trend, let footer, rect(for: trend).maxY > rect(for: footer).minY {
            violations.append("ActivityTrendCard.maxY exceeds DeviceStatusBar.minY")
        }
        if let quick, let footer, rect(for: quick).maxY > rect(for: footer).minY {
            violations.append("QuickActionsCard.maxY exceeds DeviceStatusBar.minY")
        }
        if let trend, let quick {
            let sameThirdRowY = trend.y == quick.y
            let sameThirdRowHeight = trend.height == quick.height
            let sameThirdRowBottom = trend.y + trend.height == quick.y + quick.height
            reportLines.append("[\(layoutName)] third row alignment audit")
            reportLines.append("ActivityTrendCard.y == QuickActionsCard.y: \(trend.y) / \(quick.y) \(sameThirdRowY ? "PASS" : "FAIL")")
            reportLines.append("ActivityTrendCard.height == QuickActionsCard.height: \(trend.height) / \(quick.height) \(sameThirdRowHeight ? "PASS" : "FAIL")")
            reportLines.append("ActivityTrendCard.maxY == QuickActionsCard.maxY: \(trend.y + trend.height) / \(quick.y + quick.height) \(sameThirdRowBottom ? "PASS" : "FAIL")")
            if sameThirdRowY == false {
                violations.append("ActivityTrendCard and QuickActionsCard do not start on the same third row")
            }
            if sameThirdRowHeight == false {
                violations.append("ActivityTrendCard and QuickActionsCard heights differ")
            }
            if sameThirdRowBottom == false {
                violations.append("ActivityTrendCard and QuickActionsCard bottom edges differ")
            }
        }

        let minimumGap = Int(WorkbenchV2Tokens.Layout.dashboardRowGap)
        let spacingChecks: [(String, AuditComponentFrame?, AuditComponentFrame?)] = [
            ("ActivityTrendCard.minY - PendingItemsCard.maxY", pending, trend),
            ("ActivityTrendCard.minY - RecentCollectionCard.maxY", recent, trend),
            ("QuickActionsCard.minY - TodayOverviewPanel.maxY", today, quick),
            ("DeviceStatusBar.minY - ActivityTrendCard.maxY", trend, footer),
            ("DeviceStatusBar.minY - QuickActionsCard.maxY", quick, footer)
        ]
        reportLines.append("[\(layoutName)] spacing audit minimum=\(minimumGap)")
        for check in spacingChecks {
            guard let upper = check.1, let lower = check.2 else {
                violations.append("\(check.0) missing frames")
                continue
            }
            let actualGap = lower.y - (upper.y + upper.height)
            let passes = actualGap >= minimumGap
            reportLines.append("\(check.0): \(actualGap) \(passes ? "PASS" : "FAIL")")
            if passes == false {
                violations.append("\(check.0) is \(actualGap), expected >= \(minimumGap)")
            }
        }

        let exactGap = Int(WorkbenchV2Tokens.Layout.dashboardRowGap)
        let gridGapChecks: [(String, AuditComponentFrame?, AuditComponentFrame?, (AuditComponentFrame, AuditComponentFrame) -> Int)] = [
            ("CurrentFocusCard.right -> TodayOverviewPanel.left", currentFocus, today, { left, right in right.x - (left.x + left.width) }),
            ("PendingItemsCard.right -> RecentCollectionCard.left", pending, recent, { left, right in right.x - (left.x + left.width) }),
            ("ActivityTrendCard.right -> QuickActionsCard.left", trend, quick, { left, right in right.x - (left.x + left.width) }),
            ("CurrentFocusCard.bottom -> PendingItemsCard.top", currentFocus, pending, { upper, lower in lower.y - (upper.y + upper.height) }),
            ("CurrentFocusCard.bottom -> RecentCollectionCard.top", currentFocus, recent, { upper, lower in lower.y - (upper.y + upper.height) }),
            ("PendingItemsCard.bottom -> ActivityTrendCard.top", pending, trend, { upper, lower in lower.y - (upper.y + upper.height) }),
            ("RecentCollectionCard.bottom -> ActivityTrendCard.top", recent, trend, { upper, lower in lower.y - (upper.y + upper.height) }),
            ("TodayOverviewPanel.bottom -> QuickActionsCard.top", today, quick, { upper, lower in lower.y - (upper.y + upper.height) })
        ]
        reportLines.append("[\(layoutName)] six-card grid gutter audit expected=\(exactGap)")
        for check in gridGapChecks {
            guard let first = check.1, let second = check.2 else {
                violations.append("\(check.0) missing frames")
                continue
            }
            let actualGap = check.3(first, second)
            let passes = actualGap == exactGap
            reportLines.append("\(check.0): \(actualGap) \(passes ? "PASS" : "FAIL")")
            if passes == false {
                violations.append("\(check.0) is \(actualGap), expected \(exactGap)")
            }
        }

        let gridAlignmentChecks: [(String, Bool)] = [
            (
                "CurrentFocusCard.y == TodayOverviewPanel.y",
                currentFocus.flatMap { focus in today.map { focus.y == $0.y } } ?? false
            ),
            (
                "PendingItemsCard.y == RecentCollectionCard.y",
                pending.flatMap { pending in recent.map { pending.y == $0.y } } ?? false
            ),
            (
                "ActivityTrendCard.y == QuickActionsCard.y",
                trend.flatMap { trend in quick.map { trend.y == $0.y } } ?? false
            ),
            (
                "PendingItemsCard.maxY == RecentCollectionCard.maxY",
                pending.flatMap { pending in recent.map { pending.y + pending.height == $0.y + $0.height } } ?? false
            ),
            (
                "ActivityTrendCard.maxY == QuickActionsCard.maxY",
                trend.flatMap { trend in quick.map { trend.y + trend.height == $0.y + $0.height } } ?? false
            )
        ]
        reportLines.append("[\(layoutName)] six-card grid alignment audit")
        for check in gridAlignmentChecks {
            reportLines.append("\(check.0): \(check.1 ? "PASS" : "FAIL")")
            if check.1 == false {
                violations.append("\(check.0) failed")
            }
        }

        if violations.isEmpty == false {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): " + violations.joined(separator: "; ")]
            )
        }

        let footerCheck = footer.map { $0.y + $0.height <= Int(contentSize.height) } ?? true
        if footerCheck == false {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 12,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): DeviceStatusBar.maxY exceeds content height"]
            )
        }

        return reportLines.joined(separator: "\n")
    }

    private func validateCurrentFocusFrames(
        layoutName: String,
        cardFrame: AuditComponentFrame,
        frames: [AuditComponentFrame],
        contentSize: NSSize
    ) throws -> String {
        let trackedOrder = [
            "CurrentFocusBackground",
            "CurrentFocusContent",
            "CurrentFocusMetrics",
            "CurrentFocusActions"
        ]
        let cardRect = CGRect(x: cardFrame.x, y: cardFrame.y, width: cardFrame.width, height: cardFrame.height)
        let namedFrames = trackedOrder.compactMap { name in
            frames.first(where: { $0.name == name })
        }

        if namedFrames.count != trackedOrder.count {
            let missing = trackedOrder.filter { name in frames.contains(where: { $0.name == name }) == false }
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 21,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): missing current focus frames: \(missing.joined(separator: ", "))"]
            )
        }

        var reportLines: [String] = ["[\(layoutName)] current focus internal audit"]
        var violations: [String] = []

        for frame in namedFrames {
            let rect = CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
            let boundsOk = rect.minX >= cardRect.minX
                && rect.maxX <= cardRect.maxX
                && rect.minY >= cardRect.minY
                && rect.maxY <= cardRect.maxY
                && rect.maxX <= contentSize.width
                && rect.maxY <= contentSize.height
            reportLines.append(
                "\(frame.name): x=\(frame.x) y=\(frame.y) w=\(frame.width) h=\(frame.height) maxX=\(Int(rect.maxX)) maxY=\(Int(rect.maxY)) bounds=\(boundsOk ? "PASS" : "FAIL")"
            )
            if boundsOk == false {
                violations.append("\(frame.name) exceeds CurrentFocusCard bounds")
            }
        }

        if let actions = namedFrames.first(where: { $0.name == "CurrentFocusActions" }) {
            let actionsRect = CGRect(x: actions.x, y: actions.y, width: actions.width, height: actions.height)
            if actionsRect.maxY > cardRect.maxY - 1 {
                violations.append("CurrentFocusActions.maxY exceeds CurrentFocusCard.maxY")
            }
        }

        if let background = namedFrames.first(where: { $0.name == "CurrentFocusBackground" }) {
            let backgroundRect = CGRect(x: background.x, y: background.y, width: background.width, height: background.height)
            if backgroundRect.minX < cardRect.minX
                || backgroundRect.minY < cardRect.minY
                || backgroundRect.maxX > cardRect.maxX
                || backgroundRect.maxY > cardRect.maxY {
                violations.append("CurrentFocusBackground exceeds CurrentFocusCard bounds")
            }
        }

        if violations.isEmpty == false {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 22,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): " + violations.joined(separator: "; ")]
            )
        }

        return reportLines.joined(separator: "\n")
    }

    private func validateWorkbenchV2BackgroundPixels(
        cardFrame: AuditComponentFrame,
        baselinePath: URL,
        comparisonPaths: [URL]
    ) throws -> String {
        let cardRect = CGRect(
            x: cardFrame.x,
            y: cardFrame.y,
            width: cardFrame.width,
            height: cardFrame.height
        )
        guard let baselineBitmap = bitmapImageRep(from: baselinePath) else {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 30,
                userInfo: [NSLocalizedDescriptionKey: "Unable to read baseline screenshot \(baselinePath.path)"]
            )
        }

        var reportLines: [String] = ["[background] pixel audit"]
        reportLines.append("CurrentFocusCard: x=\(cardFrame.x) y=\(cardFrame.y) w=\(cardFrame.width) h=\(cardFrame.height)")

        for path in comparisonPaths {
            guard let comparisonBitmap = bitmapImageRep(from: path) else {
                throw NSError(
                    domain: "AcWorkWorkbenchV2Audit",
                    code: 31,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to read comparison screenshot \(path.path)"]
                )
            }

            let result = comparePixelsOutsideCard(
                baseline: baselineBitmap,
                comparison: comparisonBitmap,
                cardRect: cardRect
            )
            let status = result.changedPixels == 0 ? "PASS" : "FAIL"
            reportLines.append("\(path.lastPathComponent): \(status) outsideChangedPixels=\(result.changedPixels) sampledPixels=\(result.sampledPixels)")
            if result.changedPixels > 0 {
                throw NSError(
                    domain: "AcWorkWorkbenchV2Audit",
                    code: 32,
                    userInfo: [NSLocalizedDescriptionKey: "\(path.lastPathComponent): background pixels changed outside CurrentFocusCard"]
                )
            }
        }

        return reportLines.joined(separator: "\n")
    }

    private func bitmapImageRep(from path: URL) -> NSBitmapImageRep? {
        guard let image = NSImage(contentsOf: path),
              let tiffData = image.tiffRepresentation else {
            return nil
        }
        return NSBitmapImageRep(data: tiffData)
    }

    private func comparePixelsOutsideCard(
        baseline: NSBitmapImageRep,
        comparison: NSBitmapImageRep,
        cardRect: CGRect
    ) -> (changedPixels: Int, sampledPixels: Int) {
        let width = min(baseline.pixelsWide, comparison.pixelsWide)
        let height = min(baseline.pixelsHigh, comparison.pixelsHigh)
        let scaleX = CGFloat(width) / CGFloat(WorkbenchV2Metrics.defaultContentWidth)
        let scaleY = CGFloat(height) / CGFloat(WorkbenchV2Metrics.defaultContentHeight)
        let pixelCardRect = CGRect(
            x: cardRect.minX * scaleX,
            y: cardRect.minY * scaleY,
            width: cardRect.width * scaleX,
            height: cardRect.height * scaleY
        ).insetBy(dx: -2, dy: -2)

        var changedPixels = 0
        var sampledPixels = 0
        for y in 0..<height {
            for x in 0..<width {
                if pixelCardRect.contains(CGPoint(x: x, y: y)) {
                    continue
                }

                sampledPixels += 1
                guard let baselineColor = baseline.colorAt(x: x, y: y),
                      let comparisonColor = comparison.colorAt(x: x, y: y) else {
                    continue
                }

                let delta = abs(baselineColor.redComponent - comparisonColor.redComponent)
                    + abs(baselineColor.greenComponent - comparisonColor.greenComponent)
                    + abs(baselineColor.blueComponent - comparisonColor.blueComponent)
                    + abs(baselineColor.alphaComponent - comparisonColor.alphaComponent)
                if delta > 0.1 {
                    changedPixels += 1
                }
            }
        }

        return (changedPixels, sampledPixels)
    }
    #endif

    private func previewClipboardPinActions() -> ClipboardPinActions {
        ClipboardPinActions(
            showItem: { _ in },
            showAll: {},
            hideAll: {},
            closeAll: {},
            copyDiagnostics: {}
        )
    }

    private func showToolWorkspacePreviewWindow() {
        let isNarrowPreview = ProcessInfo.processInfo.arguments.contains("--tool-workspace-preview-narrow")
        let contentWidth: CGFloat = isNarrowPreview ? 880 : 1280
        let contentHeight: CGFloat = isNarrowPreview ? 1180 : 980

        if toolWorkspacePreviewWindow == nil {
            let contentView = NSHostingView(
                rootView: ToolWorkspacePreviewRoot()
                    .preferredColorScheme(.dark)
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Tool Workspace Preview"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            self.configureTransparentWindow(window)
            window.contentView = contentView
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            toolWorkspacePreviewWindow = window
        }
    }

    private func showProductPanelPreviewWindow() {
        let isNarrowPreview = ProcessInfo.processInfo.arguments.contains("--product-panel-preview-narrow")
        let contentWidth = isNarrowPreview ? ProductPanelTokens.Layout.narrowWidth : ProductPanelTokens.Layout.defaultWidth
        let contentHeight: CGFloat = isNarrowPreview ? 960 : 900

        if productPanelPreviewWindow == nil {
            let contentView = NSHostingView(
                rootView: ProductPanelPreviewSample()
                    .preferredColorScheme(.dark)
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Product Panel Preview"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            self.configureTransparentWindow(window)
            window.contentView = contentView
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            productPanelPreviewWindow = window
        }
    }

    private func showAgentPreviewWindow() {
        let isNarrowPreview = ProcessInfo.processInfo.arguments.contains("--agent-preview-narrow")
        let previewSelection: String
        if ProcessInfo.processInfo.arguments.contains("--agent-preview-tool-call") {
            previewSelection = "toolCall"
        } else if ProcessInfo.processInfo.arguments.contains("--agent-preview-automation") {
            previewSelection = "automation"
        } else {
            previewSelection = "quickAsk"
        }
        let contentWidth: CGFloat = isNarrowPreview ? 880 : 1280
        let contentHeight: CGFloat = isNarrowPreview ? 1180 : 980

        if agentPreviewWindow == nil {
            let contentView = NSHostingView(
                rootView: AgentDashboardView(
                    viewModel: AgentViewModel.previewSample(),
                    selectedSidebarItem: previewSelection,
                    showRightPanel: true,
                    previewSidebarSelection: previewSelection,
                    shouldLoadDashboardData: false
                )
                    .preferredColorScheme(.dark)
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Agent Preview"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            self.configureTransparentWindow(window)
            window.contentView = contentView
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            agentPreviewWindow = window
        }
    }

    private func showSystemStatusPreviewWindow() {
        let isNarrowPreview = ProcessInfo.processInfo.arguments.contains("--system-status-preview-narrow")
        let contentWidth: CGFloat = isNarrowPreview ? 880 : 1280
        let contentHeight: CGFloat = isNarrowPreview ? 1120 : 980

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

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "System Status Preview"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            self.configureTransparentWindow(window)
            window.contentView = contentView
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        let diagnostics = clipboardPinWindowManager?.diagnosticsReport() ?? "AcWork Clipboard Pin Diagnostics\nWindow Count: 0\nNo open pin windows."
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

        menu.addItem(NSMenuItem(title: "显示主窗口", action: #selector(showMainWindowFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "显示灵动胶囊", action: #selector(toggleDesktopCapsuleFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let pinMenu = NSMenu(title: "剪贴板 Pin")
        pinMenu.addItem(NSMenuItem(title: "全部显示 Pin 窗口", action: #selector(showClipboardPinWindowsFromMenu), keyEquivalent: ""))
        pinMenu.addItem(NSMenuItem(title: "全部隐藏 Pin 窗口", action: #selector(hideClipboardPinWindowsFromMenu), keyEquivalent: ""))
        pinMenu.addItem(NSMenuItem(title: "全部关闭 Pin 窗口", action: #selector(closeClipboardPinWindowsFromMenu), keyEquivalent: ""))
        pinMenu.addItem(NSMenuItem.separator())
        pinMenu.addItem(NSMenuItem(title: "复制 Pin 诊断", action: #selector(copyClipboardPinDiagnosticsFromMenu), keyEquivalent: ""))
        let pinMenuItem = NSMenuItem(title: "剪贴板 Pin", action: nil, keyEquivalent: "")
        pinMenuItem.submenu = pinMenu
        menu.addItem(pinMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 快速操作
        let captureMenu = NSMenu(title: "快速采集")
        captureMenu.addItem(NSMenuItem(title: "截图", action: #selector(captureScreenshot), keyEquivalent: ""))
        captureMenu.addItem(NSMenuItem(title: "胶囊输入", action: #selector(showCapsuleFromMenu), keyEquivalent: ""))
        let captureItem = NSMenuItem(title: "快速采集", action: nil, keyEquivalent: "")
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
        case "打开 Agent":
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

    @objc private func captureScreenshot() {
        guard SettingsLocalPreferences.isCaptureScreenshotEnabled() else {
            appState.showError(.serviceUnavailable("截图捕获已在设置中关闭"))
            return
        }

        Task {
            await performCapture(mode: .fullscreen)
        }
    }

    func captureAreaScreenshot() {
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

    func openSettingsWindow() {
        showSettings()
    }

    @objc private func showSettings() {
        appState.navigate(to: .settings)
        showMainWindow()
    }

    @objc private func handleOpenHomeNotification(_ notification: Notification) {
        appState.navigate(to: .home)
        showMainWindow()
    }

    @objc private func handleOpenSettingsNotification(_ notification: Notification) {
        showSettings()
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
            
            // 处理采集结果
            NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }
    
    private func showScreenshotPreview(image: NSImage?, result: CaptureResult) {
        // 创建预览窗口
        let previewWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        screenshotPreviewWindow = previewWindow
        previewWindow.title = "截图预览"
        configureTransparentWindow(previewWindow)
        previewWindow.center()
        
        // 创建预览视图
        let previewView = ScreenshotPreviewView(
            image: image,
            captureResult: result,
            onPin: { [weak self] in
                self?.showClipboardPinWindow(captureResult: result)
            },
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
            screenshotPreviewWindow = nil
        }
    }
}

// MARK: - Screenshot Preview View

struct ScreenshotPreviewView: View {
    let image: NSImage?
    let captureResult: CaptureResult
    let onPin: () -> Void
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
                    Button("Pin 到桌面") {
                        onPin()
                    }
                    .buttonStyle(.bordered)

                    Button("保存到收集箱") {
                        saveToInbox()
                        onDismiss()
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }
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
    
    private func saveToInbox() {
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureCompleted"),
            object: captureResult
        )
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

        window.title = AcWorkBrand.displayName
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

private extension JSONEncoder {
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
