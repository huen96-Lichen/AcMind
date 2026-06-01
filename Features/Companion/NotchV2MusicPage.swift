import SwiftUI
import AppKit

struct NotchV2MusicPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 200, rightColumnWidth: 224) {
            leftColumn
        } centerColumn: {
            centerColumn
        } rightColumn: {
            rightColumn
        }
    }

    private var leftColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "来源", subtitle: "播放入口", symbol: "music.note.list") {
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow(label: "来源", value: sourceTitle)
                    summaryRow(label: "状态", value: playbackStatusText)
                    summaryRow(label: "曲目", value: titleText)
                    summaryRow(label: "位置", value: currentTimeText)
                }
            }

            NotchV2Card(title: "队列", subtitle: "轻摘要", symbol: "list.bullet") {
                if viewModel.playbackState.title.isEmpty {
                    emptyQueueState
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前没有完整队列视图。")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                            .lineLimit(1)
                        Text("这里只保留正在播放的摘要和控制入口。")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
    }

    private var centerColumn: some View {
        NotchV2Card(title: "正在播放", subtitle: playbackStatusText, symbol: "play.circle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.playbackState.title.isEmpty {
                    mediaEmptyState
                } else {
                    HStack(alignment: .center, spacing: 14) {
                        AlbumArtworkHeroView(artworkData: viewModel.playbackState.artwork)
                            .frame(width: 96, height: 96)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(titleText)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(NotchV2DesignTokens.primaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text("\(artistText) · \(albumText)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            progressRow

                            HStack(spacing: 10) {
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
                    .overlay(NotchV2DesignTokens.separator)

                HStack(spacing: 8) {
                    NotchV2StatusPill(icon: "waveform", title: playbackStatusText, accent: NotchV2DesignTokens.cardBackgroundStrong)
                    NotchV2StatusPill(icon: "timer", title: "\(currentTimeText) / \(durationText)", accent: NotchV2DesignTokens.innerCardBackground)
                    NotchV2StatusPill(icon: "speaker.wave.2", title: volumeText, accent: NotchV2DesignTokens.innerCardBackground)
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "播放摘要", subtitle: "状态", symbol: "waveform", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow(label: "来源", value: sourceTitle)
                    summaryRow(label: "状态", value: playbackStatusText)
                    summaryRow(label: "进度", value: "\(currentTimeText) / \(durationText)")
                    summaryRow(label: "播放率", value: "\(Int(progressValue * 100))%")
                }
            }

            NotchV2Card(title: "音频状态", subtitle: "设备 / 音量", symbol: "speaker.wave.2", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    compactStatusRow(title: "音量", value: volumeText, accent: .blue)
                    compactStatusRow(title: "输出", value: playbackStateLabel, accent: NotchV2DesignTokens.accentGreen)
                    compactStatusRow(title: "设备", value: sourceTitle, accent: NotchV2DesignTokens.secondaryText)
                }
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
        if let volume = SystemEventCenter.shared.volumeLevel {
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
        HStack(spacing: 10) {
            Text(currentTimeText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardBackground)
                    Capsule(style: .continuous)
                        .fill(NotchV2DesignTokens.accentPurple)
                        .frame(width: proxy.size.width * progressValue)
                }
            }
            .frame(height: 4)

            Text(durationText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
    }

    private var mediaEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "music.note.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
            Text("当前没有播放内容")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
            Text("有内容时显示封面、标题、艺术家和进度。")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    }

    private var emptyQueueState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
            Text("暂无队列视图")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
            Text("空播放时只保留克制提示，不占大面积空白。")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .frame(width: 40, alignment: .leading)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
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
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
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
                        .fill(isPrimary ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.innerCardBackground)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isPrimary ? 0.08 : 0.04), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct AlbumArtworkHeroView: View {
    let artworkData: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(NotchV2DesignTokens.accentPurple)

            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
