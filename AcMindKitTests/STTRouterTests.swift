import XCTest
@testable import AcMindKit

final class STTRouterTests: XCTestCase {
    func testTranscribeStreamFallsBackToAppleSpeechViaLazyLoadedCompatibilityPath() async throws {
        let tracker = ProviderRequestTracker()

        let router = STTRouter(
            provider: .openAI,
            transcriberFactory: { provider in
                await tracker.record(provider)

                switch provider {
                case .openAI:
                    return FailingTranscriber()
                case .appleSpeech:
                    return EchoTranscriber(text: "兼容兜底结果")
                default:
                    return EchoTranscriber(text: "\(provider.rawValue)-unused")
                }
            }
        )

        let updates = SnapshotRecorder()
        let result = try await router.transcribeStream(
            audioFile: AudioFile(url: URL(fileURLWithPath: "/tmp/demo.m4a"))
        ) { snapshot in
            await updates.record(snapshot)
        }

        XCTAssertEqual(result, "兼容兜底结果")
        let recordedProviders = await tracker.recordedProviders()
        XCTAssertEqual(recordedProviders, [.openAI, .appleSpeech])

        let recordedSnapshots = await updates.snapshots
        XCTAssertEqual(recordedSnapshots.count, 1)
        XCTAssertEqual(recordedSnapshots.first?.text, "兼容兜底结果")
        XCTAssertTrue(recordedSnapshots.first?.isFinal == true)
    }

    func testLanguageSpecificTranscriptionFallsBackToCurrentProviderWhenPreferredProviderFails() async throws {
        let tracker = ProviderRequestTracker()

        let router = STTRouter(
            provider: .openAI,
            transcriberFactory: { provider in
                await tracker.record(provider)

                switch provider {
                case .senseVoice:
                    return FailingTranscriber()
                case .openAI:
                    return EchoTranscriber(text: "当前提供方兜底结果")
                case .appleSpeech:
                    return EchoTranscriber(text: "系统听写兜底结果")
                default:
                    return EchoTranscriber(text: "\(provider.rawValue)-unused")
                }
            }
        )

        let result = try await router.transcribe(
            audioFile: AudioFile(url: URL(fileURLWithPath: "/tmp/demo.m4a")),
            language: "zh"
        )

        XCTAssertEqual(result, "当前提供方兜底结果")
        let recordedProviders = await tracker.recordedProviders()
        XCTAssertEqual(recordedProviders, [.senseVoice, .openAI])
    }
}

private actor ProviderRequestTracker {
    private(set) var providers: [STTProvider] = []

    func record(_ provider: STTProvider) {
        providers.append(provider)
    }

    func recordedProviders() -> [STTProvider] {
        providers
    }
}

private actor SnapshotRecorder {
    private(set) var snapshots: [TranscriptionSnapshot] = []

    func record(_ snapshot: TranscriptionSnapshot) {
        snapshots.append(snapshot)
    }
}

private final class FailingTranscriber: Transcriber, @unchecked Sendable {
    func transcribe(audioFile: AudioFile) async throws -> String {
        throw TestTranscriberError.failure
    }

    func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        throw TestTranscriberError.failure
    }

    func createRealtimeSession() -> RealtimeTranscriptionSession? {
        nil
    }
}

private final class EchoTranscriber: Transcriber, @unchecked Sendable {
    let text: String

    init(text: String) {
        self.text = text
    }

    func transcribe(audioFile: AudioFile) async throws -> String {
        text
    }

    func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        let snapshot = TranscriptionSnapshot(text: text, isFinal: true)
        await onUpdate(snapshot)
        return text
    }

    func createRealtimeSession() -> RealtimeTranscriptionSession? {
        nil
    }
}

private enum TestTranscriberError: Error {
    case failure
}
