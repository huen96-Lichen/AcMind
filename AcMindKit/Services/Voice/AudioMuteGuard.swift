import AVFoundation
import CoreAudio

public protocol VolumeControlling: Sendable {
    func getVolume() -> Float32
    func setVolume(_ volume: Float32)
}

public struct SystemVolumeController: VolumeControlling {
    public init() {}

    public func getVolume() -> Float32 {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &defaultOutputDeviceIDSize,
            &defaultOutputDeviceID
        )

        var volume: Float32 = 1.0
        var volumeSize = UInt32(MemoryLayout<Float32>.size)
        address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &address,
            0,
            nil,
            &volumeSize,
            &volume
        )
        return volume
    }

    public func setVolume(_ volume: Float32) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &defaultOutputDeviceIDSize,
            &defaultOutputDeviceID
        )

        var vol = volume
        let volumeSize = UInt32(MemoryLayout<Float32>.size)
        address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &address,
            0,
            nil,
            volumeSize,
            &vol
        )
    }
}

public final class AudioMuteGuard: @unchecked Sendable {
    public static let shared = AudioMuteGuard()

    private let volumeController: VolumeControlling
    private var previousVolume: Float32 = 1.0
    private var isMuted = false

    public init(volumeController: VolumeControlling = SystemVolumeController()) {
        self.volumeController = volumeController
    }

    public func forceRestore() {
        guard isMuted else { return }
        volumeController.setVolume(previousVolume)
        isMuted = false
    }

    public func mute() {
        guard !isMuted else { return }
        previousVolume = volumeController.getVolume()
        volumeController.setVolume(0)
        isMuted = true
    }

    public func unmute() {
        guard isMuted else { return }
        volumeController.setVolume(previousVolume)
        isMuted = false
    }

    deinit {
        unmute()
    }
}
