import SwiftUI
import AcMindKit

struct NotchV2AgentPage: View {
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
        NotchV2Card(title: "AI 状态", symbol: "sparkles") {
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

                HStack(spacing: 6) {
                    NotchV2StatusPill(icon: "mic.fill", title: "说入法", accent: NotchV2DesignTokens.cardBackgroundStrong) {
                        viewModel.showVoicePanel()
                    }
                    NotchV2StatusPill(icon: "arrow.up.circle.fill", title: "执行", accent: NotchV2DesignTokens.accentBlue) {
                        viewModel.showAgent()
                    }
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                VStack(alignment: .leading, spacing: 6) {
                    infoRow(label: "对话数", value: "\(viewModel.quickAskMessages.count)")
                    infoRow(label: "模型", value: viewModel.activeModelLabel)
                    infoRow(label: "提供器", value: viewModel.activeProviderStatus)
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                VStack(alignment: .leading, spacing: 4) {
                    Text("快捷入口")
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)

                    HStack(spacing: 6) {
                        quickActionMini(icon: "camera.viewfinder", title: "截图") {
                            viewModel.quickActions.first(where: { $0.title == "截图" })?.action()
                        }
                        quickActionMini(icon: "doc.text", title: "MD") {
                            viewModel.quickActions.first(where: { $0.title == "MD" })?.action()
                        }
                        quickActionMini(icon: "pin.fill", title: "Pin") {
                            viewModel.quickActions.first(where: { $0.title == "Pin" })?.action()
                        }
                    }
                }
            }
        }
    }

    private var centerColumn: some View {
        NotchV2Card(title: "对话", symbol: "message", cardAccent: NotchV2DesignTokens.accentBlue) {
            VStack(alignment: .leading, spacing: 10) {
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

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("问一句...", text: $viewModel.quickAskDraft)
                            .textFieldStyle(.plain)
                            .font(NotchV2DesignTokens.Typography.body)
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.90))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(NotchV2DesignTokens.separator.opacity(0.35), lineWidth: 1)
                            )
                            .submitLabel(.send)
                            .onSubmit {
                                Task { await viewModel.sendQuickAsk() }
                            }

                        Button {
                            Task { await viewModel.sendQuickAsk() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(NotchV2DesignTokens.accentBlue)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.quickAskDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.quickAskIsSending)
                    }

                    HStack(spacing: 8) {
                        quickPromptPill(title: "总结") {
                            viewModel.quickAskDraft = "帮我总结一下刚才的对话"
                        }
                        quickPromptPill(title: "翻译") {
                            viewModel.quickAskDraft = "翻译成英文"
                        }
                        quickPromptPill(title: "解释") {
                            viewModel.quickAskDraft = "解释一下这段内容"
                        }
                    }

                    if let error = viewModel.quickAskError, error.isEmpty == false {
                        Text(error)
                            .font(NotchV2DesignTokens.Typography.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "快捷指令", symbol: "bolt.fill", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    commandRow(
                        icon: "text.quote",
                        title: "润色文本",
                        subtitle: "优化当前输入的文字",
                        tint: NotchV2DesignTokens.accentPurple
                    ) {
                        viewModel.quickAskDraft = "帮我润色这段文字"
                    }

                    commandRow(
                        icon: "list.bullet",
                        title: "生成列表",
                        subtitle: "将内容整理成列表",
                        tint: NotchV2DesignTokens.accentBlue
                    ) {
                        viewModel.quickAskDraft = "帮我整理成列表"
                    }

                    commandRow(
                        icon: "brain",
                        title: "头脑风暴",
                        subtitle: "围绕主题发散思维",
                        tint: NotchV2DesignTokens.accentGreen
                    ) {
                        viewModel.quickAskDraft = "围绕这个主题头脑风暴"
                    }

                    commandRow(
                        icon: "checkmark.shield",
                        title: "代码审查",
                        subtitle: "检查代码质量",
                        tint: .orange
                    ) {
                        viewModel.quickAskDraft = "帮我审查这段代码"
                    }
                }
            }

            NotchV2Card(title: "对话历史", symbol: "clock.arrow.circlepath", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    if viewModel.quickAskMessages.isEmpty {
                        Text("暂无对话记录")
                            .font(NotchV2DesignTokens.Typography.body)
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                    } else {
                        ForEach(viewModel.quickAskMessages.suffix(3), id: \.id) { message in
                            historyRow(message: message)
                        }
                    }

                    Divider()
                        .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                    Button("打开完整 Agent") {
                        viewModel.showAgent()
                    }
                    .buttonStyle(.plain)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.accentBlue)
                }
            }
        }
    }

    private var chatPreviewMessages: [ChatMessage] {
        viewModel.quickAskMessages.suffix(4).map { $0 }
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user

        return HStack {
            if isUser { Spacer(minLength: 24) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .assistant ? "AI" : "我")
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(message.role == .assistant ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.secondaryText)
                Text(message.content)
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(3)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: 240, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isUser ? NotchV2DesignTokens.accentBlue.opacity(0.16) : NotchV2DesignTokens.innerCardBackground.opacity(0.90))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isUser ? NotchV2DesignTokens.accentBlue.opacity(0.18) : NotchV2DesignTokens.separator.opacity(0.25), lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 24) }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func quickActionMini(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.accentPurple)
                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.88))
            )
        }
        .buttonStyle(.plain)
    }

    private func quickPromptPill(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.88))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(NotchV2DesignTokens.separator.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func commandRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
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

    private func historyRow(message: ChatMessage) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(message.role == .assistant ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.secondaryText)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(message.role == .assistant ? "AI" : "我")
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(message.role == .assistant ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.secondaryText)
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.88))
        )
    }
}
