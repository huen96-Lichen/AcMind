import SwiftUI
import AcMindKit

struct NotchV2AgentPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    @StateObject private var agent = AgentWorkspaceViewModel()
    @State private var quickAskText = ""
    @FocusState private var quickAskFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerBand

            HStack(alignment: .top, spacing: NotchV2DesignTokens.columnGap) {
                leftRail
                    .frame(width: 220, alignment: .topLeading)

                mainWorkspace
                    .frame(maxWidth: .infinity, maxHeight: NotchV2DesignTokens.agentPanelHeight, alignment: .topLeading)
            }
        }
        .padding(.horizontal, NotchV2DesignTokens.pagePadding)
        .padding(.top, NotchV2DesignTokens.contentTopGap)
        .padding(.bottom, NotchV2DesignTokens.contentBottomGap)
        .frame(width: NotchV2DesignTokens.expandedWidth, height: NotchV2DesignTokens.expandedAgentHeight, alignment: .topLeading)
        .task {
            await agent.loadIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionVoiceAgentDraft)) { notification in
            if let draft = notification.object as? String {
                agent.acceptVoiceDraft(draft)
            }
        }
        .alert("Agent 错误", isPresented: $agent.showError) {
            Button("确定") { agent.clearError() }
        } message: {
            Text(agent.errorMessage ?? "未知错误")
        }
    }

    private var headerBand: some View {
        HStack(alignment: .center, spacing: 12) {
            NotchSectionHeader("AI", subtitle: "Quick Ask / 碎片录入 / 归纳整理")

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                NotchV2StatusPill(
                    icon: viewModel.status.icon,
                    title: viewModel.status.displayName,
                    accent: viewModel.status.color.opacity(0.22)
                )

                NotchV2StatusPill(
                    icon: agent.connectionStatusKind == .green ? "dot.radiowaves.left.and.right" : "circle.dashed",
                    title: agent.connectionStatusLabel,
                    accent: agent.connectionStatusKind == .green ? NotchV2DesignTokens.accentGreen.opacity(0.18) : NotchV2DesignTokens.cardBackgroundStrong
                )

                NotchV2StatusPill(
                    icon: "sparkle.magnifyingglass",
                    title: "入口",
                    accent: NotchV2DesignTokens.cardBackgroundStrong
                )
            }
        }
        .frame(height: 28)
    }

    private var leftRail: some View {
        VStack(alignment: .leading, spacing: NotchV2DesignTokens.cardSpacing) {
            sessionCard
                .frame(height: NotchV2DesignTokens.agentPanelHeight)
        }
    }

    private var sessionCard: some View {
        NotchV2Card(title: "会话", subtitle: "最近更新", symbol: "bubble.left.fill", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    NotchV2StatusPill(title: "\(agent.historySessions.count) 个", accent: NotchV2DesignTokens.cardBackgroundStrong)
                    NotchV2StatusPill(title: agent.activeSessionTitle, accent: NotchV2DesignTokens.accentPurple)
                }

                if agent.historySessions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("还没有碎片会话")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                        Text("先从右侧输入一句话，页面会自动生成新的整理会话。")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NotchV2DesignTokens.innerCardBackground.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(NotchV2DesignTokens.innerBorder.opacity(0.45), lineWidth: 1)
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(agent.historySessions.prefix(4)) { session in
                            sessionRow(session)
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button {
                        Task { await agent.createNewChat() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("新会话")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(NotchV2DesignTokens.innerCardActive)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(NotchV2DesignTokens.innerBorder.opacity(0.75), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        agent.selectedActionMode = .auto
                        agent.inputText = agent.inputText.isEmpty ? AgentActionMode.auto.suggestedPrompt : agent.inputText
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 10, weight: .semibold))
                            Text("自动")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .frame(width: 72)
                        .padding(.vertical, 7)
                        .background(NotchV2DesignTokens.innerCardActive)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(NotchV2DesignTokens.innerBorder.opacity(0.75), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sessionRow(_ session: AgentSessionSummary) -> some View {
        Button {
            Task { await agent.selectSession(session.id) }
        } label: {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(session.tint.opacity(0.16))
                        .frame(width: 18, height: 18)

                    Image(systemName: session.icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(session.tint)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Text(session.preview)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(session.timeLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.tertiaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(agent.selectedSessionID == session.id ? NotchV2DesignTokens.innerCardActive : NotchV2DesignTokens.innerCardBackground.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(agent.selectedSessionID == session.id ? NotchV2DesignTokens.innerBorder.opacity(0.9) : NotchV2DesignTokens.innerBorder.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var mainWorkspace: some View {
        quickAskCard
            .frame(maxHeight: NotchV2DesignTokens.agentPanelHeight, alignment: .topLeading)
    }

    private var quickAskCard: some View {
        NotchV2Card(title: "Quick Ask", subtitle: "碎片录入 / 归纳整理", symbol: "sparkle.magnifyingglass", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if quickAskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("输入一句话，AI 会直接帮你整理成结论、待办、搜索结果或笔记。")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(NotchV2DesignTokens.weakText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                    }

                    TextEditor(text: $quickAskText)
                        .focused($quickAskFocused)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 72)
                        .padding(3)
                        .background(Color.clear)
                }
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(NotchV2DesignTokens.innerBorder.opacity(0.65), lineWidth: 1)
                )

                HStack(spacing: 5) {
                    ForEach(AgentActionMode.quickActions.prefix(3)) { mode in
                        Button {
                            agent.selectedActionMode = mode
                            if quickAskText.isEmpty {
                                quickAskText = mode.suggestedPrompt
                            }
                            quickAskFocused = true
                        } label: {
                            Text(mode.displayName)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(agent.selectedActionMode == mode ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.secondaryText)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(agent.selectedActionMode == mode ? NotchV2DesignTokens.cardBackgroundDeep : NotchV2DesignTokens.innerCardBackground.opacity(0.6))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(agent.selectedActionMode == mode ? NotchV2DesignTokens.accentPurple.opacity(0.7) : NotchV2DesignTokens.innerBorder.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    Menu {
                        ForEach(agent.enabledProviders) { provider in
                            Button {
                                Task { await agent.selectProvider(provider.id) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: agent.selectedProviderID == provider.id ? "checkmark.circle.fill" : "cpu")
                                    Text(provider.name.isEmpty ? provider.modelId : provider.name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 8, weight: .semibold))
                            Text(agent.selectedProvider?.name ?? agent.currentModelLabel)
                                .font(.system(size: 8, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(NotchV2DesignTokens.innerCardBackground.opacity(0.8))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(NotchV2DesignTokens.innerBorder.opacity(0.65), lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)

                    Button {
                        quickAskText = ""
                        quickAskFocused = true
                    } label: {
                        Text("清空")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(NotchV2DesignTokens.innerCardBackground.opacity(0.8))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(NotchV2DesignTokens.innerBorder.opacity(0.65), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await sendQuickAsk() }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 8, weight: .semibold))
                            Text("发送")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(NotchV2DesignTokens.accentPurple)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(quickAskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            quickAskFocused = true
        }
    }

    private func sendQuickAsk() async {
        let content = quickAskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        quickAskText = ""

        await agent.createNewChat()
        agent.selectedActionMode = .auto
        agent.inputText = content
        await agent.sendCurrentInput()
        quickAskFocused = true
    }
}
