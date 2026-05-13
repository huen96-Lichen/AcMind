import Foundation
import AppKit
import SwiftUI
import AcMindKit

@MainActor
final class NotchV2ViewModel: ObservableObject {
    @Published var isExpanded = true
    @Published var selectedPage: NotchV2Page = .overview
    @Published var playbackState = PlaybackState()
    @Published var isVoiceRecording = false
    @Published var isCapturing = false
    @Published var status: CompanionStatus = .ready
    @Published var lastTranscription: CompanionVoiceTranscription?

    struct QuickAction: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let action: () -> Void
    }

    lazy var quickActions: [QuickAction] = [
        QuickAction(icon: "camera.viewfinder", title: "截图", action: { [weak self] in self?.captureScreenshot() }),
        QuickAction(icon: "doc.text", title: "MD", action: { [weak self] in self?.quickMarkdown() }),
        QuickAction(icon: "pin.fill", title: "Pin", action: { [weak self] in self?.showAgent() }),
        QuickAction(icon: "waveform", title: "SRPT", action: { [weak self] in self?.showVoicePanel() })
    ]

    init() {
        playbackState = Self.snapshot()
        lastTranscription = CompanionMockData.recentTranscriptions.first
        setupObservers()
    }

    func toggleExpansion() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            isExpanded.toggle()
        }
    }

    func collapse() {
        guard isExpanded else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            isExpanded = false
        }
    }

    func select(_ page: NotchV2Page) {
        selectedPage = page
        if isExpanded == false {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                isExpanded = true
            }
        }
    }

    func playPause() {
        MusicService.shared.togglePlay()
    }

    func nextTrack() {
        MusicService.shared.nextTrack()
    }

    func previousTrack() {
        MusicService.shared.previousTrack()
    }

    var expandedHeight: CGFloat {
        switch selectedPage {
        case .overview:
            return NotchV2DesignTokens.expandedOverviewHeight
        case .music:
            return NotchV2DesignTokens.expandedMusicHeight
        case .agent:
            return NotchV2DesignTokens.expandedAgentHeight
        case .schedule:
            return NotchV2DesignTokens.expandedOverviewHeight
        }
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStateChanged(_:)),
            name: .companionPlaybackStateChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceRecordingStarted(_:)),
            name: .companionVoiceRecordingStarted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceRecordingStopped(_:)),
            name: .companionVoiceRecordingStopped,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureSuccess(_:)),
            name: .companionCaptureSuccess,
            object: nil
        )
    }

    @objc private func handlePlaybackStateChanged(_ notification: Notification) {
        if let state = notification.object as? PlaybackState {
            playbackState = state
        }
    }

    @objc private func handleVoiceRecordingStarted(_ notification: Notification) {
        isVoiceRecording = true
    }

    @objc private func handleVoiceRecordingStopped(_ notification: Notification) {
        isVoiceRecording = false
    }

    @objc private func handleCaptureSuccess(_ notification: Notification) {
        isCapturing = false
        ToastManager.shared.show(.success, "截图已完成")
    }

    private func captureScreenshot() {
        isCapturing = true
        ToastManager.shared.show(.info, "正在截图...")
        NotchPanel.shared.orderOut(nil)
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureScreenshot"),
            object: ["mode": ScreenshotMode.fullscreen.rawValue]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NotchPanel.shared.show()
        }
        collapse()
    }

    private func quickMarkdown() {
        NotificationCenter.default.post(name: Notification.Name("companion.quickMarkdown"), object: nil)
        ToastManager.shared.show(.info, "打开 MD")
        collapse()
    }

    private func showVoicePanel() {
        NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
        collapse()
    }

    private func showAgent() {
        NotificationCenter.default.post(name: .companionShowAgent, object: nil)
        collapse()
    }

    private static func snapshot() -> PlaybackState {
        let service = MusicService.shared
        return PlaybackState(
            title: service.songTitle,
            artist: service.artistName,
            album: service.album,
            artwork: service.albumArt?.tiffRepresentation,
            isPlaying: service.isPlaying,
            duration: service.songDuration,
            currentTime: service.elapsedTime,
            playbackRate: service.playbackRate,
            isShuffled: service.isShuffled,
            repeatMode: service.repeatMode,
            bundleIdentifier: service.bundleIdentifier,
            lastUpdated: Date()
        )
    }
}
