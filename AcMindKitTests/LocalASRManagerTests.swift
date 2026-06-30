import XCTest
@testable import AcMindKit

final class LocalASRManagerTests: XCTestCase {
    func testAvailableModelsIncludeAllRoutableLocalProviders() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = LocalASRManager(modelsDirectory: root)
        let models = await manager.listAvailableModels()
        let ids = Set(models.map(\.id))

        XCTAssertTrue(ids.contains("sensevoice-small"))
        XCTAssertTrue(ids.contains("whisperkit-medium"))
        XCTAssertTrue(ids.contains("funasr-paraformer"))
        XCTAssertTrue(ids.contains("qwen3-asr-0.6b"))
        XCTAssertTrue(ids.contains("parakeet-tdt-0.6b-v2"))
    }

    func testSherpaModelRequiresExpectedFilesBeforeItIsMarkedDownloaded() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let senseVoiceDirectory = root.appendingPathComponent("sense_voice_small", isDirectory: true)
        try FileManager.default.createDirectory(at: senseVoiceDirectory, withIntermediateDirectories: true)

        let manager = LocalASRManager(modelsDirectory: root)
        let initiallyDownloaded = await manager.isModelDownloaded("sensevoice-small")
        XCTAssertFalse(initiallyDownloaded)

        try Data().write(to: senseVoiceDirectory.appendingPathComponent("model.int8.onnx"))
        try Data().write(to: senseVoiceDirectory.appendingPathComponent("tokens.txt"))

        let downloadedAfterArtifacts = await manager.isModelDownloaded("sensevoice-small")
        XCTAssertTrue(downloadedAfterArtifacts)
    }

    func testWhisperKitModelDirectoryMustContainModelArtifacts() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let whisperDirectory = root.appendingPathComponent("whisperkit-medium", isDirectory: true)
        try FileManager.default.createDirectory(at: whisperDirectory, withIntermediateDirectories: true)

        let manager = LocalASRManager(modelsDirectory: root)
        let initiallyDownloaded = await manager.isModelDownloaded("whisperkit-medium")
        XCTAssertFalse(initiallyDownloaded)

        try Data().write(to: whisperDirectory.appendingPathComponent("AudioEncoder.mlmodelc"))

        let downloadedAfterArtifact = await manager.isModelDownloaded("whisperkit-medium")
        XCTAssertTrue(downloadedAfterArtifact)
    }

    func testWhisperKitDetectsArtifactsInDownloadedNestedLayout() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root
            .appendingPathComponent("whisperkit-medium/models/argmaxinc/whisperkit-coreml/openai_whisper-medium", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data().write(to: nested.appendingPathComponent("AudioEncoder.mlmodelc"))

        let manager = LocalASRManager(modelsDirectory: root)
        let isDownloaded = await manager.isModelDownloaded("whisperkit-medium")
        XCTAssertTrue(isDownloaded)
    }

    func testArchiveInstallerFlattensSingleTopLevelDirectory() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = root.appendingPathComponent("staging", isDirectory: true)
        let archiveRoot = staging.appendingPathComponent("upstream-versioned-name", isDirectory: true)
        let destination = root.appendingPathComponent("sense_voice_small", isDirectory: true)
        try FileManager.default.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
        try Data().write(to: archiveRoot.appendingPathComponent("model.int8.onnx"))
        try Data().write(to: archiveRoot.appendingPathComponent("tokens.txt"))

        try LocalASRManager.installExtractedContents(from: staging, to: destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("model.int8.onnx").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("upstream-versioned-name").path))
    }

    func testParakeetRequiresTransducerArtifacts() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = root.appendingPathComponent("parakeet", isDirectory: true)
        try FileManager.default.createDirectory(at: model, withIntermediateDirectories: true)
        for name in ["encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt"] {
            try Data().write(to: model.appendingPathComponent(name))
        }
        let decoder = SherpaOnnxCommandLineDecoder(
            model: .parakeet,
            modelIdentifier: SherpaOnnxModel.parakeet.defaultModelIdentifier,
            modelFolder: root.path
        )
        XCTAssertTrue(decoder.isModelInstalled(storageURL: root))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind-LocalASRManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
