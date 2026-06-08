//
//  MusicService.swift
//  AcMind
//
//  Adapted from BoringNotch MusicManager
//  Uses multiple methods for media detection
//

import AppKit
import ApplicationServices
import Combine
import OSLog
import SwiftUI
import Darwin

// MARK: - Playback State

/// 播放状态
public struct PlaybackState: Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var artwork: Data?
    public var isPlaying: Bool
    public var duration: TimeInterval
    public var currentTime: TimeInterval
    public var playbackRate: Double
    public var isShuffled: Bool
    public var repeatMode: RepeatMode
    public var bundleIdentifier: String?
    public var lastUpdated: Date

    public init(
        title: String = "",
        artist: String = "",
        album: String = "",
        artwork: Data? = nil,
        isPlaying: Bool = false,
        duration: TimeInterval = 0,
        currentTime: TimeInterval = 0,
        playbackRate: Double = 1.0,
        isShuffled: Bool = false,
        repeatMode: RepeatMode = .off,
        bundleIdentifier: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.isPlaying = isPlaying
        self.duration = duration
        self.currentTime = currentTime
        self.playbackRate = playbackRate
        self.isShuffled = isShuffled
        self.repeatMode = repeatMode
        self.bundleIdentifier = bundleIdentifier
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Repeat Mode

public enum RepeatMode: String, Sendable, CaseIterable {
    case off = "off"
    case all = "all"
    case one = "one"
}

// MARK: - Now Playing Snapshot

private struct NowPlayingSnapshot: Sendable {
    let title: String
    let artist: String
    let album: String
    let artworkData: Data?
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let playbackRate: Double
    let bundleIdentifier: String?
    let source: String

    var isPlaying: Bool {
        playbackRate > 0
    }
}

// MARK: - Music Service

/// 音乐服务 - 监控和控制媒体播放
/// 使用多种方式获取媒体信息（MRMediaRemote、AppleScript、Distributed Notifications）
@MainActor
public class MusicService: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AcMind", category: "MusicService")

    // MARK: - Published Properties

    @Published public var songTitle: String = ""
    @Published public var artistName: String = ""
    @Published public var albumArt: NSImage?
    @Published public var isPlaying: Bool = false
    @Published public var album: String = ""
    @Published public var bundleIdentifier: String?
    @Published public var songDuration: TimeInterval = 0
    @Published public var elapsedTime: TimeInterval = 0
    @Published public var timestampDate: Date = .init()
    @Published public var playbackRate: Double = 1.0
    @Published public var isShuffled: Bool = false
    @Published public var repeatMode: RepeatMode = .off

    private var updateTimer: Timer?
    private var currentArtworkData: Data?

    // MARK: - Initialization

    public init() {
        setupMediaMonitoring()
    }

    // MARK: - Setup

    private func setupMediaMonitoring() {
        Self.logger.debug("Starting music monitoring")

        // 使用定时器定期更新
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateNowPlayingInfo()
            }
        }

        Task { await updateNowPlayingInfo() }
    }

    // MARK: - Media Detection Methods

    private func updateNowPlayingInfo() async {
        if let snapshot = await LegacyPlayerNowPlayingProbe.fetch(logger: Self.logger) {
            apply(snapshot: snapshot)
            return
        }

        if let snapshot = await QishuiMusicNowPlayingProbe.fetch(logger: Self.logger) {
            apply(snapshot: snapshot)
            return
        }

        if let snapshot = await MediaRemoteNowPlayingProbe.fetch(logger: Self.logger) {
            apply(snapshot: snapshot)
            return
        }

        if let snapshot = await SafariNowPlayingProbe.fetch(logger: Self.logger) {
            apply(snapshot: snapshot)
            return
        }

        Self.logger.debug("No now playing source found")
        if !songTitle.isEmpty || isPlaying {
            isPlaying = false
            timestampDate = Date()
            broadcastState()
        }
    }

    private func apply(snapshot: NowPlayingSnapshot) {
        songTitle = snapshot.title
        artistName = snapshot.artist
        album = snapshot.album
        songDuration = snapshot.duration
        elapsedTime = snapshot.elapsedTime
        playbackRate = snapshot.playbackRate
        isPlaying = snapshot.isPlaying
        bundleIdentifier = snapshot.bundleIdentifier
        timestampDate = Date()
        if let artworkData = snapshot.artworkData, let image = NSImage(data: artworkData) {
            albumArt = image
            currentArtworkData = artworkData
        } else {
            albumArt = nil
            currentArtworkData = nil
        }

        Self.logger.debug(
            "Now playing hit: source=\(snapshot.source, privacy: .public) title=\(snapshot.title, privacy: .public) artist=\(snapshot.artist, privacy: .public) bundle=\(snapshot.bundleIdentifier ?? "unknown", privacy: .public)"
        )
        broadcastState()
    }

    /// 广播播放状态
    private func broadcastState() {
        let state = PlaybackState(
            title: songTitle,
            artist: artistName,
            album: album,
            artwork: currentArtworkData,
            isPlaying: isPlaying,
            duration: songDuration,
            currentTime: elapsedTime,
            playbackRate: playbackRate,
            isShuffled: isShuffled,
            repeatMode: repeatMode,
            bundleIdentifier: bundleIdentifier,
            lastUpdated: Date()
        )
        NotificationCenter.default.post(
            name: .companionPlaybackStateChanged,
            object: state
        )
    }

    private func executeAppleScript(_ source: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                let result = script.executeAndReturnError(&error)
                if let error = error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? -1
                    let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript execution failed"
                    Self.logger.debug("AppleScript error code=\(code, privacy: .public) message=\(message, privacy: .public)")
                    continuation.resume(throwing: NSError(domain: "AppleScript", code: code, userInfo: error as? [String: Any]))
                } else {
                    continuation.resume(returning: result.stringValue ?? "")
                }
            } else {
                continuation.resume(throwing: NSError(domain: "AppleScript", code: -1))
            }
        }
    }

    // MARK: - Playback Control

    public func togglePlay() {
        Task {
            _ = try? await executeAppleScript("""
            tell application "System Events"
                set processList to name of every process
            end tell
            
            if processList contains "汽水音乐" then
                tell application "汽水音乐" to playpause
            else if processList contains "网易云音乐" then
                tell application "网易云音乐" to playpause
            else if processList contains "Music" then
                tell application "Music" to playpause
            else if processList contains "Spotify" then
                tell application "Spotify" to playpause
            end if
            """)
        }
    }

    public func nextTrack() {
        Task {
            _ = try? await executeAppleScript("""
            tell application "System Events"
                set processList to name of every process
            end tell
            
            if processList contains "汽水音乐" then
                tell application "汽水音乐" to next track
            else if processList contains "网易云音乐" then
                tell application "网易云音乐" to next track
            else if processList contains "Music" then
                tell application "Music" to next track
            else if processList contains "Spotify" then
                tell application "Spotify" to next track
            end if
            """)
        }
    }

    public func previousTrack() {
        Task {
            _ = try? await executeAppleScript("""
            tell application "System Events"
                set processList to name of every process
            end tell
            
            if processList contains "汽水音乐" then
                tell application "汽水音乐" to previous track
            else if processList contains "网易云音乐" then
                tell application "网易云音乐" to previous track
            else if processList contains "Music" then
                tell application "Music" to previous track
            else if processList contains "Spotify" then
                tell application "Spotify" to previous track
            end if
            """)
        }
    }

    public func openMusicApp() {
        // 打开最近播放的应用或汽水音乐
        if let bundleId = bundleIdentifier {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.open(url)
                return
            }
        }
        // 兼容路径：打开汽水音乐
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.soda.music") {
            NSWorkspace.shared.open(url)
        }
    }
}

private func runAppleScript(_ source: String) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            let result = script.executeAndReturnError(&error)
            if let error = error {
                let code = error[NSAppleScript.errorNumber] as? Int ?? -1
                let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript execution failed"
                print("[AcMind.MusicService] AppleScript error code=\(code) message=\(message)")
                continuation.resume(throwing: NSError(domain: "AppleScript", code: code, userInfo: error as? [String: Any]))
            } else {
                continuation.resume(returning: result.stringValue ?? "")
            }
        } else {
            continuation.resume(throwing: NSError(domain: "AppleScript", code: -1))
        }
    }
}

// MARK: - Now Playing Probes

private enum MediaRemoteNowPlayingProbe {
    static func fetch(logger: Logger) async -> NowPlayingSnapshot? {
        await withCheckedContinuation { continuation in
            let frameworkURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
            guard let bundle = CFBundleCreate(kCFAllocatorDefault, frameworkURL as CFURL) else {
                logger.debug("MediaRemote framework not available")
                continuation.resume(returning: nil)
                return
            }

            let symbolName = "MRMediaRemoteGetNowPlayingInfo" as CFString
            guard let symbol = CFBundleGetFunctionPointerForName(bundle, symbolName) else {
                logger.debug("MediaRemote symbol missing: \(symbolName as String, privacy: .public)")
                continuation.resume(returning: nil)
                return
            }

            typealias Function = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
            let function = unsafeBitCast(symbol, to: Function.self)

            function(.main) { info in
                guard let info else {
                    logger.debug("MediaRemote returned no now playing dictionary")
                    continuation.resume(returning: nil)
                    return
                }

                let dictionary = info as NSDictionary
                let snapshot = NowPlayingSnapshot.make(from: dictionary, source: "MediaRemote")
                if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    let keys = dictionary.allKeys.compactMap { $0 as? String }.sorted()
                    logger.debug("MediaRemote dictionary did not contain readable keys: \(keys.joined(separator: ","), privacy: .public)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

private enum LegacyPlayerNowPlayingProbe {
    private struct Adapter {
        let name: String
        let bundleIdentifier: String
        let script: String
    }

    static func fetch(logger: Logger) async -> NowPlayingSnapshot? {
        for adapter in adapters {
            guard isApplicationAvailable(bundleIdentifier: adapter.bundleIdentifier) else {
                logger.debug("Skipping missing app: \(adapter.name, privacy: .public)")
                continue
            }

            do {
                let result = try await runAppleScript(adapter.script)
                if let snapshot = NowPlayingSnapshot.make(fromAppleScript: result, source: adapter.name) {
                    logger.debug("AppleScript adapter hit: \(adapter.name, privacy: .public)")
                    return snapshot
                }
            } catch {
                logger.debug("AppleScript adapter failed: \(adapter.name, privacy: .public) reason=\(error.localizedDescription, privacy: .public)")
            }
        }

        return nil
    }

    private static var adapters: [Adapter] {
        [
            Adapter(
                name: "Music",
                bundleIdentifier: "com.apple.Music",
                script: """
                tell application "Music"
                    if player state is playing or player state is paused then
                        return name of current track & "|||" & artist of current track & "|||" & album of current track & "|||" & duration of current track & "|||" & player position & "|||" & (player state as text) & "|||com.apple.Music"
                    end if
                end tell
                return ""
                """
            ),
            Adapter(
                name: "Spotify",
                bundleIdentifier: "com.spotify.client",
                script: """
                tell application "Spotify"
                    if player state is playing or player state is paused then
                        return name of current track & "|||" & artist of current track & "|||" & album of current track & "|||" & duration of current track & "|||" & player position & "|||" & (player state as text) & "|||com.spotify.client"
                    end if
                end tell
                return ""
                """
            ),
            Adapter(
                name: "网易云音乐",
                bundleIdentifier: "com.netease.cloudmusic",
                script: """
                tell application "网易云音乐"
                    if player state is playing or player state is paused then
                        return name of current track & "|||" & artist of current track & "|||" & album of current track & "|||" & duration of current track & "|||" & player position & "|||" & (player state as text) & "|||com.netease.cloudmusic"
                    end if
                end tell
                return ""
                """
            ),
        ]
    }
}

private enum SafariNowPlayingProbe {
    private struct Adapter {
        let name: String
        let bundleIdentifier: String
        let script: String
    }

    static func fetch(logger: Logger) async -> NowPlayingSnapshot? {
        guard let adapter = adapters.first else { return nil }

        guard isApplicationAvailable(bundleIdentifier: adapter.bundleIdentifier) else {
            logger.debug("Skipping missing browser: \(adapter.name, privacy: .public)")
            return nil
        }

        do {
            let result = try await runAppleScript(adapter.script)
            if let snapshot = NowPlayingSnapshot.make(fromBrowserAppleScript: result, source: adapter.name, bundleIdentifier: adapter.bundleIdentifier) {
                logger.debug("Browser adapter hit: \(adapter.name, privacy: .public)")
                return snapshot
            }
        } catch {
            logger.debug("Browser adapter failed: \(adapter.name, privacy: .public) reason=\(error.localizedDescription, privacy: .public)")
        }

        return nil
    }

    private static var adapters: [Adapter] {
        [
            Adapter(
                name: "Safari浏览器",
                bundleIdentifier: "com.apple.Safari",
                script: browserScript(
                    applicationName: "Safari",
                    browserLabel: "Safari浏览器",
                    tabAccessor: "current tab of front window"
                )
            )
        ]
    }

    private static func browserScript(
        applicationName: String,
        browserLabel: String,
        tabAccessor: String
    ) -> String {
        """
        tell application "\(applicationName)"
            if it is running then
                try
                    if exists front window then
                        set tabRef to \(tabAccessor)
                        if tabRef is not missing value then
                            set tabTitle to name of tabRef
                            set tabURL to URL of tabRef
                            return tabTitle & "|||" & tabURL & "|||" & "\(browserLabel)"
                        end if
                    end if
                end try
            end if
        end tell
        return ""
        """
    }
}

private enum QishuiMusicNowPlayingProbe {
    private struct Candidate {
        let text: String
        let frame: CGRect
    }

    private static let accessibilityPromptFlagKey = "AcMind.MusicService.didPromptAccessibility"

    static func fetch(logger: Logger) async -> NowPlayingSnapshot? {
        guard isApplicationAvailable(bundleIdentifier: "com.soda.music") else {
            logger.debug("Skipping missing app: 汽水音乐")
            return nil
        }

        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.soda.music" || $0.localizedName == "汽水音乐" || $0.localizedName == "QishuiMusic"
        }) else {
            logger.debug("汽水音乐 is not running")
            return nil
        }

        guard app.isActive || app.isHidden == false else {
            logger.debug("汽水音乐 is not active or hidden")
            return nil
        }

        if AXIsProcessTrusted() == false {
            if UserDefaults.standard.bool(forKey: Self.accessibilityPromptFlagKey) == false {
                UserDefaults.standard.set(true, forKey: Self.accessibilityPromptFlagKey)
                let options: [String: Any] = ["AXTrustedCheckOptionPrompt": true]
                let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
                logger.debug("Accessibility prompt requested for 汽水音乐, trusted=\(trusted)")
            } else {
                logger.debug("Accessibility not trusted for 汽水音乐, waiting for grant")
            }
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        guard let window = frontWindow(of: axApp) else {
            logger.debug("汽水音乐 front window not found")
            return nil
        }

        let windowFrame = rectValue(of: window, attribute: "AXFrame" as CFString) ?? .zero
        let candidates = collectStaticTextCandidates(from: window)
        
        if candidates.isEmpty {
            logger.debug("汽水音乐 accessibility tree yielded no text candidates")
            return nil
        }

        guard let title = pickQishuiTitle(from: candidates, windowFrame: windowFrame) else {
            logger.debug("汽水音乐 title candidate not found")
            return nil
        }

        let artist = pickQishuiArtist(from: candidates, title: title, windowFrame: windowFrame) ?? ""
        let elapsed = parseElapsedTime(from: candidates) ?? 0
        let total = parseTotalTime(from: candidates) ?? 0

        logger.debug("Qishui probe hit: title=\(title, privacy: .public) artist=\(artist, privacy: .public)")

        return NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: "",
            artworkData: nil,
            duration: total,
            elapsedTime: elapsed,
            playbackRate: 1.0,
            bundleIdentifier: "com.soda.music",
            source: "汽水音乐"
        )
    }

    private static func frontWindow(of app: AXUIElement) -> AXUIElement? {
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              let window = windows.first else {
            return nil
        }
        return window
    }

    private static func collectStaticTextCandidates(from element: AXUIElement) -> [Candidate] {
        var results: [Candidate] = []

        func walk(_ element: AXUIElement) {
            let role = stringValue(of: element, attribute: kAXRoleAttribute as CFString) ?? ""
            if role == "AXStaticText" {
                let text = stringValue(of: element, attribute: kAXValueAttribute as CFString) ?? ""
                if text.isEmpty == false, let frame = rectValue(of: element, attribute: "AXFrame" as CFString) {
                    results.append(Candidate(text: text, frame: frame))
                }
            }

            for child in children(of: element) {
                walk(child)
            }
        }

        walk(element)
        return results
    }

    private static func pickQishuiTitle(from candidates: [Candidate], windowFrame: CGRect) -> String? {
        let titleCandidates = candidates.filter { candidate in
            guard candidate.frame.width >= 80, candidate.frame.width <= 240 else { return false }
            guard candidate.frame.height >= 12, candidate.frame.height <= 28 else { return false }
            guard candidate.frame.minX > windowFrame.minX + windowFrame.width * 0.20 else { return false }
            guard candidate.frame.minY > windowFrame.minY + windowFrame.height * 0.45 else { return false }
            guard candidate.frame.minY < windowFrame.minY + windowFrame.height * 0.72 else { return false }
            guard ignoredTexts.contains(candidate.text) == false else { return false }
            guard candidate.text.contains(" / ") == false else { return false }
            return true
        }

        return titleCandidates
            .sorted {
                if $0.frame.width == $1.frame.width {
                    return $0.text.count > $1.text.count
                }
                return $0.frame.width > $1.frame.width
            }
            .first?
            .text
    }

    private static func pickQishuiArtist(from candidates: [Candidate], title: String, windowFrame: CGRect) -> String? {
        let titleFrame = candidates.first(where: { $0.text == title })?.frame ?? .zero
        let artistCandidates = candidates.filter { candidate in
            guard candidate.text != title else { return false }
            guard candidate.frame.width >= 18, candidate.frame.width <= 120 else { return false }
            guard candidate.frame.height >= 12, candidate.frame.height <= 20 else { return false }
            guard candidate.frame.minX > windowFrame.minX + windowFrame.width * 0.20 else { return false }
            guard candidate.frame.minY >= titleFrame.minY - 24 else { return false }
            guard candidate.frame.minY <= titleFrame.minY + 40 else { return false }
            guard ignoredTexts.contains(candidate.text) == false else { return false }
            guard candidate.text.contains(" / ") == false else { return false }
            return true
        }

        return artistCandidates
            .sorted {
                let lhsDistance = abs($0.frame.minY - titleFrame.minY)
                let rhsDistance = abs($1.frame.minY - titleFrame.minY)
                if lhsDistance == rhsDistance {
                    return $0.text.count < $1.text.count
                }
                return lhsDistance < rhsDistance
            }
            .first?
            .text
    }

    private static func parseElapsedTime(from candidates: [Candidate]) -> TimeInterval? {
        guard let candidate = candidates.first(where: { $0.text.range(of: timePattern, options: .regularExpression) != nil }) else {
            return nil
        }
        return parseTime(candidate.text).elapsed
    }

    private static func parseTotalTime(from candidates: [Candidate]) -> TimeInterval? {
        guard let candidate = candidates.first(where: { $0.text.range(of: timePattern, options: .regularExpression) != nil }) else {
            return nil
        }
        return parseTime(candidate.text).total
    }

    private static func parseTime(_ text: String) -> (elapsed: TimeInterval, total: TimeInterval) {
        let components = text.split(separator: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard components.count == 2 else { return (0, 0) }
        return (timeInterval(from: components[0]), timeInterval(from: components[1]))
    }

    private static func timeInterval(from string: String) -> TimeInterval {
        let pieces = string.split(separator: ":").map(String.init)
        guard pieces.count == 2, let minutes = Double(pieces[0]), let seconds = Double(pieces[1]) else { return 0 }
        return minutes * 60 + seconds
    }

    private static let timePattern = #"(\d{2}):(\d{2})\s*/\s*(\d{2}):(\d{2})"#

    private static let ignoredTexts: Set<String> = [
        "推荐",
        "听歌模式",
        "我的音乐",
        "我喜欢的音乐",
        "抖音收藏的音乐",
        "历史播放",
        "创建的歌单",
        "收藏的歌单和专辑",
        "升级",
        "音质",
        "音效",
        "关注",
        "歌词贡献者",
        "作词：龙军",
        "作曲：张超",
        "作词：风姿优优",
        "作曲：风姿优优"
    ]

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        guard let value = attr(element, kAXChildrenAttribute as CFString) as? [AXUIElement] else {
            return []
        }
        return value
    }

    private static func stringValue(of element: AXUIElement, attribute: CFString) -> String? {
        guard let value = attr(element, attribute) else { return nil }
        if let string = value as? String, string.isEmpty == false {
            return string
        }
        if let string = value as? NSString, string.length > 0 {
            return string as String
        }
        return nil
    }

    private static func rectValue(of element: AXUIElement, attribute: CFString) -> CGRect? {
        guard let rawValue = attr(element, attribute) else { return nil }
        let value = rawValue as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(value, .cgRect, &rect) else { return nil }
        return rect
    }

    private static func attr(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        return result == .success ? value : nil
    }
}

private func isApplicationAvailable(bundleIdentifier: String) -> Bool {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
}

private extension NowPlayingSnapshot {
    static func make(from dictionary: NSDictionary, source: String) -> NowPlayingSnapshot? {
        let title = stringValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoTitle",
            "Title",
            "title"
        ]) ?? ""
        let artist = stringValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoArtist",
            "Artist",
            "artist"
        ]) ?? ""
        let album = stringValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoAlbum",
            "Album",
            "album"
        ]) ?? ""
        let bundleIdentifier = stringValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoClientBundleIdentifier",
            "clientBundleIdentifier",
            "bundleIdentifier",
            "applicationBundleIdentifier"
        ])
        let duration = doubleValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoDuration",
            "duration"
        ]) ?? 0
        let elapsedTime = doubleValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoElapsedTime",
            "elapsedTime",
            "playbackProgress"
        ]) ?? 0
        let playbackRate = doubleValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoPlaybackRate",
            "playbackRate"
        ]) ?? (duration > 0 ? 1.0 : 0.0)
        let artworkData = dataValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoArtworkData",
            "artworkData",
            "artwork"
        ])

        guard title.isEmpty == false || artist.isEmpty == false || album.isEmpty == false else {
            return nil
        }

        return NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: album,
            artworkData: artworkData,
            duration: duration,
            elapsedTime: elapsedTime,
            playbackRate: playbackRate,
            bundleIdentifier: bundleIdentifier,
            source: source
        )
    }

    static func make(fromAppleScript output: String, source: String) -> NowPlayingSnapshot? {
        guard output.isEmpty == false else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 7 else { return nil }

        let state = parts[5].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let playbackRate: Double = (state == "playing") ? 1.0 : 0.0

        return NowPlayingSnapshot(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            artworkData: nil,
            duration: Double(parts[3]) ?? 0,
            elapsedTime: Double(parts[4]) ?? 0,
            playbackRate: playbackRate,
            bundleIdentifier: parts[6],
            source: source
        )
    }

    static func make(fromBrowserAppleScript output: String, source: String, bundleIdentifier: String) -> NowPlayingSnapshot? {
        guard output.isEmpty == false else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 3 else { return nil }

        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let second = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let third = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespacesAndNewlines) : source
        let urlString = second.contains("://") ? second : ""
        let browserLabel = second.contains("://") ? third : second
        let displayTitle = cleanBrowserTitle(title)
        let host = URL(string: urlString)?.host?.lowercased() ?? ""
        guard isLikelyBrowserMediaSource(host: host, title: displayTitle) else {
            return nil
        }

        let isBilibili = host.contains("bilibili.com") || displayTitle.localizedCaseInsensitiveContains("bilibili") || displayTitle.contains("哔哩哔哩")

        guard displayTitle.isEmpty == false else { return nil }

        return NowPlayingSnapshot(
            title: displayTitle,
            artist: browserLabel.isEmpty ? source : browserLabel,
            album: isBilibili ? "Bilibili" : (URL(string: urlString)?.host ?? urlString),
            artworkData: nil,
            duration: 0,
            elapsedTime: 0,
            playbackRate: 1.0,
            bundleIdentifier: bundleIdentifier,
            source: isBilibili ? "\(source)/Bilibili" : source
        )
    }

    private static func cleanBrowserTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: " - 哔哩哔哩", with: "")
            .replacingOccurrences(of: " - bilibili", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "_哔哩哔哩", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isLikelyBrowserMediaSource(host: String, title: String) -> Bool {
        let host = host.lowercased()
        let title = title.lowercased()

        let allowedHosts = [
            "youtube.com",
            "youtu.be",
            "music.youtube.com",
            "bilibili.com",
            "live.bilibili.com",
            "spotify.com",
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

    private static func stringValue(from dictionary: NSDictionary, keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, value.isEmpty == false {
                return value
            }
            if let value = dictionary[key] as? NSString, value.length > 0 {
                return value as String
            }
        }

        for (rawKey, rawValue) in dictionary {
            guard let key = rawKey as? String, keys.contains(key) else { continue }
            if let value = rawValue as? String, value.isEmpty == false {
                return value
            }
            if let value = rawValue as? NSString, value.length > 0 {
                return value as String
            }
        }

        return nil
    }

    private static func doubleValue(from dictionary: NSDictionary, keys: [String]) -> Double? {
        for key in keys {
            if let number = dictionary[key] as? NSNumber {
                return number.doubleValue
            }
            if let string = dictionary[key] as? String, let value = Double(string) {
                return value
            }
        }

        for (rawKey, rawValue) in dictionary {
            guard let key = rawKey as? String, keys.contains(key) else { continue }
            if let number = rawValue as? NSNumber {
                return number.doubleValue
            }
            if let string = rawValue as? String, let value = Double(string) {
                return value
            }
        }

        return nil
    }

    private static func dataValue(from dictionary: NSDictionary, keys: [String]) -> Data? {
        for key in keys {
            if let data = dictionary[key] as? Data {
                return data
            }
            if let data = dictionary[key] as? NSData {
                return data as Data
            }
        }

        for (rawKey, rawValue) in dictionary {
            guard let key = rawKey as? String, keys.contains(key) else { continue }
            if let data = rawValue as? Data {
                return data
            }
            if let data = rawValue as? NSData {
                return data as Data
            }
        }

        return nil
    }
}

// MARK: - Music Visualizer View

import QuartzCore

/// 音频可视化视图
public class AudioSpectrumView: NSView {
    private var barLayers: [CAShapeLayer] = []
    private var barScales: [CGFloat] = []
    private var isPlaying: Bool = true
    private var animationTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        let barWidth: CGFloat = 2
        let barCount = 4
        let spacing: CGFloat = barWidth
        let totalWidth = CGFloat(barCount) * (barWidth + spacing)
        let totalHeight: CGFloat = 14
        frame.size = CGSize(width: totalWidth, height: totalHeight)

        for i in 0..<barCount {
            let xPosition = CGFloat(i) * (barWidth + spacing)
            let barLayer = CAShapeLayer()
            barLayer.frame = CGRect(x: xPosition, y: 0, width: barWidth, height: totalHeight)
            barLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            barLayer.position = CGPoint(x: xPosition + barWidth / 2, y: totalHeight / 2)
            barLayer.fillColor = NSColor.white.cgColor
            barLayer.backgroundColor = NSColor.white.cgColor
            barLayer.allowsGroupOpacity = false
            barLayer.masksToBounds = true
            let path = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: totalHeight),
                                    xRadius: barWidth / 2,
                                    yRadius: barWidth / 2)
            barLayer.path = path.cgPath
            barLayers.append(barLayer)
            barScales.append(0.35)
            layer?.addSublayer(barLayer)
        }
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBars()
            }
        }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        resetBars()
    }

    private func updateBars() {
        for (i, barLayer) in barLayers.enumerated() {
            let targetScale = CGFloat.random(in: 0.35...1.0)
            barScales[i] = targetScale
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = barScales[i]
            animation.toValue = targetScale
            animation.duration = 0.3
            animation.autoreverses = true
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            barLayer.add(animation, forKey: "scaleY")
        }
    }

    private func resetBars() {
        for (i, barLayer) in barLayers.enumerated() {
            barLayer.removeAllAnimations()
            barLayer.transform = CATransform3DMakeScale(1, 0.35, 1)
            barScales[i] = 0.35
        }
    }

    public func setPlaying(_ playing: Bool) {
        isPlaying = playing
        if isPlaying {
            startAnimating()
        } else {
            stopAnimating()
        }
    }
}

/// SwiftUI 包装器
public struct MusicVisualizer: NSViewRepresentable {
    @Binding var isPlaying: Bool

    public init(isPlaying: Binding<Bool>) {
        self._isPlaying = isPlaying
    }

    public func makeNSView(context: Context) -> AudioSpectrumView {
        let view = AudioSpectrumView()
        view.setPlaying(isPlaying)
        return view
    }

    public func updateNSView(_ nsView: AudioSpectrumView, context: Context) {
        nsView.setPlaying(isPlaying)
    }
}

// MARK: - Music Player View

/// 迷你音乐播放器视图
public struct MiniMusicPlayerView: View {
    @ObservedObject private var musicService: MusicService
    @State private var isHovered = false

    public init(musicService: MusicService = MusicService()) {
        _musicService = ObservedObject(wrappedValue: musicService)
    }

    public var body: some View {
        HStack(spacing: 10) {
            // 可视化
            MusicVisualizer(isPlaying: $musicService.isPlaying)
                .frame(width: 16, height: 16)

            // 歌曲信息
            if musicService.isPlaying || !musicService.songTitle.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(musicService.songTitle)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(Color.white)

                    Text(musicService.artistName)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .frame(maxWidth: 100)

                // 控制按钮
                HStack(spacing: 8) {
                    Button(action: { musicService.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { musicService.togglePlay() }) {
                        Image(systemName: musicService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { musicService.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Text("未播放")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
