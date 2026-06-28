import XCTest
@testable import AcMindKit

@MainActor
final class VoiceServiceProtocolTests: XCTestCase {
    func testStatusHandlerCanBeInstalledAndInvokedThroughProtocol() async {
        let service = VoiceServiceMock()
        var receivedStatus: RecordingStatus?
        let expectation = expectation(description: "voice status handler invoked")

        await service.setStatusHandler { status in
            Task { @MainActor in
                receivedStatus = status
                expectation.fulfill()
            }
        }

        await service.triggerStatus(.recording)
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedStatus, .recording)
    }
}

private final class VoiceServiceMock: @unchecked Sendable, VoiceServiceProtocol {
    private var statusHandler: (@Sendable (RecordingStatus) -> Void)?

    func startRecording() async throws {}
    func stopRecording() async throws -> String { "" }
    func setStatusHandler(_ handler: @escaping @Sendable (RecordingStatus) -> Void) async {
        statusHandler = handler
    }
    func transcribe(audioURL: URL) async throws -> String { "" }
    func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String { text }
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?) async throws -> String { text }
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?, language: String) async throws -> String { text }
    func polishTranscriptStream(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?, language: String, onChunk: @escaping @Sendable (String) async -> Void) async throws -> String {
        await onChunk(text)
        return text
    }
    func translateTranscript(_ text: String, targetLanguage: String, contextInfo: String?) async throws -> String { text }
    func translateTranscriptStream(_ text: String, targetLanguage: String, contextInfo: String?, onChunk: @escaping @Sendable (String) async -> Void) async throws -> String {
        await onChunk(text)
        return text
    }
    func getRecordingStatus() async -> RecordingStatus { .idle }
    func startRealtimeTranscription(onUpdate: @escaping @Sendable (TranscriptionSnapshot) -> Void) async throws {}
    func stopRealtimeTranscription() async throws -> String { "" }
    var isRealtimeActive: Bool { get async { false } }

    func triggerStatus(_ status: RecordingStatus) async {
        statusHandler?(status)
    }
}
