import XCTest
@testable import AcMindKit

final class NotchVoiceSurfacePresentationTests: XCTestCase {
    func testListeningStateShowsRecordingCopyAndHighestPriority() {
        let state: NotchV2VoiceSurfaceState = .listening

        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.displayTitle, "说入法收音中")
        XCTAssertEqual(state.displaySubtitle, "松开 Fn 完成 · Esc 取消")
        XCTAssertEqual(state.displayIcon, "mic.fill")
        XCTAssertEqual(state.waveformMode, .listening)
        XCTAssertTrue(state.showsWaveform)
        XCTAssertEqual(state.surfacePriority, .voiceRecording)
    }

    func testProcessingStateShowsCleaningCopyAndLowFrequencyWaveform() {
        let state: NotchV2VoiceSurfaceState = .processing

        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.displayTitle, "正在清洗文稿")
        XCTAssertEqual(state.displaySubtitle, "准备写入当前光标")
        XCTAssertEqual(state.displayIcon, "waveform")
        XCTAssertEqual(state.waveformMode, .processing)
        XCTAssertTrue(state.showsWaveform)
        XCTAssertEqual(state.surfacePriority, .voiceProcessing)
    }

    func testCompletedAndCancelledStatesUseTransientFeedbackCopy() {
        let completed: NotchV2VoiceSurfaceState = .completed(destination: .clipboard)
        XCTAssertTrue(completed.isActive)
        XCTAssertEqual(completed.displayTitle, "已保存到剪贴板")
        XCTAssertEqual(completed.displaySubtitle, "可直接粘贴使用")
        XCTAssertEqual(completed.displayIcon, "checkmark.circle.fill")
        XCTAssertFalse(completed.showsWaveform)
        XCTAssertEqual(completed.surfacePriority, .defaultState)

        let cancelled: NotchV2VoiceSurfaceState = .cancelled
        XCTAssertTrue(cancelled.isActive)
        XCTAssertEqual(cancelled.displayTitle, "已取消")
        XCTAssertEqual(cancelled.displaySubtitle, "收音已停止")
        XCTAssertEqual(cancelled.displayIcon, "xmark.circle.fill")
        XCTAssertFalse(cancelled.showsWaveform)
        XCTAssertEqual(cancelled.surfacePriority, .defaultState)
    }

    func testSayInputLockBlocksNonVoiceHUDKinds() {
        XCTAssertFalse(SystemEventHUDPolicy.allowsReplacement(for: .volume, sayInputLocked: true))
        XCTAssertFalse(SystemEventHUDPolicy.allowsReplacement(for: .brightness, sayInputLocked: true))
        XCTAssertFalse(SystemEventHUDPolicy.allowsReplacement(for: .keyboardBacklight, sayInputLocked: true))
        XCTAssertFalse(SystemEventHUDPolicy.allowsReplacement(for: .microphone, sayInputLocked: true))
        XCTAssertFalse(SystemEventHUDPolicy.allowsReplacement(for: .screenshot, sayInputLocked: true))
        XCTAssertTrue(SystemEventHUDPolicy.allowsReplacement(for: .sayInput, sayInputLocked: true))
        XCTAssertTrue(SystemEventHUDPolicy.allowsReplacement(for: .volume, sayInputLocked: false))
    }

    func testSystemEventHUDPriorityRanksInteractiveEventsAbovePassiveEvents() {
        XCTAssertLessThan(SystemEventKind.volume.hudPriority, SystemEventKind.microphone.hudPriority)
        XCTAssertLessThan(SystemEventKind.microphone.hudPriority, SystemEventKind.screenshot.hudPriority)
        XCTAssertLessThan(SystemEventKind.screenshot.hudPriority, SystemEventKind.sayInput.hudPriority)
    }

    func testPendingRequestsSortByPriorityThenArrival() {
        let first = SystemEventHUDRequest(kind: .volume, queuedAt: Date(timeIntervalSince1970: 1))
        let second = SystemEventHUDRequest(kind: .screenshot, queuedAt: Date(timeIntervalSince1970: 3))
        let third = SystemEventHUDRequest(kind: .screenshot, queuedAt: Date(timeIntervalSince1970: 2))
        let fourth = SystemEventHUDRequest(kind: .sayInput, queuedAt: Date(timeIntervalSince1970: 4))

        let ordered = SystemEventHUDPolicy.orderedPendingRequests([first, second, third, fourth])

        XCTAssertEqual(ordered.map(\.kind), [.sayInput, .screenshot, .screenshot, .volume])
        XCTAssertEqual(ordered.map(\.queuedAt), [Date(timeIntervalSince1970: 4), Date(timeIntervalSince1970: 2), Date(timeIntervalSince1970: 3), Date(timeIntervalSince1970: 1)])
    }

    func testRequestPriorityMatchesKindPriority() {
        XCTAssertEqual(SystemEventHUDRequest(kind: .volume).priority, .low)
        XCTAssertEqual(SystemEventHUDRequest(kind: .microphone).priority, .medium)
        XCTAssertEqual(SystemEventHUDRequest(kind: .screenshot).priority, .high)
        XCTAssertEqual(SystemEventHUDRequest(kind: .sayInput).priority, .critical)
    }

    func testHigherPriorityEventInterruptsCurrentHud() {
        XCTAssertTrue(SystemEventHUDPolicy.shouldInterrupt(currentKind: .volume, incomingKind: .screenshot, sayInputLocked: false))
        XCTAssertFalse(SystemEventHUDPolicy.shouldInterrupt(currentKind: .screenshot, incomingKind: .volume, sayInputLocked: false))
        XCTAssertTrue(SystemEventHUDPolicy.shouldInterrupt(currentKind: .microphone, incomingKind: .sayInput, sayInputLocked: true))
        XCTAssertFalse(SystemEventHUDPolicy.shouldInterrupt(currentKind: .volume, incomingKind: .screenshot, sayInputLocked: true))
    }
}
