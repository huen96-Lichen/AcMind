import Foundation

public enum ActivityStateLabelFormatter {
    public static func activityLabel(
        isActive: Bool,
        activeLabel: String,
        idleLabel: String
    ) -> String {
        isActive ? activeLabel : idleLabel
    }

    public static func voiceCompactLabel(
        state: NotchV2VoiceSurfaceState,
        realtimeTranscript: String
    ) -> String {
        switch state {
        case .idle:
            return "说入法"
        case .listening:
            return transcriptLabel(prefix: "收音中", transcript: realtimeTranscript)
        case .processing:
            return "清洗中"
        case .completed:
            return "已写入"
        case .cancelled:
            return "已取消"
        }
    }

    public static func recordingSubtitleLabel(realtimeTranscript: String) -> String {
        realtimeTranscript.isEmpty ? "收音中..." : "收音中 · \(realtimeTranscript)"
    }

    private static func transcriptLabel(prefix: String, transcript: String) -> String {
        transcript.isEmpty ? prefix : "\(prefix) · \(transcript)"
    }
}
