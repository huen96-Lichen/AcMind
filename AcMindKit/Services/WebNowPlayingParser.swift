import Foundation

public struct WebNowPlayingMetadata: Sendable, Equatable {
    public let title: String
    public let artist: String
    public let album: String
    public let bundleIdentifier: String
    public let source: String

    public init(title: String, artist: String, album: String, bundleIdentifier: String, source: String) {
        self.title = title
        self.artist = artist
        self.album = album
        self.bundleIdentifier = bundleIdentifier
        self.source = source
    }
}

public enum WebNowPlayingParser {
    public static func isBrowserHomepageTitle(_ title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else { return false }

        let homepageKeywords = [
            "动态首页",
            "首页",
            "推荐",
            "关注",
            "收藏",
            "历史",
            "稍后再看"
        ]

        return homepageKeywords.contains(where: { trimmedTitle.localizedCaseInsensitiveContains($0) })
    }

    public static func parse(
        fromBrowserAppleScript output: String,
        source: String,
        bundleIdentifier: String
    ) -> WebNowPlayingMetadata? {
        guard output.isEmpty == false else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 3 else { return nil }

        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let second = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let third = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespacesAndNewlines) : source
        let urlString = second.contains("://") ? second : ""
        let browserLabel = second.contains("://") ? third : second
        let url = URL(string: urlString)
        let host = url?.host?.lowercased() ?? ""
        let path = url?.path.lowercased() ?? ""
        let displayTitle = cleanBrowserTitle(title, host: host)

        if isBilibiliHomepage(host: host, path: path, title: displayTitle) {
            return nil
        }

        guard isLikelyBrowserMediaSource(host: host, title: displayTitle) else {
            return nil
        }

        let isBilibili = host.contains("bilibili.com") || displayTitle.localizedCaseInsensitiveContains("bilibili") || displayTitle.contains("哔哩哔哩")
        guard displayTitle.isEmpty == false else { return nil }

        return WebNowPlayingMetadata(
            title: displayTitle,
            artist: browserLabel.isEmpty ? source : browserLabel,
            album: isBilibili ? "Bilibili" : normalizeAlbumHost(url?.host ?? urlString),
            bundleIdentifier: bundleIdentifier,
            source: isBilibili ? "\(source)/Bilibili" : source
        )
    }

    static func cleanBrowserTitle(_ raw: String, host: String) -> String {
        let normalizedHost = host.lowercased()
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffixes = browserTrailingSuffixes(for: normalizedHost)

        // First remove platform-specific suffixes, then generic descriptive tails.
        // Re-run until the title stops changing so stacked suffixes collapse cleanly.
        while true {
            let previous = title
            title = stripKnownSuffixes(from: title, suffixes: suffixes)
            title = stripTrailingDescriptors(from: title)
            title = trimDanglingSeparators(from: title)
            if title == previous {
                break
            }
        }

        return title
    }

    private static func browserTrailingSuffixes(for host: String) -> [String] {
        var suffixes = [
            " - YouTube",
            " - YouTube Music",
            " — YouTube",
            " | YouTube",
            " | YouTube Music"
        ]

        if host.contains("spotify.com") {
            suffixes.append(contentsOf: [
                " - Spotify",
                " | Spotify"
            ])
        }

        if host.contains("apple.com") || host.contains("music.apple.com") {
            suffixes.append(contentsOf: [
                " - Apple Music",
                " | Apple Music",
                " - Apple Podcasts",
                " | Apple Podcasts"
            ])
        }

        if host.contains("bilibili.com") {
            suffixes.append(contentsOf: [
                " - bilibili",
                " - 哔哩哔哩",
                "_哔哩哔哩",
                " | 哔哩哔哩"
            ])
        }

        if host.contains("music.163.com") {
            suffixes.append(contentsOf: [
                " - 网易云音乐",
                " | 网易云音乐"
            ])
        }

        if host.contains("qq.com") || host.contains("y.qq.com") {
            suffixes.append(contentsOf: [
                " - QQ音乐",
                " | QQ音乐"
            ])
        }

        if host.contains("soundcloud.com") {
            suffixes.append(contentsOf: [
                " - SoundCloud",
                " | SoundCloud"
            ])
        }

        if host.contains("kuwo.cn") {
            suffixes.append(contentsOf: [
                " - 酷我音乐",
                " | 酷我音乐",
                " - Kuwo Music",
                " | Kuwo Music"
            ])
        }

        if host.contains("kugou.com") {
            suffixes.append(contentsOf: [
                " - 酷狗音乐",
                " | 酷狗音乐",
                " - Kugou Music",
                " | Kugou Music"
            ])
        }

        return suffixes
    }

    private static func stripKnownSuffixes(from title: String, suffixes: [String]) -> String {
        for suffix in suffixes where title.hasSuffix(suffix) {
            return String(title.dropLast(suffix.count))
        }
        return title
    }

    private static func trimDanglingSeparators(from title: String) -> String {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-_|—·"))
        return title.trimmingCharacters(in: separators)
    }

    private static let trailingDescriptorRegexes: [NSRegularExpression] = {
        let patterns = [
            #"\s*[\(\[【（]\s*(official video|official audio|official music video|music video|audio|lyrics|lyric video|mv|topic|visualizer|clean version|explicit|4k|8k|hd|uhd|full album|中字|中文字幕|中字版|官方\s*mv|官方\s*音频|官方\s*音乐视频|官方\s*视频|live|remix|radio edit|acoustic|instrumental|karaoke|sped up|slowed|nightcore|performance)\s*[\)\]】）]\s*$"#,
            #"\s*-\s*(topic|official video|official audio|official music video|music video|audio|lyrics|lyric video|mv|visualizer)\s*$"#,
        ]

        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    private static func stripTrailingDescriptors(from title: String) -> String {
        for regex in trailingDescriptorRegexes {
            let range = NSRange(title.startIndex..<title.endIndex, in: title)
            if let match = regex.firstMatch(in: title, options: [], range: range), match.range.location != NSNotFound {
                if let swiftRange = Range(match.range, in: title) {
                    return String(title[..<swiftRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return title
    }

    private static func normalizeAlbumHost(_ host: String) -> String {
        if host == "music.youtube.com" {
            return "youtube.com"
        }

        if host == "youtu.be" {
            return "youtube.com"
        }

        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }

        if host.hasPrefix("m.") {
            return String(host.dropFirst(2))
        }

        return host
    }

    static func isBilibiliHomepage(host: String, path: String, title: String) -> Bool {
        guard host.contains("bilibili.com") else { return false }

        let playablePathMarkers = [
            "/video/",
            "/bangumi/play/",
            "/audio/",
            "/cheese/play/",
            "/medialist/play/",
            "/live/"
        ]

        if playablePathMarkers.contains(where: { path.contains($0) }) {
            return false
        }

        return isBrowserHomepageTitle(title)
            || path.isEmpty
            || path == "/"
    }

    static func isLikelyBrowserMediaSource(host: String, title: String) -> Bool {
        let host = host.lowercased()
        let title = title.lowercased()

        let allowedHosts = [
            "youtube.com",
            "youtu.be",
            "music.youtube.com",
            "bilibili.com",
            "live.bilibili.com",
            "spotify.com",
            "open.spotify.com",
            "music.apple.com",
            "music.163.com",
            "y.qq.com",
            "kuwo.cn",
            "kugou.com",
            "soundcloud.com",
            "podcasts.apple.com"
        ]

        if allowedHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
            return true
        }

        let titleKeywords = [
            "播放",
            "正在播放",
            "music",
            "song",
            "album",
            "playlist",
            "radio",
            "podcast",
            "bilibili",
            "哔哩哔哩"
        ]
        return titleKeywords.contains(where: { title.contains($0) })
    }
}
