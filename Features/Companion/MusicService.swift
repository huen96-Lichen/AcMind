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
import AcMindKit
import OSLog
import SwiftUI
import Darwin
import Vision

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
    public var sourceLabel: String
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
        sourceLabel: String = "",
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
        self.sourceLabel = sourceLabel
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

struct NowPlayingSnapshot: Sendable {
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
    @Published public var lyrics: String?
    @Published public var isLoadingLyrics: Bool = false
    @Published public var sourceLabel: String = ""

    private var updateTimer: Timer?
    private var currentArtworkData: Data?
    private var lastLyricsKey: String?
    private var stalenessTracker = NowPlayingStalenessTracker(clearThreshold: 2)
    private var nowPlayingAdapterProcess: Process?
    private var nowPlayingAdapterPipeHandler: JSONLinesPipeHandler?
    private var nowPlayingAdapterTask: Task<Void, Never>?
    private var nowPlayingAdapterIsRunning = false

    // MARK: - Initialization

    public init() {
        setupMediaMonitoring()
    }

    // MARK: - Setup

    private func setupMediaMonitoring() {
        Self.logger.debug("Starting music monitoring")

        Task { await startNowPlayingStreamIfAvailable() }

        // 使用定时器定期更新
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.nowPlayingAdapterIsRunning, self.hasPlaybackContext() {
                    return
                }
                await self.updateNowPlayingInfo()
            }
        }

        Task { await updateNowPlayingInfo() }
    }

    private func hasPlaybackContext() -> Bool {
        songTitle.isEmpty == false ||
        artistName.isEmpty == false ||
        album.isEmpty == false ||
        bundleIdentifier != nil ||
        sourceLabel.isEmpty == false
    }

    private func adapterRepeatMode(from value: Int) -> RepeatMode {
        switch value {
        case 2:
            return .one
        case 3:
            return .all
        default:
            return .off
        }
    }

    private func startNowPlayingStreamIfAvailable() async {
        guard
            let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            let frameworkPath = Bundle.main.privateFrameworksPath?.appending("/MediaRemoteAdapter.framework")
        else {
            Self.logger.debug("MediaRemote adapter resources missing, using polling fallback")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "stream"]

        let pipeHandler = JSONLinesPipeHandler()
        process.standardOutput = pipeHandler.getPipe()

        do {
            try process.run()
        } catch {
            Self.logger.debug("Failed to launch mediaremote adapter: \(error.localizedDescription, privacy: .public)")
            return
        }

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.nowPlayingAdapterIsRunning = false
                self?.nowPlayingAdapterProcess = nil
                self?.nowPlayingAdapterPipeHandler = nil
                self?.nowPlayingAdapterTask?.cancel()
                self?.nowPlayingAdapterTask = nil
            }
        }

        nowPlayingAdapterProcess = process
        nowPlayingAdapterPipeHandler = pipeHandler
        nowPlayingAdapterIsRunning = true

        nowPlayingAdapterTask = Task { [weak self] in
            await self?.consumeNowPlayingStream()
        }
    }

    private func consumeNowPlayingStream() async {
        guard let pipeHandler = nowPlayingAdapterPipeHandler else { return }

        await pipeHandler.readJSONLines(as: NowPlayingAdapterUpdate.self) { [weak self] update in
            await self?.handleNowPlayingAdapterUpdate(update)
        }
    }

    private func handleNowPlayingAdapterUpdate(_ update: NowPlayingAdapterUpdate) async {
        let payload = update.payload
        let diff = update.diff ?? false

        let resolvedTitle = payload.title ?? (diff ? songTitle : "")
        let resolvedArtist = payload.artist ?? (diff ? artistName : "")
        let resolvedAlbum = payload.album ?? (diff ? album : "")
        let resolvedDuration = payload.duration ?? (diff ? songDuration : 0)

        let resolvedCurrentTime: TimeInterval
        if let elapsedTime = payload.elapsedTime {
            resolvedCurrentTime = elapsedTime
        } else if diff {
            if payload.playing == false {
                let timeSinceLastUpdate = Date().timeIntervalSince(timestampDate)
                resolvedCurrentTime = elapsedTime + (playbackRate * timeSinceLastUpdate)
            } else {
                resolvedCurrentTime = elapsedTime
            }
        } else {
            resolvedCurrentTime = 0
        }

        let resolvedIsShuffled: Bool
        if let shuffleMode = payload.shuffleMode {
            resolvedIsShuffled = shuffleMode != 1
        } else if diff {
            resolvedIsShuffled = isShuffled
        } else {
            resolvedIsShuffled = false
        }

        let resolvedRepeatMode: RepeatMode
        if let repeatModeValue = payload.repeatMode {
            resolvedRepeatMode = adapterRepeatMode(from: repeatModeValue)
        } else if diff {
            resolvedRepeatMode = repeatMode
        } else {
            resolvedRepeatMode = .off
        }

        let resolvedArtworkData: Data?
        if let artworkDataString = payload.artworkData {
            resolvedArtworkData = Data(base64Encoded: artworkDataString.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if !diff {
            resolvedArtworkData = nil
        } else {
            resolvedArtworkData = currentArtworkData
        }

        let resolvedIsPlaying = payload.playing ?? (diff ? isPlaying : false)
        var resolvedPlaybackRate = payload.playbackRate ?? (diff ? playbackRate : 1.0)
        if resolvedIsPlaying == false {
            resolvedPlaybackRate = 0
        } else if payload.playbackRate == nil, resolvedPlaybackRate <= 0 {
            resolvedPlaybackRate = 1.0
        }
        let resolvedBundleIdentifier = (
            payload.parentApplicationBundleIdentifier ??
            payload.bundleIdentifier ??
            (diff ? bundleIdentifier : nil)
        )

        let snapshot = NowPlayingSnapshot(
            title: resolvedTitle,
            artist: resolvedArtist,
            album: resolvedAlbum,
            artworkData: resolvedArtworkData,
            duration: resolvedDuration,
            elapsedTime: resolvedCurrentTime,
            playbackRate: resolvedPlaybackRate,
            bundleIdentifier: resolvedBundleIdentifier,
            source: ""
        )

        // Preserve repeat/shuffle state after the snapshot apply.
        isShuffled = resolvedIsShuffled
        repeatMode = resolvedRepeatMode

        apply(snapshot: snapshot)
    }

    // MARK: - Media Detection Methods

    private func updateNowPlayingInfo() async {
        var fallbackSnapshot: NowPlayingSnapshot?

        if let snapshot = await LegacyPlayerNowPlayingProbe.fetch(logger: Self.logger) {
            if snapshot.isPlaying {
                stalenessTracker.recordSourceFound()
                apply(snapshot: snapshot)
                return
            }
            fallbackSnapshot = fallbackSnapshot ?? snapshot
        }

        if let snapshot = await QishuiMusicNowPlayingProbe.fetch(logger: Self.logger) {
            if snapshot.isPlaying {
                stalenessTracker.recordSourceFound()
                apply(snapshot: snapshot)
                return
            }
            fallbackSnapshot = fallbackSnapshot ?? snapshot
        }

        if let snapshot = await MediaRemoteNowPlayingProbe.fetch(logger: Self.logger) {
            if snapshot.isPlaying {
                stalenessTracker.recordSourceFound()
                apply(snapshot: snapshot)
                return
            }
            fallbackSnapshot = fallbackSnapshot ?? snapshot
        }

        if let browserSnapshot = await BrowserNowPlayingProbe.fetch(logger: Self.logger) {
            stalenessTracker.recordSourceFound()
            apply(snapshot: browserSnapshot)
            return
        }

        if let fallbackSnapshot {
            stalenessTracker.recordSourceFound()
            apply(snapshot: fallbackSnapshot)
            return
        }

        Self.logger.debug("No now playing source found")
        if stalenessTracker.recordSourceMissing() {
            clearNowPlayingState()
        }
    }

    private func apply(snapshot: NowPlayingSnapshot) {
        let titleChanged = snapshot.title != songTitle
        songTitle = snapshot.title
        artistName = snapshot.artist
        album = snapshot.album
        songDuration = snapshot.duration
        elapsedTime = snapshot.elapsedTime
        playbackRate = snapshot.playbackRate
        isPlaying = snapshot.isPlaying
        bundleIdentifier = snapshot.bundleIdentifier
        sourceLabel = NowPlayingSourceLabelFormatter.displayName(
            bundleIdentifier: snapshot.bundleIdentifier,
            source: snapshot.source
        )
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
        if titleChanged { fetchLyrics() }
    }

    private func clearNowPlayingState() {
        guard !songTitle.isEmpty || !artistName.isEmpty || !album.isEmpty || isPlaying || bundleIdentifier != nil || sourceLabel.isEmpty == false else {
            return
        }

        songTitle = ""
        artistName = ""
        album = ""
        albumArt = nil
        currentArtworkData = nil
        isPlaying = false
        songDuration = 0
        elapsedTime = 0
        playbackRate = 1.0
        bundleIdentifier = nil
        sourceLabel = ""
        timestampDate = Date()
        lyrics = nil
        isLoadingLyrics = false
        lastLyricsKey = nil
        stalenessTracker.reset()
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
            sourceLabel: sourceLabel,
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

    nonisolated private func sendMediaRemoteCommand(_ command: UInt32) {
        let frameworkURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, frameworkURL as CFURL) else { return }
        guard let symbol = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else { return }
        typealias SendCommandFunction = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
        let fn = unsafeBitCast(symbol, to: SendCommandFunction.self)
        _ = fn(command, nil)
    }

    public func togglePlay() {
        sendMediaRemoteCommand(2)
    }

    public func nextTrack() {
        sendMediaRemoteCommand(4)
    }

    public func previousTrack() {
        sendMediaRemoteCommand(5)
    }

    public func fetchLyrics() {
        let title = songTitle
        let artist = artistName
        guard !title.isEmpty else {
            lyrics = nil
            return
        }
        let key = "\(title)|\(artist)"
        if key == lastLyricsKey, lyrics != nil { return }
        lastLyricsKey = key
        isLoadingLyrics = true
        Task.detached { [weak self] in
            let result = await Self.requestLyrics(title: title, artist: artist)
            await MainActor.run {
                self?.lyrics = result
                self?.isLoadingLyrics = false
            }
        }
    }

    private static func requestLyrics(title: String, artist: String) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("AcMind/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let synced = json?["syncedLyrics"] as? String, !synced.isEmpty {
                return synced
            }
            if let plain = json?["plainLyrics"] as? String, !plain.isEmpty {
                return plain
            }
            return nil
        } catch {
            return nil
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
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AcMind", category: "MusicService")
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            let result = script.executeAndReturnError(&error)
            if let error = error {
                let code = error[NSAppleScript.errorNumber] as? Int ?? -1
                let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript execution failed"
                logger.error("[AcMind.MusicService] AppleScript error code=\(code) message=\(message)")
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

            guard let getNowPlayingInfo = getFunctionPointer(bundle: bundle, name: "MRMediaRemoteGetNowPlayingInfo") else {
                logger.debug("MediaRemote symbol missing: MRMediaRemoteGetNowPlayingInfo")
                continuation.resume(returning: nil)
                return
            }

            typealias InfoFunction = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
            typealias BoolFunction = @convention(c) (DispatchQueue, @escaping (CFBoolean?) -> Void) -> Void

            if let getIsPlaying = getFunctionPointer(bundle: bundle, name: "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
                let isPlayingFn = unsafeBitCast(getIsPlaying, to: BoolFunction.self)
                isPlayingFn(.main) { playing in
                    let systemIsPlaying = (playing as? Bool) ?? false
                    let infoFn = unsafeBitCast(getNowPlayingInfo, to: InfoFunction.self)
                    infoFn(.main) { info in
                        continuation.resume(returning: Self.buildSnapshot(
                            info: info, systemIsPlaying: systemIsPlaying, logger: logger
                        ))
                    }
                }
            } else {
                let infoFn = unsafeBitCast(getNowPlayingInfo, to: InfoFunction.self)
                infoFn(.main) { info in
                    continuation.resume(returning: Self.buildSnapshot(
                        info: info, systemIsPlaying: nil, logger: logger
                    ))
                }
            }
        }
    }

    private static func getFunctionPointer(bundle: CFBundle, name: String) -> UnsafeMutableRawPointer? {
        CFBundleGetFunctionPointerForName(bundle, name as CFString)
    }

    private static func buildSnapshot(info: CFDictionary?, systemIsPlaying: Bool?, logger: Logger) -> NowPlayingSnapshot? {
        guard let info else {
            logger.debug("MediaRemote returned no now playing dictionary")
            return nil
        }

        let dictionary = info as NSDictionary
        if let snapshot = NowPlayingSnapshot.make(
            from: dictionary,
            source: "MediaRemote",
            systemIsPlaying: systemIsPlaying,
            allowBrowserBundles: false
        ) {
            return snapshot
        }

        let keys = dictionary.allKeys.compactMap { $0 as? String }.sorted()
        logger.debug("MediaRemote dictionary did not contain readable keys: \(keys.joined(separator: ","), privacy: .public)")
        return nil
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

private enum BrowserNowPlayingProbe {
    private struct Adapter {
        let name: String
        let bundleIdentifier: String
        let script: String
    }

    static func fetch(logger: Logger) async -> NowPlayingSnapshot? {
        for adapter in adapters {
            guard isApplicationAvailable(bundleIdentifier: adapter.bundleIdentifier) else {
                logger.debug("Skipping missing browser: \(adapter.name, privacy: .public)")
                continue
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
            ),
            Adapter(
                name: "Chrome浏览器",
                bundleIdentifier: "com.google.Chrome",
                script: browserScript(
                    applicationName: "Google Chrome",
                    browserLabel: "Chrome浏览器",
                    tabAccessor: "active tab of front window"
                )
            ),
            Adapter(
                name: "Edge浏览器",
                bundleIdentifier: "com.microsoft.Edge",
                script: browserScript(
                    applicationName: "Microsoft Edge",
                    browserLabel: "Edge浏览器",
                    tabAccessor: "active tab of front window"
                )
            ),
            Adapter(
                name: "Brave浏览器",
                bundleIdentifier: "com.brave.Browser",
                script: browserScript(
                    applicationName: "Brave Browser",
                    browserLabel: "Brave浏览器",
                    tabAccessor: "active tab of front window"
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

// MARK: - MediaRemote Adapter Stream

private struct NowPlayingAdapterUpdate: Codable, Sendable {
    let payload: NowPlayingAdapterPayload
    let diff: Bool?
}

private struct NowPlayingAdapterPayload: Codable, Sendable {
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double?
    let elapsedTime: Double?
    let shuffleMode: Int?
    let repeatMode: Int?
    let artworkData: String?
    let timestamp: String?
    let playbackRate: Double?
    let playing: Bool?
    let parentApplicationBundleIdentifier: String?
    let bundleIdentifier: String?
}

@MainActor
private final class JSONLinesPipeHandler {
    private let pipe: Pipe
    private let fileHandle: FileHandle
    private var buffer = ""

    init() {
        pipe = Pipe()
        fileHandle = pipe.fileHandleForReading
    }

    func getPipe() -> Pipe {
        pipe
    }

    func readJSONLines<T: Decodable & Sendable>(as type: T.Type, onLine: @escaping @Sendable (T) async -> Void) async {
        do {
            try await processLines(as: type, onLine: onLine)
        } catch {
            Self.logger?.debug("JSON line reader stopped: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func processLines<T: Decodable & Sendable>(as type: T.Type, onLine: @escaping @Sendable (T) async -> Void) async throws {
        while true {
            let data = try await readData()
            guard data.isEmpty == false else { break }

            if let chunk = String(data: data, encoding: .utf8) {
                buffer.append(chunk)

                while let range = buffer.range(of: "\n") {
                    let line = String(buffer[..<range.lowerBound])
                    buffer = String(buffer[range.upperBound...])

                    if line.isEmpty == false {
                        await processJSONLine(line, as: type, onLine: onLine)
                    }
                }
            }
        }
    }

    private func processJSONLine<T: Decodable & Sendable>(_ line: String, as type: T.Type, onLine: @escaping @Sendable (T) async -> Void) async {
        guard let data = line.data(using: .utf8) else { return }
        do {
            let decodedObject = try JSONDecoder().decode(T.self, from: data)
            await onLine(decodedObject)
        } catch {
            // Ignore malformed JSON lines from the adapter stream.
        }
    }

    private func readData() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                handle.readabilityHandler = nil
                continuation.resume(returning: data)
            }
        }
    }

    func close() async {
        do {
            fileHandle.readabilityHandler = nil
            try fileHandle.close()
        } catch {
            // Nothing to clean up if the pipe has already been torn down.
        }
    }

    private nonisolated static var logger: Logger? {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "AcMind", category: "MusicService")
    }
}

private enum QishuiMusicNowPlayingProbe {
    private struct Candidate {
        let text: String
        let frame: CGRect
    }

    private nonisolated(unsafe) static var didLogMissingAccessibilityThisLaunch = false

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

        guard let windowFrame = visibleWindowFrame(for: app.processIdentifier) else {
            logger.debug("汽水音乐 visible window frame not found")
            return nil
        }

        var candidates: [Candidate] = []

        if AXIsProcessTrusted() {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            if let window = frontWindow(of: axApp) {
                let axWindowFrame = rectValue(of: window, attribute: "AXFrame" as CFString) ?? windowFrame
                candidates = collectTextCandidates(from: window)
                if candidates.isEmpty {
                    candidates = await collectOCRTextCandidates(from: axWindowFrame, logger: logger)
                } else {
                    let ocrCandidates = await collectOCRTextCandidates(from: axWindowFrame, logger: logger)
                    candidates.append(contentsOf: ocrCandidates)
                }
            } else if !didLogMissingAccessibilityThisLaunch {
                didLogMissingAccessibilityThisLaunch = true
                logger.debug("Accessibility trusted but 汽水音乐 front window not found, falling back to OCR")
            }
        }

        if candidates.isEmpty {
            candidates = await collectOCRTextCandidates(from: windowFrame, logger: logger)
        }

        if candidates.isEmpty {
            logger.debug("汽水音乐 yielded no text candidates")
            return nil
        }

        let lyricsTrack = pickQishuiTrackFromLyricsScreen(from: candidates, windowFrame: windowFrame)
        guard let title = lyricsTrack?.title ?? pickQishuiTitle(from: candidates, windowFrame: windowFrame) else {
            logger.debug("汽水音乐 title candidate not found")
            return nil
        }

        let artist = lyricsTrack?.artist ?? pickQishuiArtist(from: candidates, title: title, windowFrame: windowFrame) ?? ""
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

    private static func collectTextCandidates(from element: AXUIElement) -> [Candidate] {
        var results: [Candidate] = []

        func walk(_ element: AXUIElement) {
            let role = stringValue(of: element, attribute: kAXRoleAttribute as CFString) ?? ""
            let values = [
                stringValue(of: element, attribute: kAXValueAttribute as CFString),
                stringValue(of: element, attribute: kAXTitleAttribute as CFString),
                stringValue(of: element, attribute: kAXDescriptionAttribute as CFString),
                stringValue(of: element, attribute: "AXHelp" as CFString)
            ]

            if role == "AXStaticText" || role == "AXButton" || role == "AXLink" || values.contains(where: { ($0 ?? "").isEmpty == false }) {
                if let frame = rectValue(of: element, attribute: "AXFrame" as CFString) {
                    for text in values.compactMap({ $0 }) {
                        let cleaned = cleanQishuiText(text)
                        if cleaned.isEmpty == false {
                            results.append(Candidate(text: cleaned, frame: frame))
                        }
                    }
                }
            }

            for child in children(of: element) {
                walk(child)
            }
        }

        walk(element)
        return results
    }

    private static func collectOCRTextCandidates(
        from windowFrame: CGRect,
        logger: Logger
    ) async -> [Candidate] {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return [] }
        let image = CGWindowListCreateImage(windowFrame, [.optionOnScreenOnly], kCGNullWindowID, [.bestResolution])

        guard let image else {
            logger.debug("汽水音乐 OCR capture failed")
            return []
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    logger.debug("汽水音乐 OCR failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: [])
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let candidates = observations.compactMap { observation -> Candidate? in
                    guard let text = observation.topCandidates(1).first?.string else { return nil }
                    let cleaned = cleanQishuiText(text)
                    guard cleaned.isEmpty == false else { return nil }

                    let boundingBox = observation.boundingBox
                    let frame = CGRect(
                        x: windowFrame.minX + boundingBox.minX * windowFrame.width,
                        y: windowFrame.minY + (1 - boundingBox.maxY) * windowFrame.height,
                        width: boundingBox.width * windowFrame.width,
                        height: boundingBox.height * windowFrame.height
                    )
                    return Candidate(text: cleaned, frame: frame)
                }
                continuation.resume(returning: candidates)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "ja-JP", "en-US"]
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                } catch {
                    logger.debug("汽水音乐 OCR request failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private static func visibleWindowFrame(for processIdentifier: pid_t) -> CGRect? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let candidates = windowList.compactMap { windowInfo -> CGRect? in
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == processIdentifier else {
                return nil
            }

            guard let layer = windowInfo[kCGWindowLayer as String] as? Int, layer == 0 else {
                return nil
            }

            guard let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any] else {
                return nil
            }

            return CGRect(dictionaryRepresentation: bounds as CFDictionary)
        }

        return candidates.max(by: {
            ($0.width * $0.height) < ($1.width * $1.height)
        })
    }

    private static func pickQishuiTitle(from candidates: [Candidate], windowFrame: CGRect) -> String? {
        let titleCandidates = candidates.filter { candidate in
            guard candidate.frame.width >= 80, candidate.frame.width <= 240 else { return false }
            guard candidate.frame.height >= 12, candidate.frame.height <= 28 else { return false }
            guard candidate.frame.minX > windowFrame.minX + windowFrame.width * 0.20 else { return false }
            guard candidate.frame.minY > windowFrame.minY + windowFrame.height * 0.45 else { return false }
            guard candidate.frame.minY < windowFrame.minY + windowFrame.height * 0.90 else { return false }
            guard ignoredTexts.contains(candidate.text) == false else { return false }
            guard candidate.text.contains(" / ") == false else { return false }
            guard isQishuiNoise(candidate.text) == false else { return false }
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

    private static func pickQishuiTrackFromLyricsScreen(from candidates: [Candidate], windowFrame: CGRect) -> (title: String, artist: String?)? {
        let titleCandidates = candidates.filter { candidate in
            let normalizedX = (candidate.frame.midX - windowFrame.minX) / max(windowFrame.width, 1)
            let normalizedY = (candidate.frame.midY - windowFrame.minY) / max(windowFrame.height, 1)
            guard normalizedX >= 0.22, normalizedX <= 0.62 else { return false }
            guard normalizedY >= 0.54, normalizedY <= 0.90 else { return false }
            guard candidate.frame.height >= 16, candidate.frame.height <= 48 else { return false }
            guard candidate.text.count <= 36 else { return false }
            guard ignoredTexts.contains(candidate.text) == false else { return false }
            guard isQishuiNoise(candidate.text) == false else { return false }
            return true
        }

        guard let titleCandidate = titleCandidates.sorted(by: { lhs, rhs in
            if abs(lhs.frame.height - rhs.frame.height) > 2 {
                return lhs.frame.height > rhs.frame.height
            }
            return lhs.frame.minY < rhs.frame.minY
        }).first else {
            return nil
        }

        let artist = candidates.filter { candidate in
            let normalizedX = (candidate.frame.midX - windowFrame.minX) / max(windowFrame.width, 1)
            guard candidate.text != titleCandidate.text else { return false }
            guard normalizedX >= 0.22, normalizedX <= 0.62 else { return false }
            guard candidate.frame.minY >= titleCandidate.frame.maxY - 2 else { return false }
            guard candidate.frame.minY <= titleCandidate.frame.maxY + 48 else { return false }
            guard candidate.frame.height >= 10, candidate.frame.height <= 28 else { return false }
            guard candidate.text.count <= 32 else { return false }
            guard ignoredTexts.contains(candidate.text) == false else { return false }
            guard isQishuiNoise(candidate.text) == false else { return false }
            return true
        }
        .sorted {
            let lhsDistance = abs($0.frame.minY - titleCandidate.frame.maxY)
            let rhsDistance = abs($1.frame.minY - titleCandidate.frame.maxY)
            return lhsDistance < rhsDistance
        }
        .first?
        .text

        return (titleCandidate.text, artist)
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
            guard isQishuiNoise(candidate.text) == false else { return false }
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

    private static func cleanQishuiText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isQishuiNoise(_ text: String) -> Bool {
        if text.isEmpty { return true }
        if text.range(of: timePattern, options: .regularExpression) != nil { return true }
        if text.contains("歌手") || text.contains("歌曲") || text.contains("专辑") { return true }
        if text.contains("SVIP") || text.contains("VIP") || text.contains("w+") { return true }
        if text.contains("搜索") || text.contains("推荐") || text.contains("收藏") { return true }
        if text.hasPrefix("作词") || text.hasPrefix("作曲") { return true }
        return false
    }

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

    private static func intValue(of element: AXUIElement, attribute: CFString) -> Int? {
        guard let rawValue = attr(element, attribute) else { return nil }
        if let number = rawValue as? NSNumber {
            return number.intValue
        }
        return nil
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

extension NowPlayingSnapshot {
    static func make(
        from dictionary: NSDictionary,
        source: String,
        systemIsPlaying: Bool? = nil,
        allowBrowserBundles: Bool = true
    ) -> NowPlayingSnapshot? {
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
        let explicitRate = doubleValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoPlaybackRate",
            "playbackRate"
        ])
        let playbackRate: Double
        if let explicitRate {
            playbackRate = explicitRate
        } else if let systemIsPlaying {
            playbackRate = systemIsPlaying ? 1.0 : 0.0
        } else if title.isEmpty == false {
            playbackRate = 1.0
        } else {
            playbackRate = 0.0
        }
        let artworkData = dataValue(from: dictionary, keys: [
            "kMRMediaRemoteNowPlayingInfoArtworkData",
            "artworkData",
            "artwork"
        ])

        if allowBrowserBundles == false, isBrowserBundleIdentifier(bundleIdentifier) {
            return nil
        }

        if isBrowserBundleIdentifier(bundleIdentifier), WebNowPlayingParser.isBrowserHomepageTitle(title) {
            return nil
        }

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
        guard let metadata = WebNowPlayingParser.parse(
            fromBrowserAppleScript: output,
            source: source,
            bundleIdentifier: bundleIdentifier
        ) else {
            return nil
        }

        return NowPlayingSnapshot(
            title: metadata.title,
            artist: metadata.artist,
            album: metadata.album,
            artworkData: nil,
            duration: 0,
            elapsedTime: 0,
            playbackRate: 1.0,
            bundleIdentifier: metadata.bundleIdentifier,
            source: metadata.source
        )
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

private func isBrowserBundleIdentifier(_ bundleIdentifier: String?) -> Bool {
    guard let bundleIdentifier else { return false }
    return [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.Edge",
        "com.brave.Browser"
    ].contains(bundleIdentifier)
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
                Text(
                    NowPlayingSourceLabelFormatter.playbackContextLabel(
                        isPlaying: false,
                        bundleIdentifier: musicService.bundleIdentifier,
                        source: musicService.sourceLabel,
                        playingPrefix: "播放中",
                        idlePrefix: "未播放"
                    )
                )
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(isHovered ? 0.38 : 0.3))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(isHovered ? 0.18 : 0.08), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
