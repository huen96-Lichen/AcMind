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
                stageStrip
                statusChip
                transcriptCard
                actionRow
            }
            .padding(20)
        }
        .frame(width: 560, height: 360)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                        .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: AppSurfaceTokens.separator.opacity(0.10), radius: 10, x: 0, y: 5)
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
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                    .frame(width: 34, height: 34)

                Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: AppSurfaceTokens.Typography.controlStrong, weight: .semibold))
                    .foregroundStyle(viewModel.isProcessing ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.accentOrange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("说入法")
                    .font(.system(size: AppSurfaceTokens.Typography.cardTitle, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text("长按 Fn 开始，说完松开即可整理成可直接使用的文稿")
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()

            Button {
                Task { await cancelAndDismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
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
                .font(.system(size: AppSurfaceTokens.Typography.body, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private var stageStrip: some View {
        HStack(spacing: 8) {
            stageChip(title: "监听", isActive: viewModel.isRecording)
            stageChip(title: "转写", isActive: viewModel.isProcessing)
            stageChip(title: "修正", isActive: viewModel.hasResult)
            stageChip(title: "发送", isActive: viewModel.hasResult)
            Spacer(minLength: 0)
        }
    }

    private func stageChip(title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
            .foregroundStyle(isActive ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isActive ? AppSurfaceTokens.accentBlue.opacity(0.16) : AppSurfaceTokens.separator.opacity(0.35), lineWidth: 1)
            )
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.resultTitle)
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Spacer()

                if viewModel.hasResult {
                    Button("恢复原文") {
                        viewModel.revertEditedText()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                    Button("复制") {
                        viewModel.copyResultToClipboard()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                }
            }

            ScrollView {
                if viewModel.hasResult {
                    TextEditor(text: $viewModel.editableText)
                        .font(.system(size: AppSurfaceTokens.Typography.bodyLarge))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 188, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                                .fill(AppSurfaceTokens.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                                .stroke(AppSurfaceTokens.separator.opacity(0.35), lineWidth: 1)
                        )
                } else if viewModel.isRealtimeMode && !viewModel.realtimeText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("实时转写")
                            .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)

                        Text(viewModel.realtimeText)
                            .font(.system(size: AppSurfaceTokens.Typography.body))
                            .foregroundStyle(AppSurfaceTokens.primaryText.opacity(0.75))
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(.easeInOut(duration: 0.15), value: viewModel.realtimeText)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                            .fill(AppSurfaceTokens.cardBackgroundSoft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                            .stroke(AppSurfaceTokens.separator.opacity(0.35), lineWidth: 1)
                    )
                } else {
                    if viewModel.displayText.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: "waveform.badge.mic")
                                    .font(.system(size: AppSurfaceTokens.Typography.controlStrong, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)

                                Text("准备就绪")
                                    .font(.system(size: AppSurfaceTokens.Typography.body, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.primaryText)
                            }

                            Text("按住 Fn 说话，松开后会自动整理。")
                                .font(.system(size: AppSurfaceTokens.Typography.body))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .lineSpacing(3)

                            HStack(spacing: 8) {
                                helperPill("实时转写")
                                helperPill("自动润色")
                                helperPill("可编辑修正")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                    } else {
                        Text(viewModel.displayText)
                            .font(.body)
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func helperPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
            .foregroundStyle(AppSurfaceTokens.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.35), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var actionRow: some View {
        if viewModel.hasResult {
            HStack(spacing: 12) {
                Button {
                    Task { await cancelAndDismiss() }
                } label: {
                    Text("关闭")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.copyResultToClipboard()
                } label: {
                    Text("复制修正版")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(viewModel.editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } else {
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
    }

    private var primaryActionTitle: String {
        if viewModel.isRecording { return "完成整理" }
        return "开始说话"
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
    @Published var statusText = SayInputPresentationLabelFormatter.preparingText
    @Published var displayText = ""
    @Published var editableText = ""
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
            statusText = SayInputPresentationLabelFormatter.startFailedText
            return
        }

        statusText = SayInputPresentationLabelFormatter.loadingSettingsText
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
        editableText = ""
        resultTitle = "转写结果"
        statusText = SayInputPresentationLabelFormatter.recordingText

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
            statusText = SayInputPresentationLabelFormatter.startFailedText
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
        statusText = SayInputPresentationLabelFormatter.processingText
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
            editableText = outcome.polishedText

            switch outcome.deliveryState {
            case .insertedIntoFocusedField:
                resultTitle = SayInputPresentationLabelFormatter.resultTitle(for: .insertedIntoFocusedField)
                statusText = SayInputPresentationLabelFormatter.resultDetail(for: .insertedIntoFocusedField)
                NotificationCenter.default.post(
                    name: .companionVoiceProcessingFinished,
                    object: ["destination": NotchV2VoiceCompletionDestination.focusedField.rawValue]
                )
            case .copiedAndSavedToInbox:
                resultTitle = SayInputPresentationLabelFormatter.resultTitle(for: .copiedAndSavedToInbox)
                statusText = SayInputPresentationLabelFormatter.resultDetail(for: .copiedAndSavedToInbox)
                NotificationCenter.default.post(
                    name: .companionVoiceProcessingFinished,
                    object: ["destination": NotchV2VoiceCompletionDestination.inbox.rawValue]
                )
            case .copiedToClipboard:
                resultTitle = SayInputPresentationLabelFormatter.resultTitle(for: .copiedToClipboard)
                statusText = SayInputPresentationLabelFormatter.resultDetail(for: .copiedToClipboard)
                NotificationCenter.default.post(
                    name: .companionVoiceProcessingFinished,
                    object: ["destination": NotchV2VoiceCompletionDestination.clipboard.rawValue]
                )
            case .awaitingUserChoice:
                resultTitle = SayInputPresentationLabelFormatter.resultTitle(for: .awaitingUserChoice)
                statusText = SayInputPresentationLabelFormatter.resultDetail(for: .awaitingUserChoice)
                NotificationCenter.default.post(
                    name: .companionVoiceProcessingFinished,
                    object: ["destination": NotchV2VoiceCompletionDestination.clipboard.rawValue]
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            statusText = SayInputPresentationLabelFormatter.processingFailedText
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
        guard editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(editableText, forType: .string)
        statusText = SayInputPresentationLabelFormatter.clipboardCopiedText
    }

    func revertEditedText() {
        editableText = displayText
    }
}
