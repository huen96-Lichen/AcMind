import SwiftUI
import AppKit
import AcMindKit

// MARK: - 设置分类（新）

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
        case .aiModels: return "智能与模型"
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
    case .none: return AppSurfaceTokens.secondaryText
    case .info: return AppSurfaceTokens.secondaryText
    case .warning: return AppSurfaceTokens.accentOrange
    case .critical: return .red
    }
}

// MARK: - 设置视图

struct SettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var viewModel: SettingsViewModel
    @State private var selectedCategory: SettingsCategory
    @State private var searchQuery: String
    @State private var recordingShortcutTarget: ShortcutRecordingTarget?
    @FocusState private var searchFieldFocused: Bool
    private let cloudSyncService: CloudSyncServiceProtocol

    init(
        viewModel: SettingsViewModel = SettingsViewModel(),
        cloudSyncService: CloudSyncServiceProtocol = CloudSyncService(storage: StorageService()),
        initialCategory: SettingsCategory = .general,
        initialSearchQuery: String = ""
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _selectedCategory = State(initialValue: initialCategory)
        _searchQuery = State(initialValue: initialSearchQuery)
        self.cloudSyncService = cloudSyncService
    }

    var body: some View {
        AcWorkShell(
            title: "设置",
            subtitle: "管理应用偏好",
            searchContent: AnyView(
                AcSearchField(
                    text: $searchQuery,
                    placeholder: "搜索设置...",
                    width: 260,
                    focusBinding: $searchFieldFocused
                )
            ),
            compactToolbar: true,
            leadingRailWidth: 208,
            trailingRailWidth: 0,
            leadingRail: { settingsSidebar },
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if settingsSearchQuery.isEmpty == false {
                            settingsSearchResultsPanel
                                .padding(.bottom, AppSurfaceTokens.Spacing.lg)
                        }

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
                            CaptureInputSettingsPage(
                                viewModel: viewModel,
                                recordingShortcutTarget: $recordingShortcutTarget,
                                cloudSyncService: cloudSyncService
                            )
                        case .security:
                            SecuritySettingsPage(viewModel: viewModel)
                        case .about:
                            AboutSettingsPage(viewModel: viewModel)
                        }
                    }
                    .padding(AppSurfaceTokens.Spacing.xl)
                    .frame(maxWidth: 920, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
            },
            trailingRail: { EmptyView() }
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
        .background(searchKeyboardShortcut)
        .onAppear {
            consumePendingSettingsCategory()
        }
        .onChange(of: appState.pendingSettingsCategory) { _, _ in
            consumePendingSettingsCategory()
        }
        .onChange(of: settingsSearchQuery) { _, newValue in
            if let matchedCategory = SettingsSearchCatalog.bestCategory(for: newValue) {
                selectedCategory = matchedCategory
            }
        }
    }

    private var settingsSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func consumePendingSettingsCategory() {
        guard let category = appState.pendingSettingsCategory else { return }
        selectedCategory = category
        appState.pendingSettingsCategory = nil
    }

    private var searchKeyboardShortcut: some View {
        Button("搜索设置") {
            searchFieldFocused = true
        }
        .keyboardShortcut("f", modifiers: .command)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSurfaceTokens.Spacing.xs) {
                    ForEach(SettingsCategory.allCases) { category in
                        SettingsNavigationRow(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(AppSurfaceTokens.Spacing.sm)
            }
        }
        .background(AppSurfaceTokens.contentBackground)
    }

    private var settingsSearchResultsPanel: some View {
        let results = SettingsSearchCatalog.results(for: settingsSearchQuery)

        return AppSurfaceCard(
            title: "搜索结果",
            subtitle: results.isEmpty ? "没有匹配项" : "定位到 \(results.count) 个设置项",
            padding: 14
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if results.isEmpty {
                    Text("没有找到匹配的设置项。可以试试“主题”、“快捷键”、“权限”或“备份”。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(results.prefix(6)) { result in
                        Button {
                            selectedCategory = result.category
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(result.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppSurfaceTokens.primaryText)
                                    Spacer()
                                    Text(result.category.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                                }

                                Text(result.summary)
                                    .font(.caption2)
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(2)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: selectedCategory.displayName,
                description: selectedCategory.description,
                status: settingsSearchQuery.isEmpty ? nil : "搜索：\(settingsSearchQuery)"
            )

            HStack(spacing: 12) {
                MetricCard(
                    label: "当前分类",
                    primaryValue: selectedCategory.displayName,
                    trend: selectedCategory.description,
                    state: settingsSearchQuery.isEmpty ? "浏览" : "搜索",
                    tint: AppSurfaceTokens.accentBlue
                ) {
                    Image(systemName: selectedCategory.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                }

                StateContainer(phase: .ready) {
                    Text("可从菜单栏「AcMind→截图」、首页「截图」、侧栏「截图」、截图工作区、随身快捷键和胶囊打开。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.bottom, 20)
    }

}

private struct SettingsNavigationRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSurfaceTokens.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(AppSurfaceTokens.accentBlue.opacity(isSelected ? 0.14 : 0.08))

                    Image(systemName: category.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)

                    Text(category.description)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText.opacity(isSelected || isHovered ? 0.8 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(rowBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
        .accessibilityLabel("\(category.displayName)，\(category.description)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: Color {
        if isSelected {
            return AppSurfaceTokens.accentBlue.opacity(0.10)
        }
        if isHovered {
            return AppSurfaceTokens.separator.opacity(0.18)
        }
        return .clear
    }
}

struct SettingsSearchResult: Identifiable {
    let id = UUID()
    let category: SettingsCategory
    let title: String
    let summary: String
    let keywords: [String]
}

enum SettingsSearchCatalog {
    private static let resultsCatalog: [SettingsSearchResult] = [
        .init(category: .general, title: "外观", summary: "主题、语言和启动时的视觉偏好。", keywords: ["外观", "主题", "语言", "启动"]),
        .init(category: .general, title: "启动行为", summary: "开机显示、窗口恢复和首屏行为。", keywords: ["启动", "窗口", "恢复"]),
        .init(category: .general, title: "通知", summary: "任务完成、更新提醒和通知开关。", keywords: ["通知", "提醒", "消息"]),
        .init(category: .general, title: "快捷键总览", summary: "最常用能力的快速总览。", keywords: ["快捷键", "总览"]),
        .init(category: .companion, title: "随身胶囊", summary: "胶囊位置、展开状态和启动显示。", keywords: ["胶囊", "随身", "位置"]),
        .init(category: .companion, title: "说入法", summary: "语音输入方式、输出和收集行为。", keywords: ["说入法", "语音", "输入", "输出"]),
        .init(category: .companion, title: "随身快捷键", summary: "录制说入法、收集、截图和日程快捷键。", keywords: ["快捷键", "录制", "截图", "日程"]),
        .init(category: .companion, title: "随身捕获", summary: "剪贴板、文本和链接的快速收集。", keywords: ["捕获", "剪贴板", "链接", "文本"]),
        .init(category: .aiModels, title: "模型路由策略", summary: "自动、本地优先、云端优先和成本/质量策略。", keywords: ["模型", "路由", "策略", "本地", "云端"]),
        .init(category: .aiModels, title: "可用模型提供商", summary: "启用、添加和删除当前提供商。", keywords: ["提供商", "模型", "添加", "删除"]),
        .init(category: .aiModels, title: "使用总览", summary: "本地统计、当前快照和用量风险。", keywords: ["使用", "总览", "风险", "用量"]),
        .init(category: .dataKnowledge, title: "数据存储", summary: "数据库和附件目录。", keywords: ["数据", "存储", "数据库", "附件"]),
        .init(category: .dataKnowledge, title: "知识库", summary: "库路径、默认文件夹和路径校验。", keywords: ["库", "路径", "文件夹"]),
        .init(category: .dataKnowledge, title: "输出规则", summary: "文件命名、冲突策略和前置元数据。", keywords: ["输出", "规则", "命名", "冲突", "模板"]),
        .init(category: .dataKnowledge, title: "备份与恢复", summary: "创建、恢复和自动备份状态。", keywords: ["备份", "恢复", "自动"]),
        .init(category: .captureInput, title: "剪贴板捕获", summary: "自动采集和激活应用限制。", keywords: ["剪贴板", "捕获", "自动"]),
        .init(category: .captureInput, title: "云端同步", summary: "同步状态、启用开关和重试。", keywords: ["云", "同步", "icloud"]),
        .init(category: .captureInput, title: "截图捕获", summary: "自动打码、尺寸和圆角。", keywords: ["截图", "打码", "圆角"]),
        .init(category: .captureInput, title: "说入法结果", summary: "润色模式和提示词风格。", keywords: ["说入法", "润色", "提示词"]),
        .init(category: .captureInput, title: "语音识别引擎", summary: "语音识别引擎选择。", keywords: ["asr", "引擎", "识别"]),
        .init(category: .security, title: "系统权限", summary: "麦克风、屏幕录制、辅助功能和通知。", keywords: ["权限", "麦克风", "录屏", "辅助功能", "通知"]),
        .init(category: .security, title: "隐私安全", summary: "本地优先、敏感内容不上传和钥匙串。", keywords: ["隐私", "安全", "本地", "上传", "钥匙串"]),
        .init(category: .security, title: "日志", summary: "智能调用和错误日志开关。", keywords: ["日志", "错误", "调用"]),
        .init(category: .about, title: "关于 AcWork", summary: "版本、更新、许可和支持入口。", keywords: ["关于", "版本", "支持", "许可", "帮助"])
    ]

    static func results(for query: String) -> [SettingsSearchResult] {
        let normalizedQuery = query.lowercased()
        guard normalizedQuery.isEmpty == false else { return [] }

        return resultsCatalog.filter { result in
            result.title.lowercased().contains(normalizedQuery)
            || result.summary.lowercased().contains(normalizedQuery)
            || result.keywords.contains(where: { $0.lowercased().contains(normalizedQuery) })
        }
    }

    static func bestCategory(for query: String) -> SettingsCategory? {
        let normalizedQuery = query.lowercased()
        guard normalizedQuery.isEmpty == false else { return nil }

        let scored = resultsCatalog.reduce(into: [SettingsCategory: Int]()) { scores, result in
            var score = 0
            if result.title.lowercased().contains(normalizedQuery) { score += 3 }
            if result.summary.lowercased().contains(normalizedQuery) { score += 1 }
            score += result.keywords.filter { $0.lowercased().contains(normalizedQuery) }.count * 2
            scores[result.category, default: 0] += score
        }

        return scored.max { lhs, rhs in lhs.value < rhs.value }?.key
    }
}

struct LivePreviewPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let tone: StatusBadgeTone
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, tone: StatusBadgeTone, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        AppSurfaceCard(title: title, subtitle: subtitle, padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                StatusBadge(text: subtitle, tone: tone, compact: true)
                content
            }
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }
}

// MARK: - 快捷键录制器

enum ShortcutRecordingTarget: String, Identifiable {
    case appScreenshotHotkey
    case voiceShortcut
    case captureShortcut
    case screenshotShortcut
    case agentShortcut
    case scheduleShortcut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appScreenshotHotkey: return "录制全局截图热键"
        case .voiceShortcut: return "录制说入法快捷键"
        case .captureShortcut: return "录制快速收集快捷键"
        case .screenshotShortcut: return "录制截图捕获快捷键"
        case .agentShortcut: return "录制智能体快捷键"
        case .scheduleShortcut: return "录制今日日程快捷键"
        }
    }

    @MainActor
    func apply(shortcut: String, on viewModel: SettingsViewModel) {
        switch self {
        case .appScreenshotHotkey:
            viewModel.captureScreenshotHotkey = shortcut
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
                        .stroke(AppSurfaceTokens.separator.opacity(0.92), lineWidth: 1)
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

// MARK: - 设置分类说明

extension SettingsCategory {
    var description: String {
        switch self {
        case .general: return "配置 AcWork 的基础偏好"
        case .companion: return "设置随身胶囊、语音和快捷键"
        case .aiModels: return "管理提供商、模型选择和使用统计"
        case .dataKnowledge: return "配置数据存储、库和知识库"
        case .captureInput: return "设置剪贴板、截图和说入法"
        case .security: return "管理权限、隐私和安全"
        case .about: return "查看版本信息、帮助和反馈"
        }
    }
}

// MARK: - 设置卡片视图（用于卡片式布局）

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
    }
}

// MARK: - 通用设置页

struct GeneralSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "外观", description: "调整 AcWork 的视觉风格") {
                VStack(alignment: .leading, spacing: 12) {
                    AcSettingRow(title: "主题", description: "调整 AcWork 的视觉风格") {
                        AcSegmentedControl(
                            options: AppTheme.allCases,
                            selection: $viewModel.theme
                        ) { $0.displayName }
                        .frame(maxWidth: 240)
                    }

                    AcSettingRow(title: "语言", description: "界面显示语言") {
                        AcSegmentedControl(
                            options: ["zh-CN", "en"],
                            selection: $viewModel.language
                        ) { $0 == "zh-CN" ? "简体中文" : "英文" }
                        .frame(maxWidth: 240)
                    }
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

            SettingsCard(title: "快捷键总览", description: "查看常用快捷键") {
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
            AcActionButton(title: "保存", icon: "checkmark", isLoading: viewModel.isLoading) {
                Task {
                    await viewModel.saveSettings()
                }
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - 随身能力设置页

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

            SettingsCard(title: "说入法", description: "长按 Fn 唤起，选择输出落点与收集行为") {
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
                    ShortcutConfigRow(action: "说入法", shortcut: $viewModel.companionVoiceShortcut) {
                        recordingShortcutTarget = .voiceShortcut
                    }
                    ShortcutConfigRow(action: "快速收集", shortcut: $viewModel.companionCaptureShortcut) {
                        recordingShortcutTarget = .captureShortcut
                    }
                    ShortcutConfigRow(action: "截图捕获", shortcut: $viewModel.companionScreenshotShortcut) {
                        recordingShortcutTarget = .screenshotShortcut
                    }
                    ShortcutConfigRow(action: "打开智能体", shortcut: $viewModel.companionAgentShortcut) {
                        recordingShortcutTarget = .agentShortcut
                    }
                    ShortcutConfigRow(action: "今日日程", shortcut: $viewModel.companionScheduleShortcut) {
                        recordingShortcutTarget = .scheduleShortcut
                    }
                }
            }

            SettingsCard(title: "随身捕获", description: "把内容快速收集到 AcWork") {
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

// MARK: - AI 模型设置页

struct AIModelsSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingAddProvider = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "就绪总览", description: "把模型和语音入口放在一起看") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        statusTile(
                            title: "默认智能",
                            value: viewModel.defaultProviderId.isEmpty ? "未配置" : viewModel.defaultProviderId,
                            subtitle: viewModel.providers.first(where: { $0.id == viewModel.defaultProviderId })?.name ?? "当前默认智能提供商",
                            tint: viewModel.defaultProviderId.isEmpty ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.accentBlue
                        )

                        statusTile(
                            title: "默认语音",
                            value: asrDisplayName(for: viewModel.voiceDefaultProvider),
                            subtitle: "说入法当前识别引擎",
                            tint: AppSurfaceTokens.accentGreen
                        )

                        statusTile(
                            title: "模型策略",
                            value: viewModel.modelRoutingStrategy.displayName,
                            subtitle: "当前路由优先级",
                            tint: AppSurfaceTokens.secondaryText
                        )
                    }

                    HStack(spacing: 8) {
                        Button {
                            AppState.shared.navigate(to: .modelManagement)
                        } label: {
                            Label("打开模型管理", systemImage: "square.stack.3d.up")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            AppState.shared.navigate(to: .voiceEntry)
                        } label: {
                            Label("打开说入法", systemImage: "waveform")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            AppState.shared.navigate(to: .workbench, workbenchToolRoute: .apiTest)
                        } label: {
                            Label("验证接口", systemImage: "checkmark.shield")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            AppState.shared.navigate(to: .settings)
                        } label: {
                            Label("查看设置首页", systemImage: "gearshape")
                        }
                        .buttonStyle(.bordered)

                        Spacer(minLength: 0)
                    }
                }
            }

            SettingsCard(title: "模型路由策略", description: "选择不同任务的默认路由方式") {
                HStack(spacing: 8) {
                    StrategyButton(title: "自动", subtitle: "智能选择最佳模型", icon: "wand.and.stars", selected: viewModel.modelRoutingStrategy == .automatic) {
                        viewModel.modelRoutingStrategy = .automatic
                        Task { await viewModel.saveSettings() }
                    }
                    StrategyButton(title: "优先本地", subtitle: "优先使用本地智能 / 语音识别", icon: "harddrive", selected: viewModel.modelRoutingStrategy == .localPriority) {
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
                        Text("智能提供商")
                            .font(.subheadline)
                        Spacer()
                        Button("+ 添加提供商") {
                            showingAddProvider = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if viewModel.providers.isEmpty {
                        Text("暂无提供商，请先添加")
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

            SettingsCard(title: "使用总览", description: "查看本地实时统计与已保存的提供商配置") {
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
                    .background(AppSurfaceTokens.cardBackgroundSoft)
                    .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
                }
            }

            PluginManagementSettingsSection()

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

    private func statusTile(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
    }

    private func asrDisplayName(for providerID: String) -> String {
        STTProvider(rawValue: STTProvider.selectableIdentifier(from: providerID))?.displayName ?? "系统听写"
    }
}

private struct PluginManagementSettingsSection: View {
    @State private var pluginSummaries: [PluginManagementSummary] = []
    @State private var isLoadingPluginSummaries = false

    var body: some View {
        SettingsCard(title: "插件扩展", description: "查看语音识别、润色与注入扩展的运行状态") {
            VStack(alignment: .leading, spacing: AppSurfaceTokens.Spacing.sm) {
                HStack(spacing: AppSurfaceTokens.Spacing.sm) {
                    Text(pluginSummaryHeadline)
                        .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    Spacer(minLength: 0)

                    Button {
                        Task { await loadPluginSummaries() }
                    } label: {
                        Label(isLoadingPluginSummaries ? "刷新中" : "刷新插件", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isLoadingPluginSummaries)
                }

                if isLoadingPluginSummaries && pluginSummaries.isEmpty {
                    ProgressView("正在读取插件状态…")
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
                } else if pluginSummaries.isEmpty {
                    Text("尚未发现插件。安装扩展后，它们会显示在这里。")
                        .font(.system(size: AppSurfaceTokens.Typography.body))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(pluginSummaries.enumerated()), id: \.element.id) { index, summary in
                            pluginSummaryRow(summary)

                            if index < pluginSummaries.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadPluginSummaries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pluginManagerDidChange)) { _ in
            Task { await loadPluginSummaries() }
        }
    }

    private var pluginSummaryHeadline: String {
        guard pluginSummaries.isEmpty == false else {
            return isLoadingPluginSummaries ? "正在读取插件状态" : "没有已安装的插件"
        }

        let activeCount = pluginSummaries.filter { $0.status == .active }.count
        let errorCount = pluginSummaries.filter { $0.status == .error }.count
        return errorCount == 0
            ? "\(pluginSummaries.count) 个插件，\(activeCount) 个运行中"
            : "\(pluginSummaries.count) 个插件，\(errorCount) 个需要处理"
    }

    private func pluginSummaryRow(_ summary: PluginManagementSummary) -> some View {
        HStack(alignment: .top, spacing: AppSurfaceTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: AppSurfaceTokens.Spacing.xxs) {
                Text(summary.name)
                    .font(.system(size: AppSurfaceTokens.Typography.rowTitle, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text(pluginPolicySummary(summary.policy))
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(2)

                if let errorMessage = summary.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: AppSurfaceTokens.Typography.caption))
                        .foregroundStyle(AppSurfaceTokens.accentOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            StatusBadge(text: summary.status.displayName, tone: pluginStatusTone(summary.status))
        }
        .padding(.vertical, AppSurfaceTokens.Spacing.xs)
    }

    private func pluginStatusTone(_ status: PluginStatus) -> StatusBadgeTone {
        switch status {
        case .active: return .success
        case .loading: return .info
        case .discovered: return .warning
        case .inactive: return .neutral
        case .error: return .danger
        }
    }

    private func pluginPolicySummary(_ policy: PluginSandboxPolicySnapshot) -> String {
        let capabilities = policy.permissionLabels.isEmpty ? "无额外权限" : policy.permissionLabels.joined(separator: "、")
        return "\(capabilities) · 内存 \(policy.resourceLimits.memoryMB) MB · CPU \(policy.resourceLimits.cpuPercent)%"
    }

    private func loadPluginSummaries() async {
        isLoadingPluginSummaries = true
        defer { isLoadingPluginSummaries = false }
        pluginSummaries = await PluginManager.shared.getManagementSummaries()
    }
}

// MARK: - 数据与知识设置页

struct DataKnowledgeSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "文档处理总览", description: "网页精读、文档转换和文字识别的就绪状态") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        statusTile(
                            title: "网页精读",
                            value: commandReadyText(for: "defuddle"),
                            subtitle: "defuddle / markitdown",
                            tint: commandReadyTint(for: ["defuddle", "markitdown"])
                        )

                        statusTile(
                            title: "文档转换",
                            value: "可用",
                            subtitle: "PDFKit / textutil / markitdown",
                            tint: AppSurfaceTokens.accentGreen
                        )

                        statusTile(
                            title: "文字识别",
                            value: "可用",
                            subtitle: "Vision OCR / 识别结果回写",
                            tint: AppSurfaceTokens.accentBlue
                        )
                    }

                    HStack(spacing: 8) {
                        Button {
                            AppState.shared.navigate(to: .workbench, workbenchToolRoute: .webDigest)
                        } label: {
                            Label("打开网页精读", systemImage: "globe")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            AppState.shared.navigate(to: .workbench, workbenchToolRoute: .documentConvert)
                        } label: {
                            Label("打开文档转换", systemImage: "doc.text")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            AppState.shared.navigate(to: .workbench, workbenchToolRoute: .ocr)
                        } label: {
                            Label("打开文字识别", systemImage: "text.viewfinder")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            AppState.shared.navigate(to: .workbench)
                        } label: {
                            Label("打开工具台", systemImage: "wrench.and.screwdriver")
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("这些入口覆盖网页正文提取、文件转文稿、图片文字识别和批量下载能力。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsCard(title: "数据存储", description: "配置本地数据和附件存储位置") {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsPathRow(
                        title: "本地数据库位置",
                        path: viewModel.databaseDirectoryPath,
                        note: "数据库目录不可直接编辑，但可以复制或在访达中查看。",
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

            SettingsCard(title: "知识库", description: "配置知识库集成") {
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
                                    .foregroundStyle(viewModel.validateVaultPath() ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.accentOrange)
                                Text(viewModel.validateVaultPath() ? "路径有效" : "路径无效")
                                    .font(.caption)
                                    .foregroundStyle(viewModel.validateVaultPath() ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.accentOrange)
                            }
                        }
                    }

                    TextField("默认收件箱文件夹", text: $viewModel.vaultDefaultFolder)
                        .textFieldStyle(.roundedBorder)
                }
            }

            SettingsCard(title: "输出规则", description: "配置文稿输出格式和规则") {
                VStack(alignment: .leading, spacing: 12) {
                    AcSettingRow(title: "文件命名规则", description: "决定导出文件的命名方式", isStacked: true) {
                        AcSegmentedControl(
                            options: VaultConfig.VaultPathRule.allCases,
                            selection: $viewModel.vaultPathRule
                        ) { $0.displayName }
                    }

                    AcSettingRow(title: "冲突策略", description: "同名文件存在时如何处理", isStacked: true) {
                        AcSegmentedControl(
                            options: ConflictStrategy.allCases,
                            selection: $viewModel.vaultConflictStrategy
                        ) { $0.displayName }
                    }

                    Toggle("自动添加元数据", isOn: $viewModel.autoFrontmatter)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("元数据头模板（JSON）")
                            .font(.subheadline)

                        AppSurfaceTextEditorShell(text: $viewModel.vaultFrontmatterTemplateText, minHeight: 120)
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

    private func statusTile(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
    }

    private func commandReadyText(for command: String) -> String {
        commandExists(named: command) ? "已就绪" : "未检测到"
    }

    private func commandReadyTint(for commands: [String]) -> Color {
        commands.contains(where: { commandExists(named: $0) }) ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange
    }

    private func commandExists(named name: String) -> Bool {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        if candidates.contains(where: { fm.isExecutableFile(atPath: $0) }) {
            return true
        }
        guard let pathValue = ProcessInfo.processInfo.environment["PATH"] else { return false }
        return pathValue.split(separator: ":").contains { component in
            fm.isExecutableFile(atPath: URL(fileURLWithPath: String(component)).appendingPathComponent(name).path)
        }
    }
}

// MARK: - 捕获输入设置页

struct CaptureInputSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var recordingShortcutTarget: ShortcutRecordingTarget?
    @State private var cloudSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "com.acmind.cloudSync.enabled")
    @State private var cloudSyncSummary = CloudSyncStatusSummary(
        title: "云同步状态",
        detail: "云同步状态加载中。",
        canRetry: false,
        retryTitle: nil
    )
    @FocusState private var isEditingScreenshotPresetName: Bool
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
        recordingShortcutTarget: Binding<ShortcutRecordingTarget?>,
        cloudSyncService: CloudSyncServiceProtocol = CloudSyncService(storage: StorageService())
    ) {
        self.viewModel = viewModel
        self._recordingShortcutTarget = recordingShortcutTarget
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

            SettingsCard(title: "截图捕获", description: "配置截图与滚动截图行为") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Button("打开截图工作区") {
                            (NSApp.delegate as? AppDelegate)?.showScreenshotOptionsPanel()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("打开截图历史") {
                            AppState.shared.navigate(to: .screenshotHistory)
                        }
                        .buttonStyle(.bordered)

                        Text("可从菜单栏「AcWork→截图」、首页「截图」、侧栏「截图」、截图工作区、随身快捷键和胶囊打开。")
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("截图预设")
                                .font(.subheadline)
                            Spacer()
                            Picker("", selection: $viewModel.selectedScreenshotPresetID) {
                                ForEach(viewModel.screenshotPresets) { preset in
                                    Text(preset.name).tag(preset.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .onChange(of: viewModel.selectedScreenshotPresetID) { _, newValue in
                                viewModel.selectScreenshotPreset(id: newValue)
                                Task { await viewModel.saveSettings() }
                            }
                        }

                        HStack(spacing: 10) {
                            TextField("预设名称", text: presetNameBinding)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 180)
                                .focused($isEditingScreenshotPresetName)
                                .onSubmit {
                                    Task { await viewModel.saveSettings() }
                                }

                            Picker("默认输出", selection: presetOutputActionBinding) {
                                ForEach(ScreenshotPresetOutputAction.allCases) { action in
                                    Text(action.displayName).tag(action)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        HStack(spacing: 8) {
                            Button("保存当前预设") {
                                viewModel.applyCurrentScreenshotSettingsToSelectedPreset()
                                Task { await viewModel.saveSettings() }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("新建预设") {
                                viewModel.createBlankScreenshotPreset()
                                Task { await viewModel.saveSettings() }
                            }
                            .buttonStyle(.bordered)

                            Button("复制当前预设") {
                                viewModel.duplicateSelectedScreenshotPreset()
                                Task { await viewModel.saveSettings() }
                            }
                            .buttonStyle(.bordered)

                            Button("删除预设") {
                                viewModel.deleteSelectedScreenshotPreset()
                                Task { await viewModel.saveSettings() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.screenshotPresets.count <= 1)

                            Button("恢复默认预设") {
                                viewModel.restoreDefaultScreenshotPresets()
                                Task { await viewModel.saveSettings() }
                            }
                            .buttonStyle(.bordered)
                        }

                        Text("切换预设会立即应用到下一次截图；修改参数后点击“保存当前预设”写回当前方案。")
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Toggle("启用截图捕获", isOn: $viewModel.captureScreenshotEnabled)

                    SettingsPathRow(
                        title: "截图存储路径",
                        path: viewModel.assetsDirectoryPath,
                        note: "普通截图保存为 screenshot_<timestamp>.png，滚动截图保存为 scrollshot_<timestamp>.png。",
                        onCopy: {
                            copyToPasteboard(viewModel.assetsDirectoryPath)
                        },
                        onReveal: {
                            revealPathInFinder(viewModel.assetsDirectoryPath)
                        }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("全局截图热键")
                                .font(.subheadline)
                            Spacer()
                            TextField("", text: $viewModel.captureScreenshotHotkey)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 120)
                                .layoutPriority(1)
                            Button("录制") {
                                recordingShortcutTarget = .appScreenshotHotkey
                            }
                            .controlSize(.small)
                        }

                        Text("这个热键由应用级设置注册。空值表示不自动注册。")
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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

                    if viewModel.screenRecordingStatus != .authorized {
                        HStack(spacing: 10) {
                            Text("当前屏幕录制权限未开启，截图无法正常工作。")
                                .font(.caption)
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Button("打开屏幕录制设置") {
                                Task {
                                    await viewModel.openSystemPreferences(for: .screenRecording)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
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
                            .foregroundStyle(AppSurfaceTokens.secondaryText)

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
                    Text("功能还在持续完善。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                }
            }

            SettingsCard(title: "语音识别引擎", description: "选择语音识别引擎") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("识别引擎")
                        .font(.subheadline)

                    Picker("", selection: $viewModel.voiceDefaultProvider) {
                        ForEach(STTProvider.selectableCases, id: \.rawValue) { provider in
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
        .onReceive(NotificationCenter.default.publisher(for: .cloudSyncDidChange)) { _ in
            Task { await refreshCloudSyncSummary() }
        }
        .onChange(of: isEditingScreenshotPresetName) { _, isFocused in
            guard isFocused == false else { return }
            Task { await viewModel.saveSettings() }
        }
    }

    @MainActor
    private func refreshCloudSyncSummary() async {
        cloudSyncEnabled = await cloudSyncService.isSyncEnabled()
        let status = await cloudSyncService.getSyncStatus()
        cloudSyncSummary = CloudSyncStatusSummary.make(from: status)
    }

    private var presetNameBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedScreenshotPreset.name },
            set: { viewModel.renameSelectedScreenshotPreset(to: $0) }
        )
    }

    private var presetOutputActionBinding: Binding<ScreenshotPresetOutputAction> {
        Binding(
            get: { viewModel.selectedScreenshotPreset.defaultOutputAction },
            set: {
                viewModel.updateSelectedScreenshotPresetOutputAction($0)
                Task { await viewModel.saveSettings() }
            }
        )
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

// MARK: - 安全设置页

struct SecuritySettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "系统权限", description: "管理 AcWork 需要的系统权限") {
                VStack(spacing: 12) {
                    AcPermissionRow(
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

                    AcPermissionRow(
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

                    AcPermissionRow(
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

                    AcPermissionRow(
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

                    AcPermissionRow(
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
                        Toggle("智能调用日志", isOn: $viewModel.aiCallLogEnabled)
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

// MARK: - 关于设置页

struct AboutSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "关于 AcWork", description: "AcWork - 本地优先个人智能工作台") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AcWorkBrand.displayName)
                                .font(.title)
                                .fontWeight(.bold)
                            Text("本地优先个人智能工作台")
                                .font(.caption)
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Text("版本 \(viewModel.diagnosticAppVersionString)")
                                .font(.caption)
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                    }

                    Divider()

                    HStack(spacing: 16) {
                        AcActionButton(
                            title: viewModel.isCheckingForUpdates ? "检查中..." : "检查更新",
                            icon: "arrow.clockwise",
                            isProminent: false,
                            isLoading: viewModel.isCheckingForUpdates
                        ) {
                            Task {
                                await viewModel.checkForUpdates()
                            }
                        }
                        AcActionButton(title: "帮助与反馈", icon: "questionmark.circle", isProminent: false) {
                            viewModel.openFeedbackPage()
                        }
                        AcActionButton(title: "开源许可", icon: "doc.text", isProminent: false) {
                            viewModel.openLicensePage()
                        }
                    }
                }
            }

            SettingsCard(title: "状态总览", description: "完整本机状态集中到主侧边栏的「状态」") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("诊断看板已移到侧边栏。")
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
                    Link("项目主页", destination: URL(string: "https://github.com/huen96-Lichen/AcMind")!)
                    Link("问题反馈", destination: URL(string: "https://github.com/huen96-Lichen/AcMind/issues")!)
                    Link("提交支持请求", destination: URL(string: "https://github.com/huen96-Lichen/AcMind/issues/new")!)
                }
            }
        }
    }
}

// MARK: - 辅助视图

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
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                )
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
                    .background(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                    )
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
            .background(isSelected ? AppSurfaceTokens.cardBackgroundSoft : AppSurfaceTokens.cardBackgroundSoft)
            .foregroundStyle(isSelected ? AppSurfaceTokens.primaryText : AppSurfaceTokens.primaryText)
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(isSelected ? AppSurfaceTokens.separator.opacity(0.85) : AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
            )
            .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
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
            .background(selected ? AppSurfaceTokens.cardBackgroundSoft : AppSurfaceTokens.cardBackgroundSoft)
            .foregroundStyle(selected ? AppSurfaceTokens.primaryText : AppSurfaceTokens.primaryText)
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(selected ? AppSurfaceTokens.separator.opacity(0.85) : AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
            )
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
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
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
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
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
                .foregroundStyle(AppSurfaceTokens.secondaryText)
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
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
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

// MARK: - 添加 Provider Sheet

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
