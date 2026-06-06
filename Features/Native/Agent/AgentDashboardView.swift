import SwiftUI
import AppKit
import AcMindKit

struct AgentDashboardView: View {
    @StateObject private var viewModel = AgentViewModel()
    @State private var selectedSidebarItem: String? = "normal"
    @State private var showRightPanel = true

    private func sidebarSections(recentItems: [SourceItem], projectContextItems: [SecondarySidebarItem]) -> [SecondarySidebarSection] {
        let recentSectionItems = recentItems.prefix(3).map { item in
            SecondarySidebarItem(
                id: item.id,
                title: item.title ?? item.previewText ?? "未命名",
                icon: "bubble.left",
                badge: item.status.displayName
            )
        }

        return [
            SecondarySidebarSection(
                id: "mode",
                title: "对话模式",
                items: [
                    SecondarySidebarItem(id: "normal", title: "普通对话", icon: "bubble.left"),
                    SecondarySidebarItem(id: "task", title: "任务执行", icon: "play.circle"),
                    SecondarySidebarItem(id: "quickAsk", title: "Quick Ask", icon: "questionmark.circle"),
                    SecondarySidebarItem(id: "toolCall", title: "工具调用", icon: "wrench"),
                    SecondarySidebarItem(id: "automation", title: "自动化", icon: "arrow.triangle.2.circlepath")
                ]
            ),
            SecondarySidebarSection(
                id: "recent",
                title: "最近记录",
                items: recentSectionItems.isEmpty ? [
                    SecondarySidebarItem(id: "empty", title: "暂无最近记录", icon: "clock", badge: nil)
                ] : recentSectionItems
            ),
            SecondarySidebarSection(
                id: "context",
                title: "项目上下文",
                items: projectContextItems
            )
        ]
    }

    var body: some View {
        WorkspacePageShell(
            title: currentModeTitle,
            subtitle: "AcMind · \(viewModel.currentWorkspaceTitle)",
            headerActions: AnyView(headerActions),
            leadingRailWidth: 208,
            trailingRailWidth: 224,
            leadingRail: {
                SecondarySidebarWithHeader(
                    title: "Agent",
                    subtitle: "对话与任务执行",
                    sections: sidebarSections(recentItems: viewModel.recentItems, projectContextItems: viewModel.projectContextItems),
                    selectedItem: $selectedSidebarItem
                )
            },
            content: {
                conversationPane
            },
            trailingRail: {
                if showRightPanel {
                    rightPanel
                } else {
                    EmptyRailPlaceholder(title: "任务面板", subtitle: "已收起")
                }
            }
        )
        .background(AppVisualBackdrop())
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .task {
            await viewModel.loadDashboardData()
        }
    }

    private var conversationPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    messageStream
                    executionFeedback
                }
                .padding(20)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            composerBar
                .padding(16)
        }
    }

    private var headerActions: some View {
        HStack {
            HStack(spacing: 12) {
                StatusPill(label: viewModel.isLoading ? "忙碌" : "待命", color: viewModel.isLoading ? .orange : AppSurfaceTokens.accentGreen)

                StatusPill(label: viewModel.recordingStatus.displayName, color: recordingColor(for: viewModel.recordingStatus))

                Menu {
                    ForEach(viewModel.availableModelOptions) { option in
                        Button(option.displayName) {
                            viewModel.selectModel(option)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedModelLabel)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppSurfaceTokens.cardBackgroundSoft))
                }
                .menuStyle(.borderlessButton)
                .disabled(viewModel.availableModelOptions.isEmpty)
                .fixedSize()

                Button(action: { showRightPanel.toggle() }) {
                    Image(systemName: showRightPanel ? "sidebar.right" : "sidebar.right")
                        .font(.system(size: 14))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.clear() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var messageStream: some View {
        VStack(alignment: .leading, spacing: 16) {
            MessageBubble(isUser: false, content: "你好！我是 AcMind Agent，有什么可以帮你的吗？")

            if isQuickAskMode, let answer = viewModel.quickAskAnswer, !answer.isEmpty {
                MessageBubble(isUser: false, content: answer)
            }

            if let transcript = viewModel.lastTranscript, !transcript.isEmpty {
                MessageBubble(isUser: true, content: transcript)
            }

            if isQuickAskMode, viewModel.quickAskMessages.isEmpty == false {
                ForEach(viewModel.quickAskMessages, id: \.id) { message in
                    MessageBubble(isUser: message.role == .user, content: message.content)
                }
            }

            if let note = viewModel.distilledNote {
                MessageBubble(isUser: false, content: note.summary ?? "整理完成")
            }
        }
    }

    private var executionFeedback: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在处理...")
                        .font(.system(size: 13))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
            }
        }
    }

    private var composerBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: { Task { await viewModel.toggleRecording() } }) {
                    Image(systemName: viewModel.recordingStatus == .recording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(viewModel.recordingStatus == .recording ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(.plain)

                Button(action: { Task { await viewModel.saveToInbox() } }) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.clear() }) {
                    Image(systemName: "wrench")
                        .font(.system(size: 16))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(.plain)

                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 36, maxHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius)
                            .stroke(AppSurfaceTokens.separator, lineWidth: 1)
                    )

                Button(action: {
                    Task {
                        if isToolCallMode {
                            await viewModel.runToolAction(
                                toolType: .ai,
                                action: "chat",
                                parameters: [
                                    "prompt": viewModel.inputText,
                                    "providerId": viewModel.selectedModelOption?.providerId ?? "",
                                    "model": viewModel.selectedModelOption?.modelName ?? ""
                                ]
                            )
                        } else if isQuickAskMode {
                            viewModel.quickAskQuestion = viewModel.inputText
                            await viewModel.quickAsk()
                        } else {
                            await viewModel.distill()
                        }
                    }
                }) {
                    Image(systemName: isToolCallMode ? "wrench.and.screwdriver.fill" : (isQuickAskMode ? "questionmark.circle.fill" : "arrow.up.circle.fill"))
                        .font(.system(size: 24))
                        .foregroundStyle(isToolCallMode ? AppSurfaceTokens.accentGreen : (isQuickAskMode ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.accentPrimary))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("任务面板")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { showRightPanel = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                taskSection(title: "执行中的任务", items: viewModel.isLoading ? ["正在处理输入..."] : [])
                recentTasksSection
                quickActionsSection
                if let result = viewModel.toolCallResult, !result.isEmpty {
                    toolCallResultCard(result)
                }
            }
                .padding(16)
            }
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private func taskSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)

            if items.isEmpty {
                Text("暂无任务")
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
            } else {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(item)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
                }
            }
        }
    }

    private var recentTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近任务")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)

            ForEach(viewModel.recentItems.prefix(5), id: \.id) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title ?? item.previewText ?? "未命名")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(item.status.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷功能")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                if isToolCallMode {
                    quickActionRow(icon: "sparkles", title: "AI 对话", action: {
                        Task {
                            await viewModel.runToolAction(
                                toolType: .ai,
                                action: "chat",
                                parameters: [
                                    "prompt": viewModel.inputText,
                                    "providerId": viewModel.selectedModelOption?.providerId ?? "",
                                    "model": viewModel.selectedModelOption?.modelName ?? ""
                                ]
                            )
                        }
                    })
                    quickActionRow(icon: "server.rack", title: "列出 Provider", action: {
                        Task { await viewModel.runToolAction(toolType: .ai, action: "providers") }
                    })
                    quickActionRow(icon: "cpu", title: "检查模型", action: {
                        Task {
                            await viewModel.runToolAction(
                                toolType: .ai,
                                action: "models",
                                parameters: [
                                    "providerId": viewModel.selectedModelOption?.providerId ?? ""
                                ]
                            )
                        }
                    })
                } else if isAutomationMode {
                    quickActionRow(icon: "calendar", title: "查看定时任务", action: {
                        Task { await viewModel.runToolAction(toolType: .schedule, action: "list") }
                    })
                    quickActionRow(icon: "tray", title: "查看收集箱", action: {
                        Task { await viewModel.runToolAction(toolType: .inbox, action: "list") }
                    })
                    quickActionRow(icon: "doc.on.clipboard", title: "复制结果", action: copyCurrentResult)
                } else {
                    quickActionRow(icon: "sparkles", title: "AI 整理", action: { Task { await viewModel.distill() } })
                    quickActionRow(icon: "tray.and.arrow.down", title: "保存到收集箱", action: { Task { await viewModel.saveToInbox() } })
                    quickActionRow(icon: "doc.on.clipboard", title: "复制结果", action: copyCurrentResult)
                }
            }
        }
    }

    private func toolCallResultCard(_ result: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("工具调用结果")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)

            Text(result)
                .font(.system(size: 12))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
        }
    }

    private func copyCurrentResult() {
        let result = viewModel.distilledNote?.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
    }

    private func quickActionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(AppSurfaceTokens.cardBackgroundSoft))
        }
        .buttonStyle(.plain)
    }

    private var currentModeTitle: String {
        switch selectedSidebarItem {
        case "task":
            return "任务执行"
        case "quickAsk":
            return "Quick Ask"
        case "toolCall":
            return "工具调用"
        case "automation":
            return "自动化"
        default:
            return "普通对话"
        }
    }

    private var isQuickAskMode: Bool {
        selectedSidebarItem == "quickAsk"
    }

    private var isToolCallMode: Bool {
        selectedSidebarItem == "toolCall"
    }

    private var isAutomationMode: Bool {
        selectedSidebarItem == "automation"
    }
}

private struct EmptyRailPlaceholder: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }
}

struct MessageBubble: View {
    let isUser: Bool
    let content: String

    var body: some View {
        HStack {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(content)
                    .font(.system(size: 13))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius)
                            .fill(isUser ? AppSurfaceTokens.accentBlue.opacity(0.15) : AppSurfaceTokens.cardBackgroundSoft)
                    )

                    Text(isUser ? "你" : "Agent")
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

            if !isUser { Spacer() }
        }
    }
}

private struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.1)))
    }
}

private func recordingColor(for status: RecordingStatus) -> Color {
    switch status {
            case .idle:
                return AppSurfaceTokens.secondaryText
            case .recording:
                return AppSurfaceTokens.accentOrange
            case .processing:
                return AppSurfaceTokens.accentPrimary
            case .error:
                return AppSurfaceTokens.accentOrange
            }
        }
