import XCTest

final class MusicNowPlayingStateResetTests: XCTestCase {
    func testMusicServiceClearsStaleStateWhenNoSourceFound() throws {
        let source = try readSource("Features/Companion/MusicService.swift")

        XCTAssertTrue(source.contains("clearNowPlayingState()"))
        XCTAssertTrue(source.contains("songTitle = \"\""))
        XCTAssertTrue(source.contains("lyrics = nil"))
        XCTAssertTrue(source.contains("lastLyricsKey = nil"))
    }

    func testMusicServicePrefersRealMusicBeforeBrowserPlayback() throws {
        let source = try readSource("Features/Companion/MusicService.swift")
        let legacyRange = source.range(of: "LegacyPlayerNowPlayingProbe.fetch")
        let mediaRemoteRange = source.range(of: "MediaRemoteNowPlayingProbe.fetch")
        let browserRange = source.range(of: "BrowserNowPlayingProbe.fetch")

        XCTAssertNotNil(legacyRange)
        XCTAssertNotNil(mediaRemoteRange)
        XCTAssertNotNil(browserRange)
        if let legacyRange, let mediaRemoteRange, let browserRange {
            XCTAssertLessThan(source.distance(from: source.startIndex, to: legacyRange.lowerBound), source.distance(from: source.startIndex, to: mediaRemoteRange.lowerBound))
            XCTAssertLessThan(source.distance(from: source.startIndex, to: mediaRemoteRange.lowerBound), source.distance(from: source.startIndex, to: browserRange.lowerBound))
        }
        XCTAssertTrue(source.contains("allowBrowserBundles: false"))
    }

    func testQishuiProbeFallsBackToVisibleWindowOCR() throws {
        let source = try readSource("Features/Companion/MusicService.swift")

        XCTAssertTrue(source.contains("visibleWindowFrame(for:"))
        XCTAssertTrue(source.contains("CGWindowListCopyWindowInfo"))
        XCTAssertTrue(source.contains("collectOCRTextCandidates(from: windowFrame"))
        XCTAssertTrue(source.contains("AXIsProcessTrusted()"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
