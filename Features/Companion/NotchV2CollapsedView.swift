import SwiftUI

struct NotchV2CollapsedView: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        ZStack {
            NotchShape(topCornerRadius: 8, bottomCornerRadius: NotchV2DesignTokens.islandBottomRadius)
                .fill(NotchV2DesignTokens.islandBackground)
                .shadow(color: .black.opacity(0.24), radius: 8, x: 0, y: 2)

            if viewModel.hasVoiceOverride {
                SayInputWaveformHalo(
                    isActive: viewModel.showsVoiceWaveform,
                    mode: viewModel.voiceWaveformMode,
                    accent: viewModel.voiceDisplayAccent
                )
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .allowsHitTesting(false)
            }

            HStack(spacing: 10) {
                Text("灵动大陆")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)

                Rectangle()
                    .fill(NotchV2DesignTokens.separator.opacity(0.55))
                    .frame(width: 1, height: 10)

                ViewThatFits(in: .horizontal) {
                    collapsedDetails
                    collapsedTitleOnly
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    if viewModel.displaySettings.showCollapsedStatusDots {
                        NotchV2StatusDot(color: collapsedAccentDotColor)
                        NotchV2StatusDot(color: collapsedSecondaryDotColor)
                    }
                    Button(action: { viewModel.toggleExpansion() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                            .frame(width: 18, height: 18)
                            .background(
                                Capsule().fill(NotchV2DesignTokens.cardBackgroundStrong)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(width: viewModel.collapsedSize.width, height: viewModel.collapsedSize.height)
        .clipped()
        .overlay(
            NotchShape(topCornerRadius: 8, bottomCornerRadius: NotchV2DesignTokens.islandBottomRadius)
                .stroke(NotchV2DesignTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var collapsedDetails: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(collapsedTitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)

            if viewModel.displaySettings.showCollapsedSubtitle, let subtitle = collapsedSubtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(subtitleAccentColor)
                    .lineLimit(1)
            }
        }
    }

    private var collapsedTitleOnly: some View {
        Text(collapsedTitle)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(NotchV2DesignTokens.primaryText)
            .lineLimit(1)
    }

    private var collapsedTitle: String {
        viewModel.collapsedRuntimeSurface.title
    }

    private var collapsedSubtitle: String? {
        viewModel.collapsedRuntimeSurface.subtitle
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

    private var collapsedSecondaryDotColor: Color {
        if viewModel.hasVoiceOverride {
            return viewModel.voiceDisplayAccent.opacity(0.42)
        }

        return viewModel.collapsedRuntimeSurface.accentColor.opacity(0.45)
    }
}

private struct NotchV2StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .shadow(color: color.opacity(0.22), radius: 2, x: 0, y: 0)
    }
}
