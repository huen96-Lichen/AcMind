import SwiftUI
import AppKit

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
                    }

                    Divider()
                        .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                    HStack(spacing: 8) {
                        Image(systemName: viewModel.activeRuntimeSurface.symbol)
                            .font(NotchV2DesignTokens.Typography.caption)
                            .foregroundStyle(viewModel.activeRuntimeSurface.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("当前运行")
                                .font(NotchV2DesignTokens.Typography.caption)
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                                .lineLimit(1)
                            Text(viewModel.activeRuntimeSurface.subtitle)
                                .font(NotchV2DesignTokens.Typography.body)
                                .foregroundStyle(NotchV2DesignTokens.primaryText)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "常用入口", symbol: "arrow.triangle.2.circlepath", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(spacing: 8) {
                    entryButton(
                        title: "音乐",
                        subtitle: "播放与队列",
                        icon: "music.note",
                        tint: NotchV2DesignTokens.accentGreen
                    ) {
                        viewModel.select(.music)
                    }

                    entryButton(
                        title: "AI",
                        subtitle: "对话入口",
                        icon: "sparkles",
                        tint: NotchV2DesignTokens.accentBlue
                    ) {
                        viewModel.select(.agent)
                    }

                    entryButton(
                        title: "状态",
                        subtitle: "本机进程",
                        icon: "desktopcomputer",
                        tint: NotchV2DesignTokens.secondaryText
                    ) {
                        (NSApp.delegate as? AppDelegate)?.showSystemStatus()
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

    private func entryButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tint)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(NotchV2DesignTokens.Typography.title)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.82))
            )
        }
        .buttonStyle(.plain)
    }
}
