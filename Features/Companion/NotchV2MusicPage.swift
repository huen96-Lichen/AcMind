import SwiftUI
import AppKit

struct NotchV2MusicPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            AlbumArtworkHeroView(artworkData: viewModel.playbackState.artwork)
                .frame(width: 176, height: 176)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(titleText)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(2)
                    Text("\(artistText) · \(albumText)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                }

                progressRow

                HStack(spacing: 14) {
                    playbackButton(systemName: "backward.fill", size: 56) {
                        viewModel.previousTrack()
                    }

                    playbackButton(systemName: viewModel.playbackState.isPlaying ? "pause.fill" : "play.fill", size: 64, isPrimary: true) {
                        viewModel.playPause()
                    }

                    playbackButton(systemName: "forward.fill", size: 56) {
                        viewModel.nextTrack()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            NotchV2Card(title: "播放来源", subtitle: "队列", symbol: "waveform") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sourceTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                        Text("最近播放")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }

                    Divider()
                        .overlay(NotchV2DesignTokens.separator)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([(1, "彩虹"), (2, "夜曲"), (3, "稻香")], id: \.0) { item in
                            HStack(spacing: 8) {
                                Text(String(format: "%02d", item.0))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(NotchV2DesignTokens.accentPurple)
                                    .frame(width: 22, alignment: .leading)
                                Text(item.1)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                                Spacer()
                                Text("3:42")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(width: 220)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, NotchV2DesignTokens.bottomPadding)
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
            Text(formatTime(viewModel.playbackState.currentTime))
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

            Text(formatTime(viewModel.playbackState.duration))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
    }

    private func playbackButton(systemName: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 18 : 15, weight: .semibold))
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
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(NotchV2DesignTokens.accentPurple)

            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}
