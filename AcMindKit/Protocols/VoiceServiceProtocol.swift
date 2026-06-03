import Foundation

public protocol VoiceServiceProtocol: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> String
    func transcribe(audioURL: URL) async throws -> String
    func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?) async throws -> String
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?, language: String) async throws -> String
    func polishTranscriptStream(
        _ text: String,
        mode: VoicePolishMode,
        hotwords: [String],
        customSystemPrompt: String?,
        contextInfo: String?,
        language: String,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String
    func translateTranscript(
        _ text: String,
        targetLanguage: String,
        contextInfo: String?
    ) async throws -> String
    func translateTranscriptStream(
        _ text: String,
        targetLanguage: String,
        contextInfo: String?,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String
    func getRecordingStatus() async -> RecordingStatus
}

public extension VoiceServiceProtocol {
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String] = [], customSystemPrompt: String? = nil, contextInfo: String? = nil) async throws -> String {
        try await polishTranscript(text, mode: mode)
    }

    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String] = [], customSystemPrompt: String? = nil, contextInfo: String? = nil, language: String = "auto") async throws -> String {
        try await polishTranscript(text, mode: mode, hotwords: hotwords, customSystemPrompt: customSystemPrompt, contextInfo: contextInfo)
    }

    func polishTranscriptStream(
        _ text: String,
        mode: VoicePolishMode,
        hotwords: [String] = [],
        customSystemPrompt: String? = nil,
        contextInfo: String? = nil,
        language: String = "auto",
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let polished = try await polishTranscript(
            text,
            mode: mode,
            hotwords: hotwords,
            customSystemPrompt: customSystemPrompt,
            contextInfo: contextInfo,
            language: language
        )
        await onChunk(polished)
        return polished
    }

    func translateTranscript(
        _ text: String,
        targetLanguage: String,
        contextInfo: String? = nil
    ) async throws -> String {
        text
    }

    func translateTranscriptStream(
        _ text: String,
        targetLanguage: String,
        contextInfo: String? = nil,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        await onChunk(text)
        return text
    }
}
