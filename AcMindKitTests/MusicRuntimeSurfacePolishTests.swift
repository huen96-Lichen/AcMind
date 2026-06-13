import XCTest

final class MusicRuntimeSurfacePolishTests: XCTestCase {
    func testRuntimeMusicSurfaceIncludesSourceLabelWhenAvailable() throws {
        let source = try readSource("Features/Companion/NotchRuntimeSurface.swift")

        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.trackSummaryLabel"))
        XCTAssertTrue(source.contains("bundleIdentifier: context.playbackState.bundleIdentifier"))
        XCTAssertTrue(source.contains("trackSummary"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
