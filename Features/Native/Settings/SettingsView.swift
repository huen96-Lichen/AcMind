import SwiftUI
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

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedCategory: SettingsCategory = .general

    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航
            VStack(spacing: 0) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.secondary)
                    TextField("搜索设置...", text: .constant(""))
                        .textFieldStyle(.plain)
                        .font(.caption)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding(12)

                Divider()

                // 导航列表
                List(selection: $selectedCategory) {
                    ForEach(SettingsCategory.allCases) { category in
                        HStack(spacing: 12) {
                            Image(systemName: category.icon)
                                .foregroundStyle(Color(NSColor.systemBlue))
                            Text(category.displayName)
                        }
                        .tag(category)
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.sidebar)
                .scrollDisabled(true)
            }
            .frame(width: 180)
            .background(Color(NSColor.controlBackgroundColor))

            // 右侧内容
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 页面标题区域
                    settingsHeader

                    // 设置内容
                    switch selectedCategory {
                    case .general:
                        GeneralSettingsPage(viewModel: viewModel)
                    case .companion:
                        CompanionSettingsPage(viewModel: viewModel)
                    case .aiModels:
                        AIModelsSettingsPage(viewModel: viewModel)
                    case .dataKnowledge:
                        DataKnowledgeSettingsPage(viewModel: viewModel)
                    case .captureInput:
                        CaptureInputSettingsPage(viewModel: viewModel)
                    case .security:
                        SecuritySettingsPage(viewModel: viewModel)
                    case .about:
                        AboutSettingsPage(viewModel: viewModel)
                    }
                }
                .padding(24)
            }
            .frame(minWidth: 500)
        }
        .frame(minWidth: 700, minHeight: 600)
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedCategory.displayName)
                .font(.title)
                .fontWeight(.semibold)
            Text(selectedCategory.description)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Settings Category Description

extension SettingsCategory {
    var description: String {
        switch self {
        case .general: return "配置 AcMind 的基础偏好设置"
        case .companion: return "设置随身胶囊、语音和快捷键等全局能力"
        case .aiModels: return "管理 AI Provider、模型选择和使用统计"
        case .dataKnowledge: return "配置数据存储、Vault 和知识库"
        case .captureInput: return "设置剪贴板、截图、语音输入等捕获能力"
        case .security: return "管理系统权限、隐私设置和安全选项"
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
                        .foregroundStyle(Color.secondary)
                }
            }
            content
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - General Settings Page

struct GeneralSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "外观", description: "自定义 AcMind 的视觉风格") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("主题", selection: $viewModel.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("语言", selection: $viewModel.language) {
                        Text("简体中文").tag("zh-CN")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                }
            }

            SettingsCard(title: "启动行为", description: "配置应用启动时的行为") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启动时显示随身胶囊", isOn: .constant(true))
                    Toggle("启动时恢复上次窗口位置", isOn: .constant(true))
                }
            }

            SettingsCard(title: "通知", description: "管理应用通知偏好") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启用通知", isOn: .constant(true))
                    Toggle("任务完成时通知", isOn: .constant(true))
                    Toggle("更新可用时通知", isOn: .constant(true))
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

                            Toggle("启动时自动显示", isOn: .constant(true))
                            Toggle("默认展开", isOn: $viewModel.companionCapsuleExpanded)
                            Toggle("菜单栏贴合", isOn: .constant(false))
                        }
                        .padding(.leading, 8)
                    }
                }
            }

            SettingsCard(title: "随身语音", description: "全局语音转写能力") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用随身语音", isOn: $viewModel.companionVoiceEnabled)

                    if viewModel.companionVoiceEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("快捷键")
                                    .font(.subheadline)
                                Spacer()
                                TextField("", text: .constant("⌘⇧V"))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                                Button("录制") {}
                                    .controlSize(.small)
                            }

                            Text("转写完成后")
                                .font(.subheadline)

                            Picker("", selection: $viewModel.companionVoiceOutputMode) {
                                ForEach(VoiceOutputMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()

                            Toggle("保存转写历史到收集箱", isOn: $viewModel.companionVoiceSaveToInbox)
                        }
                        .padding(.leading, 8)
                    }
                }
            }

            SettingsCard(title: "随身快捷键", description: "配置全局快捷键") {
                VStack(spacing: 8) {
                    ShortcutConfigRow(action: "随身语音", shortcut: "⌘⇧V")
                    ShortcutConfigRow(action: "快速收集", shortcut: "⌘⇧C")
                    ShortcutConfigRow(action: "截图捕获", shortcut: "⌘⇧4")
                    ShortcutConfigRow(action: "打开 Agent", shortcut: "⌘1")
                    ShortcutConfigRow(action: "今日日程", shortcut: "⌘4")
                }
            }

            SettingsCard(title: "随身捕获", description: "快速收集内容到 AcMind") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("截图到收集箱", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("文本快速收集", isOn: .constant(true))
                    Toggle("链接快速收集", isOn: .constant(true))
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
            SettingsCard(title: "模型路由策略", description: "选择 AcMind 如何为不同任务选择最合适的模型") {
                HStack(spacing: 8) {
                    StrategyButton(title: "自动", subtitle: "智能选择最佳模型", icon: "wand.and.stars", selected: true)
                    StrategyButton(title: "优先本地", subtitle: "优先使用本地模型", icon: "harddrive")
                    StrategyButton(title: "优先云端", subtitle: "优先使用云端模型", icon: "cloud")
                    StrategyButton(title: "低成本", subtitle: "优先选择低成本模型", icon: "coins")
                    StrategyButton(title: "高质量", subtitle: "优先选择高质量模型", icon: "sparkles")
                    StrategyButton(title: "隐私优先", subtitle: "优先本地处理", icon: "lock")
                }
            }

            SettingsCard(title: "可用模型提供商", description: "启用并配置你使用的 AI 模型提供商") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AI Providers")
                            .font(.subheadline)
                        Spacer()
                        Button("+ 添加提供商") {
                            showingAddProvider = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if viewModel.providers.isEmpty {
                        Text("暂无 Provider，请添加")
                            .foregroundStyle(Color.secondary)
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

            SettingsCard(title: "使用概览（本月）", description: "查看 AI 使用统计和消耗") {
                VStack(spacing: 16) {
                    HStack {
                        StatBox(label: "总调用次数", value: "2,633", change: "+18%")
                        StatBox(label: "总消耗", value: "$12.45", change: "+22%")
                        StatBox(label: "输入 Tokens", value: "1.32M", change: "+15%")
                        StatBox(label: "输出 Tokens", value: "0.48M", change: "+20%")
                    }

                    // 简化的图表占位
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("每日消耗趋势")
                                .font(.subheadline)
                            Spacer()
                            Text("5月")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 100)
                    }
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本地数据库位置")
                            .font(.subheadline)
                        TextField("", text: .constant("~/Library/Application Support/AcMind"))
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("附件存储位置")
                            .font(.subheadline)
                        TextField("", text: .constant("~/Library/Application Support/AcMind/Attachments"))
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                    }
                }
            }

            SettingsCard(title: "Obsidian Vault", description: "配置 Obsidian Vault 集成") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("选择 Vault 文件夹", text: $viewModel.vaultPath)
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
                                    .foregroundStyle(viewModel.validateVaultPath() ? .green : .red)
                                Text(viewModel.validateVaultPath() ? "路径有效" : "路径无效")
                                    .font(.caption)
                                    .foregroundStyle(viewModel.validateVaultPath() ? .green : .red)
                            }
                        }
                    }

                    TextField("默认 Inbox 文件夹", text: $viewModel.vaultDefaultFolder)
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

                    Toggle("自动添加 Frontmatter", isOn: $viewModel.autoFrontmatter)
                }
            }

            SettingsCard(title: "备份与恢复", description: "管理数据备份") {
                VStack(alignment: .leading, spacing: 12) {
                    Button("创建备份") {}
                        .buttonStyle(.bordered)

                    Button("恢复备份") {}
                        .buttonStyle(.bordered)

                    Toggle("自动备份（每周）", isOn: .constant(true))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "剪贴板捕获", description: "配置剪贴板自动采集") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("自动采集剪贴板", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("仅在激活应用时采集", isOn: .constant(false))
                }
            }

            SettingsCard(title: "截图捕获", description: "配置截图和滚动截图设置") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用截图捕获", isOn: .constant(true))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("滚动截图")
                            .font(.subheadline)

                        Toggle("启用自动滚动", isOn: $viewModel.scrollCaptureAutoScroll)

                        if viewModel.scrollCaptureAutoScroll {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("滚动速度")
                                        .font(.caption)
                                    Slider(value: $viewModel.scrollCaptureSpeed, in: 1...4, step: 1)
                                    Text("\(Int(viewModel.scrollCaptureSpeed))")
                                        .font(.caption)
                                        .frame(width: 20)
                                }

                                HStack {
                                    Text("最大高度")
                                        .font(.caption)
                                    TextField("30000", value: $viewModel.scrollCaptureMaxHeight, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    Text("像素")
                                        .font(.caption)
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
            }

            SettingsCard(title: "语音输入", description: "配置语音转写输入") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用语音输入", isOn: .constant(true))

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
                                Text("Prompt 风格")
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
                    Toggle("截图时自动打码人脸", isOn: $viewModel.autoRedactFaces)
                    Toggle("截图时自动检测 PII", isOn: $viewModel.autoDetectPII)

                    if viewModel.autoDetectPII {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PII 类型")
                                .font(.subheadline)

                            ForEach(RedactionType.allCases, id: \.self) { type in
                                Toggle(type.displayName, isOn: Binding(
                                    get: { viewModel.enabledRedactionTypes.contains(type) },
                                    set: { enabled in
                                        if enabled {
                                            viewModel.enabledRedactionTypes.insert(type)
                                        } else {
                                            viewModel.enabledRedactionTypes.remove(type)
                                        }
                                    }
                                ))
                            }
                        }
                        .padding(.leading, 8)
                    }

                    HStack {
                        Text("打码方式")
                            .font(.subheadline)
                        Picker("", selection: $viewModel.censorMode) {
                            ForEach(CensorMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                    }
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

// MARK: - Security Settings Page

struct SecuritySettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsCard(title: "系统权限", description: "管理 AcMind 需要的系统权限") {
                VStack(spacing: 12) {
                    PermissionRow(
                        title: "麦克风",
                        description: "用于语音输入",
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
                        description: "用于访问 Vault 文件夹",
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
                }
            }

            SettingsCard(title: "隐私安全", description: "配置隐私相关设置") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("本地优先模式", isOn: .constant(true))
                    Toggle("敏感内容不上传云端", isOn: .constant(true))
                    Toggle("API Key 使用 Keychain 存储", isOn: .constant(true))
                }
            }

            SettingsCard(title: "日志", description: "管理应用日志") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("AI 调用日志", isOn: .constant(true))
                        Toggle("错误日志", isOn: .constant(true))
                    }

                    Button("打开日志文件夹") {}
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
                            .foregroundStyle(Color(NSColor.systemBlue))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AcMind")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("AI 驱动的知识助手")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            Text("版本 1.0.0 (1234)")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }

                    Divider()

                    HStack(spacing: 16) {
                        Button("检查更新") {}
                            .buttonStyle(.bordered)
                        Button("帮助与反馈") {}
                            .buttonStyle(.bordered)
                        Button("开源许可") {}
                            .buttonStyle(.bordered)
                    }
                }
            }

            SettingsCard(title: "诊断信息", description: "查看应用诊断信息") {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsInfoRow(label: "应用版本", value: "1.0.0 (1234)")
                    SettingsInfoRow(label: "macOS 版本", value: "14.5 (23F79)")
                    SettingsInfoRow(label: "设备", value: "MacBook Pro (16-inch, 2023)")
                    SettingsInfoRow(label: "处理器", value: "Apple M3 Max")
                    SettingsInfoRow(label: "内存", value: "36 GB Unified Memory")

                    Button("复制诊断信息") {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            SettingsCard(title: "支持", description: "获取帮助和支持") {
                VStack(alignment: .leading, spacing: 8) {
                    Link("官方文档", destination: URL(string: "https://docs.acmind.app")!)
                    Link("常见问题", destination: URL(string: "https://docs.acmind.app/faq")!)
                    Link("联系支持", destination: URL(string: "mailto:support@acmind.app")!)
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
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct ShortcutConfigRow: View {
    let action: String
    let shortcut: String

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
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                Button("录制") {}
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
            .background(isSelected ? Color(NSColor.systemBlue) : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .regular)
    }
}

struct StrategyButton: View {
    let title: String
    let subtitle: String
    let icon: String
    var selected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
        }
        .padding(12)
        .background(selected ? Color(NSColor.systemBlue).opacity(0.1) : Color.secondary.opacity(0.05))
        .foregroundStyle(selected ? Color(NSColor.systemBlue) : Color.primary)
        .cornerRadius(8)
        .frame(width: 90)
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
                            .foregroundStyle(Color.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondary)
                    }
                }
                HStack(spacing: 8) {
                    Text(provider.providerType.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Text("模型: \(provider.modelId)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button("管理配置") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("删除") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(Color.red)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
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
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(change)
                .font(.caption)
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
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
                .foregroundStyle(Color.secondary)
            Spacer()
            Text(value)
                .font(.caption)
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
                    .foregroundStyle(Color.secondary)
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
                        .foregroundStyle(Color.green)
                }
            }
        }
    }
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
        case .unknown: return Color.gray.opacity(0.2)
        case .notDetermined, .requesting: return Color.orange.opacity(0.2)
        case .denied, .restricted, .needsSystemSettings, .failed: return Color.red.opacity(0.2)
        case .authorized: return Color.green.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .unknown: return .gray
        case .notDetermined, .requesting: return .orange
        case .denied, .restricted, .needsSystemSettings, .failed: return .red
        case .authorized: return .green
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
            Text("添加 Provider")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("名称", text: $name)
                Picker("类型", selection: $providerType) {
                    ForEach(ProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $apiKey)
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
                        await viewModel.addProvider(config)
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
