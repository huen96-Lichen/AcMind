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

    private var hotCornerSettingsStore: HotCornerSettingsStore? {
        serviceContainer?.hotCornerSettingsStore
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showLaunchWindow()
        setupStatusBar()
        setupNotifications()

        // 初始化服务容器
        Task {
            do {
                let container = try await ServiceContainer.setup()
                await MainActor.run {
                    self.serviceContainer = container
                    self.appState.bindServiceContainerState(container)
                    self.hideLaunchWindow()
                    self.connectCompanionPanels()
                    if self.clipboardPinWindowManager == nil {
                        self.clipboardPinWindowManager = ClipboardPinWindowManager(assetStore: self.assetStore ?? AssetStore())
                    }
                    
                    // 检查是否需要显示 OOBE
                    if !UserDefaults.standard.bool(forKey: OOBEWindowController.completionDefaultsKey) {
                        self.showOOBE()
                    } else {
                        self.showMainWindow()
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

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true

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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
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
        mainWindowController?.normalizeWindowSizeIfNeeded(targetContentSize: AppWindowGeometry.mainFrame.size)
        if shouldRestoreWindowPosition == false {
            mainWindowController?.window?.setFrame(
                MainWindowController.frameRect(forContentSize: AppWindowGeometry.mainFrame.size, origin: AppWindowGeometry.mainFrame.origin, styleMask: mainWindowController?.window?.styleMask),
                display: true
            )
        }
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        mainWindowController?.window?.orderFrontRegardless()
        appState.mainWindowDidOpen()
    }

    func hideMainWindow() {
        mainWindowController?.close()
        mainWindowController = nil
        appState.mainWindowDidClose()
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
        notchPanelController.showCompact()
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
        #if DEBUG
        print("[ClipboardPin] request pin item=\(item.id) type=\(item.type.displayName)")
        #endif
        if clipboardPinWindowManager == nil {
            let assetStore = self.assetStore ?? AssetStore()
            clipboardPinWindowManager = ClipboardPinWindowManager(assetStore: assetStore)
        }
        clipboardPinWindowManager?.show(item: item)
    }

    func hideClipboardPinWindows() {
        #if DEBUG
        print("[ClipboardPin] hide all request")
        #endif
        clipboardPinWindowManager?.hideAll()
    }

    func showClipboardPinWindows() {
        #if DEBUG
        print("[ClipboardPin] show all request")
        #endif
        clipboardPinWindowManager?.showAll()
    }

    func closeClipboardPinWindows() {
        #if DEBUG
        print("[ClipboardPin] close all request")
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
        let diagnostics = clipboardPinWindowManager?.diagnosticsReport() ?? "AcMind Clipboard Pin Diagnostics\nWindow Count: 0\nNo open pin windows."
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

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "AcMind")
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
            print("[AcMind.App] app did become active, refreshing permissions")
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
                print("⚠️ 删除收集项失败: \(error.localizedDescription)")
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

    @objc private func handleHotCornersDidChange(_ notification: Notification) {
        setupHotCorners()
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
        guard let hotCornerStore = hotCornerSettingsStore else {
            hotCornerManager?.stop()
            hotCornerManager = nil
            return
        }

        if hotCornerManager == nil {
            hotCornerManager = HotCornerManager(actionExecutor: { [weak self] action in
                self?.performHotCornerAction(action)
            })
        }

        Task { [weak self] in
            let settings = await hotCornerStore.getHotCornerSettings()
            await MainActor.run {
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

        for item in SidebarItem.mainItems {
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
                print("⚠️ 注册全局快捷键失败: \(item.displayName) - \(error.localizedDescription)")
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
                print("⚠️ 注册截图热键失败: \(hotkeyString) - \(error.localizedDescription)")
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
                print("⚠️ 注册随身快捷键失败: \(shortcutConfig.action) - \(error.localizedDescription)")
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
                print("⚠️ 注册语音快捷键失败: \(shortcutString) - \(error.localizedDescription)")
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
            appState.selectSidebarItem(.agent)
            showMainWindow()
        case "今日日程":
            appState.selectSidebarItem(.schedule)
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
            print("⚠️ 未找到应用: \(bundleIdentifier)")
            return
        }

        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                print("⚠️ 打开应用失败: \(error.localizedDescription)")
            }
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("⚠️ 无效 URL: \(urlString)")
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
            print("⚠️ 未知功能: \(identifier)")
        }
    }

    private func openInternalRoute(_ routeIdentifier: String) {
        if let item = SidebarItem(rawValue: routeIdentifier) {
            showPreferredSurface(for: item)
        } else {
            print("⚠️ 未知内部路由: \(routeIdentifier)")
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
                appState.selectSidebarItem(.dynamicContinent)
                showMainWindow()
            }
        case .agent:
            if notchPanelEnabled {
                showNotchPanel(page: .agent)
            } else {
                appState.selectSidebarItem(.agent)
                showMainWindow()
            }
        case .schedule:
            if notchPanelEnabled {
                showNotchPanel(page: .schedule)
            } else {
                appState.selectSidebarItem(.schedule)
                showMainWindow()
            }
        case .systemStatus:
            appState.selectSidebarItem(.home)
            showMainWindow()
        case .voiceEntry:
            appState.selectSidebarItem(.voiceEntry)
            showMainWindow()
        default:
            appState.selectSidebarItem(item)
            showMainWindow()
        }
    }

    @objc func showSystemStatus() {
        appState.selectSidebarItem(.home)
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

    @objc private func showSettings() {
        appState.selectSidebarItem(.settings)
        showMainWindow()
    }

    @objc private func handleOpenHomeNotification(_ notification: Notification) {
        appState.selectSidebarItem(.home)
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
        previewWindow.title = "截图预览"
        previewWindow.center()
        
        // 创建预览视图
        let previewView = ScreenshotPreviewView(
            image: image,
            captureResult: result,
            onDismiss: {
                previewWindow.close()
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

// MARK: - Screenshot Preview View

struct ScreenshotPreviewView: View {
    let image: NSImage?
    let captureResult: CaptureResult
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
                
                Button("保存到收集箱") {
                    saveToInbox()
                    onDismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
            .background(AppSurfaceTokens.cardBackgroundSoft)
            
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
                .background(AppSurfaceTokens.secondarySidebarBackground)
            }
        }
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "AcMind"
        window.contentMinSize = NSSize(width: 1200, height: 650)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
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

        guard let window else { return }
        let targetContentSize = NSSize(width: 1200, height: 650)
        if window.contentLayoutRect.size != targetContentSize {
            window.setFrame(Self.frameRect(forContentSize: targetContentSize, origin: window.frame.origin, styleMask: window.styleMask), display: true)
        }
    }

    func normalizeWindowSizeIfNeeded(targetContentSize: NSSize) {
        guard let window else { return }
        if window.contentLayoutRect.size != targetContentSize {
            window.setFrame(Self.frameRect(forContentSize: targetContentSize, origin: window.frame.origin, styleMask: window.styleMask), display: true)
        }
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

        window.title = "AcMind Capsule"
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

        window.title = "AcMind"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .moveToActiveSpace]
        window.level = .statusBar
        window.center()
        window.orderFrontRegardless()

        let contentView = LaunchView()
            .environmentObject(AppState.shared)

        window.contentView = NSHostingView(rootView: contentView)

        self.init(window: window)
    }
}

// MARK: - Window Geometry

enum AppWindowGeometry {
    static let mainFrame = NSRect(x: 120, y: 120, width: 1200, height: 650)
    static let launchFrame = NSRect(x: 220, y: 180, width: 460, height: 340)
    static let capsuleFrame = NSRect(x: 320, y: 260, width: 400, height: 60)
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
