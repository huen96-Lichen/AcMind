import SwiftUI
import AcMindKit

struct NotchV2AgentPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 136, rightColumnWidth: 0) {
            leftColumn
        } centerColumn: {
            centerColumn
        } rightColumn: {
            EmptyView()
        }
    }

    private var leftColumn: some View {
        NotchV2Card(title: "对话历史", symbol: "clock.arrow.circlepath", fillHeight: true) {
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
                            ForEach(viewModel.quickAskMessages.suffix(4), id: \.id) { message in
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
        NotchV2Card(title: "对话", symbol: "message", fillHeight: true, cardAccent: NotchV2DesignTokens.accentBlue) {
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

                Spacer(minLength: 0)

                quickAskComposer
            }
        }
    }

    private var quickAskComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("快速提问")
                        .font(NotchV2DesignTokens.Typography.title)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                    Text("基于当前上下文继续问，不要把它当成普通输入框。")
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                StatusBadge(
                    text: viewModel.quickAskIsSending ? "发送中" : "Ready",
                    tone: viewModel.quickAskIsSending ? .warning : .info,
                    icon: viewModel.quickAskIsSending ? "arrow.triangle.2.circlepath" : "sparkles"
                )
            }

                HStack(spacing: 8) {
                    notchComposerStage(title: "输入", isActive: viewModel.quickAskDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false, tint: NotchV2DesignTokens.accentBlue)
                    notchComposerStage(title: "发送", isActive: viewModel.quickAskIsSending, tint: NotchV2DesignTokens.accentBlue)
                    notchComposerStage(title: "历史", isActive: viewModel.quickAskMessages.isEmpty == false, tint: NotchV2DesignTokens.secondaryText)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    VStack(spacing: 8) {
                    quickComposerAction(icon: "sparkles", title: "总结", tint: NotchV2DesignTokens.secondaryText) {
                        viewModel.quickAskDraft = "帮我总结一下刚才的对话"
                    }
                    quickComposerAction(icon: "translate", title: "翻译", tint: NotchV2DesignTokens.secondaryText) {
                        viewModel.quickAskDraft = "翻译成英文"
                    }
                }

                ZStack(alignment: .topLeading) {
                    AppSurfaceTextEditorShell(
                        text: $viewModel.quickAskDraft,
                        minHeight: 86,
                        font: NotchV2DesignTokens.Typography.body
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
                .frame(maxWidth: .infinity, minHeight: 86, maxHeight: 116, alignment: .topLeading)
                .onTapGesture {
                    // keep focus behaviour native; TextEditor will take focus naturally when clicked
                }

                Button {
                    Task { await viewModel.sendQuickAsk() }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: viewModel.quickAskIsSending ? "progress.indicator" : "arrow.up.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(viewModel.quickAskIsSending ? "发送中" : "发送")
                            .font(NotchV2DesignTokens.Typography.caption)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 110)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(viewModel.quickAskIsSending ? NotchV2DesignTokens.secondaryText.opacity(0.55) : NotchV2DesignTokens.accentBlue.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(NotchV2DesignTokens.separator.opacity(0.20), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.quickAskDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.quickAskIsSending)
            }

            HStack(spacing: 8) {
                quickPromptPill(title: "解释") {
                    viewModel.quickAskDraft = "解释一下这段内容"
                }
                quickPromptPill(title: "追问") {
                    viewModel.quickAskDraft = "继续追问当前上下文"
                }
                quickPromptPill(title: "整理") {
                    viewModel.quickAskDraft = "把这些内容整理成要点"
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.22), lineWidth: 1)
        )
    }

    private func notchComposerStage(title: String, isActive: Bool, tint: Color) -> some View {
        Text(title)
            .font(NotchV2DesignTokens.Typography.caption)
            .foregroundStyle(isActive ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? tint.opacity(0.16) : NotchV2DesignTokens.innerCardBackground.opacity(0.90))
                )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isActive ? tint.opacity(0.22) : NotchV2DesignTokens.separator.opacity(0.18), lineWidth: 1)
            )
    }

    private func quickComposerAction(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(NotchV2DesignTokens.Typography.caption)
            }
            .foregroundStyle(tint)
            .frame(width: 56, height: 34)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var chatPreviewMessages: [ChatMessage] {
        viewModel.quickAskMessages.suffix(3).map { $0 }
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user

        return HStack {
            if isUser { Spacer(minLength: 24) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .assistant ? "AI" : "我")
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isUser ? NotchV2DesignTokens.accentBlue.opacity(0.08) : NotchV2DesignTokens.cardBackgroundStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isUser ? NotchV2DesignTokens.accentBlue.opacity(0.12) : NotchV2DesignTokens.separator.opacity(0.25), lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 24) }
        }
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
                Text(message.role == .assistant ? "AI" : "我")
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground)
        )
    }
}
