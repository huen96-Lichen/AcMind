import Foundation

public protocol VoiceServiceProtocol: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> String
    func transcribe(audioURL: URL) async throws -> String
    func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?) async throws -> String
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?, language: String) async throws -> String
    func getRecordingStatus() async -> RecordingStatus
}

public extension VoiceServiceProtocol {
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String] = [], customSystemPrompt: String? = nil, contextInfo: String? = nil) async throws -> String {
        try await polishTranscript(text, mode: mode)
    }

    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String] = [], customSystemPrompt: String? = nil, contextInfo: String? = nil, language: String = "auto") async throws -> String {
        try await polishTranscript(text, mode: mode, hotwords: hotwords, customSystemPrompt: customSystemPrompt, contextInfo: contextInfo)
    }
}
