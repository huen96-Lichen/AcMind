import Foundation
import AcMindKit

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
    @Published var distilledNote: DistilledNote?
    @Published var isLoading: Bool = false
    @Published var isSaved: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // MARK: - Voice
    @Published var recordingStatus: RecordingStatus = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastTranscript: String?

    private let storage: StorageServiceProtocol
    private let aiRuntime: AIRuntimeProtocol
    private let voiceService: VoiceServiceProtocol
    private let distillService: DistillServiceProtocol

    private var recordingTimer: Timer?

    init(
        storage: StorageServiceProtocol? = nil,
        aiRuntime: AIRuntimeProtocol? = nil,
        voiceService: VoiceServiceProtocol? = nil
    ) {
        let container = ServiceContainer.isInitialized() ? ServiceContainer.shared : nil
        self.storage = storage ?? container?.storageService ?? StorageService()
        self.aiRuntime = aiRuntime ?? container?.aiRuntime ?? AIRuntimeService()
        self.voiceService = voiceService ?? container?.voiceService ?? VoiceService()
        self.distillService = container?.distillService ?? DistillService()

        // 设置状态回调
        Task {
            await setupVoiceStatusHandler()
        }
    }

    private func setupVoiceStatusHandler() async {
        if let service = voiceService as? VoiceService {
            await service.setStatusHandler { [weak self] status in
                Task { @MainActor in
                    self?.recordingStatus = status
                    if status == .idle || status == .error {
                        self?.stopRecordingTimer()
                    }
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
        _ = await (recentTask, modelTask, projectTask)
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

        if selectedModelLabel == "未配置模型" || !availableModelOptions.contains(where: { $0.displayName == selectedModelLabel }) {
            selectedModelLabel = availableModelOptions.first?.displayName ?? "未配置模型"
        }
    }

    func selectModel(_ option: ModelOption) {
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
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }

    func distill() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        distilledNote = nil

        let item = SourceItem(
            type: .text,
            source: .manual,
            status: .distilling,
            title: String(text.prefix(50)),
            previewText: text
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

            inputText = ""
            await loadRecentItems()
        } catch {
            errorMessage = "AI 整理失败: \(error.localizedDescription)"
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
