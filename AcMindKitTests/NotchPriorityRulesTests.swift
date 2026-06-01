import XCTest
@testable import AcMindKit

final class NotchPriorityRulesTests: XCTestCase {
    func testVoiceRecordingRanksAboveEveryOtherCollapsedState() {
        XCTAssertLessThan(NotchV2SurfacePriority.voiceRecording.rawValue, NotchV2SurfacePriority.voiceProcessing.rawValue)
        XCTAssertLessThan(NotchV2SurfacePriority.voiceRecording.rawValue, NotchV2SurfacePriority.screenshot.rawValue)
        XCTAssertLessThan(NotchV2SurfacePriority.voiceRecording.rawValue, NotchV2SurfacePriority.systemEventHUD.rawValue)
        XCTAssertLessThan(NotchV2SurfacePriority.voiceRecording.rawValue, NotchV2SurfacePriority.music.rawValue)
        XCTAssertLessThan(NotchV2SurfacePriority.voiceRecording.rawValue, NotchV2SurfacePriority.defaultState.rawValue)
    }

    func testPriorityOrderMatchesProductRequirements() {
        let ordered: [NotchV2SurfacePriority] = [
            .voiceRecording,
            .voiceProcessing,
            .screenshot,
            .systemEventHUD,
            .music,
            .defaultState
        ]

        XCTAssertEqual(ordered.map(\.rawValue), [0, 1, 2, 3, 4, 5])
    }
}
