import SwiftUI
import Combine
import AcMindKit

// MARK: - System Event Types

extension SystemEventKind {
    var icon: String {
        switch self {
        case .volume: return "speaker.wave.2.fill"
        case .brightness: return "sun.max.fill"
        case .keyboardBacklight: return "keyboard.fill"
        case .microphone: return "mic.fill"
        case .sayInput: return "waveform"
        case .screenshot: return "camera.viewfinder"
        }
    }

    var displayName: String {
        switch self {
        case .volume: return "音量"
        case .brightness: return "亮度"
        case .keyboardBacklight: return "键盘背光"
        case .microphone: return "麦克风"
        case .sayInput: return "说入法"
        case .screenshot: return "截图"
        }
    }

    var subtitle: String {
        switch self {
        case .volume: return "系统音量变更"
        case .brightness: return "显示亮度变更"
        case .keyboardBacklight: return "键盘背光变更"
        case .microphone: return "麦克风静音 / 解除静音"
        case .sayInput: return "说入法收音状态"
        case .screenshot: return "截图完成 / 处理中"
        }
    }

    var accent: Color {
        switch self {
        case .volume: return .blue
        case .brightness: return .orange
        case .keyboardBacklight: return .purple
        case .microphone: return .red
        case .sayInput: return .green
        case .screenshot: return .cyan
        }
    }
}

struct SystemEventHUDItem: Identifiable {
    let id = UUID()
    let kind: SystemEventKind
    let title: String
    let detail: String
    let progress: Double?
}

// MARK: - System Event Center

@MainActor
final class SystemEventCenter: ObservableObject {
    @Published var currentHUD: SystemEventHUDItem?
    @Published var volumeLevel: Double?
    @Published var brightnessLevel: Double?
    @Published var keyboardBacklightLevel: Double?
    @Published var microphoneMuted: Bool?
    @Published var sayInputActive: Bool = false
    @Published var screenshotInProgress: Bool = false

    private var dismissTask: Task<Void, Never>?
    private var sayInputLocked: Bool = false
    private var currentRequest: SystemEventHUDRequest?
    private var pendingRequests: [SystemEventHUDRequest] = []

    init() {
        setupVoiceLockObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupVoiceLockObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSayInputRecordingStarted(_:)),
            name: .companionVoiceRecordingStarted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSayInputRecordingLocked(_:)),
            name: .companionVoiceRecordingStopped,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSayInputRecordingLocked(_:)),
            name: .companionVoiceProcessingStarted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSayInputUnlocked(_:)),
            name: .companionVoiceProcessingFinished,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSayInputUnlocked(_:)),
            name: .companionVoiceCancelled,
            object: nil
        )
    }

    @objc private func handleSayInputRecordingStarted(_ notification: Notification) {
        sayInputLocked = true
        sayInputActive = true
    }

    @objc private func handleSayInputRecordingLocked(_ notification: Notification) {
        sayInputLocked = true
        sayInputActive = true
    }

    @objc private func handleSayInputUnlocked(_ notification: Notification) {
        sayInputLocked = false
        sayInputActive = false
        flushPendingRequests()
    }

    func publish(_ kind: SystemEventKind, title: String? = nil, detail: String? = nil, progress: Double? = nil, duration: TimeInterval = 1.5) {
        let request = SystemEventHUDRequest(
            kind: kind,
            title: title,
            detail: detail,
            progress: progress,
            duration: duration
        )

        let displaySettings = CompanionDisplaySettingsStore.load()
        guard displaySettings.showSystemEventHUD, displaySettings.enabledSystemEventKinds.contains(kind) else {
            return
        }

        switch kind {
        case .volume:
            if let progress {
                volumeLevel = progress
            }
        case .brightness:
            if let progress {
                brightnessLevel = progress
            }
        case .keyboardBacklight:
            if let progress {
                keyboardBacklightLevel = progress
            }
        case .microphone:
            if let progress {
                microphoneMuted = progress <= 0.5
            }
        case .sayInput:
            let text = "\(title ?? "") \(detail ?? "")"
            sayInputActive = text.contains("收音") || text.contains("录音")
        case .screenshot:
            screenshotInProgress = true
        }

        if kind == .sayInput {
            updateSayInputLockState(title: title, detail: detail)
        }

        enqueueHUDRequest(request)
    }

    var pendingHUDKinds: [SystemEventKind] {
        pendingRequests.map(\.kind)
    }

    func enqueueHUDRequest(_ request: SystemEventHUDRequest) {
        if currentRequest == nil {
            guard SystemEventHUDPolicy.allowsReplacement(for: request.kind, sayInputLocked: sayInputLocked) else {
                pendingRequests.append(request)
                pendingRequests = SystemEventHUDPolicy.orderedPendingRequests(pendingRequests)
                return
            }
            present(request)
            return
        }

        guard let currentRequest else {
            pendingRequests.append(request)
            pendingRequests = SystemEventHUDPolicy.orderedPendingRequests(pendingRequests)
            return
        }

        if currentRequest.kind == request.kind {
            present(request)
            return
        }

        if SystemEventHUDPolicy.shouldInterrupt(
            currentKind: currentRequest.kind,
            incomingKind: request.kind,
            sayInputLocked: sayInputLocked
        ) {
            pendingRequests.append(currentRequest)
            pendingRequests = SystemEventHUDPolicy.orderedPendingRequests(pendingRequests)
            present(request)
            return
        }

        pendingRequests.append(request)
        pendingRequests = SystemEventHUDPolicy.orderedPendingRequests(pendingRequests)
    }

    private func updateSayInputLockState(title: String?, detail: String?) {
        let text = "\(title ?? "") \(detail ?? "")"
        if text.contains("收音中") || text.contains("清洗文稿") || text.contains("正在收音") || text.contains("录音中") {
            sayInputLocked = true
            sayInputActive = true
        } else if text.contains("已取消") || text.contains("已写入") || text.contains("已保存") {
            sayInputLocked = false
            sayInputActive = false
        }
    }

    func dismiss(animated: Bool = false) {
        dismissTask?.cancel()
        dismissTask = nil
        currentRequest = nil
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                currentHUD = nil
                screenshotInProgress = false
                if sayInputActive == false {
                    // keep value as-is; top bar uses it as a persistent flag
                }
            }
        } else {
            currentHUD = nil
            screenshotInProgress = false
        }

        flushPendingRequests()
    }

    private func present(_ request: SystemEventHUDRequest) {
        let item = SystemEventHUDItem(
            kind: request.kind,
            title: request.title ?? defaultTitle(for: request.kind, progress: request.progress),
            detail: request.detail ?? defaultDetail(for: request.kind, progress: request.progress),
            progress: request.progress
        )

        currentRequest = request
        dismissTask?.cancel()

        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            currentHUD = item
        }

        if request.duration <= 0 || request.kind == .sayInput && sayInputLocked {
            return
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(request.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.dismiss(animated: true)
            }
        }
    }

    private func flushPendingRequests() {
        guard currentRequest == nil else { return }
        guard let next = pendingRequests.first else { return }
        pendingRequests.removeFirst()
        present(next)
    }

    private func defaultTitle(for kind: SystemEventKind, progress: Double?) -> String {
        switch kind {
        case .volume:
            return progress.map { "音量 \($0)%" } ?? "音量调整"
        case .brightness:
            return progress.map { "亮度 \($0)%" } ?? "亮度调整"
        case .keyboardBacklight:
            return progress.map { "键盘背光 \($0)%" } ?? "键盘背光"
        case .microphone:
            return "麦克风"
        case .sayInput:
            return SayInputPresentationLabelFormatter.hudTitle(for: .idle)
        case .screenshot:
            return "截图"
        }
    }

    private func defaultDetail(for kind: SystemEventKind, progress: Double?) -> String {
        switch kind {
        case .volume:
            return "系统音量"
        case .brightness:
            return "显示亮度"
        case .keyboardBacklight:
            return "键盘背光"
        case .microphone:
            return microphoneMuted == true ? "已静音" : "正常收音"
        case .sayInput:
            return sayInputActive ? SayInputPresentationLabelFormatter.recordingText : SayInputPresentationLabelFormatter.finishedText
        case .screenshot:
            return screenshotInProgress ? "处理中" : "已完成"
        }
    }
}

// MARK: - HUD View

struct SystemEventHUDView: View {
    @ObservedObject private var center: SystemEventCenter

    init(center: SystemEventCenter) {
        _center = ObservedObject(wrappedValue: center)
    }

    var body: some View {
        if let event = center.currentHUD {
            HStack(spacing: 12) {
                Image(systemName: event.kind.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(event.kind.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                    Text(event.detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }

                Spacer(minLength: 10)

                if let progress = event.progress {
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(NotchV2DesignTokens.innerCardBackground)
                        Capsule(style: .continuous)
                            .fill(event.kind.accent)
                            .frame(width: max(10, 84 * CGFloat(progress / 100.0)))
                    }
                    .frame(width: 84, height: 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 260)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(NotchV2DesignTokens.panelBackground.opacity(0.96))
                    .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(event.kind.accent.opacity(0.25), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                if center.pendingHUDKinds.isEmpty == false {
                    Text(pendingQueueText)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.9))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(event.kind.accent.opacity(0.18), lineWidth: 1)
                        )
                        .padding(.trailing, 10)
                        .padding(.bottom, 8)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var pendingQueueText: String {
        let pendingKinds = center.pendingHUDKinds
        guard pendingKinds.isEmpty == false else { return "" }

        let head = pendingKinds.prefix(3).map(\.displayName).joined(separator: " / ")
        if pendingKinds.count > 3 {
            return "排队中 · \(head) +\(pendingKinds.count - 3)"
        }
        return "排队中 · \(head)"
    }
}
