import Foundation
import AcMindKit

enum AgentMode: String, Hashable {
    case normal
    case task
    case quickAsk
    case toolCall
    case automation
}

@MainActor
class AgentViewModel: ObservableObject {
    struct ModelOption: Identifiable, Equatable {
        let id = UUID()
        let providerId: String
        let providerName: String
        let modelName: String

        var displayName: String {
            "\(providerName) · \(modelName)"
        }
    }

    @Published var inputText: String = ""
    @Published var recentItems: [SourceItem] = []
    @Published var availableModelOptions: [ModelOption] = []
    @Published var projectContextItems: [SecondarySidebarItem] = []
    @Published var selectedModelLabel: String = "未配置模型"
    @Published var selectedModelOption: ModelOption?
    @Published var distilledNote: DistilledNote?
    @Published var quickAskQuestion: String = ""
    @Published var quickAskAnswer: String?
    @Published var quickAskHistory: [ChatSession] = []
    @Published var quickAskMessages: [ChatMessage] = []
    @Published var selectedQuickAskSessionId: String?
    @Published var toolCallResult: String?
    @Published var isLoading: Bool = false
    @Published var isSaved: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    @Published var selectedMode: AgentMode = .normal
    @Published var agentTasks: [AgentTask] = []
    @Published var taskStatusFilter: AgentTaskStatus?
    @Published var currentTask: AgentTask?

    // MARK: - Voice
    @Published var recordingStatus: RecordingStatus = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastTranscript: String?

    private let storage: StorageServiceProtocol
    private let aiRuntime: AIRuntimeProtocol
    private let voiceService: VoiceServiceProtocol
    private let distillService: DistillServiceProtocol
    private let quickAskService: AgentQuickAskService
    private let agentToolRouter: AgentToolRouterProtocol
    private let agentMemoryService: AgentMemoryServiceProtocol
    private let agentSkillService: AgentSkillServiceProtocol
    private let agentTaskBoardService: AgentTaskBoardServiceProtocol

    private var recordingTimer: Timer?

    init(
        storage: StorageServiceProtocol? = nil,
        aiRuntime: AIRuntimeProtocol? = nil,
        voiceService: VoiceServiceProtocol? = nil
    ) {
        self.storage = storage ?? StorageService()
        self.aiRuntime = aiRuntime ?? AIRuntimeService()
        self.voiceService = voiceService ?? VoiceService()
        self.distillService = DistillService(aiRuntime: self.aiRuntime, storage: self.storage)
        self.agentMemoryService = AgentMemoryService(storage: self.storage)
        self.agentSkillService = AgentSkillService(storage: self.storage)
        self.agentTaskBoardService = AgentTaskBoardService(storage: self.storage)
        self.quickAskService = AgentQuickAskService(aiRuntime: self.aiRuntime, storage: self.storage)
        self.agentToolRouter = AgentToolRouter(storage: self.storage, voiceService: self.voiceService, aiRuntime: self.aiRuntime)

        Task {
            await setupVoiceStatusHandler()
        }
    }

    private func setupVoiceStatusHandler() async {
        await voiceService.setStatusHandler { [weak self] status in
            Task { @MainActor in
                self?.recordingStatus = status
                if status == .idle || status == .error {
                    self?.stopRecordingTimer()
                }
            }
        }
    }

    func loadRecentItems() async {
        do {
            let all = try await storage.listSourceItems(filter: nil)
            recentItems = Array(all.prefix(5))
        } catch {
            print("Failed to load recent items: \(error)")
        }
    }

    func loadDashboardData() async {
        async let recentTask = loadRecentItems()
        async let modelTask = loadAvailableModelOptions()
        async let projectTask = loadProjectContextItems()
        async let historyTask = loadQuickAskHistory()
        _ = await (recentTask, modelTask, projectTask, historyTask)
    }

    func loadQuickAskHistory() async {
        do {
            let sessions = try await storage.listChatSessions(status: nil)
            quickAskHistory = sessions
                .filter { $0.metadata["kind"] == "quickAsk" }
                .prefix(5)
                .map { $0 }

            if let selectedQuickAskSessionId,
               quickAskHistory.contains(where: { $0.id == selectedQuickAskSessionId }) {
                try await loadQuickAskMessages(sessionId: selectedQuickAskSessionId)
            } else if let latest = quickAskHistory.first {
                selectedQuickAskSessionId = latest.id
                try await loadQuickAskMessages(sessionId: latest.id)
            }
        } catch {
            print("Failed to load quick ask history: \(error)")
        }
    }

    func selectQuickAskHistory(_ session: ChatSession) async {
        selectedQuickAskSessionId = session.id
        do {
            try await loadQuickAskMessages(sessionId: session.id)
        } catch {
            errorMessage = "加载 Quick Ask 历史失败: \(error.localizedDescription)"
            showError = true
        }
    }

    func loadAvailableModelOptions() async {
        let providers = await aiRuntime.listProviders().filter { $0.enabled }
        let options = providers.map { provider in
            ModelOption(
                providerId: provider.id,
                providerName: provider.name.isEmpty ? provider.providerType.displayName : provider.name,
                modelName: provider.modelId.isEmpty ? "未配置模型" : provider.modelId
            )
        }

        availableModelOptions = options.isEmpty ? [
            ModelOption(providerId: "unconfigured", providerName: "AI", modelName: "未配置模型")
        ] : options

        if let selectedModelOption,
           availableModelOptions.contains(where: {
               $0.providerId == selectedModelOption.providerId && $0.modelName == selectedModelOption.modelName
           }) {
            selectedModelLabel = selectedModelOption.displayName
        } else {
            selectedModelOption = availableModelOptions.first
            selectedModelLabel = availableModelOptions.first?.displayName ?? "未配置模型"
        }
    }

    func selectModel(_ option: ModelOption) {
        selectedModelOption = option
        selectedModelLabel = option.displayName
    }

    var currentWorkspaceTitle: String {
        projectContextItems.first?.title ?? "默认工作区"
    }

    func loadProjectContextItems() async {
        do {
            let snapshots = try await WorkbenchProjectStore.loadProjects(from: storage)
            let items = snapshots.prefix(4).map { snapshot in
                SecondarySidebarItem(
                    id: snapshot.id,
                    title: snapshot.name,
                    icon: "folder",
                    badge: snapshot.noteCount > 0 ? "\(snapshot.noteCount)" : nil
                )
            }

            projectContextItems = items.isEmpty ? [
                SecondarySidebarItem(id: "empty", title: "暂无项目", icon: "folder", badge: nil)
            ] : Array(items)
        } catch {
            projectContextItems = [
                SecondarySidebarItem(id: "error", title: "项目加载失败", icon: "exclamationmark.triangle", badge: nil, isDisabled: true)
            ]
            print("Failed to load workbench projects: \(error)")
        }
    }

    func saveToInbox() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let item = SourceItem(
            type: .text,
            source: .manual,
            status: .captured,
            title: String(text.prefix(50)),
            previewText: text
        )
        do {
            try await storage.insertSourceItem(item)
            inputText = ""
            isSaved = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            isSaved = false
            await loadRecentItems()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            showError = true
            print("Failed to save: \(error)")
        }
    }

    func clear() {
        inputText = ""
        distilledNote = nil
        toolCallResult = nil
        currentTask = nil
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }

    func loadAgentTasks(filter: AgentTaskStatus? = nil) async {
        do {
            let taskFilter: TaskFilter? = filter.map { TaskFilter(statuses: [$0]) }
            agentTasks = try await agentTaskBoardService.listTasks(filter: taskFilter)
        } catch {
            errorMessage = "加载任务失败: \(error.localizedDescription)"
            showError = true
        }
    }

    func filterAgentTasks(by status: AgentTaskStatus?) {
        taskStatusFilter = status
        Task {
            await loadAgentTasks(filter: status)
        }
    }

    func distill() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        distilledNote = nil
        currentTask = nil

        var task: AgentTask?
        if selectedMode == .task {
            task = AgentTask(
                title: String(text.prefix(50)),
                description: text,
                status: .running
            )
            if let createdTaskInput = task {
                do {
                    let created = try await agentTaskBoardService.createTask(createdTaskInput)
                    currentTask = created
                    task = created
                } catch {
                    errorMessage = "创建任务失败: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                    return
                }
            }
        }

        var contextPrefix = ""
        do {
            let memoryContext = try await agentMemoryService.getMemoryContext(types: nil, query: text)
            if !memoryContext.isEmpty {
                contextPrefix = memoryContext.toPromptString()
            }
        } catch {
            print("获取记忆上下文失败: \(error)")
        }

        let enrichedText: String
        if contextPrefix.isEmpty {
            enrichedText = text
        } else {
            enrichedText = "[参考记忆]\n\(contextPrefix)\n\n[用户输入]\n\(text)"
        }

        let item = SourceItem(
            type: .text,
            source: .manual,
            status: .distilling,
            title: String(text.prefix(50)),
            previewText: enrichedText
        )

        do {
            try await storage.insertSourceItem(item)
            let note = try await distillService.distill(sourceItem: item)
            distilledNote = note

            let updatedItem = SourceItem(
                id: item.id,
                type: item.type,
                source: item.source,
                status: .distilled,
                title: item.title,
                contentPath: item.contentPath,
                previewText: item.previewText,
                createdAt: item.createdAt
            )
            try await storage.updateSourceItem(updatedItem)

            if let task {
                try? await agentTaskBoardService.completeTask(id: task.id)
                currentTask?.status = .completed
            }

            inputText = ""
            await loadRecentItems()
        } catch {
            errorMessage = "AI 整理失败: \(error.localizedDescription)"
            showError = true

            if let task {
                try? await agentTaskBoardService.failTask(id: task.id, error: error.localizedDescription)
                currentTask?.status = .failed
                currentTask?.errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func quickAsk() async {
        let question = quickAskQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        isLoading = true
        quickAskAnswer = nil

        do {
            let response = try await quickAskService.ask(
                question: question,
                providerId: selectedModelOption?.providerId == "unconfigured" ? nil : selectedModelOption?.providerId,
                model: selectedModelOption?.modelName.isEmpty == true ? nil : selectedModelOption?.modelName
            )

            quickAskAnswer = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            quickAskQuestion = ""
            await loadQuickAskHistory()
        } catch {
            errorMessage = "Quick Ask 失败: \(error.localizedDescription)"
            showError = true
        }

        isLoading = false
    }

    private func loadQuickAskMessages(sessionId: String) async throws {
        let messages = try await storage.listChatMessages(sessionId: sessionId)
        quickAskMessages = messages
    }

    func runToolAction(
        toolType: AgentToolType,
        action: String,
        parameters: [String: String] = [:],
        context: [String: String] = [:]
    ) async {
        isLoading = true
        toolCallResult = nil

        do {
            let result = try await agentToolRouter.routeTool(
                request: AgentToolRequest(
                    toolType: toolType,
                    action: action,
                    parameters: parameters,
                    context: context
                )
            )

            var outputParts: [String] = []
            if let output = result.output, output.isEmpty == false {
                outputParts.append(output)
            }
            if let errorMessage = result.errorMessage, errorMessage.isEmpty == false {
                outputParts.append(errorMessage)
            }
            toolCallResult = outputParts.isEmpty ? (result.success ? "执行完成" : "执行失败") : outputParts.joined(separator: "\n")
        } catch {
            errorMessage = "工具调用失败: \(error.localizedDescription)"
            showError = true
        }

        isLoading = false
    }

    // MARK: - Voice Control

    func toggleRecording() async {
        switch recordingStatus {
        case .idle, .error:
            await startRecording()
        case .recording:
            await stopRecording()
        case .processing:
            // 处理中，忽略
            break
        }
    }

    private func startRecording() async {
        do {
            try await voiceService.startRecording()
            startRecordingTimer()
        } catch {
            errorMessage = "开始录音失败: \(error.localizedDescription)"
            showError = true
            print("开始录音失败: \(error)")
        }
    }

    private func stopRecording() async {
        do {
            let sourceItemId = try await voiceService.stopRecording()
            stopRecordingTimer()

            // 等待转写完成并回填
            await waitForTranscription(sourceItemId: sourceItemId)
        } catch {
            errorMessage = "停止录音失败: \(error.localizedDescription)"
            showError = true
            print("停止录音失败: \(error)")
            stopRecordingTimer()
        }
    }

    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.recordingDuration += 1
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func waitForTranscription(sourceItemId: String) async {
        // 轮询等待转写完成
        var attempts = 0
        let maxAttempts = 30 // 最多等待 30 秒

        while attempts < maxAttempts {
            do {
                if let item = try await storage.getSourceItem(id: sourceItemId) {
                    if let transcript = item.transcript {
                        // 转写完成，回填到输入框
                        await MainActor.run {
                            self.inputText = transcript
                            self.lastTranscript = transcript
                        }
                        return
                    }
                    if item.status == .deleted {
                        print("转写出错")
                        return
                    }
                }
            } catch {
                print("获取 SourceItem 失败: \(error)")
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待 1 秒
            attempts += 1
        }

        print("等待转写超时")
    }

    // MARK: - Private Helpers

    private func extractTitle(from text: String) -> String {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        return String(firstLine.prefix(40))
    }

    private func extractTags(from text: String) -> [String] {
        var tags: [String] = ["手动记录"]
        if text.count > 100 { tags.append("长文本") }
        if text.contains("http") || text.contains("www.") { tags.append("链接") }
        return tags
    }

    private func formatDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }
}
