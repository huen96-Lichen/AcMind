import AppKit
import AcMindKit

extension AppDelegate {
    func handleCornerTriggerTarget(_ target: CornerTriggerTarget) {
        switch target.kind {
        case .builtInFeature:
            guard let builtInAction = target.builtInAction else { return }
            handleBuiltInCornerAction(builtInAction)
        case .application:
            openApplication(for: target)
        }
    }

    private func handleBuiltInCornerAction(_ action: CornerBuiltInAction) {
        switch action {
        case .showMainWindow:
            showMainWindow()
        case .showDynamicSurface:
            appState.selectSidebarItem(.dynamicSurface)
            showMainWindow()
        case .showAgent:
            appState.selectSidebarItem(.agent)
            showMainWindow()
        case .showInbox:
            appState.selectSidebarItem(.inbox)
            showMainWindow()
        case .showClipboard:
            appState.selectSidebarItem(.clipboard)
            showMainWindow()
        case .showSchedule:
            appState.selectSidebarItem(.schedule)
            showMainWindow()
        case .showWorkbench:
            appState.selectSidebarItem(.workbench)
            showMainWindow()
        case .showCompanion:
            appState.selectSidebarItem(.companion)
            showMainWindow()
        case .showConfiguration:
            appState.selectSidebarItem(.config)
            showMainWindow()
        case .captureScreenshot:
            toastManager.show(.info, "正在截图...")
            Task {
                await performCapture(mode: .fullscreen)
            }
        case .showQuickNote:
            showMainWindow()
            NotificationCenter.default.post(name: .companionShowQuickNote, object: nil)
        case .showVoicePanel:
            showMainWindow()
            NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
        }
    }

    private func openApplication(for target: CornerTriggerTarget) {
        let resolvedURL: URL? = {
            if let applicationURL = target.applicationURL, FileManager.default.fileExists(atPath: applicationURL.path) {
                return applicationURL
            }

            if let bundleIdentifier = target.applicationBundleIdentifier,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                return url
            }

            if let applicationURL = target.applicationURL {
                return applicationURL
            }

            return nil
        }()

        guard let resolvedURL else {
            toastManager.show(.warning, "未找到可打开的应用")
            return
        }

        if NSWorkspace.shared.open(resolvedURL) {
            toastManager.show(.success, "已打开 \(target.displayName)")
        } else {
            toastManager.show(.error, "应用打开失败: \(target.displayName)")
        }
    }
}
