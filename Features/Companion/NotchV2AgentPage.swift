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

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("问一句...", text: $viewModel.quickAskDraft)
                            .textFieldStyle(.plain)
                            .font(NotchV2DesignTokens.Typography.body)
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .lineLimit(3)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: 320, alignment: .leading)
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
