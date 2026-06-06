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
        NotchV2Card(title: "AI 输入", symbol: "sparkles") {
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

                Text(viewModel.activeRuntimeSurface.subtitle)
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)

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
                    infoRow(label: "模型", value: viewModel.activeModelLabel)
                    infoRow(label: "提供器", value: viewModel.activeProviderStatus)
                    infoRow(label: "入口", value: "对话")
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
                        NotchV2StatusPill(title: "简洁回答", accent: NotchV2DesignTokens.cardBackgroundStrong)
                        NotchV2StatusPill(title: "上下文", accent: NotchV2DesignTokens.cardBackgroundStrong)
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
            NotchV2Card(title: "快捷入口", symbol: "square.grid.2x2", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    NotchV2ActionButton(icon: "camera.viewfinder", title: "截图", isSelected: false) {
                        viewModel.quickActions.first(where: { $0.title == "截图" })?.action()
                    }

                    NotchV2ActionButton(icon: "doc.text", title: "MD", isSelected: false) {
                        viewModel.quickActions.first(where: { $0.title == "MD" })?.action()
                    }

                    NotchV2ActionButton(icon: "pin.fill", title: "Pin", isSelected: false) {
                        viewModel.quickActions.first(where: { $0.title == "Pin" })?.action()
                    }

                    NotchV2ActionButton(icon: "waveform", title: "说入法", isSelected: false) {
                        viewModel.quickActions.first(where: { $0.title == "SRPT" })?.action()
                    }
                }
            }
        }
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
                    .foregroundStyle(message.role == .assistant ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.secondaryText)
                Text(message.content)
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: 220, alignment: .leading)
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

    private func quickActionRow(
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
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
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
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.82))
            )
        }
        .buttonStyle(.plain)
    }
}
