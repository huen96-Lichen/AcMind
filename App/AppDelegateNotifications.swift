import SwiftUI
import AppKit
import AcMindKit

extension AppDelegate {
    func setupNotifications() {
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureCompleted(_:)),
            name: Notification.Name("AcMind.captureCompleted"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWorkspaceCollapsed(_:)),
            name: Notification.Name("AcMind.workspaceCollapsed"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWorkspaceExpanded(_:)),
            name: Notification.Name("AcMind.workspaceExpanded"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWorkspaceRailWidthChanged(_:)),
            name: Notification.Name("AcMind.workspaceRailWidthChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCompanionVoiceConfigurationChanged(_:)),
            name: .companionVoiceConfigurationDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCompanionVoiceAgentDraft(_:)),
            name: .companionVoiceAgentDraft,
            object: nil
        )
    }

    @objc func handleAppDidBecomeActive(_ notification: Notification) {
        guard let serviceContainer else { return }

        Task {
            print("[AcMind.App] app did become active, refreshing permissions")
            await serviceContainer.permissionManager.refreshAll()
        }
    }

    @objc func handleNotchNavigate(_ notification: Notification) {
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
        appState.restoreWorkspaceFromHidden()
        showMainWindow()
    }

    @objc func handleWorkspaceCollapsed(_ notification: Notification) {
        let railWidth = notification.userInfo?["railWidth"] as? CGFloat ?? ACLayout.primaryRailCompact
        collapseWindowToPrimaryRail(railWidth: railWidth)
    }

    @objc func handleWorkspaceExpanded(_ notification: Notification) {
        expandWindowToFullWorkspace()
    }

    @objc func handleWorkspaceRailWidthChanged(_ notification: Notification) {
        let railWidth = notification.userInfo?["railWidth"] as? CGFloat ?? ACLayout.primaryRailCompact
        updateWindowForRailWidth(railWidth)
    }

    @objc func handleCompanionVoiceConfigurationChanged(_ notification: Notification) {
        Task {
            await refreshCompanionVoiceShortcutRegistration()
        }
    }

    @objc func handleCompanionVoiceAgentDraft(_ notification: Notification) {
        appState.selectSidebarItem(.agent)
        showMainWindow()
    }

    @objc func handleCaptureCompleted(_ notification: Notification) {
        NotificationCenter.default.post(
            name: .companionCaptureSuccess,
            object: notification.object
        )
    }

    @objc func handleCaptureNotification(_ notification: Notification) {
        Task {
            var mode: ScreenshotMode = .fullscreen
            if let userInfo = notification.object as? [String: Any],
               let modeString = userInfo["mode"] as? String,
               let capturedMode = ScreenshotMode(rawValue: modeString) {
                mode = capturedMode
            }
            await performCapture(mode: mode)
        }
    }

    @objc func handleClipboardNotification(_ notification: Notification) {
        Task {
            await performClipboardCapture()
        }
    }

    @objc func handleTextNotification(_ notification: Notification) {
        if let text = notification.object as? String {
            Task {
                await performTextCapture(text)
            }
        }
    }

    @objc func handleVoiceNotification(_ notification: Notification) {
        Task {
            await performVoiceCapture()
        }
    }

    func refreshCompanionVoiceShortcutRegistration() async {
        guard !isTerminating else { return }
        guard let serviceContainer else { return }

        let storage = serviceContainer.storageService
        let rawConfig = try? await storage.getSetting(key: "companion_config")
        let configData = rawConfig?.data(using: .utf8)
        let config = configData.flatMap { try? JSONDecoder().decode(CompanionConfiguration.self, from: $0) }
            ?? CompanionConfiguration.default

        let triggerMode = CompanionVoiceTriggerMode(rawValue: config.voiceTriggerMode) ?? .both
        let shouldRegisterShortcut = config.voiceEnabled && (triggerMode == .globalShortcut || triggerMode == .both)

        if !shouldRegisterShortcut {
            await unregisterCompanionVoiceShortcut()
            return
        }

        guard let shortcut = KeyboardShortcut(displayString: config.voiceShortcut) else {
            await unregisterCompanionVoiceShortcut()
            return
        }

        if registeredCompanionVoiceShortcut == shortcut {
            return
        }

        await unregisterCompanionVoiceShortcut()

        do {
            try await serviceContainer.settingsService.registerShortcut(shortcut) { [weak self] in
                Task { @MainActor in
                    self?.showVoicePanelFromShortcut()
                }
            }
            registeredCompanionVoiceShortcut = shortcut
        } catch {
            appState.showError(.unknown(error))
        }
    }

    private func unregisterCompanionVoiceShortcut() async {
        guard let shortcut = registeredCompanionVoiceShortcut else { return }
        guard let serviceContainer else { return }

        do {
            try await serviceContainer.settingsService.unregisterShortcut(shortcut)
        } catch {
        }

        registeredCompanionVoiceShortcut = nil
    }

    private func showVoicePanelFromShortcut() {
        NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
    }

    func setupGlobalShortcuts() {
        fnVoiceMonitor.start()
        cornerHotspotMonitor.start()
        desktopCornerHintOverlayManager.start()
    }

    @objc func showMainWindowFromMenu() {
        showMainWindow()
    }

    @objc func showCapsuleFromMenu() {
        showDesktopCapsule()
    }

    @objc func toggleDesktopCapsuleFromMenu() {
        toggleDesktopCapsule()
    }

    @objc func captureScreenshot() {
        Task {
            await performCapture(mode: .fullscreen)
        }
    }

    @objc func showSettings() {
        appState.selectSidebarItem(.settings)
        showMainWindow()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func performCapture(mode: ScreenshotMode) async {
        guard !isTerminating else { return }
        guard let serviceContainer else { return }

        do {
            let result = try await serviceContainer.captureService.captureScreenshot(mode: mode)
            var previewImage: NSImage?
            if let assetId = result.sourceItem.assetFileIds.first,
               let asset = try? await serviceContainer.assetStore.getAsset(id: assetId) {
                previewImage = NSImage(contentsOfFile: asset.filePath)
            }

            await MainActor.run {
                showScreenshotPreview(image: previewImage, result: result)
            }

            NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    private func showScreenshotPreview(image: NSImage?, result: CaptureResult) {
        let previewWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        previewWindow.title = "截图预览"
        previewWindow.center()

        let previewView = ScreenshotPreviewView(
            image: image,
            captureResult: result,
            onDismiss: {
                previewWindow.close()
            }
        )
        previewWindow.contentView = NSHostingView(rootView: previewView)

        previewWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func performClipboardCapture() async {
        guard !isTerminating else { return }
        guard let serviceContainer else { return }

        do {
            if let result = try await serviceContainer.captureService.captureFromClipboard() {
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
        guard let serviceContainer else { return }

        do {
            let result = try await serviceContainer.captureService.captureFromManualText(text)
            NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }

    private func performVoiceCapture() async {
        guard !isTerminating else { return }
        guard let serviceContainer else { return }

        do {
            let result = try await serviceContainer.captureService.captureFromVoice()
            NotificationCenter.default.post(name: Notification.Name("AcMind.captureCompleted"), object: result)
        } catch {
            await MainActor.run {
                appState.showError(AppError.unknown(error))
            }
        }
    }
}

struct ScreenshotPreviewView: View {
    let image: NSImage?
    let captureResult: CaptureResult
    let onDismiss: () -> Void

    @State private var imageSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
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
