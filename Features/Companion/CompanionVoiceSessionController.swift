import Foundation
import AppKit
import Combine
import SwiftUI
import AcMindKit

@MainActor
final class CompanionVoiceSessionController: ObservableObject {
    static let shared = CompanionVoiceSessionController()

    enum TriggerSource: String {
        case manual
        case holdToTalk
    }

    enum SessionPhase: String {
        case idle
        case arming
        case recording
        case processing
        case completed
        case error
    }

    @Published var isPresented = false
    @Published var triggerSource: TriggerSource = .manual
    @Published var phase: SessionPhase = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var transcriptText: String = ""
    @Published var errorMessage: String?
    @Published var statusHint: String = "按住 Fn 开始说入法"
    @Published var shouldAutoStart = false

    private var currentConfiguration = CompanionConfiguration.default
    private var stateCancellables = Set<AnyCancellable>()
    private var recordingTask: Task<Void, Never>?
    private var statusTimer: Timer?
    private var lastSourceItemId: String?
    private var isClosingSession = false
    private var cancelPendingStart = false
    private let textInjector: TextInjector

    private init(textInjector: TextInjector = AXTextInjector()) {
        self.textInjector = textInjector
        setupStateObservations()
    }

    var elapsedTimeFormatted: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var isBusy: Bool {
        phase == .arming || phase == .recording || phase == .processing
    }

    var isHoldToTalkEnabled: Bool {
        currentConfiguration.voiceHoldToTalkEnabled
    }

    var allowsFnHoldTrigger: Bool {
        switch currentTriggerMode {
        case .fnHold, .both:
            return true
        case .globalShortcut:
            return false
        }
    }

    var holdThreshold: TimeInterval {
        currentConfiguration.voiceHoldThreshold
    }

    var currentProvider: STTProvider {
        STTProvider(rawValue: currentConfiguration.voiceProvider) ?? .appleSpeech
    }

    var currentModel: String {
        currentConfiguration.voiceModel
    }

    var currentTriggerMode: CompanionVoiceTriggerMode {
        CompanionVoiceTriggerMode(rawValue: currentConfiguration.voiceTriggerMode) ?? .both
    }

    var currentRouteMode: CompanionVoiceRouteMode {
        CompanionVoiceRouteMode(rawValue: currentConfiguration.voiceRouteMode) ?? .smart
    }

    var actionTitle: String {
        switch phase {
        case .idle: return "按住 Fn 说话"
        case .arming: return "准备录音"
        case .recording: return "松开 Fn 结束"
        case .processing: return "正在转写"
        case .completed: return "已输入"
        case .error: return "转写失败"
        }
    }

    var actionSubtitle: String {
        switch phase {
        case .idle:
            return "像输入法一样直接说话，完成后回填到光标位置。"
        case .arming:
            return "检测到 Fn 按下，稍后自动开始录音。"
        case .recording:
            return "保持按住，松开后自动转写并插入当前输入框。"
        case .processing:
            return "正在把语音变成文字。"
        case .completed:
            return "已经回填到当前光标。"
        case .error:
            return errorMessage ?? "请检查麦克风和辅助功能权限。"
        }
    }

    func present(autoStart: Bool, source: TriggerSource = .manual) {
        Task { await refreshConfiguration() }
        isClosingSession = false
        cancelPendingStart = false
        triggerSource = source
        shouldAutoStart = autoStart
        transcriptText = ""
        errorMessage = nil
        isPresented = true
        statusHint = autoStart ? "松开 Fn 结束说入法" : "点击麦克风或直接按住 Fn"
        syncVoiceOverlay()
    }

    func beginHoldToTalk() {
        guard isHoldToTalkEnabled else { return }
        present(autoStart: true, source: .holdToTalk)
    }

    func closePanel() {
        guard !isClosingSession else { return }
        isClosingSession = true
        cancelTimers()
        if phase == .recording || phase == .processing || phase == .arming {
            Task { [weak self] in
                await self?.stopAndCommit(autoDismiss: false)
                await MainActor.run {
                    self?.resetAfterClose()
                    self?.isPresented = false
                    self?.isClosingSession = false
                }
            }
            return
        }

        isPresented = false
        shouldAutoStart = false
        isClosingSession = false
    }

    func startIfNeeded() {
        guard shouldAutoStart, phase == .idle else { return }
        shouldAutoStart = false
        Task { await beginRecording(triggeredByHold: true) }
    }

    func beginManualRecording() {
        present(autoStart: false, source: .manual)
        Task { await beginRecording(triggeredByHold: false) }
    }

    func finishRecording() {
        if phase == .idle, shouldAutoStart, triggerSource == .holdToTalk {
            closePanel()
            return
        }

        Task { await stopAndCommit(autoDismiss: triggerSource == .holdToTalk) }
    }

    func cancelRecording() {
        Task { await cancelSession() }
    }

    private func beginRecording(triggeredByHold: Bool) async {
        guard phase == .idle || phase == .completed || phase == .error else { return }
        guard ServiceContainer.isInitialized() else {
            phase = .error
            errorMessage = "服务尚未初始化"
            return
        }

        let configuration = await refreshConfiguration()
        let service = ServiceContainer.shared.voiceService
        await configureVoiceService(with: configuration)
        phase = triggeredByHold ? .arming : .recording
        elapsedTime = 0
        transcriptText = ""
        errorMessage = nil
        statusHint = triggeredByHold ? "正在唤起说入法..." : "录音已开始"
        syncVoiceOverlay()

        if triggeredByHold {
            isPresented = true
            cancelPendingStart = false
            try? await Task.sleep(for: .milliseconds(150))
            guard !cancelPendingStart else {
                resetAfterClose()
                isPresented = false
                isClosingSession = false
                return
            }
        }

        do {
            guard !cancelPendingStart else {
                resetAfterClose()
                isPresented = false
                isClosingSession = false
                return
            }
            try await service.startRecording()
            phase = .recording
            isPresented = true
            statusHint = "松开 Fn 结束输入"
            syncVoiceOverlay()
            startTimer()
            NotificationCenter.default.post(name: .companionVoiceRecordingStarted, object: nil)
        } catch let error as VoiceError {
            phase = .error
            if case .permissionDenied = error {
                errorMessage = "需要麦克风权限，请在系统设置中授权"
            } else {
                errorMessage = error.localizedDescription
            }
            statusHint = errorMessage ?? "录音失败"
            syncVoiceOverlay()
            ToastManager.shared.show(.error, error.localizedDescription)
        } catch {
            phase = .error
            errorMessage = error.localizedDescription
            statusHint = error.localizedDescription
            syncVoiceOverlay()
            ToastManager.shared.show(.error, error.localizedDescription)
        }
    }

    private func stopAndCommit(autoDismiss: Bool) async {
        guard phase == .recording || phase == .arming else { return }
        guard ServiceContainer.isInitialized() else { return }

        if phase == .arming {
            await cancelSession()
            return
        }

        cancelTimers()
        phase = .processing
        statusHint = "正在转写..."
        syncVoiceOverlay()

        do {
            let service = ServiceContainer.shared.voiceService
            let sourceItemId = try await service.stopRecording()
            lastSourceItemId = sourceItemId
            NotificationCenter.default.post(name: .companionVoiceRecordingStopped, object: nil)

            let transcript = try await waitForTranscript(sourceItemId: sourceItemId)
            transcriptText = transcript
            try await routeTranscript(transcript)

            phase = .completed
            statusHint = "已完成"
            syncVoiceOverlay()
            ToastManager.shared.show(.success, "语音已转写")

            if autoDismiss {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.isPresented = false
                    self?.resetAfterClose()
                }
            }
        } catch {
            phase = .error
            errorMessage = error.localizedDescription
            statusHint = error.localizedDescription
            syncVoiceOverlay()
            ToastManager.shared.show(.error, error.localizedDescription)
        }
    }

    private func handleManualOutput(transcript: String) async throws {
        switch VoiceOutputMode(rawValue: currentConfiguration.voiceOutputMode) ?? .copyToClipboard {
        case .copyToClipboard:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(transcript, forType: .string)
        case .autoPaste:
            try await insertTranscript(transcript)
        case .ask:
            try await insertTranscript(transcript)
        }
    }

    private func routeTranscript(_ transcript: String) async throws {
        let snapshot = await textInjector.getSelectionSnapshot()
        let destination = await resolveDestination(snapshot: snapshot, transcript: transcript)

        switch destination {
        case .inputField:
            try await deliverToInputField(transcript: transcript, snapshot: snapshot)
        case .agent:
            try await deliverToAgent(transcript: transcript)
        }
    }

    private enum TranscriptDestination {
        case inputField
        case agent
    }

    private func resolveDestination(snapshot: TextSelectionSnapshot, transcript: String) async -> TranscriptDestination {
        let routeMode = currentRouteMode
        switch routeMode {
        case .inputField:
            return .inputField
        case .agent:
            return .agent
        case .smart:
            if snapshot.isEditable || snapshot.hasAskSelectionContext {
                return .inputField
            }

            if AppState.shared.sidebarSelection == .agent || looksLikeAgentIntent(transcript) {
                return .agent
            }

            return .agent
        }
    }

    private func looksLikeAgentIntent(_ transcript: String) -> Bool {
        let normalized = transcript.lowercased()
        let keywords = [
            "agent", "帮我", "给我", "记笔记", "记一下", "整理", "总结", "分析",
            "搜索", "查一下", "联网", "网络", "新建日程", "创建日程", "安排日程",
            "本日任务", "今日任务", "待办", "任务", "提醒", "了解一下"
        ]
        return keywords.contains { normalized.contains($0.lowercased()) }
    }

    private func deliverToInputField(transcript: String, snapshot: TextSelectionSnapshot) async throws {
        let voiceSettings = await ServiceContainer.shared.settingsService.getVoiceSettings()
        let polishedText: String

        if voiceSettings.autoPolish {
            polishedText = try await ServiceContainer.shared.voiceService.polishTranscript(transcript, mode: voiceSettings.voicePolishMode)
        } else {
            polishedText = transcript
        }

        if snapshot.canReplaceSelection {
            try textInjector.replaceSelection(text: polishedText)
        } else {
            try await insertTranscript(polishedText)
        }

        if currentConfiguration.voiceOutputMode == VoiceOutputMode.copyToClipboard.rawValue {
            // 保持原有输出行为：即便直写，也同步一份到剪贴板便于粘贴到别处
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(polishedText, forType: .string)
        }
    }

    private func deliverToAgent(transcript: String) async throws {
        let draft = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }

        UserDefaults.standard.set(draft, forKey: "companion.voice.agentDraft")
        NotificationCenter.default.post(name: .companionVoiceAgentDraft, object: draft)
        NotificationCenter.default.post(name: .companionShowAgent, object: nil)
    }

    private func insertTranscript(_ transcript: String) async throws {
        let snapshot = await textInjector.getSelectionSnapshot()
        if snapshot.canReplaceSelection {
            try textInjector.replaceSelection(text: transcript)
        } else {
            try textInjector.insert(text: transcript)
        }
    }

    private func cancelSession() async {
        isClosingSession = true
        cancelTimers()

        if phase == .arming {
            cancelPendingStart = true
            resetAfterClose()
            isPresented = false
            isClosingSession = false
            return
        } else if phase == .recording {
            _ = try? await ServiceContainer.shared.voiceService.stopRecording()
            NotificationCenter.default.post(name: .companionVoiceRecordingStopped, object: nil)
        }

        resetAfterClose()
        isPresented = false
        isClosingSession = false
        cancelPendingStart = false
    }

    private func resetAfterClose() {
        cancelTimers()
        phase = .idle
        elapsedTime = 0
        shouldAutoStart = false
        statusHint = "按住 Fn 开始说入法"
        syncVoiceOverlay()
        errorMessage = nil
        lastSourceItemId = nil
        cancelPendingStart = false
    }

    private func setupStateObservations() {
        Publishers.CombineLatest3($phase, $statusHint, $transcriptText)
            .sink { phase, statusHint, transcriptText in
                VoiceRecordingHUDController.shared.sync(
                    isVisible: phase == .arming || phase == .recording || phase == .processing,
                    phase: phase,
                    status: statusHint,
                    transcript: transcriptText
                )
            }
            .store(in: &stateCancellables)
    }

    private func syncVoiceOverlay() {
        VoiceRecordingHUDController.shared.sync(
            isVisible: phase == .arming || phase == .recording || phase == .processing,
            phase: phase,
            status: statusHint,
            transcript: transcriptText
        )
    }

    private func cancelTimers() {
        recordingTask?.cancel()
        recordingTask = nil
        statusTimer?.invalidate()
        statusTimer = nil
    }

    private func startTimer() {
        cancelTimers()

        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedTime += 0.1
            }
        }
    }

    private func waitForTranscript(sourceItemId: String) async throws -> String {
        let storage = ServiceContainer.shared.storageService
        var attempts = 0

        while attempts < 60 {
            if let item = try await storage.getSourceItem(id: sourceItemId) {
                if let transcript = item.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
                   transcript.isEmpty == false {
                    return transcript
                }

                if let preview = item.previewText?.trimmingCharacters(in: .whitespacesAndNewlines),
                   preview.isEmpty == false,
                   item.status == .parsed {
                    return preview
                }
            }

            try await Task.sleep(for: .milliseconds(500))
            attempts += 1
        }

        throw VoiceError.transcriptionFailed("等待转写超时")
    }

    private func loadCompanionConfiguration() async -> CompanionConfiguration {
        guard ServiceContainer.isInitialized() else { return .default }

        let storage = ServiceContainer.shared.storageService
        do {
            if let jsonString = try await storage.getSetting(key: "companion_config"),
               let jsonData = jsonString.data(using: .utf8),
               let config = try? JSONDecoder().decode(CompanionConfiguration.self, from: jsonData) {
                return config
            }
        } catch {
            return .default
        }

        return .default
    }

    @discardableResult
    func refreshConfiguration() async -> CompanionConfiguration {
        let configuration = await loadCompanionConfiguration()
        currentConfiguration = configuration
        return configuration
    }

    private func configureVoiceService(with configuration: CompanionConfiguration) async {
        guard let voiceService = ServiceContainer.shared.voiceService as? VoiceService else { return }

        let provider = STTProvider(rawValue: configuration.voiceProvider) ?? .appleSpeech
        await voiceService.configureSpeechInput(provider: provider, modelIdentifier: configuration.voiceModel)
    }

}

// MARK: - Voice Recording HUD

@MainActor
final class VoiceRecordingHUDController {
    static let shared = VoiceRecordingHUDController()

    private var panel: VoiceRecordingHUDPanel?

    func sync(
        isVisible: Bool,
        phase: CompanionVoiceSessionController.SessionPhase,
        status: String,
        transcript: String
    ) {
        if isVisible {
            let panel = panel ?? VoiceRecordingHUDPanel()
            self.panel = panel
            panel.update(phase: phase, status: status, transcript: transcript)
            panel.showOnActiveScreen()
        } else {
            panel?.hide()
        }
    }
}

final class VoiceRecordingHUDPanel: NSPanel {
    private var hostingView: NSHostingView<VoiceRecordingHUDView>?
    private var phase: CompanionVoiceSessionController.SessionPhase = .idle
    private var status: String = ""
    private var transcript: String = ""

    init() {
        super.init(
            contentRect: .init(x: 0, y: 0, width: 360, height: 72),
            styleMask: [.nonactivatingPanel, .hudWindow, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        setupContentView()
    }

    func update(
        phase: CompanionVoiceSessionController.SessionPhase,
        status: String,
        transcript: String
    ) {
        self.phase = phase
        self.status = status
        self.transcript = transcript
        hostingView?.rootView = VoiceRecordingHUDView(
            phase: phase,
            status: status,
            transcript: transcript
        )
        reposition()
    }

    func showOnActiveScreen() {
        reposition()
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    private func setupContentView() {
        let view = VoiceRecordingHUDView(phase: phase, status: status, transcript: transcript)
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hostingView = hosting
        contentView = hosting
        syncWindowSize(to: CGSize(width: 360, height: 72))
    }

    private func reposition() {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let frame = screen.visibleFrame
        let width: CGFloat = 360
        let height: CGFloat = 72
        let x = frame.midX - width / 2
        let y = frame.minY + 14
        setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        syncWindowSize(to: CGSize(width: width, height: height))
    }

    private func syncWindowSize(to size: CGSize) {
        minSize = size
        maxSize = size
        contentMinSize = size
        contentMaxSize = size
    }
}

struct VoiceRecordingHUDView: View {
    let phase: CompanionVoiceSessionController.SessionPhase
    let status: String
    let transcript: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Capsule()
                    .fill(backgroundGradient)
                    .frame(width: 68, height: 42)

                AnimatedAudioWaveform(phase: phase)
                    .frame(width: 44, height: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("说入法")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ACColors.primaryText)

                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ACColors.secondaryText)

                if phase == .recording || phase == .processing {
                    Text(transcript.isEmpty ? "正在说话..." : transcript)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(ACColors.tertiaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if phase == .recording {
                Text("转写中")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ACColors.accentBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ACColors.accentBlue.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 360, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.56), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private var backgroundGradient: LinearGradient {
        switch phase {
        case .recording:
            return LinearGradient(colors: [ACColors.accentRed.opacity(0.3), ACColors.accentOrange.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .processing:
            return LinearGradient(colors: [ACColors.accentBlue.opacity(0.25), ACColors.accentPurple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [ACColors.softFill, ACColors.softFill], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct AnimatedAudioWaveform: View {
    let phase: CompanionVoiceSessionController.SessionPhase
    @State private var phaseSeed = 0.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(waveColor)
                        .frame(width: 3, height: barHeight(index: index, time: time))
                }
            }
            .frame(height: 20)
            .onAppear {
                phaseSeed = Double.random(in: 0...2)
            }
        }
    }

    private var waveColor: Color {
        switch phase {
        case .recording:
            return ACColors.accentRed
        case .processing:
            return ACColors.accentBlue
        default:
            return ACColors.secondaryText.opacity(0.65)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let amplitude: CGFloat
        switch phase {
        case .recording:
            amplitude = 10
        case .processing:
            amplitude = 6
        default:
            amplitude = 3
        }

        let base: CGFloat = 4
        let wave = sin(time * 4.5 + Double(index) * 0.9 + phaseSeed)
        return max(4, base + amplitude * CGFloat((wave + 1) / 2))
    }
}
