import SwiftUI
import AcMindKit

struct CompanionView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var session = CompanionVoiceSessionController.shared

    private let supportedProviders: [STTProvider] = [
        .appleSpeech,
        .senseVoice,
        .whisperKit,
        .qwen3ASR,
        .openAI,
        .aliCloud,
        .doubao
    ]

    var body: some View {
        ACSecondaryPageShell(
            header: {
                ACPageHeader(
                    title: "说入法",
                    subtitle: "只保留语音输入法能力，模型、触发、目标和输出都在这里调。"
                ) {
                    ACBadge("Fn 长按", kind: .blue)
                }
            },
            content: {
                ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    heroCard
                    engineCard
                    triggerCard
                    routeModeCard
                    outputCard
                    statusCard
                }
                    .frame(maxWidth: ACLayout.secondaryPageContentMaxWidth)
                    .padding(.vertical, 4)
                }
            }
        )
        .onAppear {
            Task { await session.refreshConfiguration() }
        }
    }

    private var heroCard: some View {
        ACCard(padding: 20) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ACColors.accentBlue.opacity(0.16),
                                    ACColors.accentPurple.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 104, height: 104)

                    Circle()
                        .fill(session.phase == .recording ? ACColors.accentRed : ACColors.accentBlue)
                        .frame(width: 48, height: 48)

                    Image(systemName: session.phase == .recording ? "waveform" : "mic.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("说入法")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(ACColors.primaryText)

                        ACBadge(session.actionTitle, kind: session.phase == .recording ? .red : .blue)
                    }

                    Text("按住 Fn 说话，系统会根据光标位置自动决定是直写到输入框，还是转给 Agent。")
                        .font(ACTypography.body)
                        .foregroundStyle(ACColors.secondaryText)

                    HStack(spacing: 8) {
                        ACBadge("长按转写", kind: .neutral)
                        ACBadge(viewModel.companionVoiceOutputMode.displayName, kind: .green)
                        ACBadge(viewModel.companionVoiceProvider.displayName, kind: .orange)
                    }

                    HStack(spacing: 10) {
                        ACButton("开始录音", kind: .primary) {
                            session.beginManualRecording()
                        }
                        ACButton("打开面板", kind: .secondary) {
                            session.present(autoStart: false)
                        }
                        ACButton("保存设置", kind: .ghost) {
                            Task {
                                await viewModel.saveSettings()
                                await session.refreshConfiguration()
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(session.elapsedTimeFormatted)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundStyle(session.phase == .recording ? ACColors.accentRed : ACColors.primaryText)

                    Text(session.statusHint)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 180, alignment: .trailing)
                }
            }
        }
    }

    private var engineCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow(title: "转写引擎 / 模型", subtitle: "选择语音转写的服务与具体模型")

                VStack(alignment: .leading, spacing: 10) {
                    Text("引擎")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.secondaryText)

                    ACSegmentedControl(supportedProviders, selection: $viewModel.companionVoiceProvider) { option, isSelected in
                        VStack(spacing: 3) {
                            Text(option.displayName)
                                .font(ACTypography.captionMedium)
                            if isSelected {
                                Text("当前")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("模型")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.secondaryText)

                    if modelOptions(for: viewModel.companionVoiceProvider).isEmpty {
                        Text("当前引擎未暴露独立模型选项。")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    } else {
                        ACSegmentedControl(modelOptions(for: viewModel.companionVoiceProvider), selection: modelSelectionBinding) { option, _ in
                            Text(option)
                                .font(ACTypography.captionMedium)
                        }
                        Text(modelHint(for: viewModel.companionVoiceProvider))
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }
                }

                HStack(spacing: 10) {
                    infoPill(title: "默认语言", value: viewModel.voiceDefaultLanguage)
                    infoPill(title: "自动润色", value: viewModel.voiceAutoPolish ? "开启" : "关闭")
                    infoPill(title: "润色模式", value: viewModel.voicePolishMode.displayName)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("语言")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.secondaryText)
                    TextField("例如 zh / en / auto", text: $viewModel.voiceDefaultLanguage)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var triggerCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow(title: "触发方式", subtitle: "管理 Fn 长按与备用快捷键")

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("启用 Fn 长按", isOn: $viewModel.companionVoiceHoldToTalkEnabled)

                    HStack(alignment: .center, spacing: 12) {
                        Text("长按阈值")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        Slider(value: $viewModel.companionVoiceHoldThreshold, in: 0.2...0.9, step: 0.01)
                        Text(String(format: "%.2f 秒", viewModel.companionVoiceHoldThreshold))
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.primaryText)
                            .frame(width: 72, alignment: .trailing)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("备用快捷键")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        TextField("例如 ⌥Space", text: $viewModel.companionVoiceShortcut)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("触发模式")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        ACSegmentedControl(CompanionVoiceTriggerMode.allCases, selection: $viewModel.companionVoiceTriggerMode) { option, _ in
                            Text(option.displayName)
                                .font(ACTypography.captionMedium)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("输出目标")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        Text("Fn 松开后，会按照这里的模式决定是直写输入框，还是交给 Agent。")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }
                }
            }
        }
    }

    private var routeModeCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow(title: "输出目标说明", subtitle: "把“输入框 / Agent / 智能判断”解释成可感知的路由行为")

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(routeModeBlueprints) { blueprint in
                        Button {
                            viewModel.companionVoiceRouteMode = blueprint.mode
                        } label: {
                            routeModeTile(for: blueprint)
                        }
                        .buttonStyle(.plain)
                    }
                }

                routeModeSummary
            }
        }
    }

    private var outputCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow(title: "输出行为", subtitle: "决定转写后如何落地")

                VStack(alignment: .leading, spacing: 10) {
                    Text("转写完成后")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.secondaryText)
                    ACSegmentedControl(VoiceOutputMode.allCases, selection: $viewModel.companionVoiceOutputMode) { option, isSelected in
                        Text(option.displayName)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("自动保存到收集箱", isOn: $viewModel.companionVoiceSaveToInbox)
                    Toggle("保持语音入口可用", isOn: $viewModel.companionVoiceEnabled)
                }

                Divider().opacity(0.6)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("自动润色", isOn: $viewModel.voiceAutoPolish)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("润色模式")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        ACSegmentedControl(VoicePolishMode.allCases, selection: $viewModel.voicePolishMode) { option, isSelected in
                            Text(option.displayName)
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                        }
                    }
                }
            }
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 16) {
            ACCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    headerRow(title: "权限与摘要", subtitle: "麦克风、无障碍和当前配置一眼看完")
                    permissionRow(label: "麦克风", status: viewModel.microphonePermissionStatus)
                    permissionRow(label: "无障碍", status: viewModel.accessibilityPermissionStatus)
                    permissionRow(label: "录屏", status: viewModel.screenRecordingPermissionStatus)
                    Divider().opacity(0.55)
                    infoTableRow(label: "引擎", value: viewModel.companionVoiceProvider.displayName)
                    infoTableRow(label: "模型", value: viewModel.companionVoiceModel)
                    infoTableRow(label: "触发", value: triggerSummary)
                    infoTableRow(label: "目标", value: viewModel.companionVoiceRouteMode.displayName)
                }
            }
        }
    }

    private var routeModeSummary: some View {
        let blueprint = routeModeBlueprint(for: viewModel.companionVoiceRouteMode)

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(blueprint.tint.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: blueprint.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(blueprint.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(blueprint.title)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                    ACBadge("当前生效", kind: .green)
                }
                Text(blueprint.summary)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                Text(blueprint.result)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(blueprint.tint.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var triggerSummary: String {
        let triggerMode = viewModel.companionVoiceTriggerMode.displayName
        let shortcut = viewModel.companionVoiceShortcut.isEmpty ? "未设置" : viewModel.companionVoiceShortcut
        return "\(triggerMode) / \(shortcut)"
    }

    private var modelSelectionBinding: Binding<String> {
        Binding(
            get: { viewModel.companionVoiceModel },
            set: { viewModel.companionVoiceModel = $0 }
        )
    }

    private func headerRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ACTypography.cardTitle)
                .foregroundStyle(ACColors.primaryText)
            Text(subtitle)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
        }
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(ACTypography.mini)
                .foregroundStyle(ACColors.secondaryText)
            Text(value)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ACColors.softFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func permissionRow(label: String, status: CompanionPermissionStatus) -> some View {
        HStack {
            Text(label)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
            Spacer(minLength: 0)
            Text(status.displayName)
                .font(ACTypography.captionMedium)
                .foregroundStyle(status.color)
        }
    }

    private func infoTableRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func modelOptions(for provider: STTProvider) -> [String] {
        switch provider {
        case .appleSpeech:
            return []
        case .senseVoice:
            return ["SenseVoiceSmall"]
        case .whisperKit:
            return ["tiny", "base", "small", "medium", "large", "large-v3", "large-v3-turbo"]
        case .qwen3ASR:
            return ["Qwen/Qwen3-ASR-0.6B"]
        case .openAI:
            return ["whisper-1"]
        case .aliCloud:
            return ["default"]
        case .doubao:
            return ["default"]
        case .funASR, .googleCloud, .groq, .freeModel:
            return ["default"]
        }
    }

    private func modelHint(for provider: STTProvider) -> String {
        switch provider {
        case .appleSpeech:
            return "系统听写不需要单独模型。"
        case .senseVoice:
            return "当前固定为 SenseVoiceSmall。"
        case .whisperKit:
            return "可在 WhisperKit 的不同尺寸模型之间切换。"
        case .qwen3ASR:
            return "当前使用 sherpa-onnx 的 Qwen3-ASR-0.6B。"
        case .openAI:
            return "OpenAI 侧使用 whisper-1。"
        case .aliCloud, .doubao, .funASR, .googleCloud, .groq, .freeModel:
            return "当前为服务端默认配置。"
        }
    }

    private func routeModeBlueprint(for mode: CompanionVoiceRouteMode) -> RouteModeBlueprint {
        routeModeBlueprints.first(where: { $0.mode == mode }) ?? routeModeBlueprints[0]
    }

    private func routeModeTile(for blueprint: RouteModeBlueprint) -> some View {
        let isSelected = viewModel.companionVoiceRouteMode == blueprint.mode

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? blueprint.tint.opacity(0.18) : ACColors.softFill)
                        .frame(width: 40, height: 40)
                    Image(systemName: blueprint.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? blueprint.tint : ACColors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(blueprint.title)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                    Text(blueprint.tagline)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? blueprint.tint : ACColors.secondaryText)
                }

                Spacer(minLength: 0)

                if isSelected {
                    ACBadge("已选", kind: .blue)
                }
            }

            Text(blueprint.summary)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
                .lineLimit(3)

            Text(blueprint.result)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.primaryText)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 146, alignment: .topLeading)
        .background(isSelected ? blueprint.tint.opacity(0.08) : ACColors.softFill)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? blueprint.tint.opacity(0.28) : ACColors.border.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: isSelected ? blueprint.tint.opacity(0.08) : .clear, radius: 8, x: 0, y: 4)
    }
}

private struct RouteModeBlueprint: Identifiable {
    let mode: CompanionVoiceRouteMode
    let icon: String
    let title: String
    let tagline: String
    let summary: String
    let result: String
    let tint: Color

    var id: CompanionVoiceRouteMode { mode }
}

private let routeModeBlueprints: [RouteModeBlueprint] = [
    .init(
        mode: .smart,
        icon: "wand.and.stars",
        title: "智能判断",
        tagline: "默认推荐",
        summary: "系统会先看当前有没有可输入的光标或选区；有就直接落到输入框，没有就转给 Agent。",
        result: "适合大多数情况。你不用选路由，Fn 一按就能继续说。",
        tint: ACColors.accentBlue
    ),
    .init(
        mode: .inputField,
        icon: "text.cursor",
        title: "输入框",
        tagline: "直写文案",
        summary: "无论当前在什么页面，都会尽量把转写结果写进当前可编辑文本，并优先按输入法逻辑处理。",
        result: "适合聊天、写作、表单输入、回复邮件这类“我就是要打字”的场景。",
        tint: ACColors.accentGreen
    ),
    .init(
        mode: .agent,
        icon: "bubble.left.and.bubble.right",
        title: "Agent",
        tagline: "下任务 / 记笔记",
        summary: "松开 Fn 后不会往输入框塞字，而是把这段话当成给 Agent 的任务意图。",
        result: "适合“帮我了解一下”“新建日程”“记下待办”“联网搜索”这些请求。",
        tint: ACColors.accentPurple
    )
]
