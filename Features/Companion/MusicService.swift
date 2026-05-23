//
//  MusicService.swift
//  AcMind
//
//  Adapted from BoringNotch MusicManager
//  Uses multiple methods for media detection
//

import AppKit
import Combine
import OSLog

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
        if let snapshot = await PlayerNowPlayingProbe.fetch(logger: Self.logger) {
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

        Self.logger.warning("No now playing source found")
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
        try await MusicServiceAppleScript.run(source, logger: Self.logger)
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
        // 降级：打开汽水音乐
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.soda.music") {
            NSWorkspace.shared.open(url)
        }
    }
}
