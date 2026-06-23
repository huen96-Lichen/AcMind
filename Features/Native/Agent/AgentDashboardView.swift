import SwiftUI
import AppKit
import AcMindKit

struct AgentDashboardView: View {
    @StateObject private var viewModel: AgentViewModel
    @State private var selectedSidebarItem: String?
    @State private var showRightPanel: Bool
    private let previewSidebarSelection: String?
    private let shouldLoadDashboardData: Bool

    init(
        viewModel: AgentViewModel = AgentViewModel(),
        selectedSidebarItem: String? = "normal",
        showRightPanel: Bool = false,
        previewSidebarSelection: String? = nil,
        shouldLoadDashboardData: Bool = true
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _selectedSidebarItem = State(initialValue: selectedSidebarItem)
        _showRightPanel = State(initialValue: showRightPanel)
        self.previewSidebarSelection = previewSidebarSelection
        self.shouldLoadDashboardData = shouldLoadDashboardData
    }

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
        AcWorkShell(
            title: currentModeTitle,
            subtitle: "AcWork · \(viewModel.currentWorkspaceTitle)",
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
        .background(AppSurfaceBackdrop())
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .task {
            if shouldLoadDashboardData {
                await viewModel.loadDashboardData()
            }
        }
        .onAppear {
            if let previewSidebarSelection, previewSidebarSelection.isEmpty == false {
                selectedSidebarItem = previewSidebarSelection
            }
        }
    }

    private var conversationPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppSurfaceCard(title: "协作概览", subtitle: "对话 + 任务 + 状态", padding: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            AppSurfaceSummaryStrip(chips: [
                                AppSurfaceSummaryChip(
                                    title: "模式",
                                    value: currentModeTitle,
                                    tint: AppSurfaceTokens.accentBlue
                                ),
                                AppSurfaceSummaryChip(
                                    title: "模型",
                                    value: viewModel.selectedModelLabel,
                                    tint: AppSurfaceTokens.accentGreen
                                ),
                                AppSurfaceSummaryChip(
                                    title: "任务",
                                    value: "\(viewModel.agentTasks.count) 个",
                                    tint: AppSurfaceTokens.secondaryText
                                )
                            ])

                            HStack(spacing: 10) {
                                overviewMetric(title: "会话", value: "\(viewModel.recentItems.count) 条", tint: AppSurfaceTokens.accentOrange)
                                overviewMetric(title: "执行态", value: viewModel.isLoading ? "处理中" : "待命", tint: viewModel.isLoading ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.secondaryText)
                                overviewMetric(title: "追溯", value: viewModel.distilledNote != nil ? "已生成" : "空", tint: viewModel.distilledNote != nil ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.secondaryText)
                            }

                            Text("顶部先把当前模式、模型、任务和执行状态亮出来，下面仍然保持消息流和输入区。")
                                .font(.system(size: AppSurfaceTokens.Typography.caption))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .lineLimit(2)
                        }
                    }

                    AppSurfaceCard(title: "对话记录", subtitle: "消息流与上下文", padding: 14) {
                        messageStream
                    }

                    if hasSupplementaryChatCards {
                        supplementaryChatCards
                    }
                }
                .padding(20)
                .frame(maxWidth: 860, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            conversationComposer
                .padding(16)
        }
    }

    private func overviewMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: AppSurfaceTokens.Typography.controlStrong, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSurfaceTokens.Spacing.sm)
        .padding(.vertical, AppSurfaceTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var headerActions: some View {
        HStack {
            HStack(spacing: 12) {
                StatusPill(
                    label: ActivityStateLabelFormatter.activityLabel(
                        isActive: viewModel.isLoading,
                        activeLabel: "忙碌",
                        idleLabel: "待命"
                    ),
                    color: AppSurfaceTokens.secondaryText
                )

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
                    .background(Capsule().fill(AppSurfaceTokens.cardBackground))
                }
                .menuStyle(.borderlessButton)
                .disabled(viewModel.availableModelOptions.isEmpty)
                .fixedSize()

                Button(action: { showRightPanel.toggle() }) {
                    Image(systemName: showRightPanel ? "sidebar.left" : "sidebar.right")
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
            MessageBubble(isUser: false, content: "你好！我是 AcWork Agent，有什么可以帮你的吗？")

            if let answer = viewModel.quickAskAnswer, !answer.isEmpty {
                MessageBubble(isUser: false, content: answer)
            }

            if let transcript = viewModel.lastTranscript, !transcript.isEmpty {
                MessageBubble(isUser: true, content: transcript)
            }

            if viewModel.quickAskMessages.isEmpty == false {
                ForEach(viewModel.quickAskMessages, id: \.id) { message in
                    MessageBubble(isUser: message.role == .user, content: message.content)
                }
            }

            if let note = viewModel.distilledNote {
                MessageBubble(isUser: false, content: note.summary ?? "整理完成")
            }
        }
    }

    private var conversationComposer: some View {
        ConversationComposerCard(
            title: composerTitle,
            subtitle: composerSubtitle,
            badgeText: viewModel.selectedModelLabel,
            badgeTone: viewModel.isLoading ? .warning : .info,
            badgeIcon: "cpu",
            stages: composerStages,
            text: $viewModel.inputText,
            placeholder: composerPlaceholder,
            iconActions: composerActions,
            suggestions: composerSuggestions,
            primaryActionTitle: composerPrimaryActionTitle,
            primaryActionIcon: composerPrimaryActionIcon,
            primaryActionTint: composerPrimaryActionTint,
            isPrimaryEnabled: viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            isBusy: viewModel.isLoading,
            footerText: composerFooterText,
            onPrimaryAction: {
                Task {
                    await performComposerPrimaryAction()
                }
            }
        )
    }

    private var hasSupplementaryChatCards: Bool {
        viewModel.quickAskQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || viewModel.isLoading
            || (viewModel.errorMessage?.isEmpty == false)
            || viewModel.currentTaskSummary != nil
            || (viewModel.toolCallResult?.isEmpty == false)
            || (permissionTraceMessage?.isEmpty == false)
    }

    @ViewBuilder
    private var supplementaryChatCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.quickAskQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                questionPromptCard(
                    title: "待确认问题",
                    question: viewModel.quickAskQuestion,
                    context: "目标模型 · \(viewModel.selectedModelLabel)"
                )
            }

            if let currentTaskSummary = viewModel.currentTaskSummary {
                taskTraceCard(summary: currentTaskSummary)
            }

            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(ToolStatusLabelFormatter.processingText)
                        .font(.system(size: 13))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackground))
            }

            if let message = permissionTraceMessage {
                permissionTraceCard(message: message)
            }

            if let result = viewModel.toolCallResult, !result.isEmpty {
                toolCallResultCard(result)
            }

            if let errorMessage = viewModel.errorMessage, errorMessage.isEmpty == false {
                errorTraceCard(errorMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                VStack(alignment: .leading, spacing: 12) {
                    AppSurfaceCard(title: "当前会话", subtitle: "任务上下文", padding: 14) {
                        summaryRailCard
                    }
                    AppSurfaceCard(title: "任务看板", subtitle: "最近状态", padding: 14) {
                        taskBoardSection
                    }
                    AppSurfaceCard(title: "最近结果", subtitle: "最近 5 条", padding: 14) {
                        recentTasksSection
                    }
                    AppSurfaceCard(title: "追溯收件箱", subtitle: "反馈、结果与错误", padding: 14) {
                        traceInboxSection
                    }
                    AppSurfaceCard(title: "快捷功能", subtitle: "当前模式可用动作", padding: 14) {
                        quickActionsSection
                    }
                }
                .padding(16)
            }
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private var summaryRailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSurfaceSummaryStrip(chips: summaryRailChips)

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.currentWorkSummary)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(2)
                Text(viewModel.currentWorkDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(4)
            }
        }
    }

    private var summaryRailChips: [AppSurfaceSummaryChip] {
        [
            AppSurfaceSummaryChip(
                title: "模型",
                value: viewModel.selectedModelLabel,
                tint: AppSurfaceTokens.accentBlue
            ),
            AppSurfaceSummaryChip(
                title: "任务",
                value: "\(viewModel.agentTasks.count) 个",
                tint: AppSurfaceTokens.accentGreen
            ),
            AppSurfaceSummaryChip(
                title: "会话",
                value: "\(viewModel.recentItems.count) 条",
                tint: AppSurfaceTokens.secondaryText
            )
        ]
    }

    private var taskBoardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.agentTasks.isEmpty {
                Text("暂无任务")
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
            } else {
                ForEach(viewModel.recentTaskSummaries.prefix(4), id: \.taskId) { summary in
                    taskSummaryCard(summary)
                }
            }
        }
    }

    private func taskSummaryCard(_ summary: AgentTaskClosureSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)
                    Text(summary.stateLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                Spacer(minLength: 0)
                Text(summary.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }

            if summary.timeline.isEmpty == false {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(summary.timeline.prefix(3)) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.status == .completed ? "checkmark.circle.fill" : (item.status == .running ? "circle.dotted" : "circle"))
                                .font(.system(size: 9))
                                .foregroundStyle(taskTimelineTint(for: item.status))
                            Text(item.title)
                                .font(.system(size: 10))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Spacer(minLength: 0)
                            if let detail = item.detail, detail.isEmpty == false {
                                Text(detail)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackground))
    }

    private func taskTimelineTint(for status: AgentTaskTimelineStatus) -> Color {
        switch status {
        case .pending: return AppSurfaceTokens.tertiaryText
        case .running: return AppSurfaceTokens.secondaryText
        case .completed: return AppSurfaceTokens.secondaryText
        case .failed: return AppSurfaceTokens.accentOrange
        }
    }

    private var workspaceFocusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前协作工作区")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .textCase(.uppercase)
                    Text(viewModel.currentWorkSummary)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    StatusPill(label: viewModel.taskBoardSummary, color: AppSurfaceTokens.secondaryText)
                    StatusPill(label: viewModel.selectedModelLabel, color: AppSurfaceTokens.secondaryText)
                }
            }

            Text(viewModel.currentWorkDetail)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(3)

            if viewModel.hasTraceableTaskData {
                HStack(spacing: 10) {
                    Label(viewModel.currentTaskStepSummary, systemImage: "checklist")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    if let currentTaskSummary = viewModel.currentTaskSummary {
                        Label(currentTaskSummary.stateLabel, systemImage: "dot.circle.and.cursorarrow")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
        )
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
                    .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackground))
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
                    .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackground))
                }
            }
        }
    }

    private var recentTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.recentItems.isEmpty {
                Text("暂无最近结果")
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
            } else {
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
                    .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackground))
                }
            }
        }
    }

    private var traceInboxSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = permissionTraceMessage {
                permissionTraceCard(message: message)
            }

            if let result = viewModel.toolCallResult, result.isEmpty == false {
                toolCallResultCard(result)
            } else if let note = viewModel.distilledNote?.summary, note.isEmpty == false {
                resultSummaryCard(title: "整理结果", text: note)
            } else if isQuickAskMode, viewModel.quickAskQuestion.isEmpty == false {
                questionPromptCard(
                    title: "待确认问题",
                    question: viewModel.quickAskQuestion,
                    context: "目标模型 · \(viewModel.selectedModelLabel)"
                )
            } else {
                Text("暂无可追溯内容")
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(AgentTraceRenderer.parse(result).enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .paragraph(let text):
                        resultSummaryCard(title: "输出", text: text)
                    case .code(let language, let code):
                        codeBlockCard(language: language, code: code)
                    case .metadata(let items):
                        metadataCard(items)
                    case .bulletList(let items):
                        bulletListCard(items)
                    }
                }
            }
        }
    }

    private func resultSummaryCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(5)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackground))
    }

    private func codeBlockCard(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(language?.isEmpty == false ? (language ?? "code") : "code")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.accentBlue)
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackground))
    }

    private func questionPromptCard(title: String, question: String, context: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)
            Text(question)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(4)
            Text(context)
                .font(.system(size: 10))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius)
                .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }

    private func metadataCard(_ items: [AgentTraceMetadataItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("结构化信息")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.key)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.accentBlue)
                            .frame(width: 84, alignment: .leading)
                        Text(item.value.isEmpty ? "—" : item.value)
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius)
                .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }

    private func bulletListCard(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("步骤")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(AppSurfaceTokens.accentGreen)
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(item)
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .lineLimit(3)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius)
                .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }

    private func permissionTraceCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("权限确认")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(4)
            Text("需要在系统设置中确认权限后重试。")
                .font(.system(size: 10))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius)
                .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }

    private func taskTraceCard(summary: AgentTaskClosureSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前任务")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .textCase(.uppercase)
                    Text(summary.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                }
                Spacer(minLength: 0)
                Text(summary.stateLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.accentBlue)
            }

            Text(summary.detail)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(3)

            if summary.timeline.isEmpty == false {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(summary.timeline.prefix(4)) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: item.status == .completed ? "checkmark.circle.fill" : (item.status == .running ? "circle.dotted" : "circle"))
                                .font(.system(size: 9))
                                .foregroundStyle(taskTimelineTint(for: item.status))
                            Text(item.title)
                                .font(.system(size: 10))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Spacer(minLength: 0)
                            if let detail = item.detail, detail.isEmpty == false {
                                Text(detail)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private func errorTraceCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("错误追溯")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.primaryText)
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
            .background(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous).fill(AppSurfaceTokens.cardBackgroundSoft))
        }
        .buttonStyle(.plain)
    }

    private var permissionTraceMessage: String? {
        [viewModel.errorMessage, viewModel.toolCallResult]
            .compactMap { $0 }
            .first { text in
                let lower = text.lowercased()
                return lower.contains("permission") || lower.contains("权限") || lower.contains("denied") || lower.contains("拒绝")
            }
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

    private var composerTitle: String {
        switch selectedSidebarItem {
        case "quickAsk":
            return "快速提问"
        case "toolCall":
            return "工具调用"
        case "automation":
            return "自动化输入"
        case "task":
            return "任务整理"
        default:
            return "输入与整理"
        }
    }

    private var composerSubtitle: String {
        switch selectedSidebarItem {
        case "quickAsk":
            return "直接追问当前上下文，发送前可继续修正。"
        case "toolCall":
            return "把输入交给工具路由，结果会回到追溯区。"
        case "automation":
            return "适合批处理和自动化动作。"
        case "task":
            return "适合把素材整理为任务。"
        default:
            return "快速提问、整理和收集共用同一入口。"
        }
    }

    private var composerPlaceholder: String {
        switch selectedSidebarItem {
        case "quickAsk":
            return "问一句，系统会连同上下文一起处理。"
        case "toolCall":
            return "描述你想调用的工具或查询目标。"
        case "automation":
            return "写下需要批量处理的内容。"
        case "task":
            return "把现在的素材整理成任务描述。"
        default:
            return "输入要整理、追问或收集的内容。"
        }
    }

    private var composerPrimaryActionTitle: String {
        if viewModel.isLoading {
            return "处理中"
        }
        switch selectedSidebarItem {
        case "quickAsk":
            return "发送"
        case "toolCall":
            return "调用"
        case "automation":
            return "执行"
        case "task":
            return "整理"
        default:
            return "处理"
        }
    }

    private var composerPrimaryActionIcon: String {
        switch selectedSidebarItem {
        case "quickAsk":
            return "questionmark.circle.fill"
        case "toolCall":
            return "wrench.and.screwdriver.fill"
        case "automation":
            return "arrow.triangle.2.circlepath"
        case "task":
            return "checklist"
        default:
            return "arrow.up.circle.fill"
        }
    }

    private var composerPrimaryActionTint: Color {
        viewModel.isLoading ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.primaryText
    }

    private var composerStages: [ConversationComposerStage] {
        [
            ConversationComposerStage(title: "输入", isActive: viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false, tint: AppSurfaceTokens.secondaryText),
            ConversationComposerStage(title: "收音", isActive: viewModel.recordingStatus == .recording, tint: AppSurfaceTokens.secondaryText),
            ConversationComposerStage(title: "发送中", isActive: viewModel.isLoading, tint: AppSurfaceTokens.secondaryText),
            ConversationComposerStage(title: "Quick Ask", isActive: isQuickAskMode, tint: AppSurfaceTokens.secondaryText)
        ]
    }

    private var composerActions: [ConversationComposerAction] {
        [
            ConversationComposerAction(
                icon: viewModel.recordingStatus == .recording ? "stop.circle.fill" : "mic.fill",
                title: viewModel.recordingStatus == .recording ? "停止" : "录音",
                tint: AppSurfaceTokens.secondaryText,
                isEnabled: true,
                action: { Task { await viewModel.toggleRecording() } }
            ),
            ConversationComposerAction(
                icon: "tray.and.arrow.down",
                title: "收集",
                tint: AppSurfaceTokens.secondaryText,
                isEnabled: viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                action: { Task { await viewModel.saveToInbox() } }
            ),
            ConversationComposerAction(
                icon: "trash",
                title: "清空",
                tint: AppSurfaceTokens.secondaryText,
                isEnabled: viewModel.inputText.isEmpty == false || viewModel.distilledNote != nil || viewModel.toolCallResult != nil || viewModel.currentTask != nil,
                action: { viewModel.clear() }
            )
        ]
    }

    private var composerSuggestions: [ConversationComposerSuggestion] {
        switch selectedSidebarItem {
        case "quickAsk":
            return [
                ConversationComposerSuggestion(title: "总结", subtitle: "当前对话", action: { viewModel.inputText = "帮我总结一下刚才的对话" }),
                ConversationComposerSuggestion(title: "翻译", subtitle: "转成英文", action: { viewModel.inputText = "翻译成英文" }),
                ConversationComposerSuggestion(title: "解释", subtitle: "当前内容", action: { viewModel.inputText = "解释一下这段内容" })
            ]
        case "toolCall":
            return [
                ConversationComposerSuggestion(title: "列 Provider", subtitle: "可用模型", action: { viewModel.inputText = "列出可用的 Provider" }),
                ConversationComposerSuggestion(title: "检查模型", subtitle: "当前 Provider", action: { viewModel.inputText = "检查当前模型" }),
                ConversationComposerSuggestion(title: "AI 对话", subtitle: "直接聊天", action: { viewModel.inputText = "继续对话并给出建议" })
            ]
        case "automation":
            return [
                ConversationComposerSuggestion(title: "查看任务", subtitle: "当前队列", action: { viewModel.inputText = "查看当前定时任务" }),
                ConversationComposerSuggestion(title: "收集箱", subtitle: "最近内容", action: { viewModel.inputText = "查看收集箱最近内容" }),
                ConversationComposerSuggestion(title: "复制结果", subtitle: "当前输出", action: { viewModel.inputText = "复制当前结果" })
            ]
        default:
            return [
                ConversationComposerSuggestion(title: "整理", subtitle: "当前输入", action: { viewModel.inputText = "把这些内容整理成要点" }),
                ConversationComposerSuggestion(title: "收集", subtitle: "保存素材", action: { viewModel.inputText = "把这段内容保存到收集箱" }),
                ConversationComposerSuggestion(title: "提问", subtitle: "追问上下文", action: { viewModel.inputText = "基于当前上下文继续追问" })
            ]
        }
    }

    private var composerFooterText: String? {
        if viewModel.recordingStatus == .recording {
            return "正在收音，松开后会进入整理。"
        }
        if viewModel.isLoading {
            return ToolStatusLabelFormatter.processingText
        }
        return nil
    }

    private func performComposerPrimaryAction() async {
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
        .background(AppSurfaceTokens.cardBackgroundSoft)
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
                    .font(.system(size: AppSurfaceTokens.Typography.body))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius)
                        .fill(isUser ? AppSurfaceTokens.cardBackground : AppSurfaceTokens.cardBackgroundSoft)
                    )

                    Text(isUser ? "你" : "Agent")
                        .font(.system(size: AppSurfaceTokens.Typography.caption))
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
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(color.opacity(0.1)))
    }
}

private func recordingColor(for status: RecordingStatus) -> Color {
    switch status {
            case .idle:
                return AppSurfaceTokens.secondaryText
            case .recording:
                return AppSurfaceTokens.secondaryText
            case .processing:
                return AppSurfaceTokens.secondaryText
            case .error:
                return AppSurfaceTokens.accentOrange
            }
        }

private struct ConversationComposerStage: Identifiable {
    let id = UUID()
    let title: String
    let isActive: Bool
    let tint: Color
}

private struct ConversationComposerAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let tint: Color
    let isEnabled: Bool
    let action: () -> Void
}

private struct ConversationComposerSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let action: () -> Void
}

private struct ConversationComposerCard: View {
    let title: String
    let subtitle: String
    let badgeText: String?
    let badgeTone: StatusBadgeTone
    let badgeIcon: String?
    let stages: [ConversationComposerStage]
    @Binding var text: String
    let placeholder: String
    let iconActions: [ConversationComposerAction]
    let suggestions: [ConversationComposerSuggestion]
    let primaryActionTitle: String
    let primaryActionIcon: String
    let primaryActionTint: Color
    let isPrimaryEnabled: Bool
    let isBusy: Bool
    let footerText: String?
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            stageStrip
            composerBody
            suggestionRow

            if let footerText, footerText.isEmpty == false {
                Text(footerText)
                    .font(.system(size: 11))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let badgeText {
                StatusBadge(text: badgeText, tone: badgeTone, icon: badgeIcon)
            }
        }
    }

    private var stageStrip: some View {
        HStack(spacing: 8) {
            ForEach(stages) { stage in
                Text(stage.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(stage.isActive ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(stage.isActive ? stage.tint.opacity(0.14) : AppSurfaceTokens.cardBackground)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(stage.isActive ? stage.tint.opacity(0.28) : AppSurfaceTokens.separator.opacity(0.45), lineWidth: 1)
                    )
            }

            Spacer(minLength: 0)
        }
    }

    private var composerBody: some View {
        HStack(alignment: .bottom, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(iconActions) { action in
                    Button {
                        action.action()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(action.title)
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundStyle(action.isEnabled ? action.tint : AppSurfaceTokens.tertiaryText)
                        .frame(width: 58, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                                .fill(action.isEnabled ? action.tint.opacity(0.10) : AppSurfaceTokens.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                                .stroke(action.isEnabled ? action.tint.opacity(0.22) : AppSurfaceTokens.separator.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!action.isEnabled)
                }
            }

            ZStack(alignment: .topLeading) {
                AppSurfaceTextEditorShell(text: $text, minHeight: 88, font: .system(size: 13))

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }

            Button {
                onPrimaryAction()
            } label: {
                VStack(spacing: 5) {
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: primaryActionIcon)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(primaryActionTitle)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isPrimaryEnabled ? .white : AppSurfaceTokens.tertiaryText)
                .frame(width: 74, height: 112)
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                        .fill(isPrimaryEnabled ? primaryActionTint : AppSurfaceTokens.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                        .stroke(isPrimaryEnabled ? primaryActionTint.opacity(0.24) : AppSurfaceTokens.separator.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPrimaryEnabled == false || isBusy)
        }
    }

    private var suggestionRow: some View {
        HStack(spacing: 8) {
            ForEach(suggestions) { suggestion in
                Button {
                    suggestion.action()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        if let subtitle = suggestion.subtitle, subtitle.isEmpty == false {
                            Text(subtitle)
                                .font(.system(size: 9.5))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                            .fill(AppSurfaceTokens.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                            .stroke(AppSurfaceTokens.separator.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
