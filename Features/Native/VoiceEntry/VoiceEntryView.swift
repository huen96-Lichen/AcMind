import SwiftUI
import AcMindKit

struct VoiceEntryView: View {
    @StateObject private var viewModel = VoiceEntryViewModel()
    @State private var selectedSection: VoiceSection = .recording

    enum VoiceSection: String, CaseIterable, Identifiable {
        case recording = "录音"
        case transcription = "转写"
        case shortcut = "快捷键"
        case permission = "权限"
        case model = "模型"
        case history = "历史记录"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .recording: return "mic.fill"
            case .transcription: return "text.quote"
            case .shortcut: return "keyboard"
            case .permission: return "lock.shield"
            case .model: return "cpu"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }

    var body: some View {
        HSplitView {
            secondarySidebar
                .frame(width: 200)

            mainContent
        }
        .background(AppSurfaceTokens.background)
    }

    private var secondarySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("语音入口")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            List(VoiceSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader
                sectionContent
            }
            .padding(24)
            .frame(maxWidth: 700, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sectionHeader: some View {
        HStack {
            Image(systemName: selectedSection.icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(selectedSection.rawValue)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .recording:
            recordingSection
        case .transcription:
            transcriptionSection
        case .shortcut:
            shortcutSection
        case .permission:
            permissionSection
        case .model:
            modelSection
        case .history:
            historySection
        }
    }

    private var recordingSection: some View {
        VStack(spacing: 24) {
            recordingStatusCard
            waveformView
            controlButtons
        }
    }

    private var recordingStatusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red.opacity(0.2) : AppSurfaceTokens.cardBackgroundSoft)
                    .frame(width: 120, height: 120)

                Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 48))
                    .foregroundStyle(viewModel.isRecording ? .red : .secondary)
            }

            Text(viewModel.isRecording ? "录音中..." : "准备录音")
                .font(.headline)

            if viewModel.isRecording {
                Text(formatTime(viewModel.recordingDuration))
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(16)
    }

    private var waveformView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("波形")
                .font(.headline)

            HStack(spacing: 2) {
                ForEach(0..<50, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(viewModel.isRecording ? Double.random(in: 0.3...1.0) : 0.1))
                        .frame(width: 4, height: CGFloat(viewModel.isRecording ? Int.random(in: 10...60) : 10))
                }
            }
            .frame(height: 60)
        }
        .padding(16)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                viewModel.toggleRecording()
            }) {
                Label(viewModel.isRecording ? "停止录音" : "开始录音", systemImage: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRecording ? .red : .accentColor)

            Button(action: {
                viewModel.sendToAgent()
            }) {
                Label("发送到 Agent", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasRecording)

            Button(action: {
                viewModel.saveToInbox()
            }) {
                Label("保存到收集箱", systemImage: "tray")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasRecording)
        }
    }

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("转写结果")
                .font(.headline)

            if viewModel.transcriptionResult.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.quote")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("暂无转写结果")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("录音完成后将自动转写")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)
            } else {
                Text(viewModel.transcriptionResult)
                    .font(.body)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppSurfaceTokens.cardBackgroundSoft)
                    .cornerRadius(12)
            }
        }
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快捷键设置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                shortcutRow(name: "开始/停止录音", shortcut: "⌘ + Shift + R")
                shortcutRow(name: "发送到 Agent", shortcut: "⌘ + Enter")
                shortcutRow(name: "保存到收集箱", shortcut: "⌘ + S")
            }
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private func shortcutRow(name: String, shortcut: String) -> some View {
        HStack {
            Text(name)
                .font(.body)
            Spacer()
            Text(shortcut)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(6)
        }
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(8)
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("权限状态")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(name: "麦克风权限", status: viewModel.microphonePermission)
                permissionRow(name: "辅助功能权限", status: viewModel.accessibilityPermission)
            }
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private func permissionRow(name: String, status: String) -> some View {
        HStack {
            Text(name)
                .font(.body)
            Spacer()
            Text(status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(status == "已授权" ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .foregroundStyle(status == "已授权" ? .green : .orange)
                .cornerRadius(6)
        }
        .padding(12)
        .background(AppSurfaceTokens.cardBackground)
        .cornerRadius(8)
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("语音模型")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                modelRow(name: "Whisper", description: "OpenAI 语音识别模型", isSelected: true)
                modelRow(name: "系统语音识别", description: "macOS 内置语音识别", isSelected: false)
            }
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private func modelRow(name: String, description: String, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(AppSurfaceTokens.secondarySidebarBackground)
        .cornerRadius(8)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("历史记录")
                .font(.headline)

            if viewModel.recordingHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("暂无录音历史")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)
            } else {
                ForEach(viewModel.recordingHistory) { record in
                    historyRow(record: record)
                }
            }
        }
    }

    private func historyRow(record: RecordingRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.body)
                Text(record.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.duration)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(8)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RecordingRecord: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let duration: String
}

@MainActor
class VoiceEntryViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasRecording = false
    @Published var transcriptionResult = ""
    @Published var microphonePermission = "已授权"
    @Published var accessibilityPermission = "未授权"
    @Published var recordingHistory: [RecordingRecord] = []

    private var timer: Timer?
    private var lastSourceItemId: String?
    private let storage: StorageServiceProtocol
    private let voiceService: VoiceServiceProtocol

    init(
        storage: StorageServiceProtocol? = nil,
        voiceService: VoiceServiceProtocol? = nil
    ) {
        let container = ServiceContainer.isInitialized() ? ServiceContainer.shared : nil
        self.storage = storage ?? container?.storageService ?? StorageService()
        self.voiceService = voiceService ?? container?.voiceService ?? VoiceService()

        Task {
            await loadRecordingHistory()
            await installStatusHandler()
        }
    }

    func toggleRecording() {
        Task {
            if isRecording {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }

    private func startRecording() async {
        do {
            try await voiceService.startRecording()
            startTimer()
        } catch {
            print("VoiceEntry start recording failed: \(error)")
        }
    }

    private func stopRecording() async {
        do {
            let sourceItemId = try await voiceService.stopRecording()
            stopTimer()
            lastSourceItemId = sourceItemId
            await waitForTranscription(sourceItemId: sourceItemId)
            hasRecording = true
            await loadRecordingHistory()
        } catch {
            print("VoiceEntry stop recording failed: \(error)")
            stopTimer()
        }
    }

    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func sendToAgent() {
        let text = transcriptionResult.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }

        NotificationCenter.default.post(name: Notification.Name("AcMind.captureText"), object: text)
        NotificationCenter.default.post(name: .companionShowAgent, object: nil)
    }

    func saveToInbox() {
        let text = transcriptionResult.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }

        NotificationCenter.default.post(name: Notification.Name("AcMind.captureText"), object: text)
        NotificationCenter.default.post(name: .companionShowInbox, object: nil)
    }

    private func installStatusHandler() async {
        if let service = voiceService as? VoiceService {
            await service.setStatusHandler { [weak self] status in
                Task { @MainActor in
                    self?.isRecording = status == .recording
                    if status == .idle || status == .error {
                        self?.stopTimer()
                    }
                }
            }
        }
    }

    private func waitForTranscription(sourceItemId: String) async {
        var attempts = 0
        let maxAttempts = 30

        while attempts < maxAttempts {
            do {
                if let item = try await storage.getSourceItem(id: sourceItemId),
                   let transcript = item.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
                   transcript.isEmpty == false {
                    transcriptionResult = transcript
                    return
                }
            } catch {
                print("VoiceEntry transcription poll failed: \(error)")
            }

            attempts += 1
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        if let item = try? await storage.getSourceItem(id: sourceItemId) {
            transcriptionResult = item.transcript?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? item.previewText
                ?? transcriptionResult
        }
    }

    private func loadRecordingHistory() async {
        do {
            let all = try await storage.listSourceItems(filter: nil)
            recordingHistory = all
                .filter { $0.source == .voice && $0.type == .audio }
                .sorted(by: { $0.createdAt > $1.createdAt })
                .prefix(8)
                .map { item in
                    RecordingRecord(
                        title: item.title ?? "语音记录",
                        date: Self.formatDate(item.createdAt),
                        duration: Self.formatDuration(from: item.metadata["duration"]) ?? (item.previewText ?? "录音")
                    )
                }
        } catch {
            print("VoiceEntry load history failed: \(error)")
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private static func formatDuration(from secondsString: String?) -> String? {
        guard let secondsString,
              let seconds = Double(secondsString) else { return nil }
        let minutes = Int(seconds) / 60
        let remaining = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remaining)
    }
}
