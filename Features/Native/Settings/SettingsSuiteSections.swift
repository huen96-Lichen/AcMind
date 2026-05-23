import Foundation
import SwiftUI
import AcMindKit

extension SettingsSuiteView {
    var generalSection: some View {
        VStack(spacing: 14) {
            settingsCard(title: "外观与启动", subtitle: "统一黑色视觉与启动行为") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("主题")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        ACSegmentedControl(AppTheme.allCases, selection: $viewModel.theme) { option, isSelected in
                            Text(option.displayName)
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
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
                    Toggle("记住窗口布局", isOn: $viewModel.rememberWorkspaceLayout)
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

    var agentSection: some View {
        VStack(spacing: 14) {
            settingsCard(title: "随身能力", subtitle: "控制胶囊、语音与快捷键") {
                VStack(alignment: .leading, spacing: 8) {
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

    var processingSection: some View {
        VStack(spacing: 14) {
            settingsCard(title: "信息处理", subtitle: "把碎片内容变成可沉淀资产") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("自动剪贴板采集", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("自动前置 Frontmatter", isOn: $viewModel.autoFrontmatter)

                    VStack(alignment: .leading, spacing: 6) {
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

    var knowledgeSection: some View {
        VStack(spacing: 14) {
            settingsCard(title: "Vault", subtitle: "Obsidian / Markdown 归档") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Vault 路径", text: $viewModel.vaultPath)
                        .textFieldStyle(.roundedBorder)
                    TextField("默认文件夹", text: $viewModel.vaultDefaultFolder)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 6) {
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

    var toolsSection: some View {
        VStack(spacing: 14) {
            settingsCard(title: "工具集", subtitle: "截图、OCR、监听与语音") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("自动监听剪贴板", isOn: $viewModel.autoCaptureClipboard)
                    Toggle("自动打码人脸", isOn: $viewModel.autoRedactFaces)
                    Toggle("检测敏感信息", isOn: $viewModel.autoDetectPII)
                    Toggle("滚动截图自动滚动", isOn: $viewModel.scrollCaptureAutoScroll)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    settingsCard(title: "截图快捷键", subtitle: "快速调用") {
                        TextField("例如 ⌘⇧3", text: $viewModel.captureScreenshotHotkey)
                            .textFieldStyle(.roundedBorder)
                    }

                    settingsCard(title: "滚动截图", subtitle: "参数与稳定性") {
                        VStack(alignment: .leading, spacing: 8) {
                            Slider(value: $viewModel.scrollCaptureSpeed, in: 1...6, step: 0.5)
                            Text("速度 \(String(format: "%.1f", viewModel.scrollCaptureSpeed))")
                                .font(ACTypography.caption)
                                .foregroundStyle(ACColors.secondaryText)
                            Stepper("最大高度 \(viewModel.scrollCaptureMaxHeight)", value: $viewModel.scrollCaptureMaxHeight, in: 12000...60000, step: 2000)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    settingsCard(title: "截图快捷键", subtitle: "快速调用") {
                        TextField("例如 ⌘⇧3", text: $viewModel.captureScreenshotHotkey)
                            .textFieldStyle(.roundedBorder)
                    }

                    settingsCard(title: "滚动截图", subtitle: "参数与稳定性") {
                        VStack(alignment: .leading, spacing: 8) {
                            Slider(value: $viewModel.scrollCaptureSpeed, in: 1...6, step: 0.5)
                            Text("速度 \(String(format: "%.1f", viewModel.scrollCaptureSpeed))")
                                .font(ACTypography.caption)
                                .foregroundStyle(ACColors.secondaryText)
                            Stepper("最大高度 \(viewModel.scrollCaptureMaxHeight)", value: $viewModel.scrollCaptureMaxHeight, in: 12000...60000, step: 2000)
                        }
                    }
                }
            }
        }
    }

    var modelsSection: some View {
        VStack(spacing: 14) {
            settingsCard(title: "能力分区", subtitle: "直接选择当前模型与保底模型，所有设置都在这一页完成。") {
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(AIModelCategory.allCases) { category in
                                capabilityPartitionTile(for: category)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(AIModelCategory.allCases) { category in
                                capabilityPartitionTile(for: category)
                            }
                        }
                    }

                    Divider().overlay(ACColors.divider)

                    selectedCapabilityEditor
                }
            }
        }
    }

    var selectedCapabilityEditor: some View {
        let category = viewModel.selectedAIModelCategory
        let preference = viewModel.aiModelPreference(for: category)
        let options = viewModel.availableAIModelOptions(for: category)
        let selectedOption = viewModel.selectedAIModelOption(for: category)
        let fallbackOption = viewModel.fallbackAIModelOption(for: category)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                ACTypeIcon(categoryIcon(for: category), tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.displayName)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text("在这里直接切换当前模型和保底模型。")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }
                Spacer(minLength: 0)
                ACBadge(preference.isEnabled ? "已启用" : "默认关闭", kind: preference.isEnabled ? .green : .disabled)
            }

            if options.isEmpty {
                ACEmptyState(
                    icon: "circle.dashed",
                    title: "暂无可选模型",
                    subtitle: "先添加 Provider，或者继续使用系统内置保底方案。"
                )
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        modelDropdownMenu(
                            title: "当前模型",
                            value: selectedOption?.displayName ?? "未配置",
                            subtitle: selectedOption?.description ?? "当前能力尚未绑定可用模型",
                            options: options,
                            category: category,
                            selectionKind: .current
                        )

                        modelDropdownMenu(
                            title: "保底模型",
                            value: fallbackOption?.displayName ?? "手动模式",
                            subtitle: fallbackOption?.description ?? "不可用时自动回退",
                            options: options,
                            category: category,
                            selectionKind: .fallback
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        modelDropdownMenu(
                            title: "当前模型",
                            value: selectedOption?.displayName ?? "未配置",
                            subtitle: selectedOption?.description ?? "当前能力尚未绑定可用模型",
                            options: options,
                            category: category,
                            selectionKind: .current
                        )

                        modelDropdownMenu(
                            title: "保底模型",
                            value: fallbackOption?.displayName ?? "手动模式",
                            subtitle: fallbackOption?.description ?? "不可用时自动回退",
                            options: options,
                            category: category,
                            selectionKind: .fallback
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                ACBadge(selectedOption?.privacyLevel ?? "本地", kind: badgeKind(for: selectedOption?.privacyLevel))
                ACBadge(selectedOption?.costLevel ?? "免费", kind: badgeKind(for: selectedOption?.costLevel))
                ACBadge(selectedOption?.loadLevel ?? "轻量", kind: badgeKind(for: selectedOption?.loadLevel))
                if selectedOption?.isAvailable == false {
                    ACBadge("不可用", kind: .red)
                }

                Spacer(minLength: 0)

                Toggle(isOn: Binding(
                    get: { preference.isEnabled },
                    set: { viewModel.setAIModelCategoryEnabled($0, for: category) }
                ))
                {
                    Text("启用此能力")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Button {
                    Task { await viewModel.testAIModelSelection(for: category) }
                } label: {
                    Label("测试", systemImage: "checkmark.seal")
                        .font(ACTypography.captionMedium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    var advancedSection: some View {
        VStack(spacing: 14) {
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
                VStack(alignment: .leading, spacing: 10) {
                    ACInfoTable([
                        .init("当前主题", value: viewModel.theme.displayName),
                        .init("语言", value: viewModel.language),
                        .init("默认导出", value: viewModel.defaultExportTarget.displayName)
                    ])
                }
            }
        }
    }

    func capabilityPartitionTile(for category: AIModelCategory) -> some View {
        let selectedOption = viewModel.selectedAIModelOption(for: category)
        let isSelected = viewModel.selectedAIModelCategory == category

        return Button {
            viewModel.selectAIModelCategory(category)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    ACTypeIcon(categoryIcon(for: category), tint: isSelected ? ACColors.accentBlue : ACColors.secondaryText, background: isSelected ? ACColors.selectedFill : ACColors.softFill, size: 24)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(ACColors.primaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("当前：\(selectedOption?.displayName ?? "未配置")")
                            .font(.system(size: 11))
                            .foregroundStyle(ACColors.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    ACBadge(capabilityStateLabel(for: category, selected: selectedOption), kind: capabilityStateKind(for: selectedOption))
                        .scaleEffect(0.92, anchor: .topTrailing)
                }
            }
            .padding(8)
            .frame(minHeight: 80, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? ACColors.selectedFill : ACColors.softFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? ACColors.accentBlue.opacity(0.45) : ACColors.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func capabilityStateLabel(for category: AIModelCategory, selected: AIModelOption?) -> String {
        if let selected {
            return selected.isAvailable ? "当前可用" : "不可用"
        }
        if category == .complexTask {
            return "默认关闭"
        }
        return "未配置"
    }

    func capabilityStateKind(for selected: AIModelOption?) -> ACBadge.Kind {
        guard let selected else { return .disabled }
        return selected.isAvailable ? .green : .red
    }

    func badgeKind(for text: String?) -> ACBadge.Kind {
        guard let text else { return .neutral }
        return badgeKind(for: text)
    }

    func badgeKind(for text: String) -> ACBadge.Kind {
        let value = text.lowercased()
        if value.contains("云端") || value.contains("付费") {
            return .orange
        }
        if value.contains("本地") || value.contains("免费") || value.contains("系统内置") {
            return .blue
        }
        if value.contains("高负载") {
            return .purple
        }
        if value.contains("轻量") {
            return .green
        }
        return .neutral
    }

    func modelDropdownMenu(
        title: String,
        value: String,
        subtitle: String,
        options: [AIModelOption],
        category: AIModelCategory,
        selectionKind: ModelSelectionKind
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button {
                    switch selectionKind {
                    case .current:
                        viewModel.selectAIModelOption(option, for: category)
                    case .fallback:
                        viewModel.selectAIModelFallbackOption(option, for: category)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.displayName)
                            Text(option.description)
                                .font(ACTypography.mini)
                                .foregroundStyle(ACColors.secondaryText)
                        }
                        Spacer(minLength: 0)
                        if option.isSystemDefault {
                            Text("系统内置")
                        } else {
                            Text(option.isAvailable ? "可用" : "不可用")
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.secondaryText)

                HStack(alignment: .center, spacing: 8) {
                    Text(value)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Text(subtitle)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.tertiaryText)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ACColors.softFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ACColors.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func categoryIcon(for category: AIModelCategory) -> String {
        switch category {
        case .speechToText: return "waveform"
        case .imageOCR: return "camera.viewfinder"
        case .textCleanup: return "text.alignleft"
        case .summarization: return "chart.bar.doc.horizontal"
        case .knowledgeRetrieval: return "magnifyingglass.circle"
        case .complexTask: return "cpu"
        }
    }

    enum ModelSelectionKind {
        case current
        case fallback
    }

    func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ACCard(padding: 15) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
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

    func settingsStatusRow(label: String, status: String, color: Color) -> some View {
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

    func permissionColor(for status: AppPermissionStatus) -> Color {
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

    func companionPermissionColor(for status: CompanionPermissionStatus) -> Color {
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
