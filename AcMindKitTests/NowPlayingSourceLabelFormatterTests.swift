import XCTest
@testable import AcMindKit

final class NowPlayingSourceLabelFormatterTests: XCTestCase {
    func testSourceLabelPrefersExplicitBrowserSource() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.displayName(bundleIdentifier: "com.google.Chrome", source: "Chrome浏览器"),
            "Chrome浏览器"
        )
    }

    func testSourceLabelNormalizesBilibiliBrowserSource() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.displayName(bundleIdentifier: "com.apple.Safari", source: "Safari浏览器/Bilibili"),
            "Safari浏览器 · Bilibili"
        )
    }

    func testSourceLabelNormalizesMultiSegmentBrowserSource() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.displayName(bundleIdentifier: "com.apple.Safari", source: "Safari浏览器/Bilibili/Official"),
            "Safari浏览器 · Bilibili · Official"
        )
    }

    func testSourceLabelNormalizesFullWidthSlash() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.displayName(bundleIdentifier: "com.apple.Safari", source: "Safari浏览器／Bilibili"),
            "Safari浏览器 · Bilibili"
        )
    }

    func testSourceLabelDeduplicatesRepeatedSegments() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.displayName(bundleIdentifier: "com.apple.Safari", source: "Safari浏览器/Bilibili/Bilibili"),
            "Safari浏览器 · Bilibili"
        )
    }

    func testSourceLabelTrimsSegmentWhitespace() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.displayName(bundleIdentifier: "com.apple.Safari", source: " Safari浏览器 / Bilibili / Official "),
            "Safari浏览器 · Bilibili · Official"
        )
    }

    func testSourceLabelFallsBackToBundleFriendlyName() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.displayName(bundleIdentifier: "com.apple.Music", source: ""),
            "Apple Music"
        )
    }

    func testSourceLabelMapsChromiumBrowsers() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.displayName(bundleIdentifier: "com.microsoft.Edge", source: ""),
            "Edge浏览器"
        )
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.displayName(bundleIdentifier: "com.brave.Browser", source: ""),
            "Brave浏览器"
        )
    }

    func testPlaybackContextLabelUsesPlayingPrefixWhenActive() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.playbackContextLabel(
                isPlaying: true,
                source: "Safari浏览器/Bilibili"
            ),
            "播放中 · Safari浏览器/Bilibili"
        )
    }

    func testPlaybackContextLabelUsesIdlePrefixWhenPaused() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.playbackContextLabel(
                isPlaying: false,
                source: "",
                idlePrefix: "音乐"
            ),
            "音乐 · 音乐来源"
        )
    }

    func testPlaybackContextLabelUsesCustomFallbackSource() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.playbackContextLabel(
                isPlaying: false,
                source: "",
                idlePrefix: "音乐",
                fallbackSource: "AcMind Music"
            ),
            "音乐 · AcMind Music"
        )
    }

    func testPlaybackContextLabelUsesBundleFallbackWhenProvided() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.playbackContextLabel(
                isPlaying: false,
                bundleIdentifier: "com.apple.Music",
                source: ""
            ),
            "音乐 · Apple Music"
        )
    }

    func testSourceSuffixReturnsEmptyStringWhenMissing() {
        XCTAssertEqual(NowPlayingSourceLabelFormatter.sourceSuffix(""), "")
    }

    func testSourceSuffixPrefixesVisibleSources() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.sourceSuffix("Safari浏览器"),
            " · Safari浏览器"
        )
    }

    func testTrackDetailLabelCombinesTitleAndSource() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.trackDetailLabel(
                title: "Apologize",
                source: "Safari浏览器"
            ),
            "Apologize · Safari浏览器"
        )
    }

    func testTrackDetailLabelFallsBackWhenTitleIsMissing() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.trackDetailLabel(
                title: "",
                source: "Safari浏览器"
            ),
            "未命名 · Safari浏览器"
        )
    }

    func testTrackDetailLabelUsesBundleFallbackWhenSourceMissing() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.trackDetailLabel(
                title: "Apologize",
                bundleIdentifier: "com.apple.Music",
                source: ""
            ),
            "Apologize · Apple Music"
        )
    }

    func testArtistDetailLabelCombinesArtistAndSource() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.artistDetailLabel(
                artist: "little grass",
                source: "Safari浏览器"
            ),
            "little grass · Safari浏览器"
        )
    }

    func testArtistDetailLabelFallsBackWhenArtistIsMissing() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.artistDetailLabel(
                artist: "",
                source: "Safari浏览器"
            ),
            "未知艺术家 · Safari浏览器"
        )
    }

    func testArtistDetailLabelUsesBundleFallbackWhenSourceMissing() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.artistDetailLabel(
                artist: "little grass",
                bundleIdentifier: "com.apple.Music",
                source: ""
            ),
            "little grass · Apple Music"
        )
    }

    func testTrackSummaryLabelCombinesArtistAlbumAndSource() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.trackSummaryLabel(
                artist: "little grass",
                album: "有可能的夜晚",
                bundleIdentifier: "com.apple.Music",
                source: ""
            ),
            "little grass · 有可能的夜晚 · Apple Music"
        )
    }

    func testAlbumDetailLabelFallsBackWhenAlbumIsMissing() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.albumDetailLabel(
                album: "",
                bundleIdentifier: "com.apple.Music",
                source: ""
            ),
            "未知专辑 · Apple Music"
        )
    }

    func testPlaybackStateLabelUsesBundleFallbackWhenSourceMissing() {
        XCTAssertEqual(
            NowPlayingSourceLabelFormatter.playbackStateLabel(
                isPlaying: true,
                bundleIdentifier: "com.apple.Music",
                source: ""
            ),
            "播放中 · Apple Music"
        )
    }
}
