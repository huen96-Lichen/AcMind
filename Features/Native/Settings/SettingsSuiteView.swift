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
        case .agent: return "随身、语音、快捷键与联动"
        case .processing: return "收集、识别、转写与整理"
        case .knowledge: return "Vault、目录与冲突规则"
        case .tools: return "截图、OCR、监听与快捷输入"
        case .models: return "Provider、默认模型与偏好"
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
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(ACColors.border)
            content
        }
        .background(ACColors.pageBackground.ignoresSafeArea())
        .alert("设置错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("设置")
                    .font(ACTypography.sectionTitle)
                    .foregroundStyle(ACColors.primaryText)
                Text("统一管理基础偏好、Agent、信息处理、知识库、工具和模型。")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineSpacing(3)
            }

            ACSearchField("搜索设置", text: $searchText, width: 220, height: 36)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredSections) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            HStack(spacing: 12) {
                                ACTypeIcon(
                                    section.icon,
                                    tint: selectedSection == section ? ACColors.accentBlue : ACColors.secondaryText,
                                    background: selectedSection == section ? ACColors.selectedFill : ACColors.softFill,
                                    size: 32
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(section.title)
                                        .font(ACTypography.itemTitle)
                                        .foregroundStyle(selectedSection == section ? ACColors.primaryText : ACColors.secondaryText)
                                        .lineLimit(1)
                                    Text(section.subtitle)
                                        .font(ACTypography.mini)
                                        .foregroundStyle(ACColors.tertiaryText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }
                            .frame(width: ACLayout.sidebarNavWidth, height: ACLayout.sidebarNavHeight, alignment: .leading)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                                    .fill(selectedSection == section ? ACColors.cardBackground : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                                    .stroke(selectedSection == section ? ACColors.border : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)

            ACCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ACTypeIcon("person.crop.circle.fill", tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("状态")
                                .font(ACTypography.itemTitle)
                                .foregroundStyle(ACColors.primaryText)
                            Text("当前配置摘要")
                                .font(ACTypography.mini)
                                .foregroundStyle(ACColors.secondaryText)
                        }
                    }

                    HStack(spacing: 6) {
                        ACBadge(viewModel.theme.displayName, kind: .blue)
                        ACBadge(viewModel.language == "zh-CN" ? "中文" : "English", kind: .neutral)
                    }

                    ACInfoTable([
                        .init("默认模型", value: viewModel.defaultModelId.isEmpty ? "未设置" : viewModel.defaultModelId),
                        .init("Vault", value: viewModel.vaultDefaultFolder),
                        .init("权限", value: permissionSummary)
                    ])
                }
            }
            .frame(width: 232, height: 126)
        }
        .padding(20)
        .frame(width: 280, alignment: .leading)
        .background(ACColors.sidebarBackground)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ACPageHeader(
                    title: selectedSection.title,
                    subtitle: selectedSection.subtitle,
                    trailing: {
                        HStack(spacing: 12) {
                            if selectedSection == .advanced {
                                ACButton("保存设置", kind: .primary) {
                                    Task { await viewModel.saveSettings() }
                                }
                            } else {
                                ACBadge("预览", kind: .neutral)
                            }
                        }
                    }
                )
                .frame(height: ACLayout.headerHeightCompact)

                VStack(alignment: .leading, spacing: 16) {
                    sectionContent
                }
                .frame(maxWidth: 960, alignment: .leading)
            }
            .padding(.horizontal, ACLayout.pagePaddingX)
            .padding(.vertical, ACLayout.pagePaddingY)
            .padding(.bottom, ACLayout.pagePaddingBottom)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ACColors.pageBackground)
    }

    @ViewBuilder
    private var sectionContent: some View {
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

    private var filteredSections: [SettingsSuiteSection] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return SettingsSuiteSection.allCases
        }

        return SettingsSuiteSection.allCases.filter { section in
            section.title.localizedCaseInsensitiveContains(searchText) ||
            section.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var permissionSummary: String {
        let values = [
            viewModel.microphoneStatus.displayName,
            viewModel.screenRecordingStatus.displayName,
            viewModel.accessibilityStatus.displayName
        ]
        return values.joined(separator: " / ")
    }

    private var generalSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "外观与启动", subtitle: "统一黑色视觉与启动行为") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("主题")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        ACSegmentedControl(AppTheme.allCases, selection: $viewModel.theme) { option, isSelected in
                            Text(option.displayName)
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("语言")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        ACSegmentedControl(["zh-CN", "en"], selection: $viewModel.language) { option, isSelected in
                            Text(option == "zh-CN" ? "简体中文" : "English")
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                        }
                    }

                    Toggle("启动时显示灵动胶囊", isOn: $viewModel.companionCapsuleEnabled)
                    Toggle("恢复上次窗口位置", isOn: $viewModel.autoFrontmatter)
                }
            }

            settingsCard(title: "快捷摘要", subtitle: "常用入口与快捷键") {
                ACInfoTable([
                    .init("主窗口", value: "⌘0"),
                    .init("灵动大陆", value: "⌘⇧Space"),
                    .init("设置", value: "⌘,")
                ])
            }
        }
    }

    private var agentSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "随身能力", subtitle: "控制胶囊、语音与快捷键") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("启用语音入口", isOn: $viewModel.companionVoiceEnabled)
                    Toggle("启用快捷指令", isOn: $viewModel.companionShortcutsEnabled)
                    Toggle("启用截图入口", isOn: $viewModel.companionCaptureEnabled)
                    Toggle("默认展开灵动大陆", isOn: $viewModel.companionCapsuleExpanded)
                }
            }

            settingsCard(title: "权限与联动", subtitle: "系统权限和默认联动状态") {
                ACInfoTable([
                    .init("麦克风", value: viewModel.microphonePermissionStatus.displayName, valueColor: companionPermissionColor(for: viewModel.microphonePermissionStatus)),
                    .init("无障碍", value: viewModel.accessibilityPermissionStatus.displayName, valueColor: companionPermissionColor(for: viewModel.accessibilityPermissionStatus)),
                    .init("录屏", value: viewModel.screenRecordingPermissionStatus.displayName, valueColor: companionPermissionColor(for: viewModel.screenRecordingPermissionStatus))
                ])
            }

            settingsCard(title: "语音路径", subtitle: "录音后写入收集箱或复制") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("输出")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        ACSegmentedControl(VoiceOutputMode.allCases, selection: $viewModel.companionVoiceOutputMode) { option, isSelected in
                            Text(option.displayName)
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                        }
                    }

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("导出目标")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        ACSegmentedControl(ExportTarget.allCases, selection: $viewModel.defaultExportTarget) { option, isSelected in
                            Text(option.displayName)
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                        }
                    }
                }
            }

            settingsCard(title: "转写 / 摘录", subtitle: "处理结果会进入收集链路") {
                ACInfoTable([
                    .init("默认语言", value: viewModel.voiceDefaultLanguage),
                    .init("自动润色", value: viewModel.voiceAutoPolish ? "开启" : "关闭"),
                    .init("润色模式", value: viewModel.voicePolishMode.displayName)
                ])
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("路径规则")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        ACSegmentedControl(VaultConfig.VaultPathRule.allCases, selection: $viewModel.vaultPathRule) { option, isSelected in
                            Text(option.displayName)
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                        }
                    }
                }
            }

            settingsCard(title: "冲突策略", subtitle: "文件命名与覆盖规则") {
                ACSegmentedControl(ConflictStrategy.allCases, selection: $viewModel.vaultConflictStrategy) { option, isSelected in
                    Text(option.displayName)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                }
            }
        }
    }

    private var toolsSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "工具集", subtitle: "截图、OCR、监听与语音") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("自动监听剪贴板", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("自动打码人脸", isOn: $viewModel.autoRedactFaces)
                    Toggle("检测敏感信息", isOn: $viewModel.autoDetectPII)
                    Toggle("滚动截图自动滚动", isOn: $viewModel.scrollCaptureAutoScroll)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                settingsCard(title: "截图快捷键", subtitle: "快速调用") {
                    TextField("例如 ⌘⇧3", text: $viewModel.captureScreenshotHotkey)
                        .textFieldStyle(.roundedBorder)
                }

                settingsCard(title: "滚动截图", subtitle: "参数与稳定性") {
                    VStack(alignment: .leading, spacing: 10) {
                        Slider(value: $viewModel.scrollCaptureSpeed, in: 1...6, step: 0.5)
                        Text("速度 \(viewModel.scrollCaptureSpeed, specifier: "%.1f")")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                        Stepper("最大高度 \(viewModel.scrollCaptureMaxHeight)", value: $viewModel.scrollCaptureMaxHeight, in: 12000...60000, step: 2000)
                    }
                }
            }
        }
    }

    private var modelsSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "默认模型", subtitle: "AcMind 需要优先使用的模型") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Default Provider ID", text: $viewModel.defaultProviderId)
                        .textFieldStyle(.roundedBorder)
                    TextField("Default Model ID", text: $viewModel.defaultModelId)
                        .textFieldStyle(.roundedBorder)
                }
            }

            settingsCard(title: "Provider 摘要", subtitle: "当前可用服务") {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.providers.isEmpty {
                        ACEmptyState(
                            icon: "server.rack",
                            title: "暂无 Provider",
                            subtitle: "可以先保留默认模型配置，后续再接真实服务。"
                        )
                    } else {
                        ForEach(viewModel.providers.prefix(4), id: \.id) { provider in
                            settingsKeyValueRow(
                                key: provider.name.isEmpty ? provider.id : provider.name,
                                value: provider.providerType.displayName
                            )
                        }
                    }
                }
            }
        }
    }

    private var advancedSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "权限状态", subtitle: "系统级能力") {
                VStack(alignment: .leading, spacing: 8) {
                    settingsStatusRow(label: "麦克风", status: viewModel.microphoneStatus.displayName, color: permissionColor(for: viewModel.microphoneStatus))
                    settingsStatusRow(label: "录屏", status: viewModel.screenRecordingStatus.displayName, color: permissionColor(for: viewModel.screenRecordingStatus))
                    settingsStatusRow(label: "无障碍", status: viewModel.accessibilityStatus.displayName, color: permissionColor(for: viewModel.accessibilityStatus))
                    settingsStatusRow(label: "磁盘访问", status: viewModel.fullDiskAccessStatus.displayName, color: permissionColor(for: viewModel.fullDiskAccessStatus))
                    settingsStatusRow(label: "通知", status: viewModel.notificationsStatus.displayName, color: permissionColor(for: viewModel.notificationsStatus))
                }
            }

            settingsCard(title: "诊断与导出", subtitle: "用于排查和收尾") {
                VStack(alignment: .leading, spacing: 12) {
                    ACInfoTable([
                        .init("当前主题", value: viewModel.theme.displayName),
                        .init("语言", value: viewModel.language),
                        .init("默认导出", value: viewModel.defaultExportTarget.displayName)
                    ])

                    HStack {
                        Spacer(minLength: 0)
                        ACButton("保存设置", kind: .primary) {
                            Task { await viewModel.saveSettings() }
                        }
                    }
                }
            }
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text(subtitle)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(2)
                }

                content()
            }
        }
    }

    private func settingsKeyValueRow(key: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(key)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .fill(ACColors.divider)
                .frame(height: 1)
                .offset(y: 20),
            alignment: .bottom
        )
    }

    private func settingsStatusRow(label: String, status: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)

            Spacer(minLength: 0)

            Text(status)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.primaryText)
        }
        .padding(.vertical, 5)
    }

    private func permissionColor(for status: AppPermissionStatus) -> Color {
        switch status {
        case .authorized:
            return ACColors.accentGreen
        case .denied, .restricted:
            return ACColors.accentRed
        case .needsSystemSettings, .requesting:
            return ACColors.accentOrange
        case .failed:
            return ACColors.accentRed
        case .unknown, .notDetermined:
            return ACColors.tertiaryText
        }
    }

    private func companionPermissionColor(for status: CompanionPermissionStatus) -> Color {
        switch status {
        case .authorized:
            return ACColors.accentGreen
        case .denied, .restricted:
            return ACColors.accentRed
        case .notDetermined:
            return ACColors.tertiaryText
        }
    }
}
