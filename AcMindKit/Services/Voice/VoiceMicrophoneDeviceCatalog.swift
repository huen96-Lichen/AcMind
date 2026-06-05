import Foundation
import AVFoundation
import CoreAudio

public struct VoiceMicrophoneDevice: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum VoiceMicrophoneDeviceCatalog {
    public static func availableInputDevices() -> [VoiceMicrophoneDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        return session.devices
            .map { VoiceMicrophoneDevice(id: $0.uniqueID, name: $0.localizedName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public static func displayName(for selection: String) -> String {
        guard selection != VoiceMicrophonePreferenceStore.defaultName else {
            return VoiceMicrophonePreferenceStore.defaultName
        }

        if let device = availableInputDevices().first(where: { $0.id == selection || $0.name == selection }) {
            return device.name
        }

        return selection
    }

    public static func applySelection(_ selection: String) -> AudioDeviceID? {
        guard selection != VoiceMicrophonePreferenceStore.defaultName else {
            return nil
        }

        guard let deviceID = resolveAudioDeviceID(for: selection) else {
            return nil
        }

        let previousDefault = currentDefaultInputDeviceID()
        guard setDefaultInputDevice(deviceID) else {
            return nil
        }

        return previousDefault
    }

    public static func restoreDefaultInputDevice(id: AudioDeviceID?) {
        guard let id else { return }
        _ = setDefaultInputDevice(id)
    }

    public static func currentDefaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID()
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr else { return nil }
        return deviceID
    }

    private static func resolveAudioDeviceID(for selection: String) -> AudioDeviceID? {
        for deviceID in allAudioDeviceIDs() {
            if let uid = deviceUID(for: deviceID), uid == selection {
                return deviceID
            }

            if let name = deviceName(for: deviceID), name == selection {
                return deviceID
            }
        }

        return nil
    }

    private static func allAudioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0

        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }

        var deviceIDs = Array(repeating: AudioDeviceID(), count: count)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else { return [] }
        return deviceIDs
    }

    private static func deviceName(for deviceID: AudioDeviceID) -> String? {
        var name = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status: OSStatus = withUnsafeMutableBytes(of: &name) { rawBytes in
            guard let baseAddress = rawBytes.baseAddress else {
                return OSStatus(-1)
            }
            return AudioObjectGetPropertyData(
                AudioObjectID(deviceID),
                &address,
                0,
                nil,
                &size,
                baseAddress
            )
        }

        guard status == noErr else { return nil }
        return name as String
    }

    private static func deviceUID(for deviceID: AudioDeviceID) -> String? {
        var uid = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status: OSStatus = withUnsafeMutableBytes(of: &uid) { rawBytes in
            guard let baseAddress = rawBytes.baseAddress else {
                return OSStatus(-1)
            }
            return AudioObjectGetPropertyData(
                AudioObjectID(deviceID),
                &address,
                0,
                nil,
                &size,
                baseAddress
            )
        }

        guard status == noErr else { return nil }
        return uid as String
    }

    private static func setDefaultInputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var mutableDeviceID = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &mutableDeviceID
        )

        return status == noErr
    }
}
