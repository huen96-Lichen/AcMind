import SwiftUI
import AppKit
import AcMindKit

// MARK: - Settings Category (New)

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case companion
    case aiModels
    case dataKnowledge
    case captureInput
    case security
    case about

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "通用"
        case .companion: return "随身能力"
        case .aiModels: return "AI 与模型"
        case .dataKnowledge: return "数据与知识库"
        case .captureInput: return "捕获与输入"
        case .security: return "权限与安全"
        case .about: return "关于"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .companion: return "sparkles"
        case .aiModels: return "brain"
        case .dataKnowledge: return "database"
        case .captureInput: return "camera"
        case .security: return "shield"
        case .about: return "info"
        }
    }
}

fileprivate func usageBurnColor(for severity: UsageBurnSeverity) -> Color {
    switch severity {
    case .none: return AppSurfaceTokens.accentGreen
    case .info: return AppSurfaceTokens.accentBlue
    case .warning: return AppSurfaceTokens.accentOrange
    case .critical: return .red
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedCategory: SettingsCategory = .general
    @State private var searchQuery = ""
    @State private var recordingShortcutTarget: ShortcutRecordingTarget?
    @State private var pluginSummaries: [PluginManagementSummary] = []
    @State private var isLoadingPluginSummaries = false
    @State private var pluginSummaryError: String?
    private let cloudSyncService: CloudSyncServiceProtocol

    init(cloudSyncService: CloudSyncServiceProtocol = CloudSyncService(storage: StorageService())) {
        self.cloudSyncService = cloudSyncService
    }

    var body: some View {
        WorkspacePageShell(
            title: "设置",
            subtitle: "管理应用偏好",
            leadingRailWidth: 208,
            trailingRailWidth: 224,
            leadingRail: {
                settingsSidebar
            },
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        settingsHeader

                        switch selectedCategory {
                        case .general:
                            GeneralSettingsPage(viewModel: viewModel)
                        case .companion:
                            CompanionSettingsPage(viewModel: viewModel, recordingShortcutTarget: $recordingShortcutTarget)
                        case .aiModels:
                            AIModelsSettingsPage(viewModel: viewModel)
                        case .dataKnowledge:
                            DataKnowledgeSettingsPage(viewModel: viewModel)
                        case .captureInput:
                            CaptureInputSettingsPage(viewModel: viewModel, cloudSyncService: cloudSyncService)
                        case .security:
                            SecuritySettingsPage(viewModel: viewModel)
                        case .about:
                            AboutSettingsPage(viewModel: viewModel)
                        }
                    }
                    .padding(24)
                }
            },
            trailingRail: {
                settingsSummaryRail
            }
        )
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .sheet(item: $recordingShortcutTarget) { target in
            ShortcutRecorderSheet(title: target.title) { shortcut in
                target.apply(shortcut: shortcut, on: viewModel)
            }
        }
        .task {
            await loadPluginSummaries()
        }
    }

    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                TextField("搜索设置...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.caption)
            }
            .padding(8)
            .background(AppSurfaceTokens.cardBackgroundSoft)
            .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
            .padding(12)

            Divider()

            List(selection: $selectedCategory) {
                ForEach(SettingsCategory.allCases) { category in
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .foregroundStyle(AppSurfaceTokens.accentBlue)
                        Text(category.displayName)
                    }
                    .tag(category)
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.sidebar)
            .scrollDisabled(true)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private var settingsSummaryRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppSurfaceCard(title: "当前分类", subtitle: "固定结构中的上下文提示", padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedCategory.displayName)
                            .font(.system(size: 16, weight: .semibold))
                        Text(selectedCategory.description)
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }

                AppSurfaceCard(title: "视图状态", subtitle: "真实可见内容", padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("搜索: \(searchQuery.isEmpty ? "无" : searchQuery)")
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Text(
                            "快捷键录制: " + SettingsStatusLabelFormatter.binaryState(
                                isEnabled: recordingShortcutTarget != nil,
                                enabledText: "进行中",
                                disabledText: "未开启"
                            )
                        )
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }

                AppSurfaceCard(title: "插件扩展", subtitle: "ASR / 润色 / 注入扩展概览", padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(pluginSummaryHeadline)
                                .font(.system(size: 12))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Spacer()
                            Button(isLoadingPluginSummaries ? "刷新中..." : "刷新") {
                                Task {
                                    await loadPluginSummaries()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(isLoadingPluginSummaries)
                        }

                        if let pluginSummaryError {
                            Text(pluginSummaryError)
                                .font(.system(size: 11))
                                .foregroundStyle(AppSurfaceTokens.accentOrange)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if pluginSummaries.isEmpty {
                            Text("尚未发现插件，放入插件目录后会在这里显示状态。")
                                .font(.system(size: 11))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(pluginSummaries.prefix(4)) { summary in
                                    pluginSummaryRow(summary)
                                }
                            }

                            if pluginSummaries.count > 4 {
                                Text("还有 \(pluginSummaries.count - 4) 个插件未展开")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private var pluginSummaryHeadline: String {
        if isLoadingPluginSummaries {
            return "正在读取插件状态"
        }
        if pluginSummaries.isEmpty {
            return "暂无插件摘要"
        }

        let activeCount = pluginSummaries.filter { $0.status == .active }.count
        let errorCount = pluginSummaries.filter { $0.status == .error }.count
        return "已发现 \(pluginSummaries.count) 个插件 · \(activeCount) 个运行中 · \(errorCount) 个错误"
    }

    private func pluginSummaryRow(_ summary: PluginManagementSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(summary.name)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                Text(summary.status.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(pluginStatusColor(summary.status).opacity(0.12))
                    .foregroundStyle(pluginStatusColor(summary.status))
                    .cornerRadius(6)
            }

            HStack(spacing: 6) {
                Text(summary.version)
                Text("·")
                Text(summary.capabilityLabels.isEmpty ? "无扩展能力" : summary.capabilityLabels.joined(separator: " / "))
            }
            .font(.system(size: 10))
            .foregroundStyle(AppSurfaceTokens.secondaryText)
            .lineLimit(1)

            Text(pluginPolicySummary(summary.policy))
                .font(.system(size: 10))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            if let errorMessage = summary.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.72))
        .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
    }

    private func pluginStatusColor(_ status: PluginStatus) -> Color {
        switch status {
        case .active:
            return AppSurfaceTokens.accentGreen
        case .loading:
            return AppSurfaceTokens.accentBlue
        case .discovered:
            return AppSurfaceTokens.accentOrange
        case .inactive:
            return AppSurfaceTokens.secondaryText
        case .error:
            return .red
        }
    }

    private func pluginPolicySummary(_ policy: PluginSandboxPolicySnapshot) -> String {
        let permissionsText = policy.permissionLabels.isEmpty ? "无显式权限" : policy.permissionLabels.joined(separator: " / ")
        return "权限: \(permissionsText) · 限制: \(policy.resourceLimits.memoryMB)MB / \(policy.resourceLimits.cpuPercent)%"
    }

    private func loadPluginSummaries() async {
        isLoadingPluginSummaries = true
        defer { isLoadingPluginSummaries = false }

        do {
            pluginSummaries = await PluginManager.shared.getManagementSummaries()
            pluginSummaryError = nil
        } catch {
            pluginSummaries = []
            pluginSummaryError = "读取插件状态失败: \(error.localizedDescription)"
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedCategory.displayName)
                .font(.title)
                .fontWeight(.semibold)
            Text(selectedCategory.description)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Shortcut Recorder

enum ShortcutRecordingTarget: String, Identifiable {
    case voiceShortcut
    case captureShortcut
    case screenshotShortcut
    case agentShortcut
    case scheduleShortcut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voiceShortcut: return "录制说入法入口快捷键"
        case .captureShortcut: return "录制快速收集快捷键"
        case .screenshotShortcut: return "录制截图捕获快捷键"
        case .agentShortcut: return "录制 Agent 快捷键"
        case .scheduleShortcut: return "录制今日日程快捷键"
        }
    }

    @MainActor
    func apply(shortcut: String, on viewModel: SettingsViewModel) {
        switch self {
        case .voiceShortcut:
            viewModel.companionVoiceShortcut = shortcut
        case .captureShortcut:
            viewModel.companionCaptureShortcut = shortcut
        case .screenshotShortcut:
            viewModel.companionScreenshotShortcut = shortcut
        case .agentShortcut:
            viewModel.companionAgentShortcut = shortcut
        case .scheduleShortcut:
            viewModel.companionScheduleShortcut = shortcut
        }
    }
}

struct ShortcutRecorderSheet: View {
    let title: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var shortcut = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("按下你想要绑定的组合键，然后点击保存。")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            ShortcutCaptureField(shortcut: $shortcut)
                .frame(height: 120)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(AppSurfaceTokens.secondaryCardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius)
                        .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
                )

            HStack {
                Button("清空") {
                    shortcut = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("保存") {
                    let value = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    onSave(value)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            shortcut = ""
        }
    }
}

struct ShortcutCaptureField: NSViewRepresentable {
    @Binding var shortcut: String

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onShortcut = { shortcut = $0 }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onShortcut = { shortcut = $0 }
        nsView.focus()
    }
}

final class ShortcutCaptureNSView: NSView {
    var onShortcut: (String) -> Void = { _ in }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focus()
    }

    func focus() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        onShortcut(Self.formatShortcut(from: event))
    }

    private static func formatShortcut(from event: NSEvent) -> String {
        var components: [String] = []
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        if flags.contains(.command) { components.append("⌘") }
        if flags.contains(.option) { components.append("⌥") }
        if flags.contains(.control) { components.append("⌃") }
        if flags.contains(.shift) { components.append("⇧") }

        let key: String
        switch event.keyCode {
        case 36: key = "Return"
        case 49: key = "Space"
        case 53: key = "Esc"
        case 51: key = "Delete"
        case 123: key = "Left"
        case 124: key = "Right"
        case 125: key = "Down"
        case 126: key = "Up"
        default:
            let raw = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            key = raw.isEmpty ? "Key\(event.keyCode)" : raw.uppercased()
        }

        components.append(key)
        return components.joined()
    }
}

// MARK: - Settings Category Description

extension SettingsCategory {
    var description: String {
        switch self {
        case .general: return "配置 AcMind 的基础偏好"
        case .companion: return "设置随身胶囊、语音和快捷键"
        case .aiModels: return "管理提供商、模型选择和使用统计"
        case .dataKnowledge: return "配置数据存储、库和知识库"
        case .captureInput: return "设置剪贴板、截图和说入法"
        case .security: return "管理权限、隐私和安全"
        case .about: return "查看版本信息、帮助和反馈"
        }
    }
}

// MARK: - Settings Card View (用于卡片式布局)

struct SettingsCard<Content: View>: View {
    let title: String
    let description: String?
    @ViewBuilder let content: Content

    init(title: String, description: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
            content
        }
        .padding(16)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(AppSurfaceTokens.secondaryCardRadius)
        .shadow(color: AppSurfaceTokens.primaryText.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - General Settings Page

struct GeneralSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "外观", description: "调整 AcMind 的视觉风格") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("主题", selection: $viewModel.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("语言", selection: $viewModel.language) {
                        Text("简体中文").tag("zh-CN")
                        Text("英文").tag("en")
                    }
                    .pickerStyle(.segmented)
                }
            }

            SettingsCard(title: "启动行为", description: "配置应用启动时的行为") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启动时显示随身胶囊", isOn: $viewModel.companionCapsuleShowOnLaunch)
                    Toggle("启动时恢复上次窗口位置", isOn: $viewModel.restoreWindowPosition)
                }
            }

            SettingsCard(title: "通知", description: "管理应用通知偏好") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启用通知", isOn: $viewModel.notificationsEnabled)
                    Toggle("任务完成时通知", isOn: $viewModel.taskCompletedNotificationsEnabled)
                    Toggle("更新可用时通知", isOn: $viewModel.updateAvailableNotificationsEnabled)
                    Text("该开关只控制检查更新时是否弹出提醒，下方的「检查更新」按钮已经可以直接使用。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsCard(title: "快捷键摘要", description: "查看常用快捷键") {
                VStack(spacing: 4) {
                    SettingsShortcutRow(action: "显示主窗口", shortcut: "⌘0")
                    SettingsShortcutRow(action: "显示随身胶囊", shortcut: "⌘⇧Space")
                    SettingsShortcutRow(action: "打开设置", shortcut: "⌘,")
                }
            }

            saveButton
        }
    }

    private var saveButton: some View {
        HStack {
            Spacer()
            Button("保存") {
                Task {
                    await viewModel.saveSettings()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding(.top, 16)
    }
}

// MARK: - Companion Settings Page (随身能力)

struct CompanionSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var recordingShortcutTarget: ShortcutRecordingTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "随身胶囊", description: "在屏幕顶部显示随身胶囊，快速访问常用能力") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用随身胶囊", isOn: $viewModel.companionCapsuleEnabled)

                    if viewModel.companionCapsuleEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("展示位置")
                                .font(.subheadline)

                            HStack(spacing: 8) {
                                PositionButton(
                                    title: "顶部居中",
                                    isSelected: viewModel.companionCapsulePosition == .topCenter,
                                    action: { viewModel.companionCapsulePosition = .topCenter }
                                )

                                PositionButton(
                                    title: "右上角",
                                    isSelected: viewModel.companionCapsulePosition == .topRight,
                                    action: { viewModel.companionCapsulePosition = .topRight }
                                )

                                PositionButton(
                                    title: "隐藏",
                                    isSelected: viewModel.companionCapsulePosition == .hidden,
                                    action: { viewModel.companionCapsulePosition = .hidden }
                                )
                            }

                            Toggle("启动时自动显示", isOn: $viewModel.companionCapsuleShowOnLaunch)
                            Toggle("默认展开", isOn: $viewModel.companionCapsuleExpanded)
                            Toggle("菜单栏贴合", isOn: $viewModel.restoreWindowPosition)
                        }
                        .padding(.leading, 8)
                    }
                }
            }

            SettingsCard(title: "说入法入口", description: "长按 Fn 唤起，选择输出落点与收集行为") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用说入法", isOn: $viewModel.companionVoiceEnabled)

                    if viewModel.companionVoiceEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("快捷键")
                                    .font(.subheadline)
                                Spacer()
                                TextField("", text: $viewModel.companionVoiceShortcut)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 120)
                                .layoutPriority(1)
                                Button("录制") {
                                    recordingShortcutTarget = .voiceShortcut
                                }
                                    .controlSize(.small)
                            }

                            Text("清洗完成后")
                                .font(.subheadline)

                            Picker("", selection: $viewModel.companionVoiceOutputMode) {
                                ForEach(VoiceOutputMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()

                            Toggle("保存说入法结果到收集箱", isOn: $viewModel.companionVoiceSaveToInbox)
                        }
                        .padding(.leading, 8)
                    }
                }
            }

            SettingsCard(title: "随身快捷键", description: "配置全局快捷键") {
                VStack(spacing: 8) {
                    ShortcutConfigRow(action: "说入法入口", shortcut: $viewModel.companionVoiceShortcut) {
                        recordingShortcutTarget = .voiceShortcut
                    }
                    ShortcutConfigRow(action: "快速收集", shortcut: $viewModel.companionCaptureShortcut) {
                        recordingShortcutTarget = .captureShortcut
                    }
                    ShortcutConfigRow(action: "截图捕获", shortcut: $viewModel.companionScreenshotShortcut) {
                        recordingShortcutTarget = .screenshotShortcut
                    }
                    ShortcutConfigRow(action: "打开 Agent", shortcut: $viewModel.companionAgentShortcut) {
                        recordingShortcutTarget = .agentShortcut
                    }
                    ShortcutConfigRow(action: "今日日程", shortcut: $viewModel.companionScheduleShortcut) {
                        recordingShortcutTarget = .scheduleShortcut
                    }
                }
            }

            SettingsCard(title: "随身捕获", description: "把内容快速收集到 AcMind") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("自动剪贴板采集", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("文本快速收集", isOn: $viewModel.companionCaptureTextEnabled)
                    Toggle("链接快速收集", isOn: $viewModel.companionCaptureLinkEnabled)
                }
            }

            saveButton
        }
    }

    private var saveButton: some View {
        HStack {
            Spacer()
            Button("保存") {
                Task {
                    await viewModel.saveSettings()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding(.top, 16)
    }
}

// MARK: - AI Models Settings Page

struct AIModelsSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingAddProvider = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "模型路由策略", description: "选择不同任务的默认路由方式") {
                HStack(spacing: 8) {
                    StrategyButton(title: "自动", subtitle: "智能选择最佳模型", icon: "wand.and.stars", selected: viewModel.modelRoutingStrategy == .automatic) {
                        viewModel.modelRoutingStrategy = .automatic
                        Task { await viewModel.saveSettings() }
                    }
                    StrategyButton(title: "优先本地", subtitle: "优先使用本地 AI / ASR", icon: "harddrive", selected: viewModel.modelRoutingStrategy == .localPriority) {
                        viewModel.modelRoutingStrategy = .localPriority
                        Task { await viewModel.saveSettings() }
                    }
                    StrategyButton(title: "优先云端", subtitle: "优先使用云端模型", icon: "cloud", selected: viewModel.modelRoutingStrategy == .cloudPriority) {
                        viewModel.modelRoutingStrategy = .cloudPriority
                        Task { await viewModel.saveSettings() }
                    }
                    StrategyButton(title: "低成本", subtitle: "优先选择低成本模型", icon: "coins", selected: viewModel.modelRoutingStrategy == .costPriority) {
                        viewModel.modelRoutingStrategy = .costPriority
                        Task { await viewModel.saveSettings() }
                    }
                    StrategyButton(title: "高质量", subtitle: "优先选择高质量模型", icon: "sparkles", selected: viewModel.modelRoutingStrategy == .qualityPriority) {
                        viewModel.modelRoutingStrategy = .qualityPriority
                        Task { await viewModel.saveSettings() }
                    }
                    StrategyButton(title: "隐私优先", subtitle: "优先本地处理", icon: "lock", selected: viewModel.modelRoutingStrategy == .privacyPriority) {
                        viewModel.modelRoutingStrategy = .privacyPriority
                        Task { await viewModel.saveSettings() }
                    }
                }
            }

            SettingsCard(title: "可用模型提供商", description: "启用并配置正在使用的提供商") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AI 提供商")
                            .font(.subheadline)
                        Spacer()
                        Button("+ 添加提供商") {
                            showingAddProvider = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if viewModel.providers.isEmpty {
                        Text("暂无提供商，请添加")
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.providers) { provider in
                                ProviderCard(provider: provider, onDelete: {
                                    Task {
                                        await viewModel.removeProvider(id: provider.id)
                                    }
                                })
                            }
                        }
                    }
                }
            }

            SettingsCard(title: "使用概览", description: "查看本地实时统计与已保存的提供商配置") {
                VStack(spacing: 16) {
                    HStack {
                        StatBox(label: "收集条目", value: "\(viewModel.usageSummary.sourceItems)", change: SettingsStatusLabelFormatter.localStorageText)
                        StatBox(label: "蒸馏笔记", value: "\(viewModel.usageSummary.distilledNotes)", change: SettingsStatusLabelFormatter.localStorageText)
                        StatBox(label: "导出记录", value: "\(viewModel.usageSummary.exportRecords)", change: SettingsStatusLabelFormatter.localStorageText)
                        StatBox(label: "剪贴板", value: "\(viewModel.usageSummary.clipboardItems)", change: SettingsStatusLabelFormatter.localStorageText)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("当前配置快照")
                                .font(.subheadline)
                            Spacer()
                            Text("实时")
                                .font(.caption)
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }

                        HStack(spacing: 10) {
                            StatBox(
                                label: "提供商",
                                value: "\(viewModel.usageSummary.providers)",
                                change: SettingsStatusLabelFormatter.configuredState(
                                    isConfigured: viewModel.usageSummary.providers != 0,
                                    configuredText: "已保存",
                                    unconfiguredText: SettingsStatusLabelFormatter.unconfiguredProviderText
                                )
                            )
                            StatBox(
                                label: "自动采集",
                                value: SettingsStatusLabelFormatter.binaryState(
                                    isEnabled: viewModel.autoCaptureClipboard,
                                    enabledText: "开",
                                    disabledText: "关"
                                ),
                                change: viewModel.autoCaptureClipboard ? "剪贴板" : "手动"
                            )
                            StatBox(
                                label: "语音润色",
                                value: SettingsStatusLabelFormatter.binaryState(
                                    isEnabled: viewModel.voiceAutoPolish,
                                    enabledText: "开",
                                    disabledText: "关"
                                ),
                                change: viewModel.voicePolishMode.displayName
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("用量风险")
                                .font(.subheadline)
                            Spacer()
                            Text(AIUsageBurnLabelFormatter.statusText(for: viewModel.usageBurnSnapshot))
                                .font(.caption)
                                .foregroundStyle(usageBurnColor(for: viewModel.usageBurnSnapshot.severity))
                        }

                        Text(AIUsageBurnLabelFormatter.summaryText(for: viewModel.usageBurnSnapshot))
                            .font(.caption)
                            .foregroundStyle(usageBurnColor(for: viewModel.usageBurnSnapshot.severity))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(AIUsageBurnLabelFormatter.detailText(for: viewModel.usageBurnSnapshot))
                            .font(.caption2)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(AIUsageBurnLabelFormatter.thresholdHintText())
                            .font(.caption2)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if viewModel.usageBurnSnapshot.windows.isEmpty == false {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(viewModel.usageBurnSnapshot.windows.enumerated()), id: \.offset) { _, window in
                                    HStack {
                                        Text(window.name)
                                            .font(.caption2)
                                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                                        Spacer()
                                        Text(AIUsageBurnLabelFormatter.windowText(for: window))
                                            .font(.caption2)
                                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                                            .monospacedDigit()
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.72))
                    .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
                }
            }

            saveButton
        }
        .sheet(isPresented: $showingAddProvider) {
            AddProviderSheet(viewModel: viewModel)
        }
    }

    private var saveButton: some View {
        HStack {
            Spacer()
            Button("保存") {
                Task {
                    await viewModel.saveSettings()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding(.top, 16)
    }
}

// MARK: - Data Knowledge Settings Page

struct DataKnowledgeSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "数据存储", description: "配置本地数据和附件存储位置") {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsPathRow(
                        title: "本地数据库位置",
                        path: viewModel.databaseDirectoryPath,
                        note: "数据库目录不可直接编辑，但可以复制或在 Finder 中查看。",
                        onCopy: {
                            copyToPasteboard(viewModel.databaseDirectoryPath)
                        },
                        onReveal: {
                            revealPathInFinder(viewModel.databaseDirectoryPath)
                        }
                    )

                    SettingsPathRow(
                        title: "附件存储位置",
                        path: viewModel.assetsDirectoryPath,
                        note: "附件目录保存截图、文件和导出内容，可以快速定位。",
                        onCopy: {
                            copyToPasteboard(viewModel.assetsDirectoryPath)
                        },
                        onReveal: {
                            revealPathInFinder(viewModel.assetsDirectoryPath)
                        }
                    )
                }
            }

            SettingsCard(title: "Obsidian 库", description: "配置 Obsidian 库集成") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("选择库文件夹", text: $viewModel.vaultPath)
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)

                            Button("选择...") {
                                Task {
                                    await viewModel.selectVaultPath()
                                }
                            }
                        }

                        if !viewModel.vaultPath.isEmpty {
                            HStack {
                                Image(systemName: viewModel.validateVaultPath() ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(viewModel.validateVaultPath() ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange)
                                Text(viewModel.validateVaultPath() ? "路径有效" : "路径无效")
                                    .font(.caption)
                                    .foregroundStyle(viewModel.validateVaultPath() ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange)
                            }
                        }
                    }

                    TextField("默认收件箱文件夹", text: $viewModel.vaultDefaultFolder)
                        .textFieldStyle(.roundedBorder)
                }
            }

            SettingsCard(title: "输出规则", description: "配置 Markdown 输出格式和规则") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("文件命名规则")
                            .font(.subheadline)

                        Picker("", selection: $viewModel.vaultPathRule) {
                            ForEach(VaultConfig.VaultPathRule.allCases, id: \.self) { rule in
                                Text(rule.displayName).tag(rule)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("冲突策略")
                            .font(.subheadline)

                        Picker("", selection: $viewModel.vaultConflictStrategy) {
                            ForEach(ConflictStrategy.allCases, id: \.self) { strategy in
                                Text(strategy.displayName).tag(strategy)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Toggle("自动添加元数据", isOn: $viewModel.autoFrontmatter)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("元数据模板（JSON）")
                            .font(.subheadline)

                        TextEditor(text: $viewModel.vaultFrontmatterTemplateText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
                    }
                }
            }

            SettingsCard(
                title: "备份与恢复",
                description: SettingsStatusLabelFormatter.backupSectionDescription(
                    autoBackupEnabled: viewModel.autoBackupEnabled
                )
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Button(SettingsStatusLabelFormatter.createBackupText) {
                        Task {
                            await viewModel.createBackup()
                        }
                    }
                        .buttonStyle(.bordered)

                    Button(SettingsStatusLabelFormatter.restoreBackupText) {
                        Task {
                            await viewModel.restoreBackup()
                        }
                    }
                        .buttonStyle(.bordered)

                    Toggle(SettingsStatusLabelFormatter.autoBackupText, isOn: $viewModel.autoBackupEnabled)

                    SettingsInfoRow(
                        label: "上次备份",
                        value: viewModel.lastBackupAtText
                    )

                    Text(
                        SettingsStatusLabelFormatter.backupTriggerText(
                            enabled: viewModel.autoBackupEnabled,
                            lastAutoBackupAt: viewModel.lastBackupAtDate
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }

            saveButton
        }
    }

    private var saveButton: some View {
        HStack {
            Spacer()
            Button("保存") {
                Task {
                    await viewModel.saveSettings()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding(.top, 16)
    }
}

// MARK: - Capture Input Settings Page

struct CaptureInputSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var cloudSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "com.acmind.cloudSync.enabled")
    @State private var cloudSyncSummary = CloudSyncStatusSummary(
        title: "云同步状态加载中",
        detail: "正在读取云同步状态。",
        canRetry: false,
        retryTitle: nil
    )
    private let cloudSyncService: CloudSyncServiceProtocol
    private static let screenshotNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        formatter.minimum = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    init(
        viewModel: SettingsViewModel,
        cloudSyncService: CloudSyncServiceProtocol = CloudSyncService(storage: StorageService())
    ) {
        self.viewModel = viewModel
        self.cloudSyncService = cloudSyncService
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "剪贴板捕获", description: "配置剪贴板自动采集") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("自动采集剪贴板", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("仅在激活应用时采集", isOn: $viewModel.captureOnlyWhenAppActive)
                }
            }

            SettingsCard(title: "云端同步", description: "查看数据同步状态") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用云端同步", isOn: $cloudSyncEnabled)
                        .onChange(of: cloudSyncEnabled) { _, newValue in
                            Task {
                                await cloudSyncService.setSyncEnabled(newValue)
                                await refreshCloudSyncSummary()
                            }
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(cloudSyncSummary.title)
                            .font(.headline)

                        Text(cloudSyncSummary.detail)
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 10) {
                        if cloudSyncSummary.canRetry, let retryTitle = cloudSyncSummary.retryTitle {
                            Button(retryTitle) {
                                Task {
                                    await cloudSyncService.sync()
                                    await refreshCloudSyncSummary()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button("刷新状态") {
                            Task {
                                await refreshCloudSyncSummary()
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Text(
                        SettingsStatusLabelFormatter.binaryState(
                            isEnabled: cloudSyncEnabled,
                            enabledText: "已开启：数据将通过 iCloud 同步",
                            disabledText: "已关闭：数据仅保存在本地"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }

            SettingsCard(title: "截图捕获", description: "配置截图和滚动截图设置") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用截图捕获", isOn: $viewModel.captureScreenshotEnabled)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("自动打码敏感内容", isOn: $viewModel.captureAutoRedactionEnabled)

                        if viewModel.captureAutoRedactionEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("打码模式")
                                    .font(.subheadline)

                                Picker("", selection: $viewModel.captureCensorMode) {
                                    ForEach(CensorMode.allCases, id: \.self) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                Text("截图会先在本地识别敏感内容，再按当前打码模式处理后保存。")
                                    .font(.caption)
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            Text("关闭后截图会直接保存，不再进行自动打码。")
                                .font(.caption)
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("截图捕获会受系统屏幕录制权限影响。")
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("截图外观")
                            .font(.subheadline)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("圆角")
                                    .font(.caption)
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                                TextField(
                                    "0",
                                    value: $viewModel.captureScreenshotCornerRadius,
                                    formatter: Self.screenshotNumberFormatter
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 90)
                                .layoutPriority(1)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("最大宽度")
                                    .font(.caption)
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                                TextField(
                                    "原始",
                                    value: $viewModel.captureScreenshotMaxWidth,
                                    formatter: Self.screenshotNumberFormatter
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 110)
                                .layoutPriority(1)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("最大高度")
                                    .font(.caption)
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                                TextField(
                                    "原始",
                                    value: $viewModel.captureScreenshotMaxHeight,
                                    formatter: Self.screenshotNumberFormatter
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 110)
                                .layoutPriority(1)
                            }

                            Button("恢复默认") {
                                viewModel.captureScreenshotCornerRadius = 0
                                viewModel.captureScreenshotMaxWidth = 0
                                viewModel.captureScreenshotMaxHeight = 0
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(AppSurfaceTokens.accentBlue)

                            Spacer()
                        }

                        Text("圆角和尺寸会在截图保存前直接作用到结果图，0 表示不限制。")
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            SettingsCard(title: "说入法结果", description: "配置转写后的自动润色方式") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用说入法输入", isOn: $viewModel.voiceInputEnabled)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("润色模式")
                            .font(.subheadline)

                        Picker("", selection: $viewModel.voicePolishMode) {
                            ForEach(VoicePolishMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()

                        if viewModel.voicePolishMode == .aiPrompt {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("提示词风格")
                                    .font(.caption)

                                Picker("", selection: $viewModel.aiPromptStyle) {
                                    ForEach(AIPromptStyle.allCases, id: \.self) { style in
                                        Text(style.displayName).tag(style)
                                    }
                                }
                                .labelsHidden()
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
            }

            SettingsCard(title: "隐私保护", description: "配置截图隐私打码") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("截图自动打码人脸、个人信息检测和打码模式已经接入截图保存流程。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Text("功能仍在持续完善。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                }
            }

            SettingsCard(title: "ASR 引擎", description: "选择语音识别引擎") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("识别引擎")
                        .font(.subheadline)

                    Picker("", selection: $viewModel.voiceDefaultProvider) {
                        ForEach(STTProvider.allCases, id: \.rawValue) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                    .labelsHidden()
                }
            }

            SettingsCard(title: "录音增强", description: "配置录音时的附加处理") {
                Toggle("录音结束后自动追加标点", isOn: $viewModel.enablePunctuationAppend)
            }

            SettingsCard(title: "高级注入设置", description: "配置转写结果的注入方式") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("注入策略")
                        .font(.subheadline)

                    Picker("", selection: $viewModel.injectionStrategy) {
                        Text("进程写入优先").tag("postToPid")
                        Text("剪贴板优先").tag("clipboard")
                    }
                    .labelsHidden()
                }
            }

            SettingsCard(title: "语言", description: "配置语音识别与翻译目标语言") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("首选语言")
                        .font(.subheadline)

                    Picker("", selection: $viewModel.preferredLanguage) {
                        Text("自动").tag("auto")
                        Text("中文").tag("zh")
                        Text("英文").tag("en")
                        Text("日文").tag("ja")
                    }
                    .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("翻译目标")
                        .font(.subheadline)

                    Picker("", selection: $viewModel.translationLanguage) {
                        Text("中文").tag("zh")
                        Text("英文").tag("en")
                        Text("日文").tag("ja")
                        Text("韩文").tag("ko")
                    }
                    .labelsHidden()
                }
            }

            saveButton
        }
        .task {
            await refreshCloudSyncSummary()
        }
    }

    @MainActor
    private func refreshCloudSyncSummary() async {
        cloudSyncEnabled = await cloudSyncService.isSyncEnabled()
        let status = await cloudSyncService.getSyncStatus()
        cloudSyncSummary = CloudSyncStatusSummary.make(from: status)
    }

    private var saveButton: some View {
        HStack {
            Spacer()
            Button("保存") {
                Task {
                    await viewModel.saveSettings()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding(.top, 16)
    }
}

// MARK: - Security Settings Page

struct SecuritySettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "系统权限", description: "管理 AcMind 需要的系统权限") {
                VStack(spacing: 12) {
                    PermissionRow(
                        title: "麦克风",
                        description: "用于说入法输入",
                        status: viewModel.microphoneStatus,
                        onRequest: {
                            Task {
                                await viewModel.requestPermission(.microphone)
                            }
                        },
                        onOpenSettings: {
                            Task {
                                await viewModel.openSystemPreferences(for: .microphone)
                            }
                        }
                    )

                    PermissionRow(
                        title: "屏幕录制",
                        description: "用于截图功能",
                        status: viewModel.screenRecordingStatus,
                        onRequest: {
                            Task {
                                await viewModel.requestPermission(.screenRecording)
                            }
                        },
                        onOpenSettings: {
                            Task {
                                await viewModel.openSystemPreferences(for: .screenRecording)
                            }
                        }
                    )

                    PermissionRow(
                        title: "辅助功能",
                        description: "用于全局快捷键",
                        status: viewModel.accessibilityStatus,
                        onRequest: {
                            Task {
                                await viewModel.requestPermission(.accessibility)
                            }
                        },
                        onOpenSettings: {
                            Task {
                                await viewModel.openSystemPreferences(for: .accessibility)
                            }
                        }
                    )

                    PermissionRow(
                        title: "完全磁盘访问",
                        description: "用于访问库文件夹",
                        status: viewModel.fullDiskAccessStatus,
                        onRequest: {
                            Task {
                                await viewModel.requestPermission(.fullDiskAccess)
                            }
                        },
                        onOpenSettings: {
                            Task {
                                await viewModel.openSystemPreferences(for: .fullDiskAccess)
                            }
                        }
                    )

                    PermissionRow(
                        title: "通知",
                        description: "用于任务完成提醒",
                        status: viewModel.notificationsStatus,
                        onRequest: {
                            Task {
                                await viewModel.requestPermission(.notifications)
                            }
                        },
                        onOpenSettings: {
                            Task {
                                await viewModel.openSystemPreferences(for: .notifications)
                            }
                        }
                    )

                    Text(AppNotificationService.strategySummary)
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsCard(title: "隐私安全", description: "配置隐私相关设置") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("本地优先模式", isOn: $viewModel.localFirstMode)
                    Toggle("敏感内容不上传云端", isOn: $viewModel.sensitiveContentNotUpload)
                    Toggle("API 密钥使用钥匙串存储", isOn: $viewModel.apiKeyUsesKeychain)
                }
            }

            SettingsCard(title: "日志", description: "管理应用日志") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("AI 调用日志", isOn: $viewModel.aiCallLogEnabled)
                        Toggle("错误日志", isOn: $viewModel.errorLogEnabled)
                    }

                    Button("打开日志文件夹") {
                        viewModel.openLogsFolder()
                    }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            saveButton
        }
    }

    private var saveButton: some View {
        HStack {
            Spacer()
            Button("保存") {
                Task {
                    await viewModel.saveSettings()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding(.top, 16)
    }
}

// MARK: - About Settings Page

struct AboutSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "关于 AcMind", description: "AcMind - AI 驱动的知识助手") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .foregroundStyle(AppSurfaceTokens.accentBlue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AcMind")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("AI 驱动的知识助手")
                                .font(.caption)
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Text("版本 \(viewModel.diagnosticAppVersionString)")
                                .font(.caption)
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                    }

                    Divider()

                    HStack(spacing: 16) {
                        Button(viewModel.isCheckingForUpdates ? "检查中..." : "检查更新") {
                            Task {
                                await viewModel.checkForUpdates()
                            }
                        }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isCheckingForUpdates)
                        Button("帮助与反馈") {
                            viewModel.openFeedbackPage()
                        }
                            .buttonStyle(.bordered)
                        Button("开源许可") {
                            viewModel.openLicensePage()
                        }
                            .buttonStyle(.bordered)
                    }
                }
            }

            SettingsCard(title: "状态入口", description: "完整本机状态集中到主侧边栏的「状态」") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("这里不再展示诊断看板，只保留跳转。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Button("查看状态") {
                        (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            SettingsCard(title: "支持", description: "获取帮助和支持") {
                VStack(alignment: .leading, spacing: 8) {
                    Link("官方文档", destination: URL(string: "https://github.com/huen96-Lichen/AcMind")!)
                    Link("常见问题", destination: URL(string: "https://github.com/huen96-Lichen/AcMind/issues")!)
                    Link("联系支持", destination: URL(string: "https://github.com/huen96-Lichen/AcMind/issues/new")!)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct SettingsShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
                .font(.body)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct ShortcutConfigRow: View {
    let action: String
    @Binding var shortcut: String
    let onRecord: () -> Void

    var body: some View {
        HStack {
            Text(action)
                .font(.body)
            Spacer()
            HStack(spacing: 8) {
                Text(shortcut)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppSurfaceTokens.cardBackgroundSoft)
                    .cornerRadius(4)
                Button("录制", action: onRecord)
                    .controlSize(.small)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PositionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.cardBackgroundSoft)
            .foregroundStyle(isSelected ? .white : AppSurfaceTokens.primaryText)
            .cornerRadius(6)
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .regular)
    }
}

struct StrategyButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .padding(12)
            .background(selected ? AppSurfaceTokens.accentBlue.opacity(0.1) : AppSurfaceTokens.cardBackgroundSoft)
            .foregroundStyle(selected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.primaryText)
            .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
            .frame(width: 90)
        }
        .buttonStyle(.plain)
    }
}

struct ProviderCard: View {
    let provider: ProviderConfig
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(provider.name)
                        .font(.body)
                        .fontWeight(.medium)
                    if provider.enabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppSurfaceTokens.accentGreen)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
                HStack(spacing: 8) {
                    Text(provider.providerType.displayName)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Text("模型：\(provider.modelId)")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button("管理配置") {
                    if let url = URL(string: provider.baseURL), !provider.baseURL.isEmpty {
                        NSWorkspace.shared.open(url)
                    } else {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(provider.modelId, forType: .string)
                    }
                }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("删除") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(AppSurfaceTokens.accentOrange)
            }
        }
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let change: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(change)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.accentGreen)
        }
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
        .frame(maxWidth: .infinity)
    }
}

struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.caption)
        }
    }
}

struct SettingsPathRow: View {
    let title: String
    let path: String
    let note: String
    let onCopy: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Button("复制") {
                    onCopy()
                }
                .buttonStyle(.borderless)

                Button("显示") {
                    onReveal()
                }
                .buttonStyle(.borderless)
            }

            Text(path)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(AppSurfaceTokens.inlineBlockRadius)

            Text(note)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: AppPermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()

            HStack(spacing: 8) {
                StatusBadge(status: status)

                switch status {
                case .unknown, .notDetermined:
                    Button("申请") {
                        onRequest()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                case .requesting:
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)

                case .denied, .restricted, .needsSystemSettings, .failed:
                    Button("去设置") {
                        onOpenSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                case .authorized:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppSurfaceTokens.accentGreen)
                }
            }
        }
    }
}

private func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

private func revealPathInFinder(_ path: String) {
    let url = URL(fileURLWithPath: path)
    NSWorkspace.shared.activateFileViewerSelecting([url])
}

struct StatusBadge: View {
    let status: AppPermissionStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .unknown: return AppSurfaceTokens.secondaryText.opacity(0.16)
        case .notDetermined, .requesting: return AppSurfaceTokens.accentOrange.opacity(0.18)
        case .denied, .restricted, .needsSystemSettings, .failed: return AppSurfaceTokens.accentOrange.opacity(0.22)
        case .authorized: return AppSurfaceTokens.accentGreen.opacity(0.18)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .unknown: return AppSurfaceTokens.secondaryText
        case .notDetermined, .requesting: return AppSurfaceTokens.accentOrange
        case .denied, .restricted, .needsSystemSettings, .failed: return AppSurfaceTokens.accentOrange
        case .authorized: return AppSurfaceTokens.accentGreen
        }
    }
}

// MARK: - Add Provider Sheet

struct AddProviderSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var providerType: ProviderType = .ollama
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var modelId = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("添加提供商")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("名称", text: $name)
                Picker("类型", selection: $providerType) {
                    ForEach(ProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("基础地址", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("API 密钥", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                TextField("默认模型", text: $modelId)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("添加") {
                    let config = ProviderConfig(
                        name: name,
                        providerType: providerType,
                        baseURL: baseURL,
                        modelId: modelId
                    )
                    Task {
                        await viewModel.addProvider(config, apiKey: apiKey)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || baseURL.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
