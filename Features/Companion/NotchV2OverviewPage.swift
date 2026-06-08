import SwiftUI

struct NotchV2OverviewPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 238, rightColumnWidth: 238) {
            leftColumn
        } centerColumn: {
            centerColumn
        } rightColumn: {
            rightColumn
        }
    }

    private var leftColumn: some View {
        NotchV2Card(
            title: "当前任务",
            symbol: "target",
            padding: 12,
            cardAccent: viewModel.activeRuntimeSurface.accentColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.activeRuntimeSurface.accentColor)
                        .frame(width: 7, height: 7)
                    Text(viewModel.activeRuntimeSurface.title)
                        .font(NotchV2DesignTokens.Typography.title)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                Text(viewModel.activeRuntimeSurface.subtitle)
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    NotchV2StatusPill(title: currentTaskSource, accent: viewModel.activeRuntimeSurface.accentColor.opacity(0.18))
                    NotchV2StatusPill(title: currentTaskPriority, accent: priorityAccent)
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                VStack(alignment: .leading, spacing: 6) {
                    compactRow(label: "焦点", value: currentFocusText)
                    compactRow(label: "最近输入", value: lastTaskText)
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                VStack(alignment: .leading, spacing: 4) {
                    Text("模块状态")
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    HStack(spacing: 6) {
                        moduleStatusDot(title: "音乐", enabled: viewModel.isModuleEnabled(.music), active: viewModel.playbackState.isPlaying)
                        moduleStatusDot(title: "AI", enabled: viewModel.isModuleEnabled(.agent), active: viewModel.status == .listening || viewModel.status == .transcribing)
                        moduleStatusDot(title: "日程", enabled: viewModel.isModuleEnabled(.schedule), active: false)
                    }
                }
            }
        }
    }

    private var centerColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "便捷动作", symbol: "bolt.fill", padding: 12, cardAccent: NotchV2DesignTokens.accentBlue) {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(viewModel.quickActions) { action in
                            NotchV2ActionButton(
                                icon: action.icon,
                                title: action.title,
                                isSelected: false,
                                action: action.action
                            )
                        }

                        NotchV2ActionButton(
                            icon: "desktopcomputer",
                            title: "状态",
                            isSelected: false
                        ) {
                            (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                        }

                        NotchV2ActionButton(
                            icon: "gearshape",
                            title: "设置",
                            isSelected: false
                        ) {
                            (NSApp.delegate as? NSObject)?.perform(Selector(("showSettings")))
                        }
                    }
                }
            }

            NotchV2Card(title: "运行中", symbol: "sparkles", padding: 12, cardAccent: viewModel.activeRuntimeSurface.accentColor) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.activeRuntimeSurface.symbol)
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(viewModel.activeRuntimeSurface.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.activeRuntimeSurface.title)
                            .font(NotchV2DesignTokens.Typography.body)
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                            .lineLimit(1)
                        Text(viewModel.activeRuntimeSurface.subtitle)
                            .font(NotchV2DesignTokens.Typography.caption)
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 0)

                    if viewModel.isVoicePriorityActive {
                        MiniVoiceWaveform(mode: viewModel.voiceWaveformMode, accent: viewModel.voiceDisplayAccent)
                    }
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            if let hint = viewModel.systemAttentionHint {
                NotchV2SystemAttentionHintCard(hint: hint)
            }

            NotchV2Card(title: "系统快览", symbol: "cpu", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    systemStatusRow(
                        icon: batteryIconName,
                        title: "电池",
                        value: viewModel.batteryStateText,
                        accent: viewModel.batteryAccent
                    )

                    systemStatusRow(
                        icon: "mic.fill",
                        title: "麦克风",
                        value: viewModel.microphonePermissionStatus.displayName,
                        accent: viewModel.microphonePermissionStatus == .authorized ? NotchV2DesignTokens.accentGreen : .orange
                    )

                    systemStatusRow(
                        icon: "display",
                        title: "录屏",
                        value: viewModel.screenRecordingPermissionStatus.displayName,
                        accent: viewModel.screenRecordingPermissionStatus == .authorized ? NotchV2DesignTokens.accentGreen : .orange
                    )

                    systemStatusRow(
                        icon: "accessibility",
                        title: "辅助功能",
                        value: viewModel.accessibilityPermissionStatus.displayName,
                        accent: viewModel.accessibilityPermissionStatus == .authorized ? NotchV2DesignTokens.accentGreen : .orange
                    )
                }
            }

            NotchV2Card(title: "快捷入口", symbol: "arrow.triangle.2.circlepath", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(spacing: 6) {
                    quickEntryRow(
                        title: "音乐",
                        subtitle: "播放与队列",
                        icon: "music.note",
                        tint: NotchV2DesignTokens.accentGreen
                    ) {
                        viewModel.select(.music)
                    }

                    quickEntryRow(
                        title: "AI",
                        subtitle: "对话入口",
                        icon: "sparkles",
                        tint: NotchV2DesignTokens.accentBlue
                    ) {
                        viewModel.select(.agent)
                    }

                    quickEntryRow(
                        title: "日程",
                        subtitle: "今日安排",
                        icon: "calendar",
                        tint: NotchV2DesignTokens.accentPurple
                    ) {
                        viewModel.select(.schedule)
                    }
                }
            }
        }
    }

    private var currentTaskSource: String {
        switch viewModel.activeRuntimeSurface.kind {
        case .voice: return "说入法"
        case .screenshot: return "截图"
        case .music: return "音乐"
        case .schedule: return "日程"
        case .agent: return "AI"
        case .systemStatus: return "状态"
        case .idle: return "本机"
        }
    }

    private var currentTaskPriority: String {
        switch viewModel.activeRuntimeSurface.priority {
        case .voiceRecording, .voiceProcessing, .screenshot, .systemEventHUD:
            return "高"
        case .music:
            return "中"
        case .defaultState:
            return "普通"
        }
    }

    private var priorityAccent: Color {
        switch viewModel.activeRuntimeSurface.priority {
        case .voiceRecording, .voiceProcessing, .screenshot, .systemEventHUD:
            return .orange.opacity(0.18)
        case .music:
            return NotchV2DesignTokens.accentGreen.opacity(0.18)
        case .defaultState:
            return NotchV2DesignTokens.cardBackgroundStrong
        }
    }

    private var currentFocusText: String {
        if let transcription = viewModel.lastTranscription?.text, transcription.isEmpty == false {
            return "最近输入已记录"
        }
        return viewModel.activeRuntimeSurface.subtitle
    }

    private var lastTaskText: String {
        if let text = viewModel.lastTranscription?.text, text.isEmpty == false {
            return text
        }
        return "等待下一条指令"
    }

    private var batteryIconName: String {
        if viewModel.batteryInfo.isCharging {
            return "bolt.fill"
        }
        if viewModel.batteryInfo.isPluggedIn {
            return "plug.fill"
        }
        let level = viewModel.batteryInfo.percentage
        switch level {
        case ..<10: return "battery.0"
        case ..<25: return "battery.25"
        case ..<50: return "battery.50"
        case ..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private func compactRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .frame(width: 42, alignment: .leading)
                .lineLimit(1)

            Text(value)
                .font(NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
    }

    private func moduleStatusDot(title: String, enabled: Bool, active: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(active ? NotchV2DesignTokens.accentGreen : (enabled ? NotchV2DesignTokens.secondaryText : NotchV2DesignTokens.weakText))
                .frame(width: 5, height: 5)
            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(enabled ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.weakText)
                .lineLimit(1)
        }
    }

    private func systemStatusRow(icon: String, title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 16)

            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(value)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.88))
        )
    }

    private func quickEntryRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.weakText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.82))
            )
        }
        .buttonStyle(.plain)
    }
}
