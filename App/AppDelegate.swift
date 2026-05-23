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
    var savedWindowFrame: NSRect?
    var lastPrimaryRailWidth: CGFloat = ACLayout.primaryRailCompact
    var isAdjustingMainWindowFrame = false
    var serviceContainer: ServiceContainer?

    // MARK: - Status Bar

    var statusItem: NSStatusItem?

    // MARK: - State

    let appState = AppState()
    let musicService = MusicService()
    let toastManager = ToastManager()
    let fnVoiceMonitor = FnVoiceHoldMonitor.shared
    lazy var cornerHotspotMonitor = GlobalCornerHotspotMonitor { [weak self] target in
        self?.handleCornerTriggerTarget(target)
    }
    lazy var desktopCornerHintOverlayManager = DesktopCornerHintOverlayManager()
    var isTerminating = false
    var registeredCompanionVoiceShortcut: KeyboardShortcut?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showLaunchWindow()
        setupStatusBar()
        setupNotifications()

        Task {
            do {
                try await ServiceContainer.setup(appState: appState)
                self.serviceContainer = ServiceContainer.shared
                await MainActor.run {
                    if let container = self.serviceContainer {
                        NotchPanel.configureShared(
                            container: container,
                            musicService: self.musicService,
                            toastManager: self.toastManager
                        )
                        DesktopCapsulePanel.configureShared(container: container)
                        CapsulePanel.configureShared(container: container)
                        CompanionVoiceSessionController.configureShared(
                            container: container,
                            appState: appState,
                            toastManager: self.toastManager
                        )
                    }
                    _ = NotchPanel.shared
                    _ = DesktopCapsulePanel.shared
                    self.setupGlobalShortcuts()
                    self.hideLaunchWindow()
                    self.showMainWindow()
                    DispatchQueue.main.async {
                        self.restoreDynamicSurface()
                    }
                    Task {
                        await self.refreshCompanionVoiceShortcutRegistration()
                    }
                }
            } catch {
                await MainActor.run {
                    appState.showError(AppError.initializationFailed(error))
                }
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else {
            return .terminateNow
        }

        isTerminating = true
        fnVoiceMonitor.stop()
        cornerHotspotMonitor.stop()
        desktopCornerHintOverlayManager.stop()

        guard let serviceContainer else {
            NotificationCenter.default.removeObserver(self)
            return .terminateNow
        }

        Task { @MainActor in
            await serviceContainer.shutdown()
            NotificationCenter.default.removeObserver(self)
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }
}
