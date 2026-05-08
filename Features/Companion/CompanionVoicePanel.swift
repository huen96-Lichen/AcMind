import SwiftUI
import AppKit
import AcMindKit

// MARK: - Companion Voice Panel
// 随身语音面板 - 连接真实 VoiceService

struct CompanionVoicePanel: View {
    @StateObject private var viewModel = CompanionVoiceViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            header

            Divider()

            // 主内容
            VStack(spacing: 20) {
                // 录音控制区
                recordingControl

                // 状态显示
                statusDisplay

                // 转写结果
                if viewModel.transcriptionText.isEmpty == false {
                    transcriptionResult
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(width: 480, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("随身语音")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(viewModel.statusColor)
            }

            Spacer()

            if viewModel.recordingStatus == .recording {
                Text(viewModel.elapsedTimeFormatted)
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(Color.red)
                    .padding(.trailing, 8)
            }

            Button(action: { viewModel.stopAndDismiss { dismiss() } }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }

    // MARK: - Recording Control

    private var recordingControl: some View {
        ZStack {
            Circle()
                .fill(viewModel.recordingStatus == .recording ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.1))
                .frame(width: 100, height: 100)

            if viewModel.recordingStatus == .recording {
                // 录音中动画 - 脉动红点
                Circle()
                    .fill(Color.red)
                    .frame(width: 40, height: 40)
                    .scaleEffect(viewModel.isRecording ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.isRecording)
            } else {
                Button(action: { viewModel.toggleRecording() }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.recordingStatus == .processing)
            }
        }
        .onTapGesture {
            viewModel.toggleRecording()
        }
    }

    // MARK: - Status Display

    private var statusDisplay: some View {
        VStack(spacing: 8) {
            if viewModel.recordingStatus == .recording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Text("正在录音...")
                        .font(.body)
                        .foregroundStyle(Color.secondary)

                    Text(viewModel.elapsedTimeFormatted)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(Color.primary)
                }
            } else if viewModel.recordingStatus == .processing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)

                    Text("正在转写...")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                }
            } else if let error = viewModel.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                        .font(.caption)

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
            } else {
                Text("点击麦克风按钮开始录音")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - Transcription Result

    private var transcriptionResult: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundStyle(Color.secondary)
                    .font(.caption)

                Text("转写结果")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)

                Spacer()

                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.transcriptionText, forType: .string)
                    ToastManager.shared.show(.success, "已复制到剪贴板")
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }

            ScrollView {
                Text(viewModel.transcriptionText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(12)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(10)
        }
    }
}

// MARK: - View Model

@MainActor
final class CompanionVoiceViewModel: ObservableObject {
    @Published var recordingStatus: RecordingStatus = .idle
    @Published var transcriptionText: String = ""
    @Published var errorMessage: String?
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRecording = false

    private var voiceService: (any VoiceServiceProtocol)? {
        ServiceContainer.shared.voiceService
    }
    private var timer: Timer?

    var elapsedTimeFormatted: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var statusText: String {
        switch recordingStatus {
        case .idle: return "准备就绪"
        case .recording: return "录音中"
        case .processing: return "转写中"
        case .error: return "出错了"
        }
    }

    var statusColor: Color {
        switch recordingStatus {
        case .idle: return Color.secondary
        case .recording: return Color.red
        case .processing: return Color.orange
        case .error: return Color.red
        }
    }

    func toggleRecording() {
        if recordingStatus == .recording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard let service = voiceService else {
            errorMessage = "语音服务未就绪"
            ToastManager.shared.show(.error, "语音服务未就绪")
            return
        }

        errorMessage = nil
        transcriptionText = ""

        Task {
            do {
                try await service.startRecording()
                recordingStatus = .recording
                isRecording = true
                elapsedTime = 0
                startTimer()

                // 同步状态到胶囊（麦克风图标高亮）
                NotificationCenter.default.post(
                    name: .companionVoiceRecordingStarted,
                    object: nil
                )

                ToastManager.shared.show(.info, "录音已开始")
            } catch let error as VoiceError {
                if case .permissionDenied = error {
                    errorMessage = "需要麦克风权限，请在系统设置中授权"
                } else {
                    errorMessage = error.localizedDescription
                }
                ToastManager.shared.show(.error, error.localizedDescription)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func stopRecording() {
        guard let service = voiceService else { return }

        stopTimer()
        recordingStatus = .processing

        Task {
            do {
                _ = try await service.stopRecording()
                recordingStatus = .idle
                isRecording = false

                NotificationCenter.default.post(
                    name: .companionVoiceRecordingStopped,
                    object: nil
                )

                ToastManager.shared.show(.success, "录音已保存")
                await loadRecentTranscription()
            } catch {
                errorMessage = error.localizedDescription
                recordingStatus = .idle
                isRecording = false
                ToastManager.shared.show(.error, error.localizedDescription)
            }
        }
    }

    func stopAndDismiss(onDismiss: @escaping () -> Void) {
        if recordingStatus == .recording {
            stopRecording()
        }
        onDismiss()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedTime += 0.1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func loadRecentTranscription() async {
        do {
            let storage = ServiceContainer.shared.storageService
            let items = try await storage.listSourceItems(
                filter: SourceItemFilter(type: SourceType.audio, limit: 1)
            )
            if let latest = items.first, let transcript = latest.transcript {
                transcriptionText = transcript
                let duration = latest.metadata["duration"].flatMap(Double.init) ?? 0
                NotificationCenter.default.post(
                    name: .companionSendToAgent,
                    object: nil,
                    userInfo: [
                        "transcription": CompanionVoiceTranscription(
                            text: transcript,
                            timestamp: latest.createdAt,
                            duration: duration
                        )
                    ]
                )
            } else if let preview = items.first?.previewText {
                transcriptionText = preview
            }
        } catch {
            print("⚠️ 加载转写结果失败: \(error)")
        }
    }
}
