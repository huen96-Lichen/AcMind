import SwiftUI
import AppKit

struct NotchV2MusicPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 238, rightColumnWidth: 238) {
            leftColumn
        } centerColumn: {
            centerColumn
        } rightColumn: {
            rightColumn
        }
    }

    private var leftColumn: some View {
        NotchV2Card(title: "来源与队列", symbol: "music.note.list") {
            VStack(alignment: .leading, spacing: 10) {
                compactRow(label: "来源", value: sourceTitle)
                compactRow(label: "状态", value: playbackStatusText)

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                if viewModel.playbackState.title.isEmpty {
                    Text("暂无队列")
                        .font(NotchV2DesignTokens.Typography.title)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Text("空播放时只保留轻量提示。")
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                } else {
                    Text("队列视图未展开")
                        .font(NotchV2DesignTokens.Typography.title)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Text("这里只显示当前播放摘要。")
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                }

            }
        }
    }

    private var centerColumn: some View {
        NotchV2Card(title: "正在播放", symbol: "play.circle.fill", cardAccent: NotchV2DesignTokens.accentGreen) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.playbackState.title.isEmpty {
                    emptyState
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        AlbumArtworkHeroView(artworkData: viewModel.playbackState.artwork)
                            .frame(width: 84, height: 84)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(titleText)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(NotchV2DesignTokens.primaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text("\(artistText) · \(albumText)")
                                .font(NotchV2DesignTokens.Typography.body)
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            progressRow

                            HStack(spacing: 8) {
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
                }
            }
        }
    }

    private var rightColumn: some View {
        NotchV2Card(title: "播放与设备", symbol: "speaker.wave.2", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
            VStack(alignment: .leading, spacing: 10) {
                compactStatusRow(title: "进度", value: "\(currentTimeText) / \(durationText)", accent: .blue)
                compactStatusRow(title: "音量", value: volumeText, accent: .blue)
                compactStatusRow(title: "输出", value: playbackStateLabel, accent: NotchV2DesignTokens.accentGreen)
            }
        }
    }

    private var titleText: String {
        viewModel.playbackState.title.isEmpty ? "未播放" : viewModel.playbackState.title
    }

    private var artistText: String {
        viewModel.playbackState.artist.isEmpty ? "未知艺术家" : viewModel.playbackState.artist
    }

    private var albumText: String {
        viewModel.playbackState.album.isEmpty ? "未知专辑" : viewModel.playbackState.album
    }

    private var sourceTitle: String {
        viewModel.playbackState.bundleIdentifier ?? "AcMind Music"
    }

    private var playbackStatusText: String {
        viewModel.playbackState.isPlaying ? "播放中" : "已暂停"
    }

    private var playbackStateLabel: String {
        viewModel.playbackState.isPlaying ? "输出中" : "待命"
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
                        .fill(NotchV2DesignTokens.innerCardBackground)
                    Capsule(style: .continuous)
                        .fill(NotchV2DesignTokens.accentBlue)
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
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "music.note.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
            Text("当前没有播放内容")
                .font(NotchV2DesignTokens.Typography.title)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
            Text("有内容时只显示封面、标题和进度。")
                .font(NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
    }

    private func compactRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .frame(width: 34, alignment: .leading)
                .lineLimit(1)
            Text(value)
                .font(NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }

    private func compactStatusRow(title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.88))
        )
    }

    private func playbackButton(systemName: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 16 : 13, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : NotchV2DesignTokens.primaryText)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isPrimary ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.innerCardBackground)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isPrimary ? 0.08 : 0.04), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
