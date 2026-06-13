import XCTest

final class MusicOverviewPolishTests: XCTestCase {
    func testOverviewCurrentTaskSourceMentionsPlayingState() throws {
        let source = try readSource("Features/Companion/NotchV2OverviewPage.swift")

        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.playbackContextLabel"))
        XCTAssertTrue(source.contains("idlePrefix: \"音乐\""))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
