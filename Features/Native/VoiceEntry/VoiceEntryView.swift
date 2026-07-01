import SwiftUI
import AppKit
import AcMindKit

struct VoiceEntryView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var preferredMicrophoneSelection = VoiceMicrophonePreferenceStore.defaultName
    @State private var microphoneDevices: [VoiceMicrophoneDevice] = []
    @State private var localASRModels: [LocalASRModelInfo] = []

    var body: some View {
        AcWorkShell(
            title: "说入法",
            subtitle: "管理触发、识别、润色与输出",
            leadingRailWidth: 0,
            trailingRailWidth: 0,
            leadingRail: { EmptyView() },
            content: { voiceContent },
            trailingRail: { EmptyView() }
        )
        .task {
            microphoneDevices = VoiceMicrophoneDeviceCatalog.availableInputDevices()
            localASRModels = await LocalASRManager.shared.listAvailableModels()
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
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            Task {
                await viewModel.loadSettings()
                await viewModel.loadPermissions()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionConfigurationDidChange)) { _ in
            Task {
                await viewModel.loadCompanionSettings()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShortcutsDidChange)) { _ in
            Task {
                await viewModel.loadCompanionSettings()
            }
        }
        .onChange(of: preferredMicrophoneSelection) { _, newValue in
            VoiceMicrophonePreferenceStore.save(newValue)
        }
    }

    private var voiceContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceSectionSpacing) {
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
                asrReadinessCard
                quickLaunchCard
                controlSections
            }
            .padding(AppSurfaceTokens.Layout.workspacePagePadding)
            .frame(maxWidth: AppSurfaceTokens.Layout.workspaceMaxWidth, alignment: .leading)
        }
        .background(AppSurfaceBackdrop())
    }

    private var workflowCard: some View {
        AppSurfaceCard(title: "当前工作流", subtitle: "监听 → 转写 → 修正 → 发送", padding: AppSurfaceTokens.Layout.workspaceCardPadding) {
            HStack(alignment: .top, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                    HStack(spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
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

                    Text("语音链路")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)

                    Text(workflowDetailText)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("触发、识别、润色、输出和连续输入都在这里配置。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
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
        AppSurfaceCard(title: "关键总览", subtitle: "触发、识别与输出", padding: AppSurfaceTokens.Layout.workspaceCardPadding) {
            VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                SectionHeader(
                    title: "总览",
                    description: "这些卡片对应说入法实际控制的链路。",
                    status: viewModel.companionVoiceEnabled ? "已启用" : "已关闭"
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppSurfaceTokens.Layout.workspaceGridSpacing),
                        GridItem(.flexible(), spacing: AppSurfaceTokens.Layout.workspaceGridSpacing)
                    ],
                    spacing: AppSurfaceTokens.Layout.workspaceGridSpacing
                ) {
                    MetricCard(
                        label: "触发",
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

    private var asrReadinessCard: some View {
        AppSurfaceCard(title: "识别就绪度", subtitle: "当前识别引擎、凭证与本地模型状态", padding: AppSurfaceTokens.Layout.workspaceCardPadding) {
            VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                HStack(spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                    statePill(title: selectedASRProvider.displayName, accent: AppSurfaceTokens.accentBlue)
                    statePill(title: asrReadinessText, accent: asrReadinessTint)
                    statePill(title: "\(localASRModels.filter { $0.isDownloaded }.count)/\(localASRModels.count) 本地模型", accent: AppSurfaceTokens.accentOrange)
                }

                HStack(alignment: .top, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前默认引擎")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Text(selectedASRProviderDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("本地模型")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Text(localASRModels.isEmpty ? "未发现本地模型" : localASRModels.map { "\($0.name)：\($0.isDownloaded ? "已下载" : "未下载")" }.joined(separator: " · "))
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        AppState.shared.navigate(to: .modelManagement)
                    } label: {
                        Label("打开模型管理", systemImage: "square.stack.3d.up")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        AppState.shared.navigate(to: .settings, settingsCategory: .aiModels)
                    } label: {
                        Label("查看模型设置", systemImage: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)

                    Button {
                        AppState.shared.navigate(to: .settings, settingsCategory: .captureInput)
                    } label: {
                        Label("查看捕获设置", systemImage: "camera.viewfinder")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var quickLaunchCard: some View {
        AppSurfaceCard(title: "快速进入", subtitle: "从设置页直接打开说入法面板", padding: AppSurfaceTokens.Layout.workspaceCardPadding) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前设备")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Text(VoiceMicrophoneDeviceCatalog.displayName(for: preferredMicrophoneSelection))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text(selectedMicrophoneStatusText)
                        .font(.system(size: 11))
                        .foregroundStyle(selectedMicrophoneIsAvailable ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.accentOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
                } label: {
                    Label("打开说入法面板", systemImage: "mic.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(height: 34)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    AppState.shared.navigate(to: .workbench, workbenchToolRoute: .apiTest)
                } label: {
                    Label("验证接口", systemImage: "checkmark.shield")
                        .font(.system(size: 13, weight: .medium))
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)

                Button {
                    AppState.shared.navigate(to: .settings)
                } label: {
                    Label("查看设置首页", systemImage: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)

                Button {
                    (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                } label: {
                    Label("查看状态", systemImage: "cpu")
                        .font(.system(size: 13, weight: .medium))
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var controlSections: some View {
        VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceSectionSpacing) {
            settingCard(title: "触发与行为", description: "说入法的触发方式和输出行为。") {
                toggleRow(title: "启用说入法", description: "控制快捷键是否可用。", isOn: persistedBinding(\.companionVoiceEnabled))
                divider
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("触发快捷键")
                            .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                        Text("当前全局触发方式。")
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

            settingCard(title: "识别与润色", description: "这些字段会直接参与识别与润色配置。") {
                pickerRow(title: "语音识别引擎", description: "当前默认语音识别提供方。", selection: persistedBinding(\.voiceDefaultProvider)) {
                    ForEach(asrProviderOptions, id: \.id) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                if STTProvider.selectableIdentifier(from: viewModel.voiceDefaultProvider) == STTProvider.qwen3ASR.rawValue {
                    Text("Qwen3 语音识别以分段结果呈现，不提供真正的实时流式输出。")
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

            settingCard(title: "纠错规则", description: "语音识别转写后、润色前自动应用的确定性文本替换。") {
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

            settingCard(title: "静音检测与注入", description: "静音检测已接入，录音时会自动应用麦克风偏好。") {
                toggleRow(title: "启用静音检测", description: "检测长静音后自动停止录音。", isOn: persistedBinding(\.voiceEnableSilenceDetection))
                divider
                stepperRow(title: "静音超时", description: "达到该时长后自动停录。", value: persistedBinding(\.voiceSilenceTimeout), range: 1...10, step: 0.5, format: { "\($0.formatted(.number.precision(.fractionLength(1))))s" })
                divider
                toggleRow(title: "录音时静音系统音频", description: "录音期间静音系统输出，防止扬声器回声影响识别。", isOn: persistedBinding(\.muteSystemAudioDuringRecording))
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
        settingCard(title: "当前链路", description: "这张卡展示当前页面控制的运行链。") {
            pipelineRow(
                "快捷键触发",
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
        settingCard(title: "状态总览", description: "完整本机状态集中在主侧边栏的「状态」。") {
            Button("查看状态") {
                (NSApp.delegate as? AppDelegate)?.showSystemStatus()
            }
            .buttonStyle(.bordered)
        }
    }

    private var microphoneCard: some View {
        settingCard(title: "录音输入设备", description: "这里选择的设备会在开始录音时写入系统默认输入；找不到时会自动退回。") {
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

                    if selectedMicrophoneIsAvailable == false {
                        Text("当前选择的麦克风未在系统设备中找到，录音时会自动回退到默认输入。")
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurfaceTokens.accentOrange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Button("恢复自动选择") {
                    preferredMicrophoneSelection = VoiceMicrophonePreferenceStore.defaultName
                }
                .buttonStyle(.bordered)
            }

            Text("选中的设备若不存在，会自动退回默认输入。")
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
        "录音中的实时反馈会出现在浮窗里，这个页面只负责配置说入法。"
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

    private var selectedMicrophoneIsAvailable: Bool {
        guard preferredMicrophoneSelection != VoiceMicrophonePreferenceStore.defaultName else {
            return true
        }
        return microphoneDevices.contains(where: { $0.id == preferredMicrophoneSelection || $0.name == preferredMicrophoneSelection })
    }

    private var selectedMicrophoneStatusText: String {
        if preferredMicrophoneSelection == VoiceMicrophonePreferenceStore.defaultName {
            return "使用系统默认输入"
        }
        if selectedMicrophoneIsAvailable {
            return "设备可用，录音时会临时切换"
        }
        return "设备未找到，录音时自动回退"
    }

    private var asrProviderOptions: [(id: String, title: String)] {
        STTProvider.selectableCases.map { ($0.rawValue, $0.displayName) }
    }

    private var languageOptions: [(id: String, title: String)] {
        [
            ("auto", "自动"),
            ("zh", "中文"),
            ("en", "英文"),
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

    private var selectedASRProvider: STTProvider {
        STTProvider(rawValue: STTProvider.selectableIdentifier(from: viewModel.voiceDefaultProvider)) ?? .appleSpeech
    }

    private var selectedASRProviderDescription: String {
        let provider = selectedASRProvider
        if provider == .appleSpeech {
            return "系统听写，开箱即用。"
        }

        if provider.isLocal {
            if let localModel = localASRModels.first(where: { localASRProviderID(for: $0.type) == provider.rawValue }) {
                return localModel.isDownloaded
                    ? "\(localModel.name) 已安装，可直接用于本地识别。"
                    : "\(localModel.name) 未下载，去模型管理下载后可用。"
            }
            return "本地模型信息未就绪，请打开模型管理检查。"
        }

        switch provider {
        case .openAI:
            return "依赖 OpenAI 兼容接口和 API Key。"
        case .aliCloud:
            return "依赖阿里云 ASR 凭证。"
        case .doubao:
            return "依赖火山引擎 ASR 凭证。"
        case .mimoASR:
            return "依赖 MiMo ASR 凭证。"
        default:
            return "当前引擎已配置。"
        }
    }

    private var asrReadinessText: String {
        let provider = selectedASRProvider
        if provider == .appleSpeech {
            return "系统可用"
        }
        if provider.isLocal {
            let installed = localASRModels.contains { localASRProviderID(for: $0.type) == provider.rawValue && $0.isDownloaded }
            return installed ? "本地就绪" : "待下载"
        }
        return viewModel.voiceDefaultProvider.isEmpty ? "未配置" : "待验证"
    }

    private var asrReadinessTint: Color {
        let provider = selectedASRProvider
        if provider == .appleSpeech {
            return AppSurfaceTokens.accentGreen
        }
        if provider.isLocal {
            let installed = localASRModels.contains { localASRProviderID(for: $0.type) == provider.rawValue && $0.isDownloaded }
            return installed ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange
        }
        return AppSurfaceTokens.accentBlue
    }

    private func localASRProviderID(for type: LocalASRModelType) -> String {
        switch type {
        case .senseVoice:
            return STTProvider.senseVoice.rawValue
        case .whisperKit:
            return STTProvider.whisperKit.rawValue
        case .funASR:
            return STTProvider.funASR.rawValue
        case .qwen3ASR:
            return STTProvider.qwen3ASR.rawValue
        case .parakeet:
            return STTProvider.parakeet.rawValue
        }
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
