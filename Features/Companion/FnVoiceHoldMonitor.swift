import AppKit

@MainActor
final class FnVoiceHoldMonitor {
    static let shared = FnVoiceHoldMonitor()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var holdTask: Task<Void, Never>?
    private var isFnDown = false
    private var isTriggered = false
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        holdTask?.cancel()
        holdTask = nil
        isFnDown = false
        isTriggered = false
        isRunning = false
    }

    private func handle(_ event: NSEvent) {
        let session = CompanionVoiceSessionController.shared
        guard session.isHoldToTalkEnabled, session.allowsFnHoldTrigger else { return }

        let fnPressed = event.modifierFlags.contains(.function)
        if fnPressed && !isFnDown {
            isFnDown = true
            scheduleHold()
        } else if !fnPressed && isFnDown {
            isFnDown = false
            holdTask?.cancel()
            holdTask = nil

            if isTriggered {
                isTriggered = false
                session.finishRecording()
            } else {
                session.cancelRecording()
            }
        }
    }

    private func scheduleHold() {
        holdTask?.cancel()
        let threshold = CompanionVoiceSessionController.shared.holdThreshold
        holdTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(threshold))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, self.isFnDown else { return }
                self.isTriggered = true
                CompanionVoiceSessionController.shared.beginHoldToTalk()
            }
        }
    }
}
