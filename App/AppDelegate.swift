import SwiftUI
import AppKit
import AcMindKit

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

    // MARK: - Status Bar

    private var statusItem: NSStatusItem?

    // MARK: - State

    private let appState = AppState.shared
    private var isTerminating = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showLaunchWindow()
        setupStatusBar()
        setupNotifications()
        setupGlobalShortcuts()

        // 初始化服务容器
        Task {
            do {
                try await ServiceContainer.setup()
                await MainActor.run {
                    self.hideLaunchWindow()
                    self.showMainWindow()
                }
            } catch {
                await MainActor.run {
                    appState.showError(AppError.initializationFailed(error))
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true

        // 清理资源
        Task {
            await ServiceContainer.shared.shutdown()
        }

        // 停止监听
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
            mainWindowController = MainWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.setFrame(AppWindowGeometry.mainFrame, display: true)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        mainWindowController?.window?.orderFrontRegardless()
        appState.mainWindowDidOpen()
    }

    func hideMainWindow() {
        mainWindowController?.close()
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
        if capsuleWindowController == nil {
            capsuleWindowController = CapsuleWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        capsuleWindowController?.showWindow(nil)
        capsuleWindowController?.window?.setFrame(AppWindowGeometry.capsuleFrame, display: true)
        capsuleWindowController?.window?.makeKeyAndOrderFront(nil)
        capsuleWindowController?.window?.orderFrontRegardless()
        appState.capsuleWindowDidOpen()
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
        capsuleWindowController?.close()
        appState.capsuleWindowDidClose()
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureNotification(_:)),
            name: Notification.Name("AcMind.captureScreenshot"),
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
    }

    @objc private func handleCaptureNotification(_ notification: Notification) {
        Task {
            await performCapture(mode: .fullscreen)
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
            await performVoiceCapture()
        }
    }

    // MARK: - Global Shortcuts

    private func setupGlobalShortcuts() {
        // 注册全局快捷键
        // 注意：实际实现需要使用 CGEvent.tapCreate 或 MASShortcut 等库
        // 这里仅作占位，后续实现
    }

    // MARK: - Actions

    @objc private func showMainWindowFromMenu() {
        showMainWindow()
    }

    @objc private func showCapsuleFromMenu() {
        showCapsuleWindow()
    }

    @objc private func captureScreenshot() {
        Task {
            await performCapture(mode: .fullscreen)
        }
    }

    @objc private func showSettings() {
        appState.selectSidebarItem(.settings)
        showMainWindow()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Capture Operations

    private func performCapture(mode: ScreenshotMode) async {
        guard !isTerminating else { return }

        do {
            let result = try await ServiceContainer.shared.captureService.captureScreenshot(mode: mode)
            // 处理采集结果
            NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    private func performClipboardCapture() async {
        guard !isTerminating else { return }

        do {
            if let result = try await ServiceContainer.shared.captureService.captureFromClipboard() {
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

        do {
            let result = try await ServiceContainer.shared.captureService.captureFromManualText(text)
            NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    private func performVoiceCapture() async {
        guard !isTerminating else { return }

        do {
            let result = try await ServiceContainer.shared.captureService.captureFromVoice()
            NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }
}

// MARK: - Main Window Controller

class MainWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "AcMind"
        window.minSize = NSSize(width: 800, height: 600)
        window.collectionBehavior = [.managed, .moveToActiveSpace]
        window.setFrameAutosaveName("MainWindow")

        // 设置内容视图
        let contentView = ContentView()
            .environmentObject(AppState.shared)
            .environmentObject(ServiceContainer.shared)

        window.contentView = NSHostingView(rootView: contentView)

        self.init(window: window)

        setupWindowDelegate()
    }

    private func setupWindowDelegate() {
        window?.delegate = self
    }
}

extension MainWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        AppState.shared.mainWindowDidBecomeKey()
    }

    func windowDidResignKey(_ notification: Notification) {
        AppState.shared.mainWindowDidResignKey()
    }

    func windowWillClose(_ notification: Notification) {
        AppState.shared.mainWindowDidClose()
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
    static let mainFrame = NSRect(x: 120, y: 120, width: 1200, height: 800)
    static let launchFrame = NSRect(x: 220, y: 180, width: 460, height: 340)
    static let capsuleFrame = NSRect(x: 320, y: 260, width: 400, height: 60)
}

extension CapsuleWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        AppState.shared.capsuleWindowDidClose()
    }
}
