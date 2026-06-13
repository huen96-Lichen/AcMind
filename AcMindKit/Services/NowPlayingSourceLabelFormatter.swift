import Foundation

public enum NowPlayingSourceLabelFormatter {
    public static func displayName(bundleIdentifier: String?, source: String) -> String {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSource.isEmpty == false {
            return normalizeBrowserSource(trimmedSource)
        }

        switch bundleIdentifier {
        case "com.apple.Music":
            return "Apple Music"
        case "com.spotify.client":
            return "Spotify"
        case "com.apple.Safari":
            return "Safari浏览器"
        case "com.google.Chrome":
            return "Chrome浏览器"
        case "com.microsoft.Edge":
            return "Edge浏览器"
        case "com.brave.Browser":
            return "Brave浏览器"
        case "com.soda.music":
            return "汽水音乐"
        case "com.netease.cloudmusic":
            return "网易云音乐"
        default:
            return bundleIdentifier ?? ""
        }
    }

    public static func playbackContextLabel(
        isPlaying: Bool,
        source: String,
        playingPrefix: String = "播放中",
        idlePrefix: String = "音乐",
        fallbackSource: String = "音乐来源"
    ) -> String {
        let displaySource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSource = displaySource.isEmpty ? fallbackSource : displaySource
        let prefix = isPlaying ? playingPrefix : idlePrefix
        return "\(prefix) · \(resolvedSource)"
    }

    public static func playbackContextLabel(
        isPlaying: Bool,
        bundleIdentifier: String?,
        source: String,
        playingPrefix: String = "播放中",
        idlePrefix: String = "音乐"
    ) -> String {
        playbackContextLabel(
            isPlaying: isPlaying,
            source: source,
            playingPrefix: playingPrefix,
            idlePrefix: idlePrefix,
            fallbackSource: displayName(bundleIdentifier: bundleIdentifier, source: "")
        )
    }

    public static func sourceSuffix(_ source: String, separator: String = " · ") -> String {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSource.isEmpty == false else { return "" }
        return "\(separator)\(trimmedSource)"
    }

    public static func trackDetailLabel(
        title: String,
        source: String,
        fallbackTitle: String = "未命名"
    ) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle
        return resolvedTitle + sourceSuffix(source)
    }

    public static func trackDetailLabel(
        title: String,
        bundleIdentifier: String?,
        source: String,
        fallbackTitle: String = "未命名"
    ) -> String {
        let resolvedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? displayName(bundleIdentifier: bundleIdentifier, source: "")
            : source
        return trackDetailLabel(title: title, source: resolvedSource, fallbackTitle: fallbackTitle)
    }

    public static func artistDetailLabel(
        artist: String,
        source: String,
        fallbackArtist: String = "未知艺术家"
    ) -> String {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedArtist = trimmedArtist.isEmpty ? fallbackArtist : trimmedArtist
        return resolvedArtist + sourceSuffix(source)
    }

    public static func artistDetailLabel(
        artist: String,
        bundleIdentifier: String?,
        source: String,
        fallbackArtist: String = "未知艺术家"
    ) -> String {
        let resolvedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? displayName(bundleIdentifier: bundleIdentifier, source: "")
            : source
        return artistDetailLabel(artist: artist, source: resolvedSource, fallbackArtist: fallbackArtist)
    }

    public static func trackSummaryLabel(
        artist: String,
        album: String,
        bundleIdentifier: String?,
        source: String,
        fallbackArtist: String = "未知艺术家",
        fallbackAlbum: String = "未知专辑"
    ) -> String {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedArtist = trimmedArtist.isEmpty ? fallbackArtist : trimmedArtist
        let resolvedAlbum = trimmedAlbum.isEmpty ? fallbackAlbum : trimmedAlbum
        let resolvedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? displayName(bundleIdentifier: bundleIdentifier, source: "")
            : source
        return "\(resolvedArtist) · \(resolvedAlbum)" + sourceSuffix(resolvedSource)
    }

    public static func albumDetailLabel(
        album: String,
        bundleIdentifier: String?,
        source: String,
        fallbackAlbum: String = "未知专辑"
    ) -> String {
        let trimmedAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAlbum = trimmedAlbum.isEmpty ? fallbackAlbum : trimmedAlbum
        let resolvedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? displayName(bundleIdentifier: bundleIdentifier, source: "")
            : source
        return resolvedAlbum + sourceSuffix(resolvedSource)
    }

    public static func playbackStateLabel(
        isPlaying: Bool,
        bundleIdentifier: String?,
        source: String,
        playingPrefix: String = "播放中",
        pausedPrefix: String = "已暂停"
    ) -> String {
        let resolvedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? displayName(bundleIdentifier: bundleIdentifier, source: "")
            : source
        let prefix = isPlaying ? playingPrefix : pausedPrefix
        return "\(prefix)" + sourceSuffix(resolvedSource)
    }

    private static func normalizeBrowserSource(_ source: String) -> String {
        let pieces = source.split(omittingEmptySubsequences: true, whereSeparator: { $0 == "/" || $0 == "／" })
        guard pieces.count > 1 else { return source }

        var normalizedPieces: [String] = []
        for piece in pieces {
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }
            if normalizedPieces.last != trimmed {
                normalizedPieces.append(trimmed)
            }
        }

        guard normalizedPieces.isEmpty == false else { return source }
        return normalizedPieces.joined(separator: " · ")
    }
}
