import Foundation
import AcMindKit

@MainActor
class AgentViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var recentItems: [SourceItem] = []
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

    func mockDistill() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        distilledNote = nil

        // 先保存到 Inbox
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
            print("Failed to save: \(error)")
        }

        // Mock AI 整理
        try? await Task.sleep(nanoseconds: 800_000_000)

        let note = DistilledNote(
            sourceItemId: item.id,
            title: extractTitle(from: text),
            summary: "这是对「\(String(text.prefix(30)))」的 AI 整理摘要。\n\n核心要点已提取，标签已自动生成。",
            tags: extractTags(from: text),
            contentMarkdown: "## \(extractTitle(from: text))\n\n\(text)\n\n---\n\n### 摘要\n\n这是 Mock AI 生成的摘要内容。后续将替换为真实 AI 蒸馏结果。\n\n### 关键信息\n\n- 来源：手动输入\n- 时间：\(formatDate())\n- 状态：已整理\n"
        )

        // 更新 SourceItem 状态
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
        try? await storage.updateSourceItem(updatedItem)

        distilledNote = note
        inputText = ""
        isLoading = false
        await loadRecentItems()
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
        await mockDistill()
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
