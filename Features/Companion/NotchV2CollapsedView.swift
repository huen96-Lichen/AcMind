import SwiftUI
import AppKit
import AcMindKit

struct NotchV2CollapsedView: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        ZStack {
            NotchShape(topCornerRadius: 8, bottomCornerRadius: NotchV2DesignTokens.islandBottomRadius)
                .fill(NotchV2DesignTokens.islandBackground)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)

            if viewModel.hasVoiceOverride {
                SayInputWaveformHalo(
                    isActive: viewModel.showsVoiceWaveform,
                    mode: viewModel.voiceWaveformMode,
                    accent: viewModel.voiceDisplayAccent
                )
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .allowsHitTesting(false)
            } else {
                HStack(spacing: 8) {
                    if viewModel.hasPlaybackContext {
                        musicCollapsedLayout
                    } else {
                        if viewModel.displaySettings.showCollapsedStatusDots {
                            NotchV2StatusDot(color: collapsedAccentDotColor)
                        }

                        ViewThatFits(in: .horizontal) {
                            collapsedDetails
                            collapsedTitleOnly
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .frame(width: 16, height: 16)
                        .background(
                            Capsule(style: .continuous)
                                .fill(NotchV2DesignTokens.cardBackgroundStrong.opacity(0.9))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(NotchV2DesignTokens.panelBorder, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(width: viewModel.collapsedSize.width, height: viewModel.collapsedSize.height)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleExpansion()
        }
        .clipped()
    }

    private var musicCollapsedLayout: some View {
        ViewThatFits(in: .horizontal) {
            musicCollapsedRichLayout
            musicCollapsedCompactLayout
            musicCollapsedTinyLayout
        }
    }

    private var musicCollapsedRichLayout: some View {
        HStack(spacing: 6) {
            CollapsedArtworkView(artworkData: viewModel.playbackState.artwork)
                .frame(
                    width: NotchV2DesignTokens.collapsedArtworkSize,
                    height: NotchV2DesignTokens.collapsedArtworkSize
                )

            VStack(alignment: .leading, spacing: 0) {
                MarqueeText(
                    .constant(viewModel.playbackState.title),
                    font: NotchV2DesignTokens.Typography.body,
                    textColor: NotchV2DesignTokens.primaryText,
                    minDuration: 2.0,
                    frameWidth: 92
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                if sourceBadgeText.isEmpty == false {
                    Text(sourceBadgeText)
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CollapsedMiniWaveform(accent: NotchV2DesignTokens.accentGreen)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var musicCollapsedCompactLayout: some View {
        HStack(spacing: 6) {
            CollapsedArtworkView(artworkData: viewModel.playbackState.artwork)
                .frame(
                    width: NotchV2DesignTokens.collapsedArtworkSize,
                    height: NotchV2DesignTokens.collapsedArtworkSize
                )

            MarqueeText(
                .constant(viewModel.playbackState.title),
                font: NotchV2DesignTokens.Typography.body,
                textColor: NotchV2DesignTokens.primaryText,
                minDuration: 2.0,
                frameWidth: 122
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            CollapsedMiniWaveform(accent: NotchV2DesignTokens.accentGreen)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var musicCollapsedTinyLayout: some View {
        HStack(spacing: 6) {
            CollapsedArtworkView(artworkData: viewModel.playbackState.artwork)
                .frame(
                    width: NotchV2DesignTokens.collapsedArtworkSize,
                    height: NotchV2DesignTokens.collapsedArtworkSize
                )

            MarqueeText(
                .constant(viewModel.playbackState.title),
                font: NotchV2DesignTokens.Typography.body,
                textColor: NotchV2DesignTokens.primaryText,
                minDuration: 2.0,
                frameWidth: 140
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var collapsedDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(collapsedTitle)
                .font(NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)

            if viewModel.displaySettings.showCollapsedSubtitle, let subtitle = collapsedSubtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(NotchV2DesignTokens.Typography.footnote)
                    .foregroundStyle(subtitleAccentColor.opacity(0.95))
                    .lineLimit(1)
            }
        }
    }

    private var collapsedTitleOnly: some View {
        Text(collapsedTitle)
            .font(NotchV2DesignTokens.Typography.body)
            .foregroundStyle(NotchV2DesignTokens.primaryText)
            .lineLimit(1)
    }

    private var collapsedTitle: String {
        viewModel.collapsedRuntimeSurface.title
    }

    private var collapsedSubtitle: String? {
        if viewModel.isRecordingActive {
            return ActivityStateLabelFormatter.recordingSubtitleLabel(
                realtimeTranscript: viewModel.realtimeTranscript
            )
        }
        return viewModel.collapsedRuntimeSurface.subtitle
    }

    private var subtitleAccentColor: Color {
        if viewModel.hasVoiceOverride {
            return viewModel.voiceDisplayAccent.opacity(0.92)
        }

        return viewModel.collapsedRuntimeSurface.accentColor.opacity(0.92)
    }

    private var collapsedAccentDotColor: Color {
        if viewModel.hasVoiceOverride {
            return viewModel.voiceDisplayAccent
        }

        return viewModel.collapsedRuntimeSurface.accentColor
    }

    private var sourceBadgeText: String {
        NowPlayingSourceLabelFormatter.playbackContextLabel(
            isPlaying: viewModel.playbackState.isPlaying,
            bundleIdentifier: viewModel.playbackState.bundleIdentifier,
            source: viewModel.playbackState.sourceLabel
        )
    }

}

private struct CollapsedArtworkView: View {
    let artworkData: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.collapsedArtworkRadius, style: .continuous)
                .fill(NotchV2DesignTokens.accentBlue)

            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: NotchV2DesignTokens.collapsedArtworkRadius, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: NotchV2DesignTokens.collapsedArtworkRadius, style: .continuous))
    }
}

private struct CollapsedMiniWaveform: View {
    let accent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: 1.2) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: 2, height: barHeight(for: index, time: time))
                        .opacity(barOpacity(for: index, time: time))
                }
            }
            .frame(height: 10)
        }
    }

    private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
        let base: CGFloat = 2.5
        let amplitude: CGFloat = 4.5
        let phase = time * 6.0 + Double(index) * 0.62
        let sample = CGFloat((sin(phase) + 1.0) / 2.0)
        return base + amplitude * sample
    }

    private func barOpacity(for index: Int, time: TimeInterval) -> Double {
        let phase = time * 5.0 + Double(index) * 0.35
        return 0.72 + 0.22 * ((sin(phase) + 1.0) / 2.0)
    }
}

private struct NotchV2StatusDot: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .shadow(color: color.opacity(isPulsing ? 0.5 : 0.15), radius: isPulsing ? 4 : 2, x: 0, y: 0)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
