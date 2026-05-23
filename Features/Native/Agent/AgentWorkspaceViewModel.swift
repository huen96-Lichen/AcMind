import Foundation
import SwiftUI
import AcMindKit

@MainActor
final class AgentWorkspaceViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var inputText: String = ""
    @Published var selectedFolderID: String = AgentProjectFolder.systemFolders.first?.id ?? "all"
    @Published var selectedSessionID: String?
    @Published var selectedActionMode: AgentActionMode = .auto
    @Published var sessions: [AgentSessionSummary] = []
    @Published var messages: [ChatMessage] = []
    @Published var executionEntries: [AgentExecutionEntry] = []
    @Published var summaryItems: [AgentResultSummaryItem] = []
    @Published var toolChain: [AgentToolChainStep] = []
    @Published var enabledProviders: [ProviderConfig] = []
    @Published var selectedProviderID: String = ""
    @Published var expandedFolderIDs: Set<String> = Set(AgentProjectFolder.systemFolders.map(\.id).filter { $0 != "all" })
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var hintText: String = "Enter 发送，Shift+Enter 换行"
    @Published var statusLabel: String = "待命"
    @Published var statusKind: ACBadge.Kind = .green
    @Published var lastActionTitle: String = "等待指令"

    private let storage: StorageServiceProtocol
    private let aiRuntime: AIRuntimeProtocol
    private let knowledgeService: KnowledgeServiceProtocol
    private let scheduleViewModel = ScheduleViewModel()
    private var didLoad = false
    private var projectFolders: [AgentProjectFolder] = AgentProjectFolder.systemFolders

    init(container: ServiceContainer) {
        self.storage = container.storageService
        self.aiRuntime = container.aiRuntime
        self.knowledgeService = container.knowledgeService
    }

    var sidebarFolders: [AgentProjectFolder] { visibleFolders }

    var historySessions: [AgentSessionSummary] {
        let query = trimmedSearchText
        return sessions
            .filter { matchesSearch($0, query: query) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(8)
            .map { $0 }
    }

    var recentSessionSections: [AgentRecentSessionSection] {
        let query = trimmedSearchText
        let matchingSessions = sessions
            .filter { matchesSearch($0, query: query) }
            .sorted { $0.updatedAt > $1.updatedAt }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: matchingSessions) { session in
            sectionKind(for: session.updatedAt, calendar: calendar)
        }

        return AgentRecentSessionSection.Kind.displayOrder.compactMap { kind -> AgentRecentSessionSection? in
            guard let sessions = grouped[kind], !sessions.isEmpty else { return nil }
            return AgentRecentSessionSection(
                kind: kind,
                sessions: sessions
            )
        }
    }

    var visibleFolders: [AgentProjectFolder] {
        let query = trimmedSearchText
        let folderCounts = Dictionary(uniqueKeysWithValues: projectFolders.map { folder in
            let count = sessions(in: folder.id, query: query).count
            return (folder.id, count)
        })

        return projectFolders
            .sorted { $0.order < $1.order }
            .filter { folder in
                guard folder.id != "all" else { return true }
                return query.isEmpty || matchesFolder(folder, query: query) || (folderCounts[folder.id] ?? 0) > 0
            }
            .map { folder in
                var copy = folder
                copy.sessionCount = folder.id == "all" ? filteredSessionCount(query: query) : (folderCounts[folder.id] ?? 0)
                return copy
            }
    }

    var visibleSessions: [AgentSessionSummary] {
        sessions(in: selectedFolderID)
    }

    var selectedFolderName: String {
        folder(for: selectedFolderID)?.name ?? "全部"
    }

    var activeSessionTitle: String {
        selectedSessionSummary?.title ?? "新建对话"
    }

    var activeSessionSubtitle: String {
        if let session = selectedSessionSummary {
            return "\(session.folderName) · \(session.messageCount) 条消息 · \(session.updatedAt.formattedAgentTime)"
        }
        return "选择一个历史对话，或者直接新建会话开始。"
    }

    var currentModelLabel: String {
        selectedProvider?.modelId ?? "本地回退"
    }

    var connectionStatusLabel: String {
        selectedProvider == nil ? "本地回退" : "在线"
    }

    var connectionStatusKind: ACBadge.Kind {
        selectedProvider == nil ? .neutral : .green
    }

    var routeSummary: String {
        selectedActionMode == .auto ? "智能判断" : selectedActionMode.displayName
    }

    var toolChainSummary: String {
        if toolChain.isEmpty {
            return "等待输入"
        }
        return "\(toolChain.filter { $0.state == .done }.count)/\(toolChain.count)"
    }

    var lastExecutionTitle: String {
        executionEntries.first?.title ?? "暂无执行"
    }

    var activeActionMode: AgentActionMode {
        selectedActionMode == .auto ? detectedActionMode(for: inputText) : selectedActionMode
    }

    var selectedSessionSummary: AgentSessionSummary? {
        sessions.first(where: { $0.id == selectedSessionID })
    }

    var selectedProvider: ProviderConfig? {
        enabledProviders.first(where: { $0.id == selectedProviderID }) ?? enabledProviders.first
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await reloadWorkspace(selectNewestIfNeeded: true)
    }

    func refreshProviders() async {
        await reloadWorkspace(selectNewestIfNeeded: false)
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }

    func acceptVoiceDraft(_ draft: String) {
        inputText = draft
        if selectedSessionID == nil {
            Task { await createNewChat() }
        }
        statusLabel = "已接收语音草稿"
        statusKind = .blue
    }

    func selectFolder(_ folderID: String) {
        selectedFolderID = folderID
        if folderID != "all" {
            expandedFolderIDs.insert(folderID)
        }
        if let first = visibleSessions.first {
            Task { await selectSession(first.id) }
        } else {
            selectedSessionID = nil
            messages = []
            toolChain = []
            summaryItems = []
        }
    }

    func createProjectFolder() async {
        let index = projectFolders.filter { !$0.isSystem }.count + 1
        let newFolder = AgentProjectFolder(
            id: "project-\(UUID().uuidString)",
            name: "项目 \(index)",
            subtitle: "新建项目文件夹",
            icon: "folder.fill",
            tint: ACColors.accentPurple,
            order: 100 + index,
            isSystem: false
        )
        projectFolders.append(newFolder)
        selectedFolderID = newFolder.id
        expandedFolderIDs.insert(newFolder.id)
        await createNewChat()
    }

    func moveSession(_ sessionID: String, to folderID: String) async {
        guard let folder = folder(for: folderID) else { return }

        do {
            guard var session = try await storage.getChatSession(id: sessionID) else { return }
            session.metadata["folderId"] = folder.id
            session.metadata["folderName"] = folder.name
            session.metadata["folderIcon"] = folder.icon
            session.updatedAt = Date()
            try await storage.updateChatSession(session)

            selectedFolderID = folder.id
            selectedSessionID = sessionID
            statusLabel = "已归入文件夹"
            statusKind = .green

            await reloadWorkspace(selectNewestIfNeeded: false)
            await selectSession(sessionID)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func renameFolder(folderID: String, to newName: String) async {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let folder = folder(for: folderID), !folder.isSystem else { return }

        do {
            let folderSessionIDs = sessions
                .filter { $0.folderID == folderID }
                .map(\.id)

            for sessionID in folderSessionIDs {
                guard var session = try await storage.getChatSession(id: sessionID) else { continue }
                session.metadata["folderName"] = trimmedName
                session.updatedAt = Date()
                try await storage.updateChatSession(session)
            }

            selectedFolderID = folderID
            statusLabel = "文件夹已重命名"
            statusKind = .green
            await reloadWorkspace(selectNewestIfNeeded: false)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func createNewChat() async {
        let folder = folder(for: selectedFolderID) ?? AgentProjectFolder.systemFolders[0]
        let session = ChatSession(
            title: "新对话",
            providerId: selectedProvider?.id,
            modelId: selectedProvider?.modelId,
            status: .active,
            metadata: [
                "folderId": folder.id,
                "folderName": folder.name,
                "folderIcon": folder.icon,
                "actionMode": selectedActionMode.rawValue
            ]
        )

        do {
            try await storage.insertChatSession(session)
            selectedSessionID = session.id
            messages = []
            toolChain = []
            summaryItems = []
            lastActionTitle = "新会话"
            await reloadWorkspace(selectNewestIfNeeded: false)
            await selectSession(session.id)
            statusLabel = "新对话已创建"
            statusKind = .green
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func selectSession(_ sessionID: String) async {
        selectedSessionID = sessionID
        if let session = sessions.first(where: { $0.id == sessionID }) {
            selectedFolderID = session.folderID
            if session.folderID != "all" {
                expandedFolderIDs.insert(session.folderID)
            }
        }

        if let storedSession = try? await storage.getChatSession(id: sessionID) {
            if let providerId = storedSession.providerId,
               enabledProviders.contains(where: { $0.id == providerId }) {
                selectedProviderID = providerId
            } else if selectedProviderID.isEmpty {
                selectedProviderID = enabledProviders.first?.id ?? ""
            }

            if let rawMode = storedSession.metadata["actionMode"] {
                selectedActionMode = AgentActionMode(rawValue: rawMode) ?? selectedActionMode
            }
        }

        await reloadMessages(for: sessionID)
    }

    func selectProvider(_ providerID: String) async {
        guard enabledProviders.contains(where: { $0.id == providerID }) else { return }
        selectedProviderID = providerID
        await lockCurrentSessionProvider()
    }

    func reloadCurrentSession() async {
        guard let sessionID = selectedSessionID else { return }
        await reloadMessages(for: sessionID)
    }

    func sendCurrentInput() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            presentError("输入不能为空")
            return
        }

        if selectedSessionID == nil {
            await createNewChat()
        }

        guard let sessionID = selectedSessionID else { return }

        let userMessage = ChatMessage(
            sessionId: sessionID,
            role: .user,
            content: content,
            status: .completed
        )

        do {
            try await storage.insertChatMessage(userMessage)
            await updateSessionTitleIfNeeded(sessionID: sessionID, content: content)
        } catch {
            presentError(error.localizedDescription)
            return
        }

        messages.append(userMessage)
        inputText = ""
        isLoading = true
        statusLabel = "正在处理"
        statusKind = .blue
        toolChain = [AgentToolChainStep(title: "解析指令", detail: "判断输入是聊天、待办、搜索还是日程", state: .running, accent: ACColors.accentBlue)]

        let mode = selectedActionMode == .auto ? detectedActionMode(for: content) : selectedActionMode
        if selectedActionMode == .auto {
            selectedActionMode = mode
        }
        await updateSessionActionMode(sessionID: sessionID, mode: mode)
        await updateSessionProvider(sessionID: sessionID)

        do {
            let result = try await execute(content: content, sessionID: sessionID)
            toolChain = result.toolChain
            summaryItems = result.summaryItems
            lastActionTitle = result.title
            statusLabel = result.statusLabel
            statusKind = result.statusKind
            executionEntries.insert(
                AgentExecutionEntry(
                    title: result.title,
                    detail: result.detail,
                    state: result.executionState,
                    accent: result.statusKind == .green ? ACColors.accentGreen : ACColors.accentBlue,
                    timestamp: Date()
                ),
                at: 0
            )

            let assistantMessage = ChatMessage(
                sessionId: sessionID,
                role: .assistant,
                content: result.reply,
                status: .completed,
                modelId: selectedProvider?.modelId,
                providerId: selectedProvider?.id
            )
            messages.append(assistantMessage)
            try await storage.insertChatMessage(assistantMessage)
            await reloadWorkspace(selectNewestIfNeeded: false)
            await reloadMessages(for: sessionID)
        } catch {
            let fallback = ChatMessage(
                sessionId: sessionID,
                role: .assistant,
                content: "这条指令我已经接住了，但执行过程中遇到错误：\(error.localizedDescription)",
                status: .failed
            )
            messages.append(fallback)
            try? await storage.insertChatMessage(fallback)
            presentError(error.localizedDescription)
        }

        isLoading = false
    }

    func deleteSession(_ sessionID: String) async {
        do {
            try await storage.deleteChatSession(id: sessionID)
            if selectedSessionID == sessionID {
                selectedSessionID = nil
                messages = []
                executionEntries = []
                summaryItems = []
                toolChain = []
            }
            statusLabel = "会话已删除"
            statusKind = .neutral
            await reloadWorkspace(selectNewestIfNeeded: true)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func reloadWorkspace(selectNewestIfNeeded: Bool) async {
        do {
            enabledProviders = (await aiRuntime.listProviders()).filter { $0.enabled }
            if selectedProviderID.isEmpty {
                selectedProviderID = enabledProviders.first?.id ?? ""
            } else if !enabledProviders.contains(where: { $0.id == selectedProviderID }) {
                selectedProviderID = enabledProviders.first?.id ?? ""
            }

            let loadedSessions = try await storage.listChatSessions(status: nil)
            let summaries = await buildSessionSummaries(from: loadedSessions)
            sessions = summaries.sorted { $0.updatedAt > $1.updatedAt }

            projectFolders = AgentProjectFolder.systemFolders
            let dynamicFolders = summaries
                .map { $0.folder }
                .reduce(into: [String: AgentProjectFolder]()) { partialResult, folder in
                    partialResult[folder.id] = folder
                }
                .values
                .sorted { $0.order < $1.order }
            projectFolders.append(contentsOf: dynamicFolders.filter { folder in
                !AgentProjectFolder.systemFolders.contains(where: { $0.id == folder.id })
            })

            if selectNewestIfNeeded && selectedSessionID == nil {
                selectedSessionID = sessions.first?.id
                if let sessionID = selectedSessionID {
                    selectedFolderID = sessions.first?.folderID ?? selectedFolderID
                    await reloadMessages(for: sessionID)
                }
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func reloadMessages(for sessionID: String) async {
        do {
            messages = try await storage.listChatMessages(sessionId: sessionID)
            await rebuildExecutionState(from: messages)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func updateSessionTitleIfNeeded(sessionID: String, content: String) async {
        do {
            guard var session = try await storage.getChatSession(id: sessionID) else { return }
            let trimmedTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedTitle.isEmpty || trimmedTitle == "新对话" else { return }

            session.title = conciseTitle(from: content, fallback: "新对话")
            session.updatedAt = Date()
            try await storage.updateChatSession(session)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func updateSessionActionMode(sessionID: String, mode: AgentActionMode) async {
        do {
            guard var session = try await storage.getChatSession(id: sessionID) else { return }
            session.metadata["actionMode"] = mode.rawValue
            session.updatedAt = Date()
            try await storage.updateChatSession(session)
        } catch {
            // 不中断主流程；这里仅用于记住会话偏好
        }
    }

    private func updateSessionProvider(sessionID: String) async {
        do {
            guard var session = try await storage.getChatSession(id: sessionID) else { return }
            guard let provider = selectedProvider else { return }
            session.providerId = provider.id
            session.modelId = provider.modelId
            session.metadata["providerId"] = provider.id
            session.metadata["providerName"] = provider.name
            session.metadata["providerType"] = provider.providerType.storageValue
            session.metadata["providerTier"] = provider.tier.storageValue
            session.metadata["modelId"] = provider.modelId
            session.updatedAt = Date()
            try await storage.updateChatSession(session)
        } catch {
            // 继续执行，不阻断主流程
        }
    }

    private func lockCurrentSessionProvider() async {
        guard let sessionID = selectedSessionID else { return }
        await updateSessionProvider(sessionID: sessionID)
    }

    private func rebuildExecutionState(from messages: [ChatMessage]) async {
        guard let latestUser = messages.last(where: { $0.role == .user }) else {
            toolChain = []
            summaryItems = []
            return
        }

        let mode = selectedActionMode == .auto ? detectedActionMode(for: latestUser.content) : selectedActionMode
        toolChain = buildToolChain(for: mode, content: latestUser.content)
        summaryItems = buildSummaryItems(for: mode, content: latestUser.content)
    }

    private func execute(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let mode = selectedActionMode == .auto ? detectedActionMode(for: content) : selectedActionMode

        switch mode {
        case .chat:
            return try await executeChat(content: content, sessionID: sessionID)
        case .task:
            return try await executeTask(content: content, sessionID: sessionID)
        case .search:
            return try await executeSearch(content: content, sessionID: sessionID)
        case .schedule:
            return try await executeSchedule(content: content, sessionID: sessionID)
        case .note:
            return try await executeNote(content: content, sessionID: sessionID)
        case .auto:
            return try await executeChat(content: content, sessionID: sessionID)
        }
    }

    private func executeChat(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let history = try await storage.listChatMessages(sessionId: sessionID)
        let systemPrompt = """
        你是 AcMind 的原生聊天式 Agent。
        你需要简洁、可执行地回应用户，并优先给出下一步动作。
        当用户提到待办、日程、资料搜索、记笔记时，请输出清晰结果，不要写空话。
        """

        let promptMessages = [ChatMessage(sessionId: sessionID, role: .system, content: systemPrompt, status: .completed)] + history
        let providerSnapshot = selectedProvider
        let fallback = buildLocalReply(for: content)

        guard let provider = providerSnapshot else {
            return AgentExecutionResult(
                title: "本地回复",
                detail: "没有可用模型配置，已使用本地回退策略",
                reply: fallback,
                toolChain: buildToolChain(for: .chat, content: content),
                summaryItems: buildSummaryItems(for: .chat, content: content),
                statusLabel: "本地回退",
                statusKind: .neutral,
                executionState: .done
            )
        }

        let providerModel = provider.modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestModel = providerModel.isEmpty ? nil : providerModel

        do {
            let response = try await aiRuntime.chat(messages: promptMessages, providerId: provider.id, model: requestModel)
            let reply = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reply.isEmpty else {
                throw AIError.invalidResponse
            }

            return AgentExecutionResult(
                title: "对话已完成",
                detail: "通过 \(provider.name) / \(provider.modelId) 生成回复",
                reply: reply,
                toolChain: buildToolChain(for: .chat, content: content),
                summaryItems: buildSummaryItems(for: .chat, content: content),
                statusLabel: "已回复",
                statusKind: .green,
                executionState: .done
            )
        } catch {
            return AgentExecutionResult(
                title: "对话失败后回退",
                detail: error.localizedDescription,
                reply: fallback,
                toolChain: buildToolChain(for: .chat, content: content),
                summaryItems: buildSummaryItems(for: .chat, content: content),
                statusLabel: "回退完成",
                statusKind: .orange,
                executionState: .failed
            )
        }
    }

    private func executeTask(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let title = conciseTitle(from: content, fallback: "新待办")
        let steps = [
            TaskStep(title: "整理需求", description: content, status: .completed, order: 1),
            TaskStep(title: "拆解步骤", description: "已形成 3-5 个可执行动作", status: .completed, order: 2),
            TaskStep(title: "写入任务看板", description: "已转入任务管理", status: .completed, order: 3),
            TaskStep(title: "等待执行", description: "后续可继续追问或接着执行", status: .pending, order: 4)
        ]
        let task = AgentTask(
            title: title,
            description: content,
            status: .running,
            priority: .medium,
            steps: steps,
            currentStepIndex: 0,
            sourceMessageId: sessionID
        )

        let createdTask = try await persistTask(task)

        return AgentExecutionResult(
            title: "已创建任务",
            detail: "任务《\(createdTask.title)》已写入任务看板",
            reply: "我已经把这条内容整理成待办《\(createdTask.title)》，并放入任务看板。你可以继续让我拆解步骤、补充优先级，或者直接开始执行。",
            toolChain: buildToolChain(for: .task, content: content),
            summaryItems: [
                AgentResultSummaryItem(title: "任务标题", value: createdTask.title, tint: ACColors.accentGreen),
                AgentResultSummaryItem(title: "状态", value: createdTask.status.displayName, tint: ACColors.accentBlue),
                AgentResultSummaryItem(title: "优先级", value: createdTask.priority.displayName, tint: ACColors.accentPurple)
            ],
            statusLabel: "任务已建",
            statusKind: .green,
            executionState: .done
        )
    }

    private func executeSearch(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let query = searchQuery(from: content)
        let cardResults = try await knowledgeService.searchCards(query: query)
        let vaultResults = (try? await knowledgeService.searchVault(query: query)) ?? []
        let webResults = try? await performWebSearch(query: query)

        var replyParts: [String] = []
        if !cardResults.isEmpty {
            replyParts.append("知识库结果：")
            replyParts.append(contentsOf: cardResults.prefix(3).map { "• \($0.canonicalTitle) · \($0.summary ?? "无摘要")" })
        }
        if !vaultResults.isEmpty {
            replyParts.append("Vault 结果：")
            replyParts.append(contentsOf: vaultResults.prefix(3).map { "• \($0.title) · \($0.excerpt)" })
        }
        if let webResults, !webResults.isEmpty {
            replyParts.append("联网搜索：")
            replyParts.append(contentsOf: webResults.prefix(3).map { "• \($0.title)\n  \($0.url)" })
        }
        if replyParts.isEmpty {
            replyParts.append("没有搜到直接命中的资料，但我已经把这条问题转成可继续追问的搜索请求。")
        }

        return AgentExecutionResult(
            title: "搜索完成",
            detail: "查询「\(query)」已完成",
            reply: replyParts.joined(separator: "\n\n"),
            toolChain: [
                AgentToolChainStep(title: "搜索知识库", detail: "调用 `searchCards`", state: .done, accent: ACColors.accentBlue),
                AgentToolChainStep(title: "搜索 Vault", detail: "调用 `searchVault`", state: .done, accent: ACColors.accentPurple),
                AgentToolChainStep(title: "联网搜索", detail: "通过 DuckDuckGo HTML 接口检索", state: .done, accent: ACColors.accentGreen)
            ],
            summaryItems: [
                AgentResultSummaryItem(title: "知识卡片", value: "\(cardResults.count) 条", tint: ACColors.accentBlue),
                AgentResultSummaryItem(title: "Vault 结果", value: "\(vaultResults.count) 条", tint: ACColors.accentPurple),
                AgentResultSummaryItem(title: "联网结果", value: "\(webResults?.count ?? 0) 条", tint: ACColors.accentGreen)
            ],
            statusLabel: "搜索完成",
            statusKind: .green,
            executionState: .done
        )
    }

    private func executeSchedule(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let parsed = parseScheduleIntent(from: content)
        let title = parsed.title
        let categoryId = scheduleViewModel.categories.first?.id ?? "default"

        scheduleViewModel.openCreateEvent(on: parsed.date, hour: parsed.hour, minute: parsed.minute)
        scheduleViewModel.createEvent(
            title: title,
            categoryId: categoryId,
            startHour: parsed.hour,
            startMinute: parsed.minute,
            durationMinutes: parsed.duration,
            isAllDay: false
        )

        let timeLabel = parsed.date.formatted(date: .abbreviated, time: .shortened)
        return AgentExecutionResult(
            title: "已安排日程",
            detail: "日程《\(title)》已写入系统日历",
            reply: "我已经把这条内容安排成日程《\(title)》，时间是 \(timeLabel)。如果你愿意，我还可以继续帮你补参会人、拆成待办，或者改成全天事件。",
            toolChain: [
                AgentToolChainStep(title: "解析时间", detail: "提取日期和时刻", state: .done, accent: ACColors.accentBlue),
                AgentToolChainStep(title: "创建日程", detail: "已写入系统日历", state: .done, accent: ACColors.accentGreen)
            ],
            summaryItems: [
                AgentResultSummaryItem(title: "标题", value: title, tint: ACColors.accentGreen),
                AgentResultSummaryItem(title: "时间", value: timeLabel, tint: ACColors.accentBlue),
                AgentResultSummaryItem(title: "时长", value: "\(parsed.duration) 分钟", tint: ACColors.accentPurple)
            ],
            statusLabel: "日程已写入",
            statusKind: .green,
            executionState: .done
        )
    }

    private func persistTask(_ task: AgentTask) async throws -> AgentTask {
        let encoded = String(data: try JSONEncoder().encode(task), encoding: .utf8) ?? ""
        try await storage.setSetting(key: "agent_task_\(task.id)", value: encoded)

        let existingIndex = (try await storage.getSetting(key: "agent_task_index")) ?? "[]"
        if let data = existingIndex.data(using: .utf8),
           var ids = try? JSONDecoder().decode([String].self, from: data),
           !ids.contains(task.id) {
            ids.insert(task.id, at: 0)
            let encodedIDs = String(data: try JSONEncoder().encode(ids), encoding: .utf8) ?? "[]"
            try await storage.setSetting(key: "agent_task_index", value: encodedIDs)
        } else {
            let encodedIDs = String(data: try JSONEncoder().encode([task.id]), encoding: .utf8) ?? "[]"
            try await storage.setSetting(key: "agent_task_index", value: encodedIDs)
        }

        return task
    }

    private func executeNote(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let item = SourceItem(
            type: .text,
            source: .manual,
            status: .captured,
            title: conciseTitle(from: content, fallback: "语音笔记"),
            previewText: content
        )
        try await storage.insertSourceItem(item)

        return AgentExecutionResult(
            title: "已保存笔记",
            detail: "内容已写入收集箱",
            reply: "我已经把这段内容保存为笔记《\(item.title ?? "语音笔记")》，后续可以继续帮你蒸馏、归类或者转成任务。",
            toolChain: [
                AgentToolChainStep(title: "整理笔记", detail: "提取语音内容", state: .done, accent: ACColors.accentBlue),
                AgentToolChainStep(title: "写入收集箱", detail: "已保存原文", state: .done, accent: ACColors.accentGreen)
            ],
            summaryItems: [
                AgentResultSummaryItem(title: "笔记标题", value: item.title ?? "语音笔记", tint: ACColors.accentGreen),
                AgentResultSummaryItem(title: "状态", value: "已保存", tint: ACColors.accentBlue)
            ],
            statusLabel: "笔记已存",
            statusKind: .green,
            executionState: .done
        )
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
        statusLabel = "出错"
        statusKind = .orange
    }

    private func buildSessionSummaries(from sessions: [ChatSession]) async -> [AgentSessionSummary] {
        var summaries: [AgentSessionSummary] = []

        for session in sessions {
            let folderID = session.metadata["folderId"] ?? "all"
            let folder = folder(for: folderID) ?? AgentProjectFolder(
                id: folderID,
                name: session.metadata["folderName"] ?? "未分类",
                subtitle: "历史归档",
                icon: "folder",
                tint: ACColors.accentBlue,
                order: 200,
                isSystem: false
            )
            let messages = (try? await storage.listChatMessages(sessionId: session.id)) ?? []
            let preview = messages.last(where: { $0.role != .system })?.content ?? "暂无消息"
            let icon = session.metadata["folderIcon"] ?? folder.icon
            let tint = folder.tint
            summaries.append(
                AgentSessionSummary(
                    id: session.id,
                    title: session.title,
                    folderID: folderID,
                    folderName: folder.name,
                    folder: folder,
                    preview: preview,
                    messageCount: messages.count,
                    createdAt: session.createdAt,
                    updatedAt: session.updatedAt,
                    timeLabel: session.updatedAt.formattedAgentTime,
                    icon: icon,
                    tint: tint
                )
            )
        }

        return summaries
    }

    private func folder(for id: String) -> AgentProjectFolder? {
        projectFolders.first(where: { $0.id == id }) ?? AgentProjectFolder.systemFolders.first(where: { $0.id == id })
    }

    func sessions(in folderID: String, query: String? = nil) -> [AgentSessionSummary] {
        let trimmedQuery = (query ?? trimmedSearchText)
        let base = folderID == "all"
            ? sessions
            : sessions.filter { $0.folderID == folderID }

        let filtered: [AgentSessionSummary]
        if trimmedQuery.isEmpty {
            filtered = base
        } else {
            filtered = base.filter { matchesSearch($0, query: trimmedQuery) }
        }

        return filtered.sorted { $0.updatedAt > $1.updatedAt }
    }

    func isFolderExpanded(_ folderID: String) -> Bool {
        folderID == "all" ? false : expandedFolderIDs.contains(folderID)
    }

    func toggleFolderExpansion(_ folderID: String) {
        guard folderID != "all" else { return }
        if expandedFolderIDs.contains(folderID) {
            expandedFolderIDs.remove(folderID)
        } else {
            expandedFolderIDs.insert(folderID)
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func filteredSessionCount(query: String) -> Int {
        query.isEmpty ? sessions.count : sessions.filter { matchesSearch($0, query: query) }.count
    }

    private func matchesFolder(_ folder: AgentProjectFolder, query: String) -> Bool {
        folder.name.localizedCaseInsensitiveContains(query) ||
        folder.subtitle.localizedCaseInsensitiveContains(query)
    }

    private func matchesSearch(_ session: AgentSessionSummary, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return session.title.localizedCaseInsensitiveContains(query) ||
        session.preview.localizedCaseInsensitiveContains(query) ||
        session.folderName.localizedCaseInsensitiveContains(query)
    }

    private func sectionKind(for date: Date, calendar: Calendar) -> AgentRecentSessionSection.Kind {
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }

        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()),
           weekInterval.contains(date) {
            return .thisWeek
        }

        if let monthInterval = calendar.dateInterval(of: .month, for: Date()),
           monthInterval.contains(date) {
            return .thisMonth
        }

        return .earlier
    }

    private func buildToolChain(for mode: AgentActionMode, content: String) -> [AgentToolChainStep] {
        switch mode {
        case .chat:
            return [
                .init(title: "解析上下文", detail: "识别对话目标", state: .done, accent: ACColors.accentBlue),
                .init(title: "生成回复", detail: "使用当前模型输出", state: .done, accent: ACColors.accentGreen),
                .init(title: "保存会话", detail: "写入本地历史", state: .done, accent: ACColors.accentPurple)
            ]
        case .task:
            return [
                .init(title: "解析任务", detail: "转成待办", state: .done, accent: ACColors.accentBlue),
                .init(title: "拆解步骤", detail: "整理为 3-5 个动作", state: .done, accent: ACColors.accentPurple),
                .init(title: "写入任务看板", detail: "创建 AgentTask", state: .done, accent: ACColors.accentGreen),
                .init(title: "生成回顾", detail: "输出下一步建议", state: .done, accent: ACColors.accentOrange)
            ]
        case .search:
            return [
                .init(title: "搜索知识库", detail: "searchCards", state: .done, accent: ACColors.accentBlue),
                .init(title: "搜索 Vault", detail: "searchVault", state: .done, accent: ACColors.accentPurple),
                .init(title: "联网检索", detail: "DuckDuckGo HTML", state: .done, accent: ACColors.accentGreen),
                .init(title: "汇总结论", detail: "生成可追问答案", state: .done, accent: ACColors.accentOrange)
            ]
        case .schedule:
            return [
                .init(title: "解析日期", detail: "自然语言时间解析", state: .done, accent: ACColors.accentBlue),
                .init(title: "创建日程", detail: "写入系统日历", state: .done, accent: ACColors.accentGreen),
                .init(title: "回写摘要", detail: "告诉你已安排的时间", state: .done, accent: ACColors.accentPurple)
            ]
        case .note:
            return [
                .init(title: "整理笔记", detail: "记录到收集箱", state: .done, accent: ACColors.accentBlue),
                .init(title: "生成摘要", detail: "准备后续蒸馏", state: .done, accent: ACColors.accentGreen),
                .init(title: "保存到收集箱", detail: "形成可追踪记录", state: .done, accent: ACColors.accentPurple)
            ]
        case .auto:
            return buildToolChain(for: detectedActionMode(for: content), content: content)
        }
    }

    private func buildSummaryItems(for mode: AgentActionMode, content: String) -> [AgentResultSummaryItem] {
        switch mode {
        case .chat:
            return []
        case .task:
            return [
                .init(title: "目标", value: conciseTitle(from: content), tint: ACColors.accentGreen),
                .init(title: "类型", value: "任务", tint: ACColors.accentBlue)
            ]
        case .search:
            return [
                .init(title: "查询", value: searchQuery(from: content), tint: ACColors.accentBlue)
            ]
        case .schedule:
            let parsed = parseScheduleIntent(from: content)
            return [
                .init(title: "标题", value: parsed.title, tint: ACColors.accentGreen),
                .init(title: "时间", value: parsed.date.formattedAgentTime, tint: ACColors.accentBlue)
            ]
        case .note:
            return [
                .init(title: "笔记", value: conciseTitle(from: content), tint: ACColors.accentPurple)
            ]
        case .auto:
            return buildSummaryItems(for: detectedActionMode(for: content), content: content)
        }
    }

    private func detectedActionMode(for content: String) -> AgentActionMode {
        let normalized = content.lowercased()
        if normalized.contains("日程") || normalized.contains("安排") || normalized.contains("提醒") || normalized.contains("会议") {
            return .schedule
        }
        if normalized.contains("待办") || normalized.contains("任务") || normalized.contains("todo") || normalized.contains("办") {
            return .task
        }
        if normalized.contains("笔记") || normalized.contains("记录") || normalized.contains("保存") || normalized.contains("记一下") {
            return .note
        }
        if normalized.contains("搜索") || normalized.contains("查一下") || normalized.contains("了解") || normalized.contains("联网") || normalized.contains("信息") {
            return .search
        }
        return .chat
    }

    private func buildLocalReply(for content: String) -> String {
        let mode = detectedActionMode(for: content)
        switch mode {
        case .task:
            return "我已经把这句话整理成可执行待办，你也可以继续让我拆成 3 到 5 步。"
        case .search:
            return "我正在帮你搜资料，并会把要点整理成可直接继续追问的结论。"
        case .schedule:
            return "我已经把这句话理解成日程请求，接下来会帮你落到具体时间。"
        case .note:
            return "我会把这段内容当成笔记收进收集箱。"
        case .chat, .auto:
            return "我已经收到这条消息。你可以继续让我把它变成待办、日程、笔记，或者先搜索信息。"
        }
    }

    private func conciseTitle(from text: String, fallback: String = "新任务") -> String {
        let trimmed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.prefix(18))
        return prefix.isEmpty ? fallback : prefix
    }

    private func searchQuery(from text: String) -> String {
        let keywords = [
            "搜索", "查一下", "了解", "联网", "信息", "资料", "关于", "帮我找", "帮我看看"
        ]
        var cleaned = text
        for keyword in keywords {
            cleaned = cleaned.replacingOccurrences(of: keyword, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text : cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseScheduleIntent(from text: String) -> ScheduleDraft {
        let calendar = Calendar.current
        let now = Date()
        var targetDate = now
        var hour = max(calendar.component(.hour, from: now) + 1, 8)
        var minute = 0
        var duration = 60

        if text.contains("明天"), let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            targetDate = tomorrow
        } else if text.contains("后天"), let dayAfter = calendar.date(byAdding: .day, value: 2, to: now) {
            targetDate = dayAfter
        } else {
            targetDate = now
        }

        if let match = text.firstMatch(of: /(\d{1,2})[:点](\d{1,2})?/) {
            hour = Int(match.1) ?? hour
            minute = Int(match.2 ?? Substring("0")) ?? 0
        } else if text.contains("下午") || text.contains("晚上") {
            hour = min(hour + 6, 22)
        } else if text.contains("上午") {
            hour = min(hour, 11)
        }

        if text.contains("半小时") {
            duration = 30
        } else if text.contains("两小时") {
            duration = 120
        } else if text.contains("一小时") {
            duration = 60
        }

        let title = conciseTitle(from: text, fallback: "新日程")
        return ScheduleDraft(title: title, date: targetDate, hour: hour, minute: minute, duration: duration)
    }

    private func performWebSearch(query: String) async throws -> [WebSearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://duckduckgo.com/html/?q=\(encoded)") else {
            return []
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        let pattern = #"<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        return matches.prefix(5).compactMap { match in
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else { return nil }
            let urlString = String(html[urlRange]).replacingOccurrences(of: "&amp;", with: "&")
            let rawTitle = String(html[titleRange])
            let title = rawTitle
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return WebSearchResult(title: title, url: urlString)
        }
    }
}
