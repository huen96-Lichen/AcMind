import SwiftUI
import AppKit
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
        case .agent: return "随身能力、说入法、快捷方式"
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

// Deprecated: Use SettingsView instead. Kept for reference only.
struct SettingsSuiteView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedSection: SettingsSuiteSection = .general
    @State private var showingDesktopCapsuleSettings = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                sectionTabs
                sectionHeader
                sectionContent
                saveButton
            }
            .padding(24)
            .frame(maxWidth: 960, alignment: .leading)
        }
        .background(AppSurfaceBackdrop())
        .alert("设置错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .sheet(isPresented: $showingDesktopCapsuleSettings) {
            DesktopCapsuleSettingsSection()
                .frame(minWidth: 700, minHeight: 560)
                .padding(16)
        }
        .task {
            await viewModel.loadSettings()
            await viewModel.loadPermissions()
            await viewModel.loadProviders()
            await viewModel.loadCompanionSettings()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("设置")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text("统一管理基础偏好、Agent、知识库和工具链，尽量保持一层就能找到。")
                    .font(.system(size: 13.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180), spacing: 12)
            ], spacing: 12) {
                AppSurfaceMetricTile(
                    title: "当前主题",
                    value: viewModel.theme.displayName,
                    subtitle: "全局视觉基线",
                    icon: "paintbrush",
                    tint: AppSurfaceTokens.secondaryText
                )
                AppSurfaceMetricTile(
                    title: "Agent 状态",
                    value: SettingsStatusLabelFormatter.binaryState(
                        isEnabled: viewModel.companionVoiceEnabled,
                        enabledText: "已启用",
                        disabledText: "未启用"
                    ),
                    subtitle: "说入法状态",
                    icon: "sparkles",
                    tint: AppSurfaceTokens.secondaryText
                )
                AppSurfaceMetricTile(
                    title: "权限概况",
                    value: permissionSummary,
                    subtitle: "麦克风 / 无障碍 / 录屏",
                    icon: "shield.checkerboard",
                    tint: permissionTint
                )
            }
        }
    }

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SettingsSuiteSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(section.title)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(minWidth: 120, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .fill(AppSurfaceTokens.cardBackgroundSoft)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .stroke(selectedSection == section ? AppSurfaceTokens.separator.opacity(0.85) : AppSurfaceTokens.separator.opacity(0.4), lineWidth: 1)
                        )
                        .foregroundStyle(selectedSection == section ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
        )
    }

    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
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
    }

    private var saveButton: some View {
        HStack {
            Spacer()
            Button("保存设置") {
                Task {
                    await viewModel.saveSettings()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding(.top, 6)
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: selectedSection.icon)
                    .font(.title2)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                Text(selectedSection.title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            Text(selectedSection.subtitle)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
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

                    Toggle("启动时显示灵动大陆", isOn: $viewModel.companionCapsuleShowOnLaunch)
                    Toggle("恢复上次位置", isOn: $viewModel.restoreWindowPosition)
                }
            }

            settingsCard(title: "快捷摘要", subtitle: "常用能力") {
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
                    Toggle("启用说入法", isOn: $viewModel.companionVoiceEnabled)
                    Toggle("启用快捷指令", isOn: $viewModel.companionShortcutsEnabled)
                    Toggle("启用截图", isOn: $viewModel.companionCaptureEnabled)
                    Toggle("默认展开灵动大陆", isOn: $viewModel.companionCapsuleExpanded)
                }
            }

            settingsCard(title: "权限", subtitle: "Agent 运行所需") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsStatusRow(label: "麦克风", status: viewModel.microphonePermissionStatus.displayName, color: permissionBadgeColor(for: viewModel.microphonePermissionStatus))
                    settingsStatusRow(label: "无障碍", status: viewModel.accessibilityPermissionStatus.displayName, color: permissionBadgeColor(for: viewModel.accessibilityPermissionStatus))
                    settingsStatusRow(label: "录屏", status: viewModel.screenRecordingPermissionStatus.displayName, color: permissionBadgeColor(for: viewModel.screenRecordingPermissionStatus))
                }
            }

            settingsCard(title: "说入法结果", subtitle: "清洗结果写入收集箱") {
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
                    Toggle("自动备份（每周）", isOn: $viewModel.autoBackupEnabled)
                    Picker("导出目标", selection: $viewModel.defaultExportTarget) {
                        ForEach(ExportTarget.allCases, id: \.self) { target in
                            Text(target.displayName).tag(target)
                        }
                    }
                    .pickerStyle(.menu)
                    settingsRow(key: "上次备份", value: viewModel.lastBackupAtText)
                }
            }

            settingsCard(title: "转写 / 摘录", subtitle: "处理结果会进入收集链路") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsRow(key: "默认语言", value: viewModel.voiceDefaultLanguage)
                    settingsRow(key: "翻译目标", value: translationLanguageDisplayName(viewModel.translationLanguage))
                    settingsRow(
                        key: "自动润色",
                        value: SettingsStatusLabelFormatter.binaryState(
                            isEnabled: viewModel.voiceAutoPolish,
                            enabledText: "开启",
                            disabledText: "关闭"
                        )
                    )
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Frontmatter 模板 (JSON)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)

                        AppSurfaceTextEditorShell(text: $viewModel.vaultFrontmatterTemplateText, minHeight: 110)
                    }
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
                    Text("截图自动打码和敏感信息检测已经接入实际捕获流程；滚动截图也已并入统一截图模式。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Button("打开桌面小胶囊设置") {
                        showingDesktopCapsuleSettings = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            settingsCard(title: "截图热键", subtitle: "快捷键配置") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsRow(
                        key: "截图热键",
                        value: SettingsStatusLabelFormatter.fallbackText(value: viewModel.captureScreenshotHotkey)
                    )
                }
            }
        }
    }

    private var advancedSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "权限管理", subtitle: "系统权限状态") {
                VStack(alignment: .leading, spacing: 8) {
                    PermissionRow(
                        title: "麦克风",
                        description: "用于说入法与录音转写",
                        status: viewModel.microphoneStatus,
                        onRequest: {
                            Task { await viewModel.requestPermission(.microphone) }
                        },
                        onOpenSettings: {
                            Task { await viewModel.openSystemPreferences(for: .microphone) }
                        }
                    )

                    PermissionRow(
                        title: "无障碍",
                        description: "用于键盘注入和系统交互",
                        status: viewModel.accessibilityStatus,
                        onRequest: {
                            Task { await viewModel.requestPermission(.accessibility) }
                        },
                        onOpenSettings: {
                            Task { await viewModel.openSystemPreferences(for: .accessibility) }
                        }
                    )

                    PermissionRow(
                        title: "录屏",
                        description: "用于截图和滚动截图",
                        status: viewModel.screenRecordingStatus,
                        onRequest: {
                            Task { await viewModel.requestPermission(.screenRecording) }
                        },
                        onOpenSettings: {
                            Task { await viewModel.openSystemPreferences(for: .screenRecording) }
                        }
                    )

                    PermissionRow(
                        title: "通知",
                        description: "用于任务完成和更新提醒",
                        status: viewModel.notificationsStatus,
                        onRequest: {
                            Task { await viewModel.requestPermission(.notifications) }
                        },
                        onOpenSettings: {
                            Task { await viewModel.openSystemPreferences(for: .notifications) }
                        }
                    )

                    Text(AppNotificationService.strategySummary)
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            settingsCard(title: "关于", subtitle: "版本信息") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsRow(key: "版本", value: viewModel.diagnosticAppVersionString)
                    settingsRow(key: "macOS", value: viewModel.diagnosticMacOSVersionString)
                    settingsRow(key: "Swift", value: "5.9")
                }
            }

            settingsCard(title: "状态概览", subtitle: "完整本机状态已集中到主侧边栏的「状态」") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("这里不再展示诊断看板，只保留跳转。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Button("查看状态") {
                        (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        AppSurfaceSectionCard(title: title, subtitle: subtitle) {
            content()
        }
    }

    private func settingsRow(key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
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
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .foregroundStyle(color)
                .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
    }

    private func permissionBadgeColor(for status: CompanionPermissionStatus) -> Color {
        switch status {
        case .notDetermined: return AppSurfaceTokens.secondaryText
        case .authorized: return AppSurfaceTokens.secondaryText
        case .denied, .restricted: return AppSurfaceTokens.secondaryText
        }
    }

    private func translationLanguageDisplayName(_ id: String) -> String {
        switch id {
        case "zh": return "中文"
        case "en": return "英文"
        case "ja": return "日文"
        case "ko": return "韩文"
        default: return id
        }
    }

    private var permissionSummary: String {
        let statuses = [
            viewModel.microphonePermissionStatus,
            viewModel.accessibilityPermissionStatus,
            viewModel.screenRecordingPermissionStatus
        ]
        let grantedCount = statuses.filter { $0 == .authorized }.count
        return SettingsStatusLabelFormatter.permissionSummary(grantedCount: grantedCount, totalCount: statuses.count)
    }

    private var permissionTint: Color {
        return AppSurfaceTokens.secondaryText
    }

}
