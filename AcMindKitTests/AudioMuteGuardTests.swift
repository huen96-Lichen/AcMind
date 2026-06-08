import XCTest
@testable import AcMindKit

final class MockVolumeController: VolumeControlling, @unchecked Sendable {
    var currentVolume: Float32 = 0.75
    private(set) var setVolumeCallCount = 0

    func getVolume() -> Float32 {
        currentVolume
    }

    func setVolume(_ volume: Float32) {
        setVolumeCallCount += 1
        currentVolume = volume
    }
}

final class AudioMuteGuardTests: XCTestCase {

    func testMuteAndUnmute() {
        let mock = MockVolumeController()
        mock.currentVolume = 0.6
        let guard_ = AudioMuteGuard(volumeController: mock)

        guard_.mute()
        XCTAssertEqual(mock.currentVolume, 0)
        XCTAssertEqual(mock.setVolumeCallCount, 1)

        guard_.unmute()
        XCTAssertEqual(mock.currentVolume, 0.6)
        XCTAssertEqual(mock.setVolumeCallCount, 2)
    }

    func testDoubleMuteIsIdempotent() {
        let mock = MockVolumeController()
        mock.currentVolume = 0.5
        let guard_ = AudioMuteGuard(volumeController: mock)

        guard_.mute()
        mock.currentVolume = 0.9
        guard_.mute()

        XCTAssertEqual(mock.currentVolume, 0.9)
        XCTAssertEqual(mock.setVolumeCallCount, 1)
    }

    func testUnmuteWithoutMuteIsNoOp() {
        let mock = MockVolumeController()
        mock.currentVolume = 0.8
        let guard_ = AudioMuteGuard(volumeController: mock)

        guard_.unmute()

        XCTAssertEqual(mock.currentVolume, 0.8)
        XCTAssertEqual(mock.setVolumeCallCount, 0)
    }

    func testForceRestore() {
        let mock = MockVolumeController()
        mock.currentVolume = 0.4
        let guard_ = AudioMuteGuard(volumeController: mock)

        guard_.mute()
        XCTAssertEqual(mock.currentVolume, 0)

        guard_.forceRestore()
        XCTAssertEqual(mock.currentVolume, 0.4)
        XCTAssertEqual(mock.setVolumeCallCount, 2)
    }

    func testForceRestoreWithoutMuteIsNoOp() {
        let mock = MockVolumeController()
        mock.currentVolume = 0.7
        let guard_ = AudioMuteGuard(volumeController: mock)

        guard_.forceRestore()

        XCTAssertEqual(mock.currentVolume, 0.7)
        XCTAssertEqual(mock.setVolumeCallCount, 0)
    }
}
