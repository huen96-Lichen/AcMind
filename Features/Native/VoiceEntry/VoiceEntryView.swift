import SwiftUI
import AppKit
import AcMindKit

struct VoiceEntryView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var preferredMicrophoneSelection = VoiceMicrophonePreferenceStore.defaultName
    @State private var microphoneDevices: [VoiceMicrophoneDevice] = []

    var body: some View {
        AcWorkShell(
            title: "说入法设置",
            subtitle: "真实控制语音输入链路：入口、识别、润色、输出、静音检测和连续输入。",
            leadingRailWidth: 208,
            trailingRailWidth: AppSurfaceTokens.Layout.summaryWidth,
            leadingRail: {
                voiceSummaryRail
            },
            content: {
                voiceContent
            },
            trailingRail: {
                voiceDetailRail
            }
        )
        .task {
            microphoneDevices = VoiceMicrophoneDeviceCatalog.availableInputDevices()
            let storedSelection = VoiceMicrophonePreferenceStore.load()
            if storedSelection == VoiceMicrophonePreferenceStore.defaultName {
                preferredMicrophoneSelection = storedSelection
            } else if let matchedDevice = microphoneDevices.first(where: { $0.id == storedSelection || $0.name == storedSelection }) {
                preferredMicrophoneSelection = matchedDevice.id
            } else {
                preferredMicrophoneSelection = storedSelection
            }
            await viewModel.loadPermissions()
        }
        .onChange(of: preferredMicrophoneSelection) { _, newValue in
            VoiceMicrophonePreferenceStore.save(newValue)
        }
    }

    private var voiceContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSurfaceTokens.Spacing.md) {
                AppSurfaceSummaryStrip(
                    chips: [
                        AppSurfaceSummaryChip(
                            title: "启用",
                            value: viewModel.companionVoiceEnabled ? "已启用" : "已关闭",
                            tint: viewModel.companionVoiceEnabled ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentSecondary
                        ),
                        AppSurfaceSummaryChip(
                            title: "快捷键",
                            value: viewModel.companionVoiceShortcut,
                            tint: AppSurfaceTokens.accentBlue
                        ),
                        AppSurfaceSummaryChip(
                            title: "输出",
                            value: viewModel.voiceOutputMode.displayName,
                            tint: AppSurfaceTokens.accentOrange
                        ),
                        AppSurfaceSummaryChip(
                            title: "麦克风",
                            value: viewModel.microphonePermissionStatus.displayName,
                            tint: AppSurfaceTokens.secondaryText
                        )
                    ]
                )

                workflowCard
                summaryGrid
                controlSections
            }
            .padding(AppSurfaceTokens.Spacing.lg)
            .frame(maxWidth: AppSurfaceTokens.Layout.pageMaxWidth, alignment: .leading)
        }
        .background(AppSurfaceBackdrop())
    }

    private var voiceSummaryRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppSurfaceCard(title: "入口概览", subtitle: "只读摘要", padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        railSummaryRow(
                            title: "启用",
                            value: SettingsStatusLabelFormatter.binaryState(
                                isEnabled: viewModel.companionVoiceEnabled,
                                enabledText: "已启用",
                                disabledText: "已关闭"
                            )
                        )
                        railSummaryRow(title: "快捷键", value: viewModel.companionVoiceShortcut)
                        railSummaryRow(title: "触发", value: viewModel.voiceTriggerMode.displayName)
                    }
                }

                AppSurfaceCard(title: "识别与输出", subtitle: "真实设置状态", padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        railSummaryRow(title: "ASR", value: providerDisplayName(viewModel.voiceDefaultProvider))
                        railSummaryRow(
                            title: "润色",
                            value: SettingsStatusLabelFormatter.binaryState(
                                isEnabled: viewModel.voiceAutoPolish,
                                enabledText: viewModel.voicePolishMode.displayName,
                                disabledText: "关闭"
                            )
                        )
                        railSummaryRow(title: "输出", value: viewModel.voiceOutputMode.displayName)
                        railSummaryRow(
                            title: "收集箱",
                            value: SettingsStatusLabelFormatter.binaryState(
                                isEnabled: viewModel.voiceSaveToInbox,
                                enabledText: "写入",
                                disabledText: "不写入"
                            )
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private var voiceDetailRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                runtimeCard
                statusEntryCard
                microphoneCard
            }
            .padding(AppSurfaceTokens.Spacing.lg)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private func railSummaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: AppSurfaceTokens.Typography.caption))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
    }

    private var workflowCard: some View {
        AppSurfaceCard(title: "当前工作流", subtitle: "监听 → 转写 → 修正 → 发送", padding: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        statePill(
                            title: viewModel.companionVoiceEnabled ? "已启用" : "已关闭",
                            accent: viewModel.companionVoiceEnabled ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentSecondary
                        )
                        statePill(
                            title: viewModel.voiceTriggerMode.displayName,
                            accent: AppSurfaceTokens.accentBlue
                        )
                        statePill(
                            title: viewModel.companionVoiceOutputMode.displayName,
                            accent: AppSurfaceTokens.accentOrange
                        )
                        statePill(
                            title: viewModel.voiceAutoPolish ? viewModel.voicePolishMode.displayName : "关闭润色",
                            accent: viewModel.voiceAutoPolish ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentSecondary
                        )
                    }

                    Text("语音链路说明")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)

                    Text(workflowDetailText)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("入口、识别、润色、输出和连续输入都在这里配置。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 10) {
                    workflowFactRow(title: "麦克风", value: viewModel.microphonePermissionStatus.displayName)
                    workflowFactRow(title: "输出方式", value: viewModel.voiceOutputMode.displayName)
                    workflowFactRow(title: "连续输入", value: continuationText)

                    Button("查看状态") {
                        (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 2)
                }
                .frame(width: 196, alignment: .leading)
            }
        }
    }

    private var summaryGrid: some View {
        AppSurfaceCard(title: "关键摘要", subtitle: "入口、识别与输出", padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "摘要概览",
                    description: "这些卡片对应说入法真正控制的链路。",
                    status: viewModel.companionVoiceEnabled ? "已启用" : "已关闭"
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    MetricCard(
                        label: "入口",
                        primaryValue: viewModel.companionVoiceShortcut,
                        trend: viewModel.voiceTriggerMode.displayName,
                        state: SettingsStatusLabelFormatter.binaryState(
                            isEnabled: viewModel.companionVoiceEnabled,
                            enabledText: "已启用",
                            disabledText: "已关闭"
                        ),
                        tint: AppSurfaceTokens.accentBlue
                    ) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.accentBlue)
                            .frame(width: 34, height: 34)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    MetricCard(
                        label: "识别",
                        primaryValue: providerDisplayName(viewModel.voiceDefaultProvider),
                        trend: languageDisplayName(viewModel.preferredLanguage),
                        state: viewModel.voiceAutoPolish ? viewModel.voicePolishMode.displayName : "关闭润色",
                        tint: AppSurfaceTokens.accentGreen
                    ) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.accentGreen)
                            .frame(width: 34, height: 34)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                MetricCard(
                    label: "输出",
                    primaryValue: viewModel.voiceOutputMode.displayName,
                    trend: translationLanguageDisplayName(viewModel.translationLanguage),
                    state: SettingsStatusLabelFormatter.binaryState(
                        isEnabled: viewModel.voiceAllowContinuation,
                        enabledText: continuationText,
                        disabledText: "关闭"
                    ),
                    lastUpdated: SettingsStatusLabelFormatter.binaryState(
                        isEnabled: viewModel.voiceSaveToInbox,
                        enabledText: "写入收集箱",
                        disabledText: "不写入收集箱"
                    ),
                    tint: AppSurfaceTokens.accentOrange
                    ) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.accentOrange)
                            .frame(width: 34, height: 34)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
            }
        }
    }

    private var controlSections: some View {
        VStack(alignment: .leading, spacing: AppSurfaceTokens.Spacing.md) {
            settingCard(title: "入口与触发", description: "说入法真实入口。已移除的独立问答和翻译入口不再出现在这里。") {
                toggleRow(title: "启用说入法", description: "控制快捷键入口是否工作。", isOn: persistedBinding(\.companionVoiceEnabled))
                divider
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("触发快捷键")
                            .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                        Text("当前全局入口。")
                            .font(.system(size: AppSurfaceTokens.Typography.caption))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    Spacer()
                    ShortcutRecorderView(shortcut: persistedBinding(\.companionVoiceShortcut))
                }
                .frame(minHeight: 44)
                divider
                pickerRow(title: "触发模式", description: viewModel.voiceTriggerMode.description, selection: persistedBinding(\.voiceTriggerMode)) {
                    ForEach(SayInputTriggerMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            settingCard(title: "识别与润色", description: "这些字段直接进入 VoiceSettings / SayInputConfiguration。") {
                pickerRow(title: "ASR 引擎", description: "当前默认语音识别提供方。", selection: persistedBinding(\.voiceDefaultProvider)) {
                    ForEach(asrProviderOptions, id: \.id) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                if viewModel.voiceDefaultProvider == "qwen3ASR" {
                    Text("Qwen3-ASR 以分段结果呈现，不提供真正的实时流式输出。")
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                divider
                pickerRow(title: "首选语言", description: "传给识别和说入法链路的语言偏好。", selection: persistedBinding(\.preferredLanguage)) {
                    ForEach(languageOptions, id: \.id) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                divider
                toggleRow(title: "自动润色", description: "录音结束后自动整理文稿。", isOn: persistedBinding(\.voiceAutoPolish))
                divider
                pickerRow(title: "润色模式", description: viewModel.voicePolishMode.description, selection: persistedBinding(\.voicePolishMode)) {
                    ForEach(VoicePolishMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            settingCard(title: "纠错规则", description: "ASR 转写后、润色前自动应用的确定性文本替换。") {
                correctionRulesSection
            }

            settingCard(title: "输出与连续输入", description: "控制交付目标、收集箱和延续窗口。") {
                pickerRow(title: "输出方式", description: "说入法最终如何交付文本。", selection: persistedBinding(\.voiceOutputMode)) {
                    ForEach(SayInputOutputMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                divider
                pickerRow(title: "翻译目标", description: "当输出方式为翻译时，译到这个语言。", selection: persistedBinding(\.translationLanguage)) {
                    ForEach(translationLanguageOptions, id: \.id) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                divider
                toggleRow(title: "保存到收集箱", description: "在交付文本同时写入收集箱。", isOn: persistedBinding(\.voiceSaveToInbox))
                divider
                toggleRow(title: "连续输入", description: "允许在短时间内延续上一段输入。", isOn: persistedBinding(\.voiceAllowContinuation))
                divider
                stepperRow(title: "连续输入窗口", description: "上一段输出后允许续写的窗口。", value: persistedBinding(\.voiceContinuationWindow), range: 5...60, step: 1, format: { "\($0.formatted(.number.precision(.fractionLength(0))))s" })
                divider
                toggleRow(title: "补全结尾标点", description: "结束时自动补充基础句末标点。", isOn: persistedBinding(\.enablePunctuationAppend))
            }

            settingCard(title: "静音检测与注入", description: "静音检测已经进入 SayInputConfiguration；麦克风设备偏好会在开始录音时自动应用。") {
                toggleRow(title: "启用静音检测", description: "检测长静音后自动停止录音。", isOn: persistedBinding(\.voiceEnableSilenceDetection))
                divider
                stepperRow(title: "静音超时", description: "达到该时长后自动停录。", value: persistedBinding(\.voiceSilenceTimeout), range: 1...10, step: 0.5, format: { "\($0.formatted(.number.precision(.fractionLength(1))))s" })
                divider
                toggleRow(title: "录音时静音系统音频", description: "录音期间临时静音系统输出，防止扬声器回声影响识别。", isOn: persistedBinding(\.muteSystemAudioDuringRecording))
                divider
                pickerRow(title: "注入策略", description: "文本写回焦点输入框的方式。", selection: persistedBinding(\.injectionStrategy)) {
                    ForEach(injectionOptions, id: \.id) { option in
                        Text(option.title).tag(option.id)
                    }
                }
            }
        }
    }

    private var runtimeCard: some View {
        settingCard(title: "当前链路", description: "这张卡展示当前页面真正控制的运行链。") {
            pipelineRow(
                "快捷键入口",
                SettingsStatusLabelFormatter.binaryState(
                    isEnabled: viewModel.companionVoiceEnabled,
                    enabledText: viewModel.companionVoiceShortcut,
                    disabledText: "已关闭"
                )
            )
            divider
            pipelineRow("悬浮入口", "CompanionVoicePanel")
            divider
            pipelineRow("录音协调", "SayInputCoordinator")
            divider
            pipelineRow("语音服务", "VoiceService")
            divider
            pipelineRow("交付结果", outputSummaryText)
        }
    }

    private var statusEntryCard: some View {
        settingCard(title: "状态入口", description: "完整本机状态集中在主侧边栏的「状态」。") {
            Button("查看状态") {
                (NSApp.delegate as? AppDelegate)?.showSystemStatus()
            }
            .buttonStyle(.bordered)
        }
    }

    private var microphoneCard: some View {
        settingCard(title: "录音输入设备", description: "这里选择的设备会在开始录音时写入系统默认输入；找不到时会回退自动选择。") {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("输入设备", selection: $preferredMicrophoneSelection) {
                        Text(VoiceMicrophonePreferenceStore.defaultName).tag(VoiceMicrophonePreferenceStore.defaultName)
                        ForEach(microphoneDevices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("当前已选: \(VoiceMicrophoneDeviceCatalog.displayName(for: preferredMicrophoneSelection))")
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("恢复自动选择") {
                    preferredMicrophoneSelection = VoiceMicrophonePreferenceStore.defaultName
                }
                .buttonStyle(.bordered)
            }

            Text("如果选中的设备在系统里不存在，会自动退回到默认输入。")
                .font(.system(size: 11))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingCard<Content: View>(title: String, description: String, @ViewBuilder content: () -> Content) -> some View {
        AppSurfaceCard(title: title, subtitle: description, padding: 14) {
            content()
        }
    }

    private func toggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    private func textRow(title: String, description: String, value: Binding<String>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer()
            TextField("", text: value)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180)
                .layoutPriority(1)
        }
        .frame(minHeight: 44)
    }

    private func pickerRow<Selection: Hashable, Content: View>(title: String, description: String, selection: Binding<Selection>, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Picker("", selection: selection) {
                content()
            }
            .labelsHidden()
            .frame(width: 200)
        }
        .frame(minHeight: 44)
    }

    private func stepperRow(title: String, description: String, value: Binding<TimeInterval>, range: ClosedRange<TimeInterval>, step: TimeInterval, format: @escaping (TimeInterval) -> String) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer()
            Stepper(value: value, in: range, step: step) {
                Text(format(value.wrappedValue))
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 68, alignment: .trailing)
            }
            .frame(width: 160)
        }
        .frame(minHeight: 44)
    }

    private func pipelineRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
    }

    private func statusRow(_ title: String, status: AppPermissionStatus) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(status.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(permissionColor(status))
        }
    }

    private func workflowFactRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
    }

    private func statePill(title: String, accent: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            )
    }

    private var workflowDetailText: String {
        "录音中的实时反馈会出现在浮窗里，这个页面只负责配置和解释说入法链路。"
    }

    private var divider: some View {
        Divider().overlay(AppSurfaceTokens.separator.opacity(0.6))
    }

    private var continuationText: String {
        "\(viewModel.voiceContinuationWindow.formatted(.number.precision(.fractionLength(0))))s"
    }

    private var outputSummaryText: String {
        let output = viewModel.voiceOutputMode.displayName
        let translated = viewModel.voiceOutputMode == .translate ? " → \(translationLanguageDisplayName(viewModel.translationLanguage))" : ""
        let summary = "\(output)\(translated)"
        return SettingsStatusLabelFormatter.binaryState(
            isEnabled: viewModel.voiceSaveToInbox,
            enabledText: "\(summary) + 收集箱",
            disabledText: summary
        )
    }

    private var asrProviderOptions: [(id: String, title: String)] {
        [
            ("whisper", "Whisper"),
            ("appleSpeech", "Apple Speech"),
            ("senseVoice", "SenseVoice"),
            ("whisperKit", "WhisperKit"),
            ("funASR", "FunASR"),
            ("qwen3ASR", "Qwen3-ASR"),
            ("parakeet", "Parakeet"),
            ("mimo_asr", "MiMo ASR")
        ]
    }

    private var languageOptions: [(id: String, title: String)] {
        [
            ("auto", "自动"),
            ("zh", "中文"),
            ("en", "English"),
            ("ja", "日本語"),
            ("ko", "한국어"),
            ("yue", "粤语")
        ]
    }

    private var injectionOptions: [(id: String, title: String)] {
        [
            ("postToPid", "postToPid"),
            ("pasteboardFallback", "pasteboardFallback")
        ]
    }

    private var translationLanguageOptions: [(id: String, title: String)] {
        [
            ("zh", "中文"),
            ("en", "英文"),
            ("ja", "日文"),
            ("ko", "韩文")
        ]
    }

    private func providerDisplayName(_ id: String) -> String {
        asrProviderOptions.first(where: { $0.id == id })?.title ?? id
    }

    private func languageDisplayName(_ id: String) -> String {
        languageOptions.first(where: { $0.id == id })?.title ?? id
    }

    private func translationLanguageDisplayName(_ id: String) -> String {
        translationLanguageOptions.first(where: { $0.id == id })?.title ?? id
    }

    private func permissionColor(_ status: AppPermissionStatus) -> Color {
        switch status {
        case .authorized: return .green
        case .notDetermined, .unknown: return .secondary
        case .requesting: return .blue
        case .needsSystemSettings, .denied, .restricted, .failed: return .orange
        }
    }

    private var correctionRulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.correctionRules, id: \.id) { rule in
                HStack(spacing: 10) {
                    TextField("匹配", text: correctionRuleBinding(for: rule, keyPath: \.pattern))
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 120)
                        .layoutPriority(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    TextField("替换", text: correctionRuleBinding(for: rule, keyPath: \.replacement))
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 120)
                        .layoutPriority(1)
                    Toggle("正则", isOn: correctionRuleBinding(for: rule, keyPath: \.isRegex))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    Button {
                        if let idx = viewModel.correctionRules.firstIndex(where: { $0.id == rule.id }) {
                            viewModel.correctionRules.remove(at: idx)
                            Task { await viewModel.saveSettings() }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                viewModel.correctionRules.append(CorrectionRule(pattern: "", replacement: ""))
                Task { await viewModel.saveSettings() }
            } label: {
                Label("添加规则", systemImage: "plus.circle")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppSurfaceTokens.accentBlue)
        }
    }

    private func correctionRuleBinding<T: Equatable>(for rule: CorrectionRule, keyPath: WritableKeyPath<CorrectionRule, T>) -> Binding<T> {
        Binding<T>(
            get: {
                guard let idx = viewModel.correctionRules.firstIndex(where: { $0.id == rule.id }) else {
                    return rule[keyPath: keyPath]
                }
                return viewModel.correctionRules[idx][keyPath: keyPath]
            },
            set: { newValue in
                guard let idx = viewModel.correctionRules.firstIndex(where: { $0.id == rule.id }) else { return }
                viewModel.correctionRules[idx][keyPath: keyPath] = newValue
                Task { await viewModel.saveSettings() }
            }
        )
    }

    private func persistedBinding<Value>(_ keyPath: ReferenceWritableKeyPath<SettingsViewModel, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { newValue in
                viewModel[keyPath: keyPath] = newValue
                Task { await viewModel.saveSettings() }
            }
        )
    }
}
