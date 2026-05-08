import Foundation
import AcMindKit

typealias StepStatus = StepStatus
typealias TaskStep = TaskStep
typealias AgentToolType = AgentToolType
typealias AgentToolResult = AgentToolResult
typealias MemoryContext = MemoryContext
typealias SkillContext = SkillContext
typealias AgentSkill = AgentSkill
typealias TaskBoard = TaskBoard
typealias AgentTask = AgentTask
typealias ModelRoute = ModelRoute
typealias ModelRouteRequest = ModelRouteRequest
typealias CurrentSessionUsage = CurrentSessionUsage
typealias AgentToolInfo = AgentToolInfo
typealias AgentMemoryService = AgentMemoryService
typealias AgentSkillService = AgentSkillService
typealias AgentTaskBoardService = AgentTaskBoardService
typealias AgentToolRouter = AgentToolRouter
typealias AgentModelRouter = AgentModelRouter
typealias MemoryType = MemoryType
typealias AgentMemory = AgentMemory
typealias ModelUsage = ModelUsage
typealias AgentToolRequest = AgentToolRequest

// MARK: - Enhanced Agent Message Model

enum AgentMessageRole: String, Sendable {
    case user
    case assistant
    case system
    case companion
    case executionStep
    case toolResult
    case confirmation
}

struct AgentMessage: Identifiable, Sendable {
    let id: UUID
    let role: AgentMessageRole
    let text: String
    let timestamp: Date
    var isLoading: Bool = false
    var distilledNote: DistilledNote? = nil
    var sourceItem: SourceItem? = nil
    var statusText: String? = nil
    var executionStep: ExecutionStepDisplay? = nil
    var toolResult: ToolResultDisplay? = nil
    var confirmation: ConfirmationDisplay? = nil

    init(
        id: UUID = UUID(),
        role: AgentMessageRole,
        text: String,
        timestamp: Date = Date(),
        isLoading: Bool = false,
        distilledNote: DistilledNote? = nil,
        sourceItem: SourceItem? = nil,
        statusText: String? = nil,
        executionStep: ExecutionStepDisplay? = nil,
        toolResult: ToolResultDisplay? = nil,
        confirmation: ConfirmationDisplay? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.isLoading = isLoading
        self.distilledNote = distilledNote
        self.sourceItem = sourceItem
        self.statusText = statusText
        self.executionStep = executionStep
        self.toolResult = toolResult
        self.confirmation = confirmation
    }
}

// MARK: - Execution Step Display

struct ExecutionStepDisplay: Identifiable, Sendable {
    let id: UUID
    let stepTitle: String
    let status: StepStatus
    let toolName: String?
    let duration: String?
    let result: String?

    init(
        id: UUID = UUID(),
        stepTitle: String,
        status: StepStatus,
        toolName: String? = nil,
        duration: String? = nil,
        result: String? = nil
    ) {
        self.id = id
        self.stepTitle = stepTitle
        self.status = status
        self.toolName = toolName
        self.duration = duration
        self.result = result
    }

    init(from step: TaskStep) {
        self.id = UUID()
        self.stepTitle = step.title
        self.status = step.status
        self.toolName = step.toolCall?.toolName
        if let ms = step.toolCall?.durationMs {
            self.duration = "\(ms)ms"
        } else {
            self.duration = nil
        }
        self.result = step.result
    }
}

// MARK: - Tool Result Display

struct ToolResultDisplay: Identifiable, Sendable {
    let id: UUID
    let toolName: String
    let toolType: AgentToolType
    let success: Bool
    let output: String?
    let error: String?
    let duration: String?

    init(
        id: UUID = UUID(),
        toolName: String,
        toolType: AgentToolType,
        success: Bool,
        output: String? = nil,
        error: String? = nil,
        duration: String? = nil
    ) {
        self.id = id
        self.toolName = toolName
        self.toolType = toolType
        self.success = success
        self.output = output
        self.error = error
        self.duration = duration
    }

    init(from result: AgentToolResult) {
        self.id = UUID()
        self.toolName = result.action
        self.toolType = result.toolType
        self.success = result.success
        self.output = result.output
        self.error = result.errorMessage
        self.duration = "\(result.durationMs)ms"
    }
}

// MARK: - Confirmation Display

struct ConfirmationDisplay: Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let actionLabel: String
    let cancelLabel: String
    var isPending: Bool = true

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        actionLabel: String = "确认",
        cancelLabel: String = "取消",
        isPending: Bool = true
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.actionLabel = actionLabel
        self.cancelLabel = cancelLabel
        self.isPending = isPending
    }
}

// MARK: - Enhanced AgentViewModel

@MainActor
class AgentViewModel: ObservableObject {
    // MARK: - Basic State
    @Published var inputText: String = ""
    @Published var messages: [AgentMessage] = []
    @Published var isLoading: Bool = false
    @Published var distilledNote: DistilledNote?
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // MARK: - Voice
    @Published var recordingStatus: RecordingStatus = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastTranscript: String?

    // MARK: - Three-Column Layout State
    @Published var selectedTab: AgentLeftTab = .sessions
    @Published var currentSession: ChatSession?
    @Published var currentGoal: String = ""

    // MARK: - Memory & Skill
    @Published var memoryContext: MemoryContext = MemoryContext()
    @Published var skillContext: SkillContext = SkillContext()
    @Published var activeSkills: [AgentSkill] = []

    // MARK: - Task Board
    @Published var taskBoard: TaskBoard = TaskBoard()
    @Published var currentTask: AgentTask?
    @Published var activeSteps: [ExecutionStepDisplay] = []

    // MARK: - Model & Usage
    @Published var currentRoute: ModelRoute?
    @Published var sessionUsage: CurrentSessionUsage = CurrentSessionUsage()
    @Published var availableTools: [AgentToolInfo] = AgentToolInfo.defaultTools

    // MARK: - Services
    private let storage: StorageServiceProtocol
    private let aiRuntime: AIRuntimeProtocol
    private let voiceService: VoiceServiceProtocol
    private let memoryService: AgentMemoryService
    private let skillService: AgentSkillService
    private let taskBoardService: AgentTaskBoardService
    private let toolRouter: AgentToolRouter
    private let modelRouter: AgentModelRouter

    private var recordingTimer: Timer?

    // MARK: - Initialization

    init(
        storage: StorageServiceProtocol? = nil,
        aiRuntime: AIRuntimeProtocol? = nil,
        voiceService: VoiceServiceProtocol? = nil
    ) {
        let container = ServiceContainer.isInitialized() ? ServiceContainer.shared : nil
        self.storage = storage ?? container?.storageService ?? StorageService()
        self.aiRuntime = aiRuntime ?? container?.aiRuntime ?? AIRuntimeService()
        self.voiceService = voiceService ?? container?.voiceService ?? VoiceService()
        self.memoryService = AgentMemoryService(storage: self.storage)
        self.skillService = AgentSkillService(storage: self.storage)
        self.taskBoardService = AgentTaskBoardService(storage: self.storage)
        self.toolRouter = AgentToolRouter(storage: self.storage)
        self.modelRouter = AgentModelRouter()

        Task {
            await initializeAgent()
        }
    }

    private func initializeAgent() async {
        do {
            try await skillService.initializeBuiltinSkills()
            await loadContexts()
            await loadTaskBoard()
            await updateAvailableTools()
        } catch {
            print("Agent 初始化失败: \(error)")
        }
    }

    // MARK: - Context Loading

    func loadContexts() async {
        do {
            memoryContext = try await memoryService.getMemoryContext(types: nil, query: nil)
            skillContext = try await skillService.getSkillContext(taskDescription: nil)
            activeSkills = skillContext.skills
        } catch {
            print("加载上下文失败: \(error)")
        }
    }

    func loadTaskBoard() async {
        do {
            let tasks = try await taskBoardService.listTasks(filter: nil)
            taskBoard = TaskBoard(tasks: tasks)
        } catch {
            print("加载任务看板失败: \(error)")
        }
    }

    func updateAvailableTools() async {
        availableTools = await toolRouter.getAvailableTools()
    }

    // MARK: - Memory Operations

    func saveMemory(type: MemoryType, key: String, value: String, tags: [String] = []) async {
        let memory = AgentMemory(type: type, key: key, value: value, tags: tags)
        do {
            try await memoryService.saveMemory(memory)
            await loadContexts()
        } catch {
            print("保存记忆失败: \(error)")
        }
    }

    func searchMemory(query: String) async {
        do {
            memoryContext = try await memoryService.getMemoryContext(types: nil, query: query)
        } catch {
            print("搜索记忆失败: \(error)")
        }
    }

    // MARK: - Skill Operations

    func enableSkill(_ skill: AgentSkill) async {
        var updated = skill
        updated.status = .active
        do {
            try await skillService.updateSkill(updated)
            await loadContexts()
        } catch {
            print("启用技能失败: \(error)")
        }
    }

    func disableSkill(_ skill: AgentSkill) async {
        var updated = skill
        updated.status = .disabled
        do {
            try await skillService.updateSkill(updated)
            await loadContexts()
        } catch {
            print("禁用技能失败: \(error)")
        }
    }

    // MARK: - Task Operations

    func createTask(title: String, description: String = "", priority: TaskPriority = .medium) async -> AgentTask? {
        let task = AgentTask(
            title: title,
            description: description,
            priority: priority
        )
        do {
            let created = try await taskBoardService.createTask(task)
            await loadTaskBoard()
            return created
        } catch {
            print("创建任务失败: \(error)")
            return nil
        }
    }

    func startTask(_ task: AgentTask) async {
        do {
            try await taskBoardService.startTask(id: task.id)
            await loadTaskBoard()
        } catch {
            print("启动任务失败: \(error)")
        }
    }

    func completeTask(_ task: AgentTask) async {
        do {
            try await taskBoardService.completeTask(id: task.id)
            await loadTaskBoard()
        } catch {
            print("完成任务失败: \(error)")
        }
    }

    // MARK: - Model Routing

    func routeModel(for request: ModelRouteRequest) async {
        do {
            currentRoute = try await modelRouter.route(request: request)
        } catch {
            print("模型路由失败: \(error)")
        }
    }

    func recordUsage(_ usage: ModelUsage) async {
        await modelRouter.recordUsage(usage)
        sessionUsage = await modelRouter.getCurrentSessionUsage()
    }

    // MARK: - Tool Execution

    func executeTool(request: AgentToolRequest) async {
        do {
            let result = try await toolRouter.routeTool(request: request)

            let toolMsg = AgentMessage(
                role: .toolResult,
                text: result.success ? (result.output ?? "完成") : (result.errorMessage ?? "失败"),
                toolResult: ToolResultDisplay(from: result)
            )
            messages.append(toolMsg)

            if !result.success {
                errorMessage = result.errorMessage
                showError = true
            }
        } catch {
            let errMsg = AgentMessage(role: .system, text: "工具执行失败: \(error.localizedDescription)")
            messages.append(errMsg)
        }
    }

    // MARK: - Enhanced Message Handling

    func addExecutionStep(_ step: TaskStep) {
        let display = ExecutionStepDisplay(from: step)
        activeSteps.append(display)

        let msg = AgentMessage(
            role: .executionStep,
            text: step.title,
            executionStep: display
        )
        messages.append(msg)
    }

    func updateExecutionStep(_ step: TaskStep) {
        if let index = activeSteps.firstIndex(where: { $0.stepTitle == step.title }) {
            activeSteps[index] = ExecutionStepDisplay(from: step)
        }

        if let msgIndex = messages.lastIndex(where: {
            $0.role == .executionStep && $0.executionStep?.stepTitle == step.title
        }) {
            messages[msgIndex] = AgentMessage(
                id: messages[msgIndex].id,
                role: .executionStep,
                text: step.title,
                timestamp: messages[msgIndex].timestamp,
                executionStep: ExecutionStepDisplay(from: step)
            )
        }
    }

    func requestConfirmation(title: String, description: String, actionLabel: String = "确认") {
        let confirmation = ConfirmationDisplay(
            title: title,
            description: description,
            actionLabel: actionLabel
        )
        let msg = AgentMessage(
            role: .confirmation,
            text: description,
            confirmation: confirmation
        )
        messages.append(msg)
    }

    func confirmAction(messageId: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var updated = messages[index]
            if var conf = updated.confirmation {
                conf.isPending = false
            }
            messages[index] = updated
        }
    }

    // MARK: - Voice Control (Preserved)

    func toggleRecording() async {
        switch recordingStatus {
        case .idle, .error:
            await startRecording()
        case .recording:
            await stopRecording()
        case .processing:
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
        }
    }

    private func stopRecording() async {
        do {
            let sourceItemId = try await voiceService.stopRecording()
            stopRecordingTimer()
            await waitForTranscription(sourceItemId: sourceItemId)
        } catch {
            errorMessage = "停止录音失败: \(error.localizedDescription)"
            showError = true
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
        var attempts = 0
        let maxAttempts = 30

        while attempts < maxAttempts {
            do {
                if let item = try await storage.getSourceItem(id: sourceItemId) {
                    if let transcript = item.transcript {
                        await MainActor.run {
                            self.inputText = transcript
                            self.lastTranscript = transcript
                            let msg = AgentMessage(
                                role: .user,
                                text: transcript,
                                statusText: "语音转写"
                            )
                            self.messages.append(msg)
                        }
                        return
                    }
                }
            } catch {
                print("获取 SourceItem 失败: \(error)")
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            attempts += 1
        }
    }

    // MARK: - Basic Operations (Preserved)

    func saveToInbox() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMsg = AgentMessage(role: .user, text: text)
        messages.append(userMsg)
        inputText = ""

        let item = SourceItem(
            type: .text,
            source: .manual,
            status: .captured,
            title: String(text.prefix(50)),
            previewText: text
        )
        do {
            try await storage.insertSourceItem(item)

            let sysMsg = AgentMessage(
                role: .system,
                text: "已保存到收集箱",
                sourceItem: item
            )
            messages.append(sysMsg)
        } catch {
            let errMsg = AgentMessage(
                role: .system,
                text: "保存失败: \(error.localizedDescription)"
            )
            messages.append(errMsg)
            errorMessage = "保存失败: \(error.localizedDescription)"
            showError = true
        }
    }

    func distill() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMsg = AgentMessage(role: .user, text: text)
        messages.append(userMsg)
        inputText = ""

        isLoading = true
        distilledNote = nil
        errorMessage = nil
        showError = false

        let loadingMsg = AgentMessage(role: .assistant, text: "正在整理...", isLoading: true)
        messages.append(loadingMsg)

        let item = SourceItem(
            type: .text,
            source: .manual,
            status: .distilling,
            title: String(text.prefix(50)),
            previewText: text
        )
        do {
            try await storage.insertSourceItem(item)
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            showError = true
            isLoading = false
            return
        }

        do {
            let routeRequest = ModelRouteRequest(
                taskType: .textSummarize,
                inputLength: text.count
            )
            await routeModel(for: routeRequest)

            let note = try await aiRuntime.runDistillation(sourceItem: item)

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

            distilledNote = note
            isLoading = false

            if let idx = messages.lastIndex(where: { $0.isLoading }) {
                messages[idx] = AgentMessage(
                    role: .assistant,
                    text: note.summary ?? "",
                    distilledNote: note,
                    sourceItem: updatedItem
                )
            }
        } catch {
            errorMessage = "AI 整理失败: \(error.localizedDescription)"
            showError = true
            isLoading = false

            if let idx = messages.lastIndex(where: { $0.isLoading }) {
                messages.remove(at: idx)
            }
        }
    }

    func clear() {
        inputText = ""
        messages.removeAll()
        activeSteps.removeAll()
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}

// MARK: - Agent Left Tab

enum AgentLeftTab: String, CaseIterable, Identifiable {
    case sessions = "会话"
    case tasks = "任务"
    case skills = "技能"
    case goals = "目标"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sessions: return "bubble.left.and.bubble.right"
        case .tasks: return "checklist"
        case .skills: return "wand.and.stars"
        case .goals: return "target"
        }
    }
}

// MARK: - Companion Transcription (Preserved)

extension AgentViewModel {
    var hasCompanionTranscription: Bool {
        companionTranscription != nil
    }

    var companionTranscription: CompanionVoiceTranscription? {
        get { _companionTranscription }
        set { _companionTranscription = newValue }
    }

    private var _companionTranscription: CompanionVoiceTranscription? {
        get { objc_getAssociatedObject(self, &companionTranscriptionKey) as? CompanionVoiceTranscription }
        set { objc_setAssociatedObject(self, &companionTranscriptionKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    func receiveCompanionTranscription(_ transcription: CompanionVoiceTranscription) {
        companionTranscription = transcription
    }

    func dismissCompanionTranscription() {
        companionTranscription = nil
    }

    func useCompanionTranscription() {
        if let transcription = companionTranscription {
            inputText = transcription.text
            companionTranscription = nil
        }
    }

    func saveCompanionToInbox() {
        if let transcription = companionTranscription {
            inputText = transcription.text
            Task {
                await saveToInbox()
            }
            companionTranscription = nil
        }
    }

    func createScheduleFromTranscription() {
        companionTranscription = nil
    }
}

nonisolated(unsafe) private var companionTranscriptionKey: UInt8 = 0
