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
    private let musicService = MusicService.shared
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
                    // 显示刘海面板
                    if self.notchPanelEnabled {
                        self.showNotchPanel()
                    }
                    // 显示胶囊
                    if self.desktopCapsuleEnabled {
                        self.showDesktopCapsule()
                    }
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

    // MARK: - Notch Panel

    func showNotchPanel() {
        NotchPanel.shared.show()
    }

    func hideNotchPanel() {
        NotchPanel.shared.hide()
    }

    func toggleNotchPanel() {
        NotchPanel.shared.toggle()
    }

    // MARK: - Desktop Capsule

    func showDesktopCapsule() {
        DesktopCapsulePanel.shared.restorePosition()
        DesktopCapsulePanel.shared.show()
    }

    func hideDesktopCapsule() {
        DesktopCapsulePanel.shared.hide()
    }

    func toggleDesktopCapsule() {
        DesktopCapsulePanel.shared.toggle()
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
        menu.addItem(NSMenuItem(title: "显示胶囊", action: #selector(toggleDesktopCapsuleFromMenu), keyEquivalent: ""))
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
    }

    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        // App 回到前台时刷新所有权限状态
        Task {
            print("[AcMind.App] app did become active, refreshing permissions")
            await ServiceContainer.shared.permissionManager.refreshAll()
        }
    }

    @objc private func handleNotchNavigate(_ notification: Notification) {
        switch notification.name {
        case .companionShowSchedule:
            appState.selectSidebarItem(.schedule)
        case .companionShowInbox:
            appState.selectSidebarItem(.inbox)
        case .companionShowAgent:
            appState.selectSidebarItem(.agent)
        default:
            break
        }
        showMainWindow()
    }

    @objc private func handleCaptureCompleted(_ notification: Notification) {
        // 截图完成后发送通知给刘海面板
        NotificationCenter.default.post(
            name: .companionCaptureSuccess,
            object: notification.object
        )
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

    @objc private func toggleDesktopCapsuleFromMenu() {
        toggleDesktopCapsule()
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
            
            // 获取截图图片用于预览
            var previewImage: NSImage?
            if let assetId = result.sourceItem.assetFileIds.first,
               let asset = try? await ServiceContainer.shared.assetStore.getAsset(id: assetId) {
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
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("保存到收集箱") {
                    saveToInbox()
                    onDismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
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
                        .foregroundColor(.secondary)
                    Text("截图已保存")
                        .font(.headline)
                    Text("可在收集箱中查看")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
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
