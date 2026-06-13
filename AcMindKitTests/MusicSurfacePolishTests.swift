import XCTest

final class MusicSurfacePolishTests: XCTestCase {
    func testCollapsedMusicSurfaceShowsSourceLabel() throws {
        let source = try readSource("Features/Companion/NotchV2CollapsedView.swift")

        XCTAssertTrue(source.contains("sourceBadgeText"))
        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.playbackContextLabel"))
        XCTAssertTrue(source.contains("bundleIdentifier: viewModel.playbackState.bundleIdentifier"))
        XCTAssertTrue(source.contains("viewModel.hasPlaybackContext"))
    }

    func testMusicPageSourceRowShowsPlayingState() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(source.contains("private var sourceTitle"))
        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.playbackContextLabel"))
        XCTAssertTrue(source.contains("bundleIdentifier: viewModel.playbackState.bundleIdentifier"))
        XCTAssertTrue(source.contains("idlePrefix: \"音乐\""))
    }

    func testMusicPageUsesThreeColumnWorkspace() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(source.contains("NotchV2DashboardLayout(leftColumnWidth: 224, rightColumnWidth: 224)"))
        XCTAssertTrue(source.contains("private var leftColumn"))
        XCTAssertTrue(source.contains("private var centerColumn"))
        XCTAssertTrue(source.contains("private var rightColumn"))
        XCTAssertTrue(source.contains("播放队列"))
    }

    func testMusicPageTrackSummaryUsesSharedFormatter() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(source.contains("private var trackSummaryText"))
        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.trackSummaryLabel"))
        XCTAssertTrue(source.contains("source: viewModel.playbackState.sourceLabel"))
    }

    func testMusicPageAlbumTextUsesSharedFormatter() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(source.contains("private var albumText"))
        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.albumDetailLabel"))
        XCTAssertTrue(source.contains("source: viewModel.playbackState.sourceLabel"))
    }

    func testMusicPageEmptyStateIncludesSourceContext() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(source.contains("private var emptyStatePlaybackContext"))
        XCTAssertTrue(source.contains("idlePrefix: \"当前没有播放内容\""))
        XCTAssertTrue(source.contains("lineLimit(2)"))
    }

    func testMusicPageQueueEmptyStateUsesSharedContextText() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(source.contains("private var queueEmptyStateTitle"))
        XCTAssertTrue(source.contains("private var queueEmptyStateDetail"))
        XCTAssertTrue(source.contains("idlePrefix: \"暂无队列\""))
    }

    func testMusicPageRightControlCardUsesFillHeight() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(source.contains("private var controlCard"))
        XCTAssertTrue(source.contains("fillHeight: true"))
        XCTAssertTrue(source.contains("viewModel.musicService.openMusicApp()"))
        XCTAssertTrue(source.contains("播放控制"))
        XCTAssertTrue(source.contains("frame(width: 66, height: 66)"))
    }

    func testMusicPageNoLongerDefinesLyricsWorkspace() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertFalse(source.contains("private var lyricsCard"))
        XCTAssertFalse(source.contains("title: \"歌词工作区\""))
        XCTAssertFalse(source.contains("viewModel.isLoadingLyrics"))
        XCTAssertFalse(source.contains("viewModel.lyrics"))
        XCTAssertFalse(source.contains("重试抓取"))
    }

    func testOverviewMusicSurfaceShowsSourceLabel() throws {
        let source = try readSource("Features/Companion/NotchV2OverviewPage.swift")

        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.playbackContextLabel"))
        XCTAssertTrue(source.contains("bundleIdentifier: viewModel.playbackState.bundleIdentifier"))
        XCTAssertTrue(source.contains("idlePrefix: \"音乐\""))
    }

    func testOverviewPageNoLongerKeepsPersistentMusicCard() throws {
        let source = try readSource("Features/Companion/NotchV2OverviewPage.swift")

        XCTAssertFalse(source.contains("MiniMusicPlayerView(musicService: viewModel.musicService)"))
        XCTAssertFalse(source.contains("音乐常驻"))
        XCTAssertTrue(source.contains("系统快览"))
    }

    func testLightStatusStripMediaItemUsesSharedSourceSuffix() throws {
        let source = try readSource("Features/Companion/NotchV2StatusStrip.swift")

        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.trackDetailLabel"))
        XCTAssertTrue(source.contains("bundleIdentifier: playbackState.bundleIdentifier"))
        XCTAssertTrue(source.contains("source: playbackState.sourceLabel"))
    }

    func testLightStatusStripMediaItemUsesSharedPlaybackStateLabel() throws {
        let source = try readSource("Features/Companion/NotchV2StatusStrip.swift")

        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.playbackStateLabel"))
        XCTAssertTrue(source.contains("pausedPrefix: \"已暂停\""))
        XCTAssertTrue(source.contains("playingPrefix: \"播放中\""))
        XCTAssertTrue(source.contains("NotchV2SurfacePriority.music.rawValue"))
    }

    func testMiniMusicPlayerEmptyStateUsesSharedPlaybackContextLabel() throws {
        let source = try readSource("Features/Companion/MusicService.swift")

        XCTAssertTrue(source.contains("NowPlayingSourceLabelFormatter.playbackContextLabel"))
        XCTAssertTrue(source.contains("idlePrefix: \"未播放\""))
        XCTAssertTrue(source.contains("bundleIdentifier: musicService.bundleIdentifier"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
