import XCTest
@testable import AcMindKit

final class ActivityStateLabelFormatterTests: XCTestCase {
    func testActivityLabelUsesActiveTextWhenActive() {
        XCTAssertEqual(
            ActivityStateLabelFormatter.activityLabel(
                isActive: true,
                activeLabel: "正在收音",
                idleLabel: "待命"
            ),
            "正在收音"
        )
    }

    func testActivityLabelUsesIdleTextWhenInactive() {
        XCTAssertEqual(
            ActivityStateLabelFormatter.activityLabel(
                isActive: false,
                activeLabel: "处理中",
                idleLabel: "待命"
            ),
            "待命"
        )
    }

    func testVoiceCompactLabelUsesTranscriptWhenListening() {
        XCTAssertEqual(
            ActivityStateLabelFormatter.voiceCompactLabel(
                state: .listening,
                realtimeTranscript: "当心慢慢靠近的时候"
            ),
            "收音中 · 当心慢慢靠近的时候"
        )
    }

    func testRecordingSubtitleLabelUsesEllipsisWhenTranscriptIsEmpty() {
        XCTAssertEqual(
            ActivityStateLabelFormatter.recordingSubtitleLabel(realtimeTranscript: ""),
            "收音中..."
        )
        XCTAssertEqual(
            ActivityStateLabelFormatter.recordingSubtitleLabel(realtimeTranscript: "快门按下"),
            "收音中 · 快门按下"
        )
    }
}
