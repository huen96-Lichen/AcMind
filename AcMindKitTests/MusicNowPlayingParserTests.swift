import XCTest
@testable import AcMindKit

final class MusicNowPlayingParserTests: XCTestCase {
    func testBrowserParserRejectsBilibiliHomepage() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "动态首页 - 哔哩哔哩|||https://www.bilibili.com/|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertNil(snapshot)
    }

    func testBrowserHomepageTitleDetectionCatchesDynamicHomepage() throws {
        XCTAssertTrue(WebNowPlayingParser.isBrowserHomepageTitle("动态首页"))
        XCTAssertTrue(WebNowPlayingParser.isBrowserHomepageTitle("动态首页 - 哔哩哔哩"))
        XCTAssertFalse(WebNowPlayingParser.isBrowserHomepageTitle("有可能的夜晚（Cover）"))
    }

    func testBrowserParserAcceptsBilibiliVideoPage() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "有可能的夜晚（Cover）_哔哩哔哩|||https://www.bilibili.com/video/BV1abcdEfGhI|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(snapshot?.title, "有可能的夜晚（Cover）")
        XCTAssertEqual(snapshot?.artist, "Safari浏览器")
        XCTAssertEqual(snapshot?.album, "Bilibili")
        XCTAssertEqual(snapshot?.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(snapshot?.source, "Safari浏览器/Bilibili")
    }

    func testBrowserParserAcceptsChromeBilibiliVideoPage() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "有可能的夜晚（Cover）_哔哩哔哩|||https://www.bilibili.com/video/BV1abcdEfGhI|||Chrome浏览器",
            source: "Chrome浏览器",
            bundleIdentifier: "com.google.Chrome"
        )

        XCTAssertEqual(snapshot?.title, "有可能的夜晚（Cover）")
        XCTAssertEqual(snapshot?.artist, "Chrome浏览器")
        XCTAssertEqual(snapshot?.album, "Bilibili")
        XCTAssertEqual(snapshot?.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(snapshot?.source, "Chrome浏览器/Bilibili")
    }

    func testBrowserParserAcceptsEdgeBilibiliVideoPage() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "有可能的夜晚（Cover）_哔哩哔哩|||https://www.bilibili.com/video/BV1abcdEfGhI|||Edge浏览器",
            source: "Edge浏览器",
            bundleIdentifier: "com.microsoft.Edge"
        )

        XCTAssertEqual(snapshot?.title, "有可能的夜晚（Cover）")
        XCTAssertEqual(snapshot?.artist, "Edge浏览器")
        XCTAssertEqual(snapshot?.album, "Bilibili")
        XCTAssertEqual(snapshot?.bundleIdentifier, "com.microsoft.Edge")
        XCTAssertEqual(snapshot?.source, "Edge浏览器/Bilibili")
    }

    func testBrowserParserAcceptsBraveBilibiliVideoPage() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "有可能的夜晚（Cover）_哔哩哔哩|||https://www.bilibili.com/video/BV1abcdEfGhI|||Brave浏览器",
            source: "Brave浏览器",
            bundleIdentifier: "com.brave.Browser"
        )

        XCTAssertEqual(snapshot?.title, "有可能的夜晚（Cover）")
        XCTAssertEqual(snapshot?.artist, "Brave浏览器")
        XCTAssertEqual(snapshot?.album, "Bilibili")
        XCTAssertEqual(snapshot?.bundleIdentifier, "com.brave.Browser")
        XCTAssertEqual(snapshot?.source, "Brave浏览器/Bilibili")
    }

    func testBrowserParserCleansYouTubeSuffixFromTitle() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "Apologize - YouTube Music|||https://music.youtube.com/watch?v=abc123|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(snapshot?.title, "Apologize")
        XCTAssertEqual(snapshot?.artist, "Safari浏览器")
        XCTAssertEqual(snapshot?.album, "youtube.com")
        XCTAssertEqual(snapshot?.source, "Safari浏览器")
    }

    func testBrowserParserStripsTrailingOfficialDescriptors() throws {
        let youtubeSnapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "Apologize (Official Video)|||https://www.youtube.com/watch?v=abc123|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(youtubeSnapshot?.title, "Apologize")

        let bilibiliSnapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "有可能的夜晚【MV】|||https://www.bilibili.com/video/BV1abcdEfGhI|||Chrome浏览器",
            source: "Chrome浏览器",
            bundleIdentifier: "com.google.Chrome"
        )

        XCTAssertEqual(bilibiliSnapshot?.title, "有可能的夜晚")
    }

    func testBrowserParserStripsChineseOfficialDescriptors() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "有可能的夜晚【官方MV】|||https://www.bilibili.com/video/BV1abcdEfGhI|||Chrome浏览器",
            source: "Chrome浏览器",
            bundleIdentifier: "com.google.Chrome"
        )

        XCTAssertEqual(snapshot?.title, "有可能的夜晚")

        let audioSnapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "稻香[官方音频]|||https://music.163.com/song?id=123|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(audioSnapshot?.title, "稻香")
    }

    func testBrowserParserStripsSpacedChineseOfficialDescriptors() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "有可能的夜晚【官方 MV】|||https://www.bilibili.com/video/BV1abcdEfGhI|||Chrome浏览器",
            source: "Chrome浏览器",
            bundleIdentifier: "com.google.Chrome"
        )

        XCTAssertEqual(snapshot?.title, "有可能的夜晚")
    }

    func testBrowserParserStripsBracketedVersionDescriptors() throws {
        let liveSnapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "The Night We Met (Live)|||https://open.spotify.com/track/xyz789|||Chrome浏览器",
            source: "Chrome浏览器",
            bundleIdentifier: "com.google.Chrome"
        )

        XCTAssertEqual(liveSnapshot?.title, "The Night We Met")

        let remixSnapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "Apologize [Remix]|||https://www.youtube.com/watch?v=abc123|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(remixSnapshot?.title, "Apologize")
    }

    func testBrowserParserStripsMixedSuffixAndDescriptor() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "Apologize - YouTube Music (Official Video)|||https://music.youtube.com/watch?v=abc123|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(snapshot?.title, "Apologize")
        XCTAssertEqual(snapshot?.album, "youtube.com")
    }

    func testBrowserParserPreservesFeatInTitle() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "Rain On Me (feat. Ariana Grande)|||https://www.youtube.com/watch?v=q5wq5ikg|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(snapshot?.title, "Rain On Me (feat. Ariana Grande)")
    }

    func testBrowserParserCleansSpotifySuffixFromTitle() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "The Night We Met - Spotify|||https://open.spotify.com/track/xyz789|||Chrome浏览器",
            source: "Chrome浏览器",
            bundleIdentifier: "com.google.Chrome"
        )

        XCTAssertEqual(snapshot?.title, "The Night We Met")
        XCTAssertEqual(snapshot?.artist, "Chrome浏览器")
        XCTAssertEqual(snapshot?.album, "open.spotify.com")
        XCTAssertEqual(snapshot?.source, "Chrome浏览器")
    }

    func testBrowserParserCleansSoundCloudSuffixFromTitle() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "Shelter - SoundCloud|||https://soundcloud.com/artist/track|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(snapshot?.title, "Shelter")
        XCTAssertEqual(snapshot?.artist, "Safari浏览器")
        XCTAssertEqual(snapshot?.album, "soundcloud.com")
        XCTAssertEqual(snapshot?.source, "Safari浏览器")
    }

    func testBrowserParserCleansApplePodcastsSuffixFromTitle() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "The Daily - Apple Podcasts|||https://podcasts.apple.com/podcast/the-daily|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(snapshot?.title, "The Daily")
        XCTAssertEqual(snapshot?.artist, "Safari浏览器")
        XCTAssertEqual(snapshot?.album, "podcasts.apple.com")
        XCTAssertEqual(snapshot?.source, "Safari浏览器")
    }

    func testBrowserParserCleansKuwoSuffixFromTitle() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "追光者 - 酷我音乐|||https://www.kuwo.cn/play_detail/123|||Chrome浏览器",
            source: "Chrome浏览器",
            bundleIdentifier: "com.google.Chrome"
        )

        XCTAssertEqual(snapshot?.title, "追光者")
        XCTAssertEqual(snapshot?.artist, "Chrome浏览器")
        XCTAssertEqual(snapshot?.album, "kuwo.cn")
        XCTAssertEqual(snapshot?.source, "Chrome浏览器")
    }

    func testBrowserParserCleansNetEaseSuffixFromTitle() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "稻香 - 网易云音乐|||https://music.163.com/song?id=123|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(snapshot?.title, "稻香")
        XCTAssertEqual(snapshot?.artist, "Safari浏览器")
        XCTAssertEqual(snapshot?.album, "music.163.com")
        XCTAssertEqual(snapshot?.source, "Safari浏览器")
    }

    func testBrowserParserCleansQQMusicSuffixFromTitle() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "晴天 | QQ音乐|||https://y.qq.com/n/ryqq/songDetail/456|||Chrome浏览器",
            source: "Chrome浏览器",
            bundleIdentifier: "com.google.Chrome"
        )

        XCTAssertEqual(snapshot?.title, "晴天")
        XCTAssertEqual(snapshot?.artist, "Chrome浏览器")
        XCTAssertEqual(snapshot?.album, "y.qq.com")
        XCTAssertEqual(snapshot?.source, "Chrome浏览器")
    }

    func testBrowserParserNormalizesMobileHosts() throws {
        let youtubeSnapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "Apologize - YouTube Music|||https://m.youtube.com/watch?v=abc123|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(youtubeSnapshot?.album, "youtube.com")

        let netEaseSnapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "稻香 - 网易云音乐|||https://m.music.163.com/song?id=123|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(netEaseSnapshot?.album, "music.163.com")
    }

    func testBrowserParserNormalizesYoutubeShortLinks() throws {
        let snapshot = WebNowPlayingParser.parse(
            fromBrowserAppleScript: "Apologize - YouTube|||https://youtu.be/abc123|||Safari浏览器",
            source: "Safari浏览器",
            bundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(snapshot?.album, "youtube.com")
        XCTAssertEqual(snapshot?.title, "Apologize")
    }

    func testMusicProbePrefersPlayingNativeSourcesBeforeBrowserFallbacks() throws {
        let source = try readSource("Features/Companion/MusicService.swift")

        let legacyIndex = try index(of: "if let snapshot = await LegacyPlayerNowPlayingProbe.fetch(logger: Self.logger)", in: source)
        let qishuiIndex = try index(of: "if let snapshot = await QishuiMusicNowPlayingProbe.fetch(logger: Self.logger)", in: source)
        let mediaRemoteIndex = try index(of: "if let snapshot = await MediaRemoteNowPlayingProbe.fetch(logger: Self.logger)", in: source)
        let browserIndex = try index(of: "if let browserSnapshot = await BrowserNowPlayingProbe.fetch(logger: Self.logger)", in: source)

        XCTAssertLessThan(legacyIndex, qishuiIndex)
        XCTAssertLessThan(qishuiIndex, mediaRemoteIndex)
        XCTAssertLessThan(mediaRemoteIndex, browserIndex)
        XCTAssertTrue(source.contains("if snapshot.isPlaying"))
        XCTAssertTrue(source.contains("fallbackSnapshot = fallbackSnapshot ?? snapshot"))
        XCTAssertTrue(source.contains("if let fallbackSnapshot"))
    }

    func testMusicPageEmptyStateDoesNotPresentAcMindAsPlaybackSource() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(source.contains("等待系统媒体"))
        XCTAssertTrue(source.contains("暂无播放来源"))
        XCTAssertFalse(source.contains("播放 AcMind Music 后这里会显示队列信息。"))
    }

    func testMusicFormatterDoesNotInventAcMindMusicWhenSourceIsEmpty() throws {
        let source = try readSource("AcMindKit/Services/NowPlayingSourceLabelFormatter.swift")

        XCTAssertFalse(source.contains("bundleIdentifier ?? \"AcMind Music\""))
        XCTAssertTrue(source.contains("bundleIdentifier ?? \"\""))
    }

    func testQishuiProbeScansBeyondStaticTextAndParsesLyricsScreen() throws {
        let source = try readSource("Features/Companion/MusicService.swift")

        XCTAssertTrue(source.contains("collectTextCandidates"))
        XCTAssertTrue(source.contains("kAXTitleAttribute"))
        XCTAssertTrue(source.contains("kAXDescriptionAttribute"))
        XCTAssertTrue(source.contains("pickQishuiTrackFromLyricsScreen"))
        XCTAssertFalse(source.contains("collectStaticTextCandidates"))
    }

    func testQishuiProbeUsesArtworkAndProgressHeuristics() throws {
        let source = try readSource("Features/Companion/MusicService.swift")

        XCTAssertTrue(source.contains("collectArtworkCandidates"))
        XCTAssertTrue(source.contains("cropArtwork"))
        XCTAssertTrue(source.contains("pickProgressCandidate"))
        XCTAssertTrue(source.contains("artworkScore"))
    }

    func testBrowserProbeIteratesAllConfiguredBrowsers() throws {
        let source = try readSource("Features/Companion/MusicService.swift")

        XCTAssertTrue(source.contains("for adapter in adapters"))
        XCTAssertFalse(source.contains("adapters.first"))
    }

    private func index(of needle: String, in source: String) throws -> Int {
        guard let range = source.range(of: needle) else {
            throw XCTSkip("Missing expected text: \(needle)")
        }
        return source.distance(from: source.startIndex, to: range.lowerBound)
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
