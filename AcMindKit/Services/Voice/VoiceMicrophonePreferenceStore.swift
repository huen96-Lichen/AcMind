import Foundation

/// 语音输入的录音设备选择存储。
///
/// 选择值会被 `VoiceService` 在开始录音时读取，并用于切换当前默认输入设备。
public enum VoiceMicrophonePreferenceStore {
    public static let key = "voice.preferredMicrophoneName.v1"
    public static let defaultName = "自动选择"

    public static func load(from defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: key) ?? defaultName
    }

    public static func save(_ value: String, to defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: key)
    }
}
