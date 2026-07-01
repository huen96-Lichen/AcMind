import XCTest
@testable import AcMindKit

final class STTProviderTests: XCTestCase {
    func testNormalizedIdentifierMapsLegacyValuesToCanonicalProviderIDs() {
        XCTAssertEqual(STTProvider.normalizedIdentifier("whisper"), STTProvider.openAI.rawValue)
        XCTAssertEqual(STTProvider.normalizedIdentifier("whisper_api"), STTProvider.openAI.rawValue)
        XCTAssertEqual(STTProvider.normalizedIdentifier("whisper_local"), STTProvider.senseVoice.rawValue)
        XCTAssertEqual(STTProvider.normalizedIdentifier("system"), STTProvider.appleSpeech.rawValue)
        XCTAssertEqual(STTProvider.normalizedIdentifier("senseVoice"), STTProvider.senseVoice.rawValue)
        XCTAssertEqual(STTProvider.normalizedIdentifier("funASR"), STTProvider.funASR.rawValue)
    }

    func testSelectableIdentifierFallsBackToAppleSpeechForUnsupportedProviders() {
        XCTAssertEqual(STTProvider.selectableIdentifier(from: STTProvider.openAI.rawValue), STTProvider.openAI.rawValue)
        XCTAssertEqual(STTProvider.selectableIdentifier(from: STTProvider.groq.rawValue), STTProvider.appleSpeech.rawValue)
        XCTAssertEqual(STTProvider.selectableIdentifier(from: STTProvider.freeModel.rawValue), STTProvider.appleSpeech.rawValue)
    }

    func testSelectableProviderNormalizesUnsupportedValuesToAppleSpeech() {
        XCTAssertEqual(STTProvider.selectableProvider(from: .openAI), .openAI)
        XCTAssertEqual(STTProvider.selectableProvider(from: .groq), .appleSpeech)
        XCTAssertEqual(STTProvider.selectableProvider(from: .freeModel), .appleSpeech)
    }
}
