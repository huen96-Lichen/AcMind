import SwiftUI
import AcMindKit

enum SettingsSuiteSection: String, CaseIterable, Identifiable {
    case general
    case agent
    case processing
    case knowledge
    case tools
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "通用"
        case .agent: return "Agent 设置"
        case .processing: return "信息处理"
        case .knowledge: return "知识库"
        case .tools: return "工具设置"
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
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct SettingsSuiteView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedSection: SettingsSuiteSection = .general

    private var sidebarSections: [SecondarySidebarSection] {
        [
            SecondarySidebarSection(
                id: "main",
                title: "设置",
                items: SettingsSuiteSection.allCases.map { section in
                    SecondarySidebarItem(
                        id: section.rawValue,
                        title: section.title,
                        icon: section.icon
                    )
                }
            )
        ]
    }

    var body: some View {
        HSplitView {
            SecondarySidebarWithHeader(
                title: "设置",
                subtitle: "统一管理基础偏好、Agent、知识库和工具链",
                sections: sidebarSections,
                selectedItem: Binding(
                    get: { selectedSection.rawValue },
                    set: { newValue in
                        if let newSection = SettingsSuiteSection(rawValue: newValue ?? "general") {
                            selectedSection = newSection
                        }
                    }
                )
            )
            .frame(width: 240)

            mainContent
        }
        .background(AppSurfaceTokens.background)
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

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader

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
                case .advanced:
                    advancedSection
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: selectedSection.icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text(selectedSection.title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            Text(selectedSection.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "外观与启动", subtitle: "统一黑色视觉与启动行为") {
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

            settingsCard(title: "快捷摘要", subtitle: "常用入口") {
                VStack(spacing: 10) {
                    settingsRow(key: "主窗口", value: "⌘0")
                    settingsRow(key: "灵动大陆", value: "⌘⇧Space")
                    settingsRow(key: "设置", value: "⌘,")
                }
            }
        }
    }

    private var agentSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Agent 空间", subtitle: "执行中枢与待命状态") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("启用语音入口", isOn: $viewModel.companionVoiceEnabled)
                    Toggle("启用快捷指令", isOn: $viewModel.companionShortcutsEnabled)
                    Toggle("启用截图入口", isOn: $viewModel.companionCaptureEnabled)
                    Toggle("默认展开灵动大陆", isOn: $viewModel.companionCapsuleExpanded)
                }
            }

            settingsCard(title: "权限", subtitle: "Agent 运行所需") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsStatusRow(label: "麦克风", status: viewModel.microphonePermissionStatus.displayName, color: viewModel.microphonePermissionStatus.color)
                    settingsStatusRow(label: "无障碍", status: viewModel.accessibilityPermissionStatus.displayName, color: viewModel.accessibilityPermissionStatus.color)
                    settingsStatusRow(label: "录屏", status: viewModel.screenRecordingPermissionStatus.displayName, color: viewModel.screenRecordingPermissionStatus.color)
                }
            }

            settingsCard(title: "语音路径", subtitle: "录音后写入收集箱") {
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

    private var processingSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "信息处理", subtitle: "把碎片内容变成可沉淀资产") {
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

            settingsCard(title: "转写 / 摘录", subtitle: "处理结果会进入收集链路") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsRow(key: "默认语言", value: viewModel.voiceDefaultLanguage)
                    settingsRow(key: "自动润色", value: viewModel.voiceAutoPolish ? "开启" : "关闭")
                    settingsRow(key: "润色模式", value: viewModel.voicePolishMode.displayName)
                }
            }
        }
    }

    private var knowledgeSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Vault", subtitle: "Obsidian / Markdown 归档") {
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

            settingsCard(title: "冲突策略", subtitle: "文件命名与覆盖规则") {
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
        VStack(spacing: 16) {
            settingsCard(title: "工具集", subtitle: "截图、OCR、监听与语音") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("自动监听剪贴板", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("截图自动打码", isOn: $viewModel.autoRedactFaces)
                    Toggle("检测敏感信息", isOn: $viewModel.autoDetectPII)
                    Toggle("滚动截图自动滚动", isOn: $viewModel.scrollCaptureAutoScroll)
                }
            }

            settingsCard(title: "截图热键", subtitle: "快捷键配置") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsRow(key: "截图热键", value: viewModel.captureScreenshotHotkey.isEmpty ? "未设置" : viewModel.captureScreenshotHotkey)
                }
            }
        }
    }

    private var advancedSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "权限管理", subtitle: "系统权限状态") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsStatusRow(label: "麦克风", status: viewModel.microphonePermissionStatus.displayName, color: viewModel.microphonePermissionStatus.color)
                    settingsStatusRow(label: "无障碍", status: viewModel.accessibilityPermissionStatus.displayName, color: viewModel.accessibilityPermissionStatus.color)
                    settingsStatusRow(label: "录屏", status: viewModel.screenRecordingPermissionStatus.displayName, color: viewModel.screenRecordingPermissionStatus.color)
                }
            }

            settingsCard(title: "关于", subtitle: "版本信息") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsRow(key: "版本", value: "0.0.4")
                    settingsRow(key: "构建", value: "2026.05.25")
                    settingsRow(key: "Swift", value: "5.9")
                }
            }
        }
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppSurfaceTokens.separator, lineWidth: 1)
        )
    }

    private func settingsRow(key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }

    private func settingsStatusRow(label: String, status: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            Text(status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
                .foregroundStyle(color)
                .cornerRadius(6)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(AppSurfaceTokens.cardBackgroundSoft))
    }
}
