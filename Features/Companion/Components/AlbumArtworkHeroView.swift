import SwiftUI
import AppKit

struct AlbumArtworkHeroView: View {
    let artworkData: Data?
    let cornerRadius: CGFloat = NotchV2DesignTokens.cardRadius
    let accentColor: Color = NotchV2DesignTokens.accentBlue

    var body: some View {
        ZStack {
            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .scaleEffect(1.3)
                    .blur(radius: 40)
                    .opacity(0.75)

                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(accentColor)

                Image(systemName: "music.note")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct MusicTrackInfoView: View {
    let title: String
    let artist: String
    let album: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(NotchV2DesignTokens.Typography.title)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
            Text(artist)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Text(album)
                .font(NotchV2DesignTokens.Typography.footnote)
                .foregroundStyle(NotchV2DesignTokens.secondaryText.opacity(0.8))
                .lineLimit(1)
        }
    }
}

struct MusicPlaybackControlsView: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
            }
            .buttonStyle(.plain)

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
            }
            .buttonStyle(.plain)

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
            }
            .buttonStyle(.plain)
        }
    }
}
