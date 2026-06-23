import SwiftUI
import AcMindKit

struct NotchV2OverviewPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        CompanionPageTemplate.triple(leftWidth: CompanionLayoutTokens.templateAColumnWidth, rightWidth: CompanionLayoutTokens.templateAColumnWidth, left: {
            leftColumn
        }, center: {
            centerColumn
        }, right: {
            rightColumn
        })
    }

    private var leftColumn: some View {
        CompanionPanel(
            title: "当前任务",
            symbol: "target",
            fillHeight: true,
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(NotchV2DesignTokens.secondaryText)
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
                    NotchV2StatusPill(title: currentTaskSource, accent: NotchV2DesignTokens.cardBackgroundStrong)
                    NotchV2StatusPill(title: currentTaskPriority, accent: priorityAccent)
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                VStack(alignment: .leading, spacing: 6) {
                    NotchV2InfoRow(title: "焦点", value: currentFocusText, icon: "scope", accent: NotchV2DesignTokens.secondaryText, compactValue: true)
                    NotchV2InfoRow(title: "最近输入", value: lastTaskText, icon: "clock.arrow.circlepath", accent: NotchV2DesignTokens.secondaryText, compactValue: true)
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                VStack(alignment: .leading, spacing: 3) {
                    Text("模块状态")
                        .font(NotchV2DesignTokens.Typography.caption.weight(.medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    if activeOverviewModules.isEmpty {
                        Text("全部待命")
                            .font(NotchV2DesignTokens.Typography.caption)
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                    } else {
                        HStack(spacing: 6) {
                            ForEach(activeOverviewModules, id: \.self) { module in
                                moduleStatusDot(
                                    title: module.displayName.replacingOccurrences(of: "模块", with: ""),
                                    enabled: viewModel.isModuleEnabled(module),
                                    active: moduleActiveState(module)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var centerColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            CompanionPanel(title: "便捷动作", symbol: "bolt.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 92, maximum: 132), spacing: 8)
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
                    }
                }
            }

            CompanionPanel(
                title: "运行中",
                symbol: "sparkles",
                fillHeight: true,
            ) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.activeRuntimeSurface.symbol)
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)

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
                NotchV2SystemAttentionHintCard(hint: hint) {
                    viewModel.openSystemStatusPage()
                }
            }

            CompanionPanel(title: "系统快览", symbol: "cpu", fillHeight: true, accent: nil) {
                VStack(alignment: .leading, spacing: 6) {
                    NotchV2InfoRow(title: "电池", value: viewModel.batteryStateText, icon: batteryIconName, accent: viewModel.batteryAccent, compactValue: true)
                    NotchV2InfoRow(title: "麦克风", value: viewModel.microphonePermissionStatus.displayName, icon: "mic.fill", accent: permissionAccent(for: viewModel.microphonePermissionStatus), compactValue: true)
                    NotchV2InfoRow(title: "录屏", value: viewModel.screenRecordingPermissionStatus.displayName, icon: "display", accent: permissionAccent(for: viewModel.screenRecordingPermissionStatus), compactValue: true)
                    NotchV2InfoRow(title: "辅助功能", value: viewModel.accessibilityPermissionStatus.displayName, icon: "accessibility", accent: permissionAccent(for: viewModel.accessibilityPermissionStatus), compactValue: true)

                    Divider()
                        .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                    NotchV2StatusPill(
                        icon: "arrow.up.right.square",
                        title: "进入状态页",
                        accent: NotchV2DesignTokens.cardBackgroundStrong,
                        action: {
                            viewModel.openSystemStatusPage()
                        }
                    )
                }
            }
        }
    }

    private var currentTaskSource: String {
        switch viewModel.activeRuntimeSurface.kind {
        case .voice: return "说入法"
        case .screenshot: return "截图"
        case .music:
            return NowPlayingSourceLabelFormatter.playbackContextLabel(
                isPlaying: viewModel.playbackState.isPlaying,
                bundleIdentifier: viewModel.playbackState.bundleIdentifier,
                source: viewModel.playbackState.sourceLabel,
                idlePrefix: "音乐"
            )
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
            return NotchV2DesignTokens.cardBackgroundStrong
        case .music:
            return NotchV2DesignTokens.cardBackgroundStrong
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
        viewModel.batteryIconName
    }

    private var activeOverviewModules: [DynamicContinentModuleID] {
        viewModel.orderedOverviewModules.filter { moduleActiveState($0) }
    }

    private func moduleStatusDot(title: String, enabled: Bool, active: Bool) -> some View {
            HStack(spacing: 4) {
                Circle()
                    .fill(active ? NotchV2DesignTokens.secondaryText : (enabled ? NotchV2DesignTokens.secondaryText.opacity(0.75) : NotchV2DesignTokens.weakText))
                    .frame(width: 5, height: 5)
                Text(title)
                .font(NotchV2DesignTokens.Typography.caption.weight(.medium))
                .foregroundStyle(enabled ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.weakText)
                .lineLimit(1)
            }
    }

    private func moduleActiveState(_ module: DynamicContinentModuleID) -> Bool {
        switch module {
        case .music:
            return viewModel.playbackState.isPlaying
        case .agent:
            return viewModel.status == .listening || viewModel.status == .transcribing
        case .schedule:
            return false
        case .systemStatus:
            return viewModel.systemAttentionHint != nil
        }
    }

    private func permissionAccent(for status: AppPermissionStatus) -> Color {
        status == .authorized ? NotchV2DesignTokens.secondaryText : NotchV2DesignTokens.weakText
    }

}
