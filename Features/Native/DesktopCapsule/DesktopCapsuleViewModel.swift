import SwiftUI
import AppKit
import AcMindKit

// MARK: - Desktop Capsule Layout Metrics

enum DesktopCapsuleLayoutMetrics {
    static let collapsedDiameter: CGFloat = 52
    static let collapsedGlyphSize: CGFloat = 42
    static let height: CGFloat = 52
    static let contentLeadingInset: CGFloat = 52
    static let contentTrailingInset: CGFloat = 12
    static let actionSlotWidth: CGFloat = 44
    static let actionSlotSpacing: CGFloat = 0
    static let menuSlotWidth: CGFloat = 40
    static let sidePadding: CGFloat = 8
}

// MARK: - Desktop Capsule View Model

@MainActor
final class DesktopCapsuleViewModel: ObservableObject {
    // MARK: - State

    @Published var isExpanded: Bool = false
    @Published var executingAction: CapsuleActionType?
    @Published var isExecuting: Bool = false
    @Published var isHoveringPanel: Bool = false
    @Published var isHoverEmphasized: Bool = false

    private var hoverOpenTask: Task<Void, Never>?
    private var hoverCollapseTask: Task<Void, Never>?

    // MARK: - Settings

    @Published private(set) var settings: DesktopCapsuleSettings = .default

    var enabledActions: [CapsuleActionConfig] {
        settings.enabledActions
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
        }
    }

    // MARK: - Expand/Collapse

    func toggleExpand() {
        cancelHoverTasks()
        isExpanded.toggle()

        // 调整窗口大小
        if isExpanded {
            let width = calculateExpandedWidth()
            DesktopCapsulePanel.shared.resizeToExpanded(width: width)
        } else {
            DesktopCapsulePanel.shared.resizeToCollapsed()
        }
    }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
    }

    func collapse() {
        guard isExpanded else { return }
        cancelHoverTasks()
        isExpanded = false
        DesktopCapsulePanel.shared.resizeToCollapsed()
    }

    func setPanelHovered(_ hovering: Bool) {
        isHoveringPanel = hovering
        isHoverEmphasized = hovering
        cancelHoverTasks()

        if hovering {
            guard !isExpanded, coordinatorAllowsHoverOpen else { return }
            scheduleHoverOpen()
        } else {
            isHoverEmphasized = false
            guard isExpanded, canAutoCollapse else { return }
            scheduleHoverCollapse()
        }
    }

    var expandedWidth: CGFloat {
        calculateExpandedWidth()
    }

    private func calculateExpandedWidth() -> CGFloat {
        let actionCount = CGFloat(enabledActions.count)
        return DesktopCapsuleLayoutMetrics.collapsedDiameter
            + DesktopCapsuleLayoutMetrics.sidePadding
            + (actionCount * DesktopCapsuleLayoutMetrics.actionSlotWidth)
            + DesktopCapsuleLayoutMetrics.menuSlotWidth
            + DesktopCapsuleLayoutMetrics.contentTrailingInset
    }

    private func cancelHoverTasks() {
        hoverOpenTask?.cancel()
        hoverCollapseTask?.cancel()
        hoverOpenTask = nil
        hoverCollapseTask = nil
    }

    private func scheduleHoverOpen() {
        hoverOpenTask?.cancel()
        hoverOpenTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, !self.isExpanded else { return }
                self.isExpanded = true
                let width = self.calculateExpandedWidth()
                DesktopCapsulePanel.shared.resizeToExpanded(width: width)
            }
        }
    }

    private func scheduleHoverCollapse() {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isExpanded, !self.isHoveringPanel, self.canAutoCollapse else { return }
                self.collapse()
            }
        }
    }

    private var coordinatorAllowsHoverOpen: Bool {
        DynamicSurfaceCoordinator.shared.dragPhase == .idle && !isExecuting
    }

    private var canAutoCollapse: Bool {
        DynamicSurfaceCoordinator.shared.dragPhase == .idle && !isExecuting
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
        // 隐藏胶囊
        DesktopCapsulePanel.shared.hide()

        do {
            let captureService = ServiceContainer.shared.captureService
            let result = try await captureService.captureScreenshot(mode: .fullscreen)
            print("截图成功: \(result.sourceItem.id)")

            // 重新显示胶囊
            await MainActor.run {
                DynamicSurfaceCoordinator.shared.transition(to: .capsuleCompact, reason: .capture)
            }
        } catch {
            print("截图失败: \(error)")
            await MainActor.run {
                DynamicSurfaceCoordinator.shared.transition(to: .capsuleCompact, reason: .capture)
            }
        }
    }

    private func executeVoiceNote() async {
        // 显示语音输入界面
        NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
    }

    private func executeUrlToText() async {
        // 显示 URL 输入对话框
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "URL转文字稿"
            alert.informativeText = "请输入网页URL"

            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            textField.placeholderString = "https://..."
            alert.accessoryView = textField

            alert.addButton(withTitle: "转换")
            alert.addButton(withTitle: "取消")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn, let url = URL(string: textField.stringValue), textField.stringValue.hasPrefix("http") {
                Task {
                    do {
                        let captureService = ServiceContainer.shared.captureService
                        let result = try await captureService.captureFromWebpage(url: url)
                        print("URL转换成功: \(result.sourceItem.id)")
                    } catch {
                        print("URL转换失败: \(error)")
                    }
                }
            }
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
        NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
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
                DynamicSurfaceCoordinator.shared.transition(to: .capsuleCompact, reason: .capture)
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
                    DynamicSurfaceCoordinator.shared.transition(to: .capsuleCompact, reason: .capture)
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
}
