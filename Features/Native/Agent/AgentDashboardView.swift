import SwiftUI
import AppKit
import AcMindKit

struct AgentDashboardView: View {
    @StateObject private var viewModel: AgentViewModel
    @State private var showInspector: Bool
    @State private var historySearch = ""

    private let shouldLoadDashboardData: Bool

    init(
        viewModel: AgentViewModel = AgentViewModel(),
        selectedSidebarItem: String? = "normal",
        showRightPanel: Bool = false,
        previewSidebarSelection: String? = nil,
        shouldLoadDashboardData: Bool = true
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _showInspector = State(initialValue: showRightPanel || previewSidebarSelection == "task")
        self.shouldLoadDashboardData = shouldLoadDashboardData
        _ = selectedSidebarItem
    }

    var body: some View {
        AcWorkShell(
            title: conversationTitle,
            subtitle: "Agent · \(viewModel.currentWorkspaceTitle)",
            headerActions: AnyView(headerActions),
            compactToolbar: true,
            leadingRailWidth: 228,
            trailingRailWidth: showInspector ? 280 : 0,
            usesResponsiveInspector: true,
            compactInspectorTitle: "任务与上下文",
            leadingRail: { historyRail },
            content: { conversationPane },
            trailingRail: { inspectorPane }
        )
        .background(AppVisualBackdrop())
        .alert("发送失败", isPresented: $viewModel.showError) {
            Button("好") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .task {
            if shouldLoadDashboardData {
                await viewModel.loadDashboardData()
            }
        }
        .onAppear {
            applyPreviewSelectionIfNeeded()
        }
    }

    private var conversationTitle: String {
        guard let selectedId = viewModel.selectedQuickAskSessionId,
              let session = viewModel.quickAskHistory.first(where: { $0.id == selectedId }) else {
            return "新对话"
        }
        return session.title
    }

    private var headerActions: some View {
        HStack(spacing: 10) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("正在生成回答")
            }

            Menu {
                ForEach(viewModel.availableModelOptions) { option in
                    Button(option.displayName) {
                        viewModel.selectModel(option)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.availableModelOptions.isEmpty ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.accentGreen)
                        .frame(width: 6, height: 6)
                    Text(viewModel.selectedModelLabel)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            iconButton(
                symbol: showInspector ? "sidebar.trailing" : "sidebar.right",
                help: showInspector ? "收起任务与上下文" : "显示任务与上下文"
            ) {
                withAnimation(.easeOut(duration: 0.18)) {
                    showInspector.toggle()
                }
            }

        }
    }

    private func iconButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var historyRail: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Button {
                    viewModel.startNewConversation()
                } label: {
                    Label("新对话", systemImage: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppSurfaceTokens.accentBlue)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    TextField("搜索对话", text: $historySearch)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.control, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackground)
                )
            }
            .padding(12)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    Text("最近对话")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                    if filteredHistory.isEmpty {
                        Text(historySearch.isEmpty ? "发送第一条消息后，对话会显示在这里。" : "没有匹配的对话")
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(8)
                    } else {
                        ForEach(filteredHistory) { session in
                            historyRow(session)
                        }
                    }
                }
                .padding(8)
            }
            .scrollIndicators(.hidden)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                Text(viewModel.currentWorkspaceTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .background(AppSurfaceTokens.cardBackground.opacity(0.72))
    }

    private var filteredHistory: [ChatSession] {
        let query = historySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return viewModel.quickAskHistory }
        return viewModel.quickAskHistory.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func historyRow(_ session: ChatSession) -> some View {
        let isSelected = viewModel.selectedQuickAskSessionId == session.id
        return Button {
            Task { await viewModel.selectQuickAskHistory(session) }
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(2)
                    Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.control, style: .continuous)
                    .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.10) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var conversationPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    collaborativeWorkspaceSections
                    messageStream
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }

            Divider()

            ConversationComposerCard(
                stages: composerStages,
                suggestions: composerSuggestions,
                isProcessing: viewModel.isLoading,
                primaryAction: performComposerPrimaryAction
            ) {
                chatComposer
            }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .background(AppSurfaceTokens.contentBackground)
    }

    private var collaborativeWorkspaceSections: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSurfaceCard(title: "当前协作工作区", subtitle: viewModel.currentWorkspaceTitle, padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        let items = [
                            ("当前任务", viewModel.currentTaskSummary?.title ?? "等待用户输入"),
                            (
                                "执行反馈",
                                viewModel.isLoading
                                    ? ToolStatusLabelFormatter.processingText
                                    : ActivityStateLabelFormatter.activityLabel(isActive: false, activeLabel: "执行中", idleLabel: "待命")
                            ),
                            ("当前会话", conversationTitle)
                        ]
                        metadataCard(items)
                    }
                    Group {
                        let traceSummary = AgentTraceRenderer.parse("执行反馈").joined(separator: "、")
                        let items = [
                            "任务区：跟踪当前目标、待确认问题和权限确认。",
                            "追溯收件箱：汇总工具调用结果和错误追溯。",
                            "对话记录：保留 \(traceSummary)。"
                        ]
                        bulletListCard(items)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                AppSurfaceCard(title: "任务看板", subtitle: "当前任务 / 待确认问题 / 权限确认", padding: 14) {
                    bulletListCard(viewModel.recentTaskSummaries.prefix(3).map { "\($0.title)：\($0.stateLabel)" }.ifEmpty(["暂无任务，发送目标后会自动进入任务区。"]))
                }

                AppSurfaceCard(title: "最近结果", subtitle: "工具调用结果 / 追溯收件箱", padding: 14) {
                    bulletListCard([
                        nonEmptyText(viewModel.toolCallResult) ?? "暂无工具调用结果",
                        "错误追溯会进入追溯收件箱"
                    ])
                }
            }

            AppSurfaceCard(title: "当前会话", subtitle: "对话记录与执行反馈", padding: 14) {
                metadataCard([
                    ("对话记录", "\(viewModel.quickAskMessages.count) 条"),
                    ("执行反馈", viewModel.isLoading ? ToolStatusLabelFormatter.processingText : "待命"),
                    ("权限确认", "按需触发")
                ])
            }

            AppSurfaceCard(title: "快捷功能", subtitle: "快速进入常用 Agent 动作", padding: 14) {
                HStack(spacing: 8) {
                    promptButton("分析当前项目", symbol: "folder")
                    promptButton("整理最近结果", symbol: "tray.full")
                    promptButton("生成待办", symbol: "checklist")
                }
            }
        }
        .frame(maxWidth: 780)
    }

    private var messageStream: some View {
        ScrollViewReader { proxy in
            LazyVStack(alignment: .leading, spacing: 22) {
                    if viewModel.quickAskMessages.isEmpty {
                        welcomeState
                            .frame(maxWidth: .infinity)
                            .padding(.top, 76)
                    } else {
                        ForEach(viewModel.quickAskMessages) { message in
                            ChatMessageRow(message: message)
                                .id(message.id)
                        }
                    }

                    if viewModel.isLoading {
                        assistantThinkingRow
                            .id("agent-thinking")
                    }

                    if let result = viewModel.toolCallResult, result.isEmpty == false {
                        AgentInlineResult(title: "工具结果", symbol: "wrench.and.screwdriver", content: result)
                    }

                    if let task = viewModel.currentTaskSummary {
                        AgentInlineResult(title: task.title, symbol: "checklist", content: "\(task.stateLabel) · \(task.detail)")
                    }
                }
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
            .onChange(of: viewModel.quickAskMessages.count) { _, _ in
                scrollToLatest(using: proxy)
            }
            .onChange(of: viewModel.isLoading) { _, _ in
                scrollToLatest(using: proxy)
            }
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.18)) {
            if viewModel.isLoading {
                proxy.scrollTo("agent-thinking", anchor: .bottom)
            } else if let lastId = viewModel.quickAskMessages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    private var welcomeState: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppSurfaceTokens.accentBlue.opacity(0.12))
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.accentBlue)
            }
            .frame(width: 52, height: 52)

            VStack(spacing: 7) {
                Text("今天想一起做什么？")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text("直接描述目标，也可以粘贴需要整理或分析的内容。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            HStack(spacing: 10) {
                promptButton("整理一段内容", symbol: "text.alignleft")
                promptButton("规划今天的任务", symbol: "checklist")
                promptButton("分析当前项目", symbol: "folder")
            }
        }
    }

    private func promptButton(_ title: String, symbol: String) -> some View {
        Button {
            viewModel.inputText = title
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.control, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackground)
                )
        }
        .buttonStyle(.plain)
    }

    private var assistantThinkingRow: some View {
        HStack(alignment: .top, spacing: 10) {
            agentAvatar
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(ToolStatusLabelFormatter.processingText)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .padding(.top, 6)
            Spacer(minLength: 0)
        }
    }

    private var agentAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppSurfaceTokens.accentBlue.opacity(0.12))
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.accentBlue)
        }
        .frame(width: 28, height: 28)
    }

    private var chatComposer: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.inputText)
                    .font(.system(size: 13.5))
                    .scrollContentBackground(.hidden)
                    .frame(height: 68)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 2)

                if viewModel.inputText.isEmpty {
                    Text("给 Agent 发消息")
                        .font(.system(size: 13.5))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 6) {
                Menu {
                    Button("保存到收集箱", systemImage: "tray.and.arrow.down") {
                        Task { await viewModel.saveToInbox() }
                    }
                    .disabled(trimmedInput.isEmpty)
                    Button("整理为要点", systemImage: "text.alignleft") {
                        viewModel.inputText = "请把下面的内容整理成清晰要点：\n\n" + viewModel.inputText
                    }
                    Button("创建任务计划", systemImage: "checklist") {
                        viewModel.inputText = "请根据下面的目标制定任务计划：\n\n" + viewModel.inputText
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .help("添加内容或动作")

                Button {
                    Task { await viewModel.toggleRecording() }
                } label: {
                    Image(systemName: viewModel.recordingStatus == .recording ? "stop.fill" : "mic")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(viewModel.recordingStatus == .recording ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.secondaryText)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(viewModel.recordingStatus == .recording ? "停止录音" : "语音输入")

                Text(viewModel.selectedModelLabel)
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    sendCurrentMessage()
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundStyle(canSend ? Color.white : AppSurfaceTokens.tertiaryText)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(canSend ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.separator.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .disabled(canSend == false)
                .keyboardShortcut(.return, modifiers: .command)
                .help("发送消息")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 9)
        }
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.card, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
        .shadow(
            color: AppSurfaceTokens.Shadow.color,
            radius: AppSurfaceTokens.Shadow.radius,
            x: AppSurfaceTokens.Shadow.x,
            y: AppSurfaceTokens.Shadow.y
        )
    }

    private var trimmedInput: String {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        trimmedInput.isEmpty == false && viewModel.isLoading == false
    }

    private func sendCurrentMessage() {
        guard canSend else { return }
        Task { await viewModel.sendMessage() }
    }

    private var composerStages: [String] {
        ["理解目标", "调用工具", "整理结果"]
    }

    private var composerSuggestions: [String] {
        ["当前任务", "待确认问题", "权限确认", "工具调用结果"]
    }

    private func performComposerPrimaryAction() {
        sendCurrentMessage()
    }

    private func applyPreviewSelectionIfNeeded() {
        if shouldLoadDashboardData {
            _ = "shouldLoadDashboardData"
        }
        if let answer = viewModel.quickAskAnswer {
            _ = answer
        }
        if viewModel.quickAskMessages.isEmpty == false {
            _ = viewModel.quickAskMessages.count
        }
        if viewModel.quickAskQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            _ = viewModel.quickAskQuestion
        }
    }

    private var inspectorPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("任务与上下文")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                iconButton(symbol: "xmark", help: "收起") {
                    withAnimation(.easeOut(duration: 0.18)) { showInspector = false }
                }
            }
            .padding(14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inspectorSection("当前对话") {
                        inspectorLine("模型", value: viewModel.selectedModelLabel)
                        inspectorLine("消息", value: "\(viewModel.quickAskMessages.count) 条")
                        inspectorLine("工作区", value: viewModel.currentWorkspaceTitle)
                    }

                    inspectorSection("任务") {
                        if viewModel.recentTaskSummaries.isEmpty {
                            Text("对话中创建的任务会显示在这里。")
                                .font(.system(size: 11.5))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        } else {
                            ForEach(viewModel.recentTaskSummaries.prefix(5), id: \.taskId) { task in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(task.title)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .lineLimit(2)
                                    Text(task.stateLabel)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    inspectorSection("最近素材") {
                        if viewModel.recentItems.isEmpty {
                            Text("暂无素材")
                                .font(.system(size: 11.5))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        } else {
                            ForEach(viewModel.recentItems.prefix(4), id: \.id) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                                    Text(item.title ?? item.previewText ?? "未命名素材")
                                        .font(.system(size: 12))
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AppSurfaceTokens.cardBackground.opacity(0.72))
    }

    private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inspectorLine(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

private struct ConversationComposerCard<Content: View>: View {
    let stages: [String]
    let suggestions: [String]
    let isProcessing: Bool
    let primaryAction: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(stages, id: \.self) { stage in
                    Text(stage)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                Spacer()
                Button(isProcessing ? ToolStatusLabelFormatter.processingText : "发送") {
                    primaryAction()
                }
                .buttonStyle(.borderless)
            }
            content
            HStack(spacing: 6) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Text(suggestion)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
        }
    }
}

private func metadataCard(_ items: [(String, String)]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        ForEach(items, id: \.0) { item in
            HStack {
                Text(item.0)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                Spacer()
                Text(item.1)
                    .foregroundStyle(AppSurfaceTokens.primaryText)
            }
            .font(.system(size: 12))
        }
    }
}

private func bulletListCard(items: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        ForEach(items, id: \.self) { item in
            Label(item, systemImage: "circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }
}

private func bulletListCard(_ items: [String]) -> some View {
    bulletListCard(items: items)
}

private func nonEmptyText(_ value: String?) -> String? {
    guard let value, value.isEmpty == false else { return nil }
    return value
}

private extension Collection {
    func ifEmpty(_ fallback: [Element]) -> [Element] {
        isEmpty ? fallback : Array(self)
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 72) }

            if isUser == false {
                avatar
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(isUser ? "你" : "Agent")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Text(message.content)
                    .font(.system(size: 13.5))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, isUser ? 13 : 0)
                    .padding(.vertical, isUser ? 10 : 0)
                    .background(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.card, style: .continuous)
                            .fill(isUser ? AppSurfaceTokens.accentBlue.opacity(0.11) : Color.clear)
                    )
            }
            .frame(maxWidth: 650, alignment: isUser ? .trailing : .leading)

            if isUser == false { Spacer(minLength: 72) }
        }
        .frame(maxWidth: .infinity)
    }

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppSurfaceTokens.accentBlue.opacity(0.12))
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.accentBlue)
        }
        .frame(width: 28, height: 28)
    }
}

private struct AgentInlineResult: View {
    let title: String
    let symbol: String
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.accentBlue)
                .frame(width: 28, height: 28)
                .background(AppSurfaceTokens.accentBlue.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(content)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.card, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
    }
}

private enum AgentTraceRenderer {
    static func parse(_ raw: String) -> [String] {
        raw.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}
