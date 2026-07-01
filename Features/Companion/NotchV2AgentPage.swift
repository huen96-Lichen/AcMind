import SwiftUI
import AcMindKit

struct NotchV2AgentPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 136, rightColumnWidth: 136) {
            leftColumn
        } centerColumn: {
            centerColumn
        } rightColumn: {
            rightColumn
        }
    }

    private var leftColumn: some View {
        CompanionPanel(title: "对话历史", symbol: "clock.arrow.circlepath", fillHeight: true) {
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

                Text(viewModel.activeModelLabel)
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(viewModel.activeProviderStatus)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)

                if modelNeedsConfiguration {
                    NotchV2StatusPill(
                        icon: "gearshape",
                        title: "配置模型",
                        accent: NotchV2DesignTokens.accentBlue,
                        action: {
                            viewModel.showMainSettings()
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    NotchV2StatusPill(
                        icon: "square.stack.3d.up",
                        title: "模型管理",
                        accent: NotchV2DesignTokens.cardBackgroundStrong,
                        action: {
                            viewModel.showModelManagement()
                        }
                    )

                    NotchV2StatusPill(
                        icon: "tray.full",
                        title: "收集箱",
                        accent: NotchV2DesignTokens.cardBackgroundStrong,
                        action: {
                            viewModel.showInbox()
                        }
                    )

                    NotchV2StatusPill(
                        icon: "brain",
                        title: "智能与模型",
                        accent: NotchV2DesignTokens.cardBackgroundStrong,
                        action: {
                            viewModel.showMainSettings(category: .aiModels)
                        }
                    )
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                if viewModel.quickAskMessages.isEmpty {
                    Text("暂无对话记录")
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(viewModel.quickAskMessages.suffix(3), id: \.id) { message in
                                historyRow(message: message)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }

    private var centerColumn: some View {
        CompanionPanel(title: "对话", symbol: "message", fillHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chatPreviewMessages, id: \.id) { message in
                            chatBubble(message)
                        }

                        if viewModel.quickAskIsSending {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("正在发送...")
                                    .font(NotchV2DesignTokens.Typography.caption)
                                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)
                quickAskComposer
            }
        }
    }

    private var rightColumn: some View {
        CompanionPanel(title: "最近上下文", symbol: "tray", fillHeight: true) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.quickAskMessages.suffix(3), id: \.id) { message in
                    historyRow(message: message)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var modelNeedsConfiguration: Bool {
        viewModel.activeModelLabel == SettingsStatusLabelFormatter.unconfiguredModelText
            || viewModel.activeProviderStatus == SettingsStatusLabelFormatter.unconfiguredProviderText
    }

    private var quickAskComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("快速提问")
                        .font(NotchV2DesignTokens.Typography.title)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                    Text("基于当前上下文继续问。")
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                StatusBadge(
                    text: viewModel.quickAskIsSending ? "发送中" : "就绪",
                    tone: viewModel.quickAskIsSending ? .warning : .info,
                    icon: viewModel.quickAskIsSending ? "arrow.triangle.2.circlepath" : "sparkles"
                )
            }

            HStack(spacing: 8) {
                notchComposerStage(title: "总结") {
                    viewModel.quickAskDraft = "帮我总结一下刚才的对话"
                }
                notchComposerStage(title: "翻译") {
                    viewModel.quickAskDraft = "翻译成英文"
                }
                notchComposerStage(title: "整理") {
                    viewModel.quickAskDraft = "把这些内容整理成要点"
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    NotchQuickAskTextEditorShell(
                        text: $viewModel.quickAskDraft,
                        minHeight: 84,
                        font: NotchV2DesignTokens.Typography.body,
                        accent: NotchV2DesignTokens.accentBlue
                    )

                    if viewModel.quickAskDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("问一句，Notch 会把当前上下文一起带上。")
                            .font(NotchV2DesignTokens.Typography.body)
                            .foregroundStyle(NotchV2DesignTokens.weakText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 104, alignment: .topLeading)
                .onTapGesture {
                    // keep focus behaviour native; TextEditor will take focus naturally when clicked
                }

                quickComposerAction
                    .disabled(viewModel.quickAskDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.quickAskIsSending)
            }

            if let error = viewModel.quickAskError, error.isEmpty == false {
                Text(error)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.22), lineWidth: 1)
        )
    }

    private var quickComposerAction: some View {
        Button {
            Task { await viewModel.sendQuickAsk() }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: viewModel.quickAskIsSending ? "progress.indicator" : "arrow.up.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(viewModel.quickAskIsSending ? "发送中" : "发送")
                    .font(NotchV2DesignTokens.Typography.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 68, height: 100)
            .background(
                RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                    .fill(viewModel.quickAskIsSending ? NotchV2DesignTokens.panelBackground.opacity(0.82) : NotchV2DesignTokens.accentBlue.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                    .stroke(NotchV2DesignTokens.separator.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private struct NotchQuickAskTextEditorShell: View {
        @Binding var text: String
        var minHeight: CGFloat
        var font: Font
        var accent: Color

        var body: some View {
            TextEditor(text: $text)
                .font(font)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: minHeight)
                .background(
                    RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.20), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous))
        }
    }

    private var chatPreviewMessages: [ChatMessage] {
        viewModel.quickAskMessages.suffix(2).map { $0 }
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user

        return HStack {
            if isUser { Spacer(minLength: 24) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .assistant ? "智能" : "我")
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(message.role == .assistant ? NotchV2DesignTokens.secondaryText : NotchV2DesignTokens.secondaryText)
                Text(message.content)
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(3)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: 320, alignment: .leading)
            .background(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                    .fill(isUser ? NotchV2DesignTokens.accentBlue.opacity(0.08) : NotchV2DesignTokens.cardBackgroundStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                    .stroke(isUser ? NotchV2DesignTokens.accentBlue.opacity(0.12) : NotchV2DesignTokens.separator.opacity(0.25), lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 24) }
        }
    }

    private func notchComposerStage(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(NotchV2DesignTokens.panelBackground.opacity(0.90))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(NotchV2DesignTokens.separator.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func historyRow(message: ChatMessage) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(message.role == .assistant ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.secondaryText)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(message.role == .assistant ? "智能" : "我")
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                Text(message.content)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground)
        )
    }
}
