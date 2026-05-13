import SwiftUI
import AcMindKit

enum SettingsSuiteSection: String, CaseIterable, Identifiable {
    case general
    case agent
    case processing
    case knowledge
    case tools
    case models
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "基础设置"
        case .agent: return "Agent 设置"
        case .processing: return "信息处理"
        case .knowledge: return "知识库 / Obsidian"
        case .tools: return "工具设置"
        case .models: return "AI 模型"
        case .advanced: return "高级设置"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "主题、语言、启动行为"
        case .agent: return "随身入口、语音、快捷方式"
        case .processing: return "收集、清洗、摘录和转写"
        case .knowledge: return "Vault、目录、冲突策略"
        case .tools: return "截图、OCR、剪贴板、监听"
        case .models: return "Provider、默认模型、语言偏好"
        case .advanced: return "权限、诊断、导出与系统"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .agent: return "sparkles"
        case .processing: return "tray.and.arrow.down"
        case .knowledge: return "books.vertical"
        case .tools: return "wrench.and.screwdriver"
        case .models: return "brain"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct SettingsSuiteView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedSection: SettingsSuiteSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()
                .overlay(AppSurfaceTokens.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    switch selectedSection {
                    case .general:
                        generalSection
                    case .agent:
                        agentSection
                    case .processing:
                        processingSection
                    case .knowledge:
                        knowledgeSection
                    case .tools:
                        toolsSection
                    case .models:
                        modelsSection
                    case .advanced:
                        advancedSection
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AppSurfaceTokens.islandBackground.ignoresSafeArea())
        .alert("设置错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .task {
            await viewModel.loadSettings()
            await viewModel.loadPermissions()
            await viewModel.loadProviders()
            await viewModel.loadCompanionSettings()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("设置")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text("统一管理基础偏好、Agent、知识库和工具链")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .padding(.bottom, 4)

            ForEach(SettingsSuiteSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedSection == section ? AppSurfaceTokens.accentPurple : AppSurfaceTokens.secondaryText)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selectedSection == section ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                            Text(section.subtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.tertiaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedSection == section ? AppSurfaceTokens.cardBackgroundStrong : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            AppSurfaceCard(title: "状态", subtitle: "当前配置摘要") {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsKeyValueRow(key: "主题", value: viewModel.theme.displayName)
                    SettingsKeyValueRow(key: "语言", value: viewModel.language)
                    SettingsKeyValueRow(key: "默认模型", value: viewModel.defaultModelId.isEmpty ? "未设置" : viewModel.defaultModelId)
                }
            }
        }
        .frame(width: 260)
        .padding(20)
        .background(AppSurfaceTokens.islandBackgroundSoft)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedSection.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(selectedSection.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(.bottom, 4)
    }

    private var generalSection: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "外观与启动", subtitle: "统一黑色视觉与启动行为") {
                VStack(alignment: .leading, spacing: 14) {
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

                    Toggle("启动时显示灵动大陆", isOn: $viewModel.companionCapsuleEnabled)
                    Toggle("恢复上次位置", isOn: $viewModel.autoFrontmatter)
                }
            }

            AppSurfaceCard(title: "快捷摘要", subtitle: "常用入口") {
                VStack(spacing: 10) {
                    SettingsKeyValueRow(key: "主窗口", value: "⌘0")
                    SettingsKeyValueRow(key: "灵动大陆", value: "⌘⇧Space")
                    SettingsKeyValueRow(key: "设置", value: "⌘,")
                }
            }
        }
    }

    private var agentSection: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "Agent 空间", subtitle: "执行中枢与待命状态") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("启用语音入口", isOn: $viewModel.companionVoiceEnabled)
                    Toggle("启用快捷指令", isOn: $viewModel.companionShortcutsEnabled)
                    Toggle("启用截图入口", isOn: $viewModel.companionCaptureEnabled)
                    Toggle("默认展开灵动大陆", isOn: $viewModel.companionCapsuleExpanded)
                }
            }

            HStack(spacing: 20) {
                AppSurfaceCard(title: "权限", subtitle: "Agent 运行所需") {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsStatusRow(label: "麦克风", status: viewModel.microphonePermissionStatus.displayName, color: viewModel.microphonePermissionStatus.color)
                        SettingsStatusRow(label: "无障碍", status: viewModel.accessibilityPermissionStatus.displayName, color: viewModel.accessibilityPermissionStatus.color)
                        SettingsStatusRow(label: "录屏", status: viewModel.screenRecordingPermissionStatus.displayName, color: viewModel.screenRecordingPermissionStatus.color)
                    }
                }

                AppSurfaceCard(title: "语音路径", subtitle: "录音后写入收集箱") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("输出", selection: $viewModel.companionVoiceOutputMode) {
                            ForEach(VoiceOutputMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)

                        Toggle("自动保存到收集箱", isOn: $viewModel.companionVoiceSaveToInbox)
                    }
                }
            }
        }
    }

    private var processingSection: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "信息处理", subtitle: "把碎片内容变成可沉淀资产") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("自动剪贴板采集", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("自动前置 Frontmatter", isOn: $viewModel.autoFrontmatter)
                    Picker("导出目标", selection: $viewModel.defaultExportTarget) {
                        ForEach(ExportTarget.allCases, id: \.self) { target in
                            Text(target.displayName).tag(target)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            AppSurfaceCard(title: "转写 / 摘录", subtitle: "处理结果会进入收集链路") {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsKeyValueRow(key: "默认语言", value: viewModel.voiceDefaultLanguage)
                    SettingsKeyValueRow(key: "自动润色", value: viewModel.voiceAutoPolish ? "开启" : "关闭")
                    SettingsKeyValueRow(key: "润色模式", value: viewModel.voicePolishMode.displayName)
                }
            }
        }
    }

    private var knowledgeSection: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "Vault", subtitle: "Obsidian / Markdown 归档") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Vault 路径", text: $viewModel.vaultPath)
                        .textFieldStyle(.roundedBorder)
                    TextField("默认文件夹", text: $viewModel.vaultDefaultFolder)
                        .textFieldStyle(.roundedBorder)
                    Picker("路径规则", selection: $viewModel.vaultPathRule) {
                        ForEach(VaultConfig.VaultPathRule.allCases, id: \.self) { rule in
                            Text(rule.displayName).tag(rule)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            AppSurfaceCard(title: "冲突策略", subtitle: "文件命名与覆盖规则") {
                Picker("策略", selection: $viewModel.vaultConflictStrategy) {
                    ForEach(ConflictStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var toolsSection: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "工具集", subtitle: "截图、OCR、监听与语音") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("自动监听剪贴板", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("截图自动红actor", isOn: $viewModel.autoRedactFaces)
                    Toggle("检测敏感信息", isOn: $viewModel.autoDetectPII)
                    Toggle("滚动截图自动滚动", isOn: $viewModel.scrollCaptureAutoScroll)
                }
            }

            HStack(spacing: 20) {
                AppSurfaceCard(title: "截图快捷键", subtitle: "快速调用") {
                    TextField("例如 ⌘⇧3", text: $viewModel.captureScreenshotHotkey)
                        .textFieldStyle(.roundedBorder)
                }

                AppSurfaceCard(title: "滚动截图", subtitle: "参数") {
                    VStack(alignment: .leading, spacing: 10) {
                        Slider(value: $viewModel.scrollCaptureSpeed, in: 1...6, step: 0.5)
                        Text("速度 \(viewModel.scrollCaptureSpeed, specifier: "%.1f")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Stepper("最大高度 \(viewModel.scrollCaptureMaxHeight)", value: $viewModel.scrollCaptureMaxHeight, in: 12000...60000, step: 2000)
                    }
                }
            }
        }
    }

    private var modelsSection: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "默认模型", subtitle: "AcMind 需要优先使用的模型") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Default Provider ID", text: $viewModel.defaultProviderId)
                        .textFieldStyle(.roundedBorder)
                    TextField("Default Model ID", text: $viewModel.defaultModelId)
                        .textFieldStyle(.roundedBorder)
                }
            }

            AppSurfaceCard(title: "Provider 摘要", subtitle: "当前可用服务") {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.providers.isEmpty {
                        Text("暂无 Provider")
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    } else {
                        ForEach(viewModel.providers.prefix(4), id: \.id) { provider in
                            SettingsKeyValueRow(key: provider.name.isEmpty ? provider.id : provider.name, value: provider.providerType.displayName)
                        }
                    }
                }
            }
        }
    }

    private var advancedSection: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "权限状态", subtitle: "系统级能力") {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsStatusRow(label: "麦克风", status: viewModel.microphoneStatus.displayName, color: permissionColor(for: viewModel.microphoneStatus))
                    SettingsStatusRow(label: "录屏", status: viewModel.screenRecordingStatus.displayName, color: permissionColor(for: viewModel.screenRecordingStatus))
                    SettingsStatusRow(label: "无障碍", status: viewModel.accessibilityStatus.displayName, color: permissionColor(for: viewModel.accessibilityStatus))
                    SettingsStatusRow(label: "磁盘访问", status: viewModel.fullDiskAccessStatus.displayName, color: permissionColor(for: viewModel.fullDiskAccessStatus))
                    SettingsStatusRow(label: "通知", status: viewModel.notificationsStatus.displayName, color: permissionColor(for: viewModel.notificationsStatus))
                }
            }

            HStack {
                Spacer()
                Button("保存设置") {
                    Task { await viewModel.saveSettings() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppSurfaceTokens.accentPurple)
            }
        }
    }
}

private struct SettingsKeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack {
            Text(key)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .font(.system(size: 13, weight: .medium))
    }
}

private struct SettingsStatusRow: View {
    let label: String
    let status: String
    let color: Color

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer()
            Text(status)
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .font(.system(size: 13, weight: .medium))
    }
}

private func permissionColor(for status: AppPermissionStatus) -> Color {
    switch status {
    case .authorized:
        return .green
    case .denied, .restricted:
        return .red
    case .needsSystemSettings, .requesting:
        return .orange
    case .failed:
        return .pink
    case .unknown, .notDetermined:
        return AppSurfaceTokens.secondaryText
    }
}
