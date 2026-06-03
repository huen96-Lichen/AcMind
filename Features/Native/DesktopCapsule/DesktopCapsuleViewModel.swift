import SwiftUI
import AppKit
import AcMindKit

// MARK: - Desktop Capsule View Model

@MainActor
final class DesktopCapsuleViewModel: ObservableObject {
    // MARK: - State

    @Published var isExpanded: Bool = false
    @Published var executingAction: CapsuleActionType?
    @Published var isExecuting: Bool = false
    @Published var isHoveringPanel: Bool = false

    // MARK: - Settings

    @Published private(set) var settings: DesktopCapsuleSettings = .default
    private var settingsObserver: NSObjectProtocol?

    var enabledActions: [CapsuleActionConfig] {
        settings.enabledActions
    }

    init() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .desktopCapsuleSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadSettingsFromStore()
            }
        }
    }

    // MARK: - Load/Save Settings

    func loadSettings() {
        // 从 UserDefaults 加载
        if let data = UserDefaults.standard.data(forKey: "AppSettings.desktopCapsule"),
           let decoded = try? JSONDecoder().decode(DesktopCapsuleSettings.self, from: data) {
            settings = decoded
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "AppSettings.desktopCapsule")
            NotificationCenter.default.post(name: .desktopCapsuleSettingsDidChange, object: nil)
        }
    }

    // MARK: - Expand/Collapse

    func toggleExpand() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            isExpanded.toggle()
        }

        // 调整窗口大小
        if isExpanded {
            let width = calculateExpandedWidth()
            DesktopCapsulePanel.shared.resizeToExpanded(width: width)
        } else {
            DesktopCapsulePanel.shared.resizeToCollapsed()
        }
    }

    func collapse() {
        guard isExpanded else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            isExpanded = false
        }
        DesktopCapsulePanel.shared.resizeToCollapsed()
    }

    private func calculateExpandedWidth() -> CGFloat {
        let actionCount = CGFloat(enabledActions.count)
        // 左侧圆形按钮 56 + 功能按钮 (44 * count) + 更多按钮 40 + padding
        return 56 + (actionCount * 44) + 40 + 20
    }

    // MARK: - Execute Actions

    func executeAction(_ type: CapsuleActionType) {
        guard !isExecuting else { return }

        executingAction = type
        isExecuting = true

        Task {
            switch type {
            case .screenshot:
                await executeScreenshot()
            case .scrollScreenshot:
                await executeScrollScreenshot()
            case .voiceNote:
                await executeVoiceNote()
            case .urlToText:
                await executeUrlToText()
            case .scheduleAnalysis:
                await executeScheduleAnalysis()
            case .clipboard:
                await executeClipboard()
            case .quickText:
                await executeQuickText()
            case .fileCapture:
                await executeFileCapture()
            }

            await MainActor.run {
                executingAction = nil
                isExecuting = false
                collapse()
            }
        }
    }

    // MARK: - Action Implementations

    private func executeScreenshot() async {
        guard SettingsLocalPreferences.isCaptureScreenshotEnabled() else {
            print("⚠️ 截图捕获已在设置中关闭")
            return
        }

        // 隐藏胶囊
        DesktopCapsulePanel.shared.hide()

        do {
            let captureService = ServiceContainer.shared.captureService
            let result = try await captureService.captureScreenshot(mode: .fullscreen)
            print("截图成功: \(result.sourceItem.id)")

            // 重新显示胶囊
            await MainActor.run {
                DesktopCapsulePanel.shared.show()
            }
        } catch {
            print("截图失败: \(error)")
            await MainActor.run {
                DesktopCapsulePanel.shared.show()
            }
        }
    }

    private func executeScrollScreenshot() async {
        guard SettingsLocalPreferences.isCaptureScreenshotEnabled() else {
            print("⚠️ 滚动截图已在设置中关闭")
            return
        }

        DesktopCapsulePanel.shared.hide()

        do {
            let captureService = ServiceContainer.shared.captureService
            let result = try await captureService.captureScrollingScreenshot()
            print("滚动截图成功: \(result.sourceItem.id)")

            await MainActor.run {
                DesktopCapsulePanel.shared.show()
            }
        } catch {
            print("滚动截图失败: \(error)")
            await MainActor.run {
                DesktopCapsulePanel.shared.show()
            }
        }
    }

    private func executeVoiceNote() async {
        guard SettingsLocalPreferences.isVoiceInputEnabled() else {
            print("⚠️ 说入法输入已在设置中关闭")
            return
        }

        // 显示说入法界面
        NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
    }

    private func executeUrlToText() async {
        guard let input = await promptForWebpageURL() else { return }
        guard let url = normalizeWebpageURL(input) else {
            print("URL转换失败: 请输入有效的网页 URL")
            return
        }

        do {
            let captureService = ServiceContainer.shared.captureService
            let result = try await captureService.captureFromWebpage(url: url)
            print("URL转换成功: \(result.sourceItem.id)")

            settings.lastWebpageURL = url
            saveSettings()
        } catch {
            print("URL转换失败: \(error)")
        }
    }

    private func executeScheduleAnalysis() async {
        // 打开日程视图
        NotificationCenter.default.post(name: .companionShowSchedule, object: nil)
    }

    private func executeClipboard() async {
        do {
            let captureService = ServiceContainer.shared.captureService
            if let result = try await captureService.captureFromClipboard() {
                print("剪贴板采集成功: \(result.sourceItem.id)")
            }
        } catch {
            print("剪贴板采集失败: \(error)")
        }
    }

    private func executeQuickText() async {
        // 显示快速文本输入
        NotificationCenter.default.post(name: .companionShowCapturePanel, object: nil)
    }

    private func executeFileCapture() async {
        // 隐藏胶囊
        DesktopCapsulePanel.shared.hide()

        await MainActor.run {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false

            guard panel.runModal() == .OK, let url = panel.url else {
                DesktopCapsulePanel.shared.show()
                return
            }

            Task {
                do {
                    let captureService = ServiceContainer.shared.captureService
                    let result = try await captureService.captureFromFile(url: url)
                    print("文件采集成功: \(result.sourceItem.id)")
                } catch {
                    print("文件采集失败: \(error)")
                }

                await MainActor.run {
                    DesktopCapsulePanel.shared.show()
                }
            }
        }
    }

    // MARK: - Settings

    func openSettings() {
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.openSettings"),
            object: nil,
            userInfo: ["tab": "capsule"]
        )
    }

    // MARK: - Update Settings

    func updateSettings(_ newSettings: DesktopCapsuleSettings) {
        settings = newSettings
        saveSettings()
    }

    func addAction(_ type: CapsuleActionType) {
        let newAction = CapsuleActionConfig(
            type: type,
            isEnabled: true,
            order: settings.actions.count
        )
        settings.actions.append(newAction)
        saveSettings()
    }

    func removeAction(id: UUID) {
        settings.actions.removeAll { $0.id == id }
        // 重新排序
        for (index, _) in settings.actions.enumerated() {
            settings.actions[index].order = index
        }
        saveSettings()
    }

    func reorderActions(from source: IndexSet, to destination: Int) {
        settings.actions.move(fromOffsets: source, toOffset: destination)
        // 重新排序
        for (index, _) in settings.actions.enumerated() {
            settings.actions[index].order = index
        }
        saveSettings()
    }

    private func reloadSettingsFromStore() {
        let wasExpanded = isExpanded
        loadSettings()

        guard wasExpanded else { return }
        let width = calculateExpandedWidth()
        DesktopCapsulePanel.shared.resizeToExpanded(width: width)
    }

    private func promptForWebpageURL() async -> String? {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "URL转文字稿"
            alert.informativeText = "请输入网页URL"

            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            textField.stringValue = preferredWebpageInputText()
            textField.placeholderString = "https://..."
            alert.accessoryView = textField

            alert.addButton(withTitle: "转换")
            alert.addButton(withTitle: "取消")

            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return nil }
            let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    private func preferredWebpageInputText() -> String {
        if let clipboardValue = clipboardWebpageInputText() {
            return clipboardValue
        }

        return settings.lastWebpageURL?.absoluteString ?? ""
    }

    private func clipboardWebpageInputText() -> String? {
        guard let rawValue = NSPasteboard.general.string(forType: .string) else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return normalizeWebpageURL(trimmed) != nil ? trimmed : nil
    }

    private func normalizeWebpageURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true {
            return url
        }

        if let url = URL(string: "https://\(trimmed)"), url.scheme?.hasPrefix("http") == true {
            return url
        }

        return nil
    }

}
