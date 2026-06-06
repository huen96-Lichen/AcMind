import SwiftUI
import AppKit
import AcMindKit

struct CompanionVoicePanel: View {
    @StateObject private var viewModel = CompanionVoicePanelViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(spacing: 18) {
                statusChip
                transcriptCard
                actionRow
            }
            .padding(20)
        }
        .frame(width: 500, height: 280)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppSurfaceTokens.background)
                .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        )
        .padding(12)
        .onAppear {
            Task { await viewModel.prepare() }
        }
        .onDisappear {
            Task { await viewModel.cleanupIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionVoiceFinishRequested)) { _ in
            Task { await viewModel.requestFinish() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .headphoneSingleTap)) { _ in
            Task { await viewModel.toggleRecording() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .headphoneDoubleTap)) { _ in
            Task { await viewModel.cancelRecording() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .headphoneLongPressStart)) { _ in
            Task { await viewModel.startRecording() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .headphoneLongPressEnd)) { _ in
            Task { await viewModel.requestFinish() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(viewModel.isProcessing ? Color.blue.opacity(0.14) : Color.red.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(viewModel.isProcessing ? .blue : .red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("说入法")
                    .font(.headline)
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text("长按 Fn 开始，说完松开即可整理成可直接使用的文稿")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()

            Button {
                Task { await cancelAndDismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(
                Circle()
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
        }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private var statusChip: some View {
        HStack(spacing: 10) {
            ProgressView()
                .opacity(viewModel.isProcessing ? 1 : 0)

            Image(systemName: viewModel.statusIcon)
                .foregroundStyle(viewModel.statusColor)

            Text(viewModel.statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.resultTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Spacer()

                if viewModel.hasResult {
                    Button("复制") {
                        viewModel.copyResultToClipboard()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                }
            }

            ScrollView {
                if viewModel.isRealtimeMode && !viewModel.realtimeText.isEmpty {
                    Text(viewModel.realtimeText)
                        .font(.system(size: 13))
                        .foregroundStyle(AppSurfaceTokens.primaryText.opacity(0.6))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.realtimeText)
                } else {
                    Text(viewModel.displayText.isEmpty ? "说完后，这里会显示清洗后的文稿。" : viewModel.displayText)
                        .font(.body)
                        .foregroundStyle(viewModel.displayText.isEmpty ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.72))
        )
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                Task { await cancelAndDismiss() }
            } label: {
                Text(viewModel.isRecording ? "取消" : "关闭")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                Task { await finishOrDismiss() }
            } label: {
                Text(primaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(primaryActionTint)
            .disabled(viewModel.isBusy)
        }
    }

    private var primaryActionTitle: String {
        if viewModel.isRecording { return "完成" }
        if viewModel.hasResult { return "完成" }
        return "开始"
    }

    private var primaryActionTint: Color {
        viewModel.isRecording ? .blue : .accentColor
    }

    private func finishOrDismiss() async {
        if viewModel.isRecording {
            await viewModel.stopAndProcess()
        } else if viewModel.hasResult {
            dismiss()
        } else {
            await viewModel.startRecording()
        }
    }

    private func cancelAndDismiss() async {
        await viewModel.cancelIfNeeded()
        dismiss()
    }
}

@MainActor
final class CompanionVoicePanelViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isBusy = false
    @Published var statusText = "正在准备说入法..."
    @Published var displayText = ""
    @Published var resultTitle = "转写结果"
    @Published var hasResult = false
    @Published var errorMessage: String?
    @Published var realtimeText: String = ""
    @Published var isRealtimeMode: Bool = false

    private let settingsViewModel = SettingsViewModel()
    private let coordinator: SayInputCoordinator?
    private var didPrepare = false
    private var isCancelled = false
    private var pendingFinishRequest = false

    init() {
        self.coordinator = SayInputCoordinator(
            voiceService: VoiceService(),
            sourceStore: StorageSayInputSourceItemStore(storage: StorageService()),
            textInjector: AXTextInjector(),
            clipboard: SystemSayInputClipboard(),
            assetStore: AssetStore()
        )
    }

    var statusIcon: String {
        if errorMessage != nil { return "exclamationmark.circle.fill" }
        if isProcessing { return "ellipsis.circle.fill" }
        if isRecording { return "waveform.circle.fill" }
        return hasResult ? "checkmark.circle.fill" : "mic.circle"
    }

    var statusColor: Color {
        if errorMessage != nil { return .orange }
        if isProcessing { return .blue }
        if isRecording { return .red }
        return hasResult ? .green : .secondary
    }

    var currentConfiguration: SayInputConfiguration {
        settingsViewModel.currentSayInputConfiguration()
    }

    func prepare() async {
        guard didPrepare == false else { return }
        didPrepare = true
        isCancelled = false

        guard coordinator != nil else {
            errorMessage = "服务尚未初始化完成"
            statusText = "无法启动说入法"
            return
        }

        statusText = "正在加载设置..."
        await settingsViewModel.loadSettings()
        await settingsViewModel.loadCompanionSettings()

        guard isCancelled == false else { return }
        await startRecording()
    }

    func startRecording() async {
        guard let coordinator else { return }
        guard isCancelled == false, isRecording == false, isBusy == false else { return }

        isBusy = true
        errorMessage = nil
        hasResult = false
        displayText = ""
        resultTitle = "转写结果"
        statusText = "正在收音..."

        // 应用前台应用的感知配置
        await coordinator.applyAppAwareConfiguration()

        coordinator.onRealtimeTranscriptUpdate = { [weak self] text in
            Task { @MainActor in
                self?.realtimeText = text
                self?.isRealtimeMode = true
                NotificationCenter.default.post(
                    name: .companionVoiceRealtimeTranscript,
                    object: text
                )
            }
        }

        do {
            try await coordinator.startRecording()
            NotificationCenter.default.post(name: .companionVoiceRecordingStarted, object: nil)
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
            statusText = "启动失败"
            NotificationCenter.default.post(name: .companionVoiceCancelled, object: nil)
        }

        isBusy = false

        if pendingFinishRequest, isRecording {
            pendingFinishRequest = false
            await stopAndProcess()
        }
    }

    func stopAndProcess() async {
        guard let coordinator else { return }
        guard isRecording, isBusy == false else { return }

        isBusy = true
        isProcessing = true
        realtimeText = ""
        isRealtimeMode = false
        statusText = "正在整理文稿..."
        NotificationCenter.default.post(name: .companionVoiceRecordingStopped, object: nil)
        NotificationCenter.default.post(name: .companionVoiceProcessingStarted, object: nil)

        do {
            let outcome = try await coordinator.stopRecording(configuration: currentConfiguration) { [weak self] chunk in
                await MainActor.run {
                    self?.displayText = chunk
                }
            }
            hasResult = true
            isRecording = false
            isProcessing = false
            displayText = outcome.polishedText

            switch outcome.deliveryState {
            case .insertedIntoFocusedField:
                resultTitle = "已写入当前光标"
                statusText = "内容已直接写入"
                NotificationCenter.default.post(
                    name: .companionVoiceProcessingFinished,
                    object: ["destination": NotchV2VoiceCompletionDestination.focusedField.rawValue]
                )
            case .copiedAndSavedToInbox:
                resultTitle = "已复制并保存到收集箱"
                statusText = "已进入收集箱"
                NotificationCenter.default.post(
                    name: .companionVoiceProcessingFinished,
                    object: ["destination": NotchV2VoiceCompletionDestination.inbox.rawValue]
                )
            case .copiedToClipboard:
                resultTitle = "已复制到剪贴板"
                statusText = "可直接粘贴使用"
                NotificationCenter.default.post(
                    name: .companionVoiceProcessingFinished,
                    object: ["destination": NotchV2VoiceCompletionDestination.clipboard.rawValue]
                )
            case .awaitingUserChoice:
                resultTitle = "已准备好"
                statusText = "内容已复制，等待你决定下一步"
                NotificationCenter.default.post(
                    name: .companionVoiceProcessingFinished,
                    object: ["destination": NotchV2VoiceCompletionDestination.clipboard.rawValue]
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            statusText = "处理失败"
            isProcessing = false
            isRecording = false
            NotificationCenter.default.post(name: .companionVoiceCancelled, object: nil)
        }

        isBusy = false
    }

    func cancelIfNeeded() async {
        guard let coordinator else { return }
        guard isCancelled == false else { return }
        isCancelled = true
        pendingFinishRequest = false
        realtimeText = ""
        isRealtimeMode = false

        if isRecording {
            do {
                try await coordinator.cancelRecording()
                NotificationCenter.default.post(name: .companionVoiceCancelled, object: nil)
            } catch {
                // 取消是兜底操作，失败时尽量不打断用户关闭窗口
            }
        }
    }

    func toggleRecording() async {
        if isRecording {
            await requestFinish()
        } else {
            await startRecording()
        }
    }

    func cancelRecording() async {
        await cancelIfNeeded()
    }

    func requestFinish() async {
        if isRecording {
            await stopAndProcess()
            return
        }

        pendingFinishRequest = true
    }

    func cleanupIfNeeded() async {
        await cancelIfNeeded()
    }

    func copyResultToClipboard() {
        guard displayText.isEmpty == false else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayText, forType: .string)
        statusText = "已复制到剪贴板"
    }
}
