import Foundation

public protocol VoiceServiceProtocol: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> String
    func transcribe(audioURL: URL) async throws -> String
    func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String
    func getRecordingStatus() async -> RecordingStatus
}
