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
}
