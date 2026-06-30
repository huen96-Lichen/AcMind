import SwiftUI
import AcMindKit

struct NotchV2MusicPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 224, rightColumnWidth: 224) {
            leftColumn
        } centerColumn: {
            centerColumn
        } rightColumn: {
            rightColumn
        }
    }

    private var leftColumn: some View {
        CompanionPanel(title: "播放队列", symbol: "music.note.list", fillHeight: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text("当前上下文")
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)

                VStack(alignment: .leading, spacing: 7) {
                    NotchV2InfoRow(title: "来源", value: sourceTitle, icon: "dot.radiowaves.left.and.right", accent: .blue, compactValue: true)
                    NotchV2InfoRow(title: "状态", value: playbackStatusText, icon: "waveform", accent: .green, compactValue: true)
                    NotchV2InfoRow(title: "专辑", value: albumText, icon: "music.note", accent: NotchV2DesignTokens.secondaryText, compactValue: true)
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                Text(queueEmptyStateTitle)
                    .font(NotchV2DesignTokens.Typography.title)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)

                Text(queueEmptyStateDetail)
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(3)
                    .truncationMode(.tail)
            }
        }
    }

    private var centerColumn: some View {
        CompanionPanel(
            title: "正在播放",
            symbol: "play.circle.fill",
            fillHeight: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.hasPlaybackContext == false {
                    emptyState
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        AlbumArtworkHeroView(artworkData: viewModel.playbackState.artwork)
                            .frame(width: 66, height: 66)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.playbackState.title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(NotchV2DesignTokens.primaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text(trackSummaryText)
                                .font(NotchV2DesignTokens.Typography.body)
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text(albumText)
                                .font(NotchV2DesignTokens.Typography.caption)
                                .foregroundStyle(NotchV2DesignTokens.secondaryText.opacity(0.92))
                                .lineLimit(1)
                                .truncationMode(.tail)

                            progressRow

                            HStack(spacing: 7) {
                                playbackButton(systemName: "backward.fill", size: 32) {
                                    viewModel.previousTrack()
                                }

                                playbackButton(systemName: viewModel.playbackState.isPlaying ? "pause.fill" : "play.fill", size: 40, isPrimary: true) {
                                    viewModel.playPause()
                                }

                                playbackButton(systemName: "forward.fill", size: 32) {
                                    viewModel.nextTrack()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                HStack(spacing: 8) {
                    NotchV2StatusPill(icon: "waveform", title: playbackStatusText, accent: NotchV2DesignTokens.cardBackgroundStrong)
                    NotchV2StatusPill(icon: "timer", title: "\(currentTimeText) / \(durationText)", accent: NotchV2DesignTokens.innerCardBackground)
                    NotchV2StatusPill(icon: "speaker.wave.2", title: volumeText, accent: NotchV2DesignTokens.innerCardBackground)
                    if sourceTitle.isEmpty == false {
                        NotchV2StatusPill(icon: "dot.radiowaves.left.and.right", title: sourceTitle, accent: NotchV2DesignTokens.innerCardBackground)
                    }
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            controlCard
        }
    }

    private var controlCard: some View {
        CompanionPanel(
            title: "播放控制",
            symbol: "slider.horizontal.3",
            fillHeight: true,
        ) {
            VStack(alignment: .leading, spacing: 7) {
                controlRow(
                    icon: "shuffle",
                    title: "随机播放",
                    value: viewModel.playbackState.isShuffled ? "已开启" : "已关闭",
                    isActive: viewModel.playbackState.isShuffled
                )
                controlRow(
                    icon: "repeat",
                    title: "循环模式",
                    value: repeatModeText,
                    isActive: viewModel.playbackState.repeatMode != .off
                )
                controlRow(
                    icon: "speaker.wave.2.fill",
                    title: "音量",
                    value: volumeText,
                    isActive: viewModel.systemEventCenter.volumeLevel != nil
                )

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                NotchV2StatusPill(
                    icon: "arrow.up.right.square",
                    title: "打开来源播放器",
                    accent: NotchV2DesignTokens.panelBackground,
                    action: {
                        viewModel.musicService.openMusicApp()
                    }
                )
            }
        }
    }

    private var trackSummaryText: String {
        NowPlayingSourceLabelFormatter.trackSummaryLabel(
            artist: viewModel.playbackState.artist,
            album: viewModel.playbackState.album,
            bundleIdentifier: viewModel.playbackState.bundleIdentifier,
            source: viewModel.playbackState.sourceLabel
        )
    }

    private var albumText: String {
        NowPlayingSourceLabelFormatter.albumDetailLabel(
            album: viewModel.playbackState.album,
            bundleIdentifier: viewModel.playbackState.bundleIdentifier,
            source: viewModel.playbackState.sourceLabel
        )
    }

    private var sourceTitle: String {
        NowPlayingSourceLabelFormatter.playbackContextLabel(
            isPlaying: viewModel.playbackState.isPlaying,
            bundleIdentifier: viewModel.playbackState.bundleIdentifier,
            source: viewModel.playbackState.sourceLabel,
            playingPrefix: "播放中",
            idlePrefix: "音乐"
        )
    }

    private var playbackStatusText: String {
        viewModel.playbackState.isPlaying ? "播放中" : "已暂停"
    }

    private var repeatModeText: String {
        switch viewModel.playbackState.repeatMode {
        case .off:
            return "循环关闭"
        case .all:
            return "列表循环"
        case .one:
            return "单曲循环"
        }
    }

    private var volumeText: String {
        if let volume = viewModel.systemEventCenter.volumeLevel {
            return "\(Int(volume.rounded()))%"
        }
        return "未采样"
    }

    private var progressValue: Double {
        guard viewModel.playbackState.duration > 0 else { return 0 }
        return max(0, min(1, viewModel.playbackState.currentTime / viewModel.playbackState.duration))
    }

    private var currentTimeText: String {
        formatTime(viewModel.playbackState.currentTime)
    }

    private var durationText: String {
        formatTime(viewModel.playbackState.duration)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var progressRow: some View {
        HStack(spacing: 8) {
            Text(currentTimeText)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(NotchV2DesignTokens.panelBackground)
                    Capsule(style: .continuous)
                        .fill(NotchV2DesignTokens.accentBlue.opacity(0.75))
                        .frame(width: proxy.size.width * progressValue)
                }
            }
            .frame(height: 4)

            Text(durationText)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: "music.note.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
            Text("等待系统媒体")
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Text(emptyStatePlaybackContext)
                .font(NotchV2DesignTokens.Typography.title)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(2)
                .truncationMode(.tail)
            Text("播放音乐或网页媒体后，这里显示封面、标题和进度。")
                .font(NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(2)

            NotchV2StatusPill(
                icon: "arrow.up.right.square",
                title: "打开来源播放器",
                accent: NotchV2DesignTokens.accentBlue,
                action: {
                    viewModel.musicService.openMusicApp()
                }
            )
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
    }

    private var emptyStatePlaybackContext: String {
        NowPlayingSourceLabelFormatter.playbackContextLabel(
            isPlaying: false,
            source: viewModel.playbackState.sourceLabel,
            playingPrefix: "播放中",
            idlePrefix: "当前没有播放内容",
            fallbackSource: "暂无播放来源"
        )
    }

    private var queueEmptyStateTitle: String {
        "队列为空"
    }

    private var queueEmptyStateDetail: String {
        if viewModel.hasPlaybackContext {
            return "当前只检测到播放中的曲目，尚未获取下一首队列。"
        }

        return NowPlayingSourceLabelFormatter.playbackContextLabel(
            isPlaying: false,
            source: viewModel.playbackState.sourceLabel,
            playingPrefix: "队列待同步",
            idlePrefix: "暂无队列",
            fallbackSource: "暂无播放来源"
        )
    }

    private func playbackButton(systemName: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(isPrimary ? .white : NotchV2DesignTokens.primaryText)
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(isPrimary ? NotchV2DesignTokens.accentBlue.opacity(0.82) : NotchV2DesignTokens.panelBackground)
                    )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func controlRow(icon: String, title: String, value: String, isActive: Bool) -> some View {
        NotchV2InfoRow(title: title, value: value, icon: icon, accent: isActive ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.secondaryText, compactValue: true)
    }
}
