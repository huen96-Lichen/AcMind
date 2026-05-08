import SwiftUI
import AcMindKit
import Foundation

struct AgentView: View {
    @StateObject private var viewModel = AgentViewModel()
    @State private var leftColumnWidth: CGFloat = 240
    @State private var rightColumnWidth: CGFloat = 280
    @State private var isLeftColumnCollapsed = false
    @State private var isRightColumnCollapsed = false

    var body: some View {
        HSplitView {
            leftColumn
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)

            centerColumn
                .frame(minWidth: 400)

            rightColumn
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 400)
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionSendToAgent)) { notification in
            if let transcription = notification.userInfo?["transcription"] as? CompanionVoiceTranscription {
                viewModel.receiveCompanionTranscription(transcription)
            }
        }
    }

    // MARK: - Left Column

    private var leftColumn: some View {
        VStack(spacing: 0) {
            tabSelector

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch viewModel.selectedTab {
                    case .sessions:
                        sessionsSection
                    case .tasks:
                        tasksSection
                    case .skills:
                        skillsSection
                    case .goals:
                        goalsSection
                    }
                }
                .padding()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AgentLeftTab.allCases) { tab in
                Button(action: {
                    viewModel.selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(viewModel.selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundStyle(viewModel.selectedTab == tab ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("最近会话")

            if let session = viewModel.currentSession {
                sessionRow(session, isSelected: true)
            }

            Button(action: {}) {
                HStack {
                    Image(systemName: "plus")
                    Text("新建会话")
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func sessionRow(_ session: ChatSession, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(session.createdAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("任务看板")

            if viewModel.taskBoard.tasks.isEmpty {
                emptyPlaceholder("暂无任务")
            } else {
                taskStatusGroup("执行中", tasks: viewModel.taskBoard.runningTasks)
                taskStatusGroup("待执行", tasks: viewModel.taskBoard.pendingTasks)
                taskStatusGroup("等待确认", tasks: viewModel.taskBoard.waitingTasks)
            }
        }
    }

    private func taskStatusGroup(_ title: String, tasks: [AgentTask]) -> some View {
        Group {
            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    ForEach(tasks.prefix(3)) { task in
                        taskRow(task)
                    }

                    if tasks.count > 3 {
                        Text("+\(tasks.count - 3) 更多")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
    }

    private func taskRow(_ task: AgentTask) -> some View {
        HStack {
            Image(systemName: task.status.icon)
                .font(.system(size: 10))
                .foregroundStyle(statusColor(for: task.status))

            Text(task.title)
                .font(.system(size: 11))
                .lineLimit(1)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
    }

    private func statusColor(for status: AgentTaskStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .running: return .accentColor
        case .waiting: return .orange
        case .failed: return .red
        case .completed: return .green
        case .archived: return .gray
        }
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("可用技能")

            ForEach(viewModel.activeSkills) { skill in
                skillRow(skill)
            }
        }
    }

    private func skillRow(_ skill: AgentSkill) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
                Text(skill.name)
                    .font(.system(size: 12, weight: .medium))
            }

            Text(skill.description)
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("当前目标")

            if viewModel.currentGoal.isEmpty {
                emptyPlaceholder("设置当前目标")
            } else {
                Text(viewModel.currentGoal)
                    .font(.system(size: 12))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            }

            TextField("输入目标...", text: $viewModel.currentGoal)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 12))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.secondary)
    }

    private func emptyPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11))
            .foregroundStyle(Color.secondary)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Center Column

    private var centerColumn: some View {
        VStack(spacing: 0) {
            messageList

            inputBar
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.messages) { message in
                            AgentMessageRow(message: message, viewModel: viewModel)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .id(message.id)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 100)

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.4))

            VStack(spacing: 8) {
                Text("今天想完成什么？")
                    .font(.system(size: 20, weight: .semibold))

                Text("输入想法、语音转写，或让 AI 帮你执行任务。")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
            }

            quickActions

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionChip(icon: "mic.fill", title: "语音输入", color: .accentColor) {
                Task { await viewModel.toggleRecording() }
            }
            quickActionChip(icon: "sparkles", title: "AI 整理", color: .orange) {
                Task { await viewModel.distill() }
            }
            quickActionChip(icon: "tray.and.arrow.down", title: "保存收集箱", color: .green) {
                Task { await viewModel.saveToInbox() }
            }
        }
        .padding(.top, 8)
    }

    private func quickActionChip(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.08))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()

            if viewModel.hasCompanionTranscription {
                companionBanner
            }

            HStack(alignment: .bottom, spacing: 10) {
                VoiceInputButton(viewModel: viewModel)
                    .frame(width: 36, height: 36)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.inputText)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .frame(minHeight: 24, maxHeight: 120)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 1)
                        )

                    if viewModel.inputText.isEmpty {
                        Text("给 Agent 发送消息...")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: 4) {
                    sendButton
                    distillButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)

            if viewModel.recordingStatus == .recording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("录音中 \(viewModel.recordingDuration, specifier: "%.0f")s")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red)
                }
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var sendButton: some View {
        let isEmpty = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button(action: {
            Task { await viewModel.saveToInbox() }
        }) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isEmpty ? .secondary : .white)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isEmpty ? Color(NSColor.controlBackgroundColor) : Color.accentColor)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isEmpty)
        .help("保存到收集箱")
    }

    private var distillButton: some View {
        let isEmpty = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button(action: {
            Task { await viewModel.distill() }
        }) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isEmpty ? .secondary : .orange)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isEmpty ? Color(NSColor.controlBackgroundColor) : Color.orange.opacity(0.12))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isEmpty || viewModel.isLoading)
        .help("AI 整理")
    }

    private var companionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.accentColor)

            if let transcription = viewModel.companionTranscription {
                Text("\"\(transcription.text.prefix(60))\(transcription.text.count > 60 ? "..." : "")\"")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("继续整理") {
                viewModel.useCompanionTranscription()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.accentColor)

            Button {
                viewModel.saveCompanionToInbox()
            } label: {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                viewModel.dismissCompanionTranscription()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.06))
    }

    // MARK: - Right Column

    private var rightColumn: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    currentContextSection
                    modelUsageSection
                    availableToolsSection
                    relatedMemoriesSection
                }
                .padding()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var currentContextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeaderRight("当前上下文")

            if viewModel.skillContext.isEmpty {
                Text("无激活上下文")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            } else {
                ForEach(viewModel.skillContext.skills.prefix(3)) { skill in
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                        Text(skill.name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var modelUsageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeaderRight("本次消耗")

            if let route = viewModel.currentRoute {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("模型:")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                        Text(route.modelId)
                            .font(.system(size: 11, weight: .medium))
                    }
                    HStack {
                        Text("任务:")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                        Text(route.taskType.displayName)
                            .font(.system(size: 11))
                    }
                    Text(route.reason)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
            } else {
                Text("等待路由...")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }

            if viewModel.sessionUsage.sessionSummary.totalRequests > 0 {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("会话总计")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.secondary)
                    Text("¥\(String(format: "%.2f", viewModel.sessionUsage.sessionSummary.totalCostCNY))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("\(viewModel.sessionUsage.sessionSummary.totalTokens) Token")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    private var availableToolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeaderRight("可用工具")

            ForEach(viewModel.availableTools.filter { $0.enabled }.prefix(5)) { tool in
                HStack(spacing: 6) {
                    Image(systemName: tool.type.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                    Text(tool.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
        }
    }

    private var relatedMemoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeaderRight("相关记忆")

            if viewModel.memoryContext.isEmpty {
                Text("暂无相关记忆")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            } else {
                if !viewModel.memoryContext.preferenceMemories.isEmpty {
                    memoryGroup("偏好", memories: viewModel.memoryContext.preferenceMemories.prefix(2))
                }
                if !viewModel.memoryContext.projectMemories.isEmpty {
                    memoryGroup("项目", memories: viewModel.memoryContext.projectMemories.prefix(2))
                }
            }
        }
    }

    private func memoryGroup(_ title: String, memories: ArraySlice<AgentMemory>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.secondary)

            ForEach(Array(memories)) { memory in
                Text(memory.key)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
        }
    }

    private func sectionHeaderRight(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.primary)
    }
}

// MARK: - Agent Message Row

struct AgentMessageRow: View {
    let message: AgentMessage
    @ObservedObject var viewModel: AgentViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                Text(roleLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)

                messageContent

                messageFooter
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var avatar: some View {
        Group {
            switch message.role {
            case .user:
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            case .assistant:
                Image(systemName: "sparkles.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.orange.opacity(0.8))
            case .system:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.green.opacity(0.7))
            case .companion:
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor.opacity(0.7))
            case .executionStep:
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.blue.opacity(0.8))
            case .toolResult:
                Image(systemName: "wrench.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.purple.opacity(0.8))
            case .confirmation:
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.orange.opacity(0.8))
            }
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user: return "你"
        case .assistant: return "AcMind"
        case .system: return "系统"
        case .companion: return "随身"
        case .executionStep: return "执行步骤"
        case .toolResult: return "工具结果"
        case .confirmation: return "确认"
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if message.isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }
        } else if let note = message.distilledNote {
            distilledCard(note)
        } else if let step = message.executionStep {
            executionStepCard(step)
        } else if let toolResult = message.toolResult {
            toolResultCard(toolResult)
        } else if let confirmation = message.confirmation {
            confirmationCard(confirmation)
        } else {
            Text(message.text)
                .font(.system(size: 14))
                .foregroundStyle(Color.primary)
                .lineSpacing(4)
        }
    }

    private var messageFooter: some View {
        HStack {
            Text(message.timestamp, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            if let status = message.statusText {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func distilledCard(_ note: DistilledNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.title ?? "未命名")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary)

            Text(note.summary ?? "")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)
                .lineSpacing(3)

            if !note.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(note.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.08))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func executionStepCard(_ step: ExecutionStepDisplay) -> some View {
        HStack(spacing: 12) {
            Image(systemName: step.status.icon)
                .font(.system(size: 16))
                .foregroundStyle(stepStatusColor(step.status))

            VStack(alignment: .leading, spacing: 2) {
                Text(step.stepTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary)

                if let toolName = step.toolName {
                    Text(toolName)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }

                if let result = step.result {
                    Text(result)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let duration = step.duration {
                Text(duration)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }

    private func stepStatusColor(_ status: StepStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .running: return .accentColor
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .gray
        }
    }

    private func toolResultCard(_ result: ToolResultDisplay) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(result.success ? Color.green : Color.red)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(result.toolType.displayName)
                        .font(.system(size: 12, weight: .medium))
                    Text(result.toolName)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }

                if let output = result.output {
                    Text(output)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }

                if let error = result.error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.red)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let duration = result.duration {
                Text(duration)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
    }

    private func confirmationCard(_ confirmation: ConfirmationDisplay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(confirmation.title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if confirmation.isPending {
                    Text("待确认")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Text(confirmation.description)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            HStack(spacing: 8) {
                Button(confirmation.actionLabel) {
                    viewModel.confirmAction(messageId: message.id)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(confirmation.cancelLabel) {
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Voice Input Button

struct VoiceInputButton: View {
    @ObservedObject var viewModel: AgentViewModel
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            Task {
                await viewModel.toggleRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(viewModel.recordingStatus == .recording ? Color.red.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                    .frame(width: 36, height: 36)

                Image(systemName: viewModel.recordingStatus == .recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(viewModel.recordingStatus == .recording ? .red : .secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .help(viewModel.recordingStatus == .recording ? "停止录音" : "开始录音")
    }
}
