import SwiftUI
import AppKit

struct NotchV2MusicPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchThreeColumnLayout(
            left: { artworkCard },
            center: { playbackCard },
            right: { queueCard }
        )
        .frame(width: NotchV2DesignTokens.expandedWidth, height: 342, alignment: .topLeading)
    }

    private var artworkCard: some View {
        NotchV2Card(title: "播放封面", subtitle: "当前曲目", symbol: "music.note", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 12) {
                MusicCoverView(artworkData: viewModel.playbackState.artwork)
                    .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(2)
                    Text("\(artistText) · \(albumText)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                NotchV2StatusPill(
                    title: viewModel.playbackState.isPlaying ? "播放中" : "已暂停",
                    accent: viewModel.playbackState.isPlaying ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.cardBackgroundStrong
                )
            }
        }
        .frame(width: 160, height: 318, alignment: .topLeading)
    }

    private var playbackCard: some View {
        NotchV2Card(title: "播放控制", subtitle: "进度与操作", symbol: "play.circle", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(titleText)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(2)

                    Text("\(artistText) · \(albumText)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(formatTime(viewModel.playbackState.currentTime))
                        Spacer(minLength: 0)
                        Text(formatTime(viewModel.playbackState.duration))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)

                    progressBar(progress: progressValue)
                        .frame(height: 4)
                }

                HStack(spacing: 12) {
                    playbackButton(systemName: "backward.fill", size: 52) {
                        viewModel.previousTrack()
                    }

                    playbackButton(systemName: viewModel.playbackState.isPlaying ? "pause.fill" : "play.fill", size: 60, isPrimary: true) {
                        viewModel.playPause()
                    }

                    playbackButton(systemName: "forward.fill", size: 52) {
                        viewModel.nextTrack()
                    }
                }

                Spacer(minLength: 0)

                NotchV2StatusPill(icon: "waveform", title: "队列同步", accent: NotchV2DesignTokens.innerCardBackground)
            }
        }
        .frame(width: 396, height: 318, alignment: .topLeading)
    }

    private var queueCard: some View {
        NotchV2Card(title: "播放来源", subtitle: "最近播放", symbol: "waveform", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text(sourceTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)

                Divider()
                    .overlay(NotchV2DesignTokens.separator)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(queueEntries) { item in
                        NotchV2QueueRow(title: item.title, duration: item.duration, isActive: item.isActive)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .frame(width: 180, height: 318, alignment: .topLeading)
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

    private var progressValue: Double {
        guard viewModel.playbackState.duration > 0 else { return 0 }
        return max(0, min(1, viewModel.playbackState.currentTime / viewModel.playbackState.duration))
    }

    private var queueEntries: [NotchV2QueueEntry] {
        [
            .init(title: "彩虹", duration: "3:42", isActive: true),
            .init(title: "夜曲", duration: "4:18", isActive: false),
            .init(title: "稻香", duration: "3:59", isActive: false)
        ]
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(NotchV2DesignTokens.innerCardBackground)
                Capsule(style: .continuous)
                    .fill(NotchV2DesignTokens.accentPurple)
                    .frame(width: proxy.size.width * progress)
            }
        }
    }

    private func playbackButton(systemName: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 16 : 13, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : NotchV2DesignTokens.primaryText)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isPrimary ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.cardBackgroundStrong)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isPrimary ? 0.08 : 0.04), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct NotchV2QueueEntry: Identifiable {
    let id = UUID()
    let title: String
    let duration: String
    let isActive: Bool
}

private struct NotchV2QueueRow: View {
    let title: String
    let duration: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(duration)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? NotchV2DesignTokens.innerCardActive : NotchV2DesignTokens.innerCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? NotchV2DesignTokens.innerBorder.opacity(0.8) : Color.clear, lineWidth: 1)
        )
    }
}

private struct MusicCoverView: View {
    let artworkData: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NotchV2DesignTokens.accentPurple)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NotchV2DesignTokens.innerBorder.opacity(0.6), lineWidth: 1)
                )

            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
