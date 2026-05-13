import SwiftUI

struct NotchV2CollapsedView: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        HStack(spacing: 10) {
            Text("灵动大陆")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)

            Rectangle()
                .fill(NotchV2DesignTokens.separator.opacity(0.55))
                .frame(width: 1, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.playbackState.title.isEmpty ? "Agent 待命" : collapsedTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                Text(collapsedSubtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                NotchV2StatusDot(color: viewModel.playbackState.isPlaying ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.secondaryText)
                NotchV2StatusDot(color: viewModel.status == .ready ? NotchV2DesignTokens.accentGreen : NotchV2DesignTokens.secondaryText)
                Button(action: { viewModel.toggleExpansion() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .frame(width: 20, height: 20)
                        .background(
                            Capsule().fill(NotchV2DesignTokens.cardBackgroundStrong)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: NotchV2DesignTokens.collapsedWidth, height: NotchV2DesignTokens.collapsedHeight)
        .clipped()
        .background(
            NotchShape(topCornerRadius: 8, bottomCornerRadius: NotchV2DesignTokens.islandBottomRadius)
                .fill(NotchV2DesignTokens.islandBackground)
                .shadow(color: .black.opacity(0.24), radius: 8, x: 0, y: 2)
        )
        .overlay(
            NotchShape(topCornerRadius: 8, bottomCornerRadius: NotchV2DesignTokens.islandBottomRadius)
                .stroke(NotchV2DesignTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }

    private var collapsedTitle: String {
        if viewModel.playbackState.isPlaying {
            return viewModel.playbackState.title
        }
        return "Agent 待命"
    }

    private var collapsedSubtitle: String {
        if viewModel.playbackState.isPlaying {
            let artist = viewModel.playbackState.artist.isEmpty ? "未知艺术家" : viewModel.playbackState.artist
            return "♪ \(viewModel.playbackState.title) · \(artist)"
        }
        return "当前状态 · \(viewModel.selectedPage.title)"
    }
}

private struct NotchV2StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.22), radius: 2, x: 0, y: 0)
    }
}
