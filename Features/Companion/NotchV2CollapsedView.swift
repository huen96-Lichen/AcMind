import SwiftUI
import AppKit
import AcMindKit

struct NotchV2CollapsedView: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    @ObservedObject private var coordinator = DynamicSurfaceCoordinator.shared
    @GestureState private var isLongPressing = false

    var body: some View {
        HStack(spacing: 10) {
            NotchV2CollapsedStatusBadge(content: viewModel.collapsedContent)

            Spacer(minLength: 0)

            Button(action: { viewModel.toggleExpansion() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .frame(width: 20, height: 20)
                    .background(
                        Capsule()
                            .fill(NotchV2DesignTokens.cardBackgroundStrong.opacity(0.78))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 11)
        .contentShape(Rectangle())
        .frame(width: NotchV2DesignTokens.collapsedWidth, height: NotchV2DesignTokens.collapsedHeight)
        .clipped()
        .scaleEffect(coordinator.dragPhase == .draggingContinent || coordinator.dragPhase == .continentLeavingTopDock ? 0.98 : 1.0)
        .opacity(coordinator.dragPhase == .draggingContinent || coordinator.dragPhase == .continentLeavingTopDock ? 0.82 : 1.0)
        .background(
            NotchShape(topCornerRadius: 10, bottomCornerRadius: NotchV2DesignTokens.islandBottomRadius)
                .fill(NotchV2DesignTokens.islandBackground)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 1)
        )
        .overlay(
            NotchShape(topCornerRadius: 10, bottomCornerRadius: NotchV2DesignTokens.islandBottomRadius)
                .fill(Color.white.opacity(viewModel.isHoverEmphasized ? 0.025 : 0.0))
        )
        .overlay(
            NotchShape(topCornerRadius: 10, bottomCornerRadius: NotchV2DesignTokens.islandBottomRadius)
                .stroke(NotchV2DesignTokens.separator.opacity(0.48), lineWidth: 1)
        )
        .onTapGesture {
            guard coordinator.dragPhase == .idle else { return }
            viewModel.toggleExpansion()
        }
        .simultaneousGesture(continentDragGesture)
    }

    private var continentDragGesture: some Gesture {
        LongPressGesture(minimumDuration: DynamicSurfaceCoordinator.longPressDuration, maximumDistance: 12)
            .updating($isLongPressing) { current, state, _ in
                state = current
            }
            .simultaneously(with: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { _ in
                guard isLongPressing else { return }
                let point = NSEvent.mouseLocation
                if coordinator.dragPhase == .idle {
                    coordinator.continentLongPressBegan(at: point)
                }
                coordinator.continentDragChanged(to: point)
            }
            .onEnded { _ in
                let point = NSEvent.mouseLocation
                coordinator.continentDragEnded(at: point)
        }
    }
}

private struct NotchV2CollapsedStatusBadge: View {
    let content: NotchV2CollapsedContent

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(content.tint.opacity(0.14))
                    .frame(width: 16, height: 16)

                Image(systemName: content.symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(content.tint)
            }

            VStack(alignment: .leading, spacing: -1) {
                Text(content.label)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.tertiaryText)
                    .tracking(0.35)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(content.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)

                    if let subtitle = content.subtitle {
                        Text(subtitle)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
