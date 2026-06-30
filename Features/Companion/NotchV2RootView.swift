import SwiftUI
import AppKit

public struct NotchV2RootView: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    private let onExpansionChange: (Bool) -> Void
    @State private var hoverTask: Task<Void, Never>?
    @State private var gestureProgress: CGFloat = 0
    @State private var gestureStartY: CGFloat?


    init(viewModel: NotchV2ViewModel, onExpansionChange: @escaping (Bool) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.onExpansionChange = onExpansionChange
    }

    public var body: some View {
        let rootShape = NotchShape(
            topCornerRadius: viewModel.presentationState.isExpandedVisual ? 14 : 8,
            bottomCornerRadius: viewModel.presentationState.isExpandedVisual ? NotchV2DesignTokens.largeRadius : NotchV2DesignTokens.islandBottomRadius
        )

        ZStack(alignment: .top) {
            backdropLayer
                .clipShape(rootShape)

            ZStack(alignment: .top) {
                NotchV2CollapsedView(viewModel: viewModel)
                    .opacity(viewModel.presentationState.isExpandedVisual ? 0 : 1)
                    .scaleEffect(viewModel.presentationState.isExpandedVisual ? 0.985 : 1, anchor: .top)
                    .allowsHitTesting(viewModel.presentationState.isExpandedVisual == false)

                NotchV2ExpandedView(viewModel: viewModel)
                    .opacity(viewModel.presentationState.isExpandedVisual ? 1 : 0)
                    .scaleEffect(viewModel.presentationState.isExpandedVisual ? 1 : NotchV2DesignTokens.transitionRemoveScale, anchor: .top)
                    .allowsHitTesting(viewModel.presentationState.isExpandedVisual)
            }
            .frame(
                width: viewModel.presentationState.isExpandedVisual ? NotchV2DesignTokens.expandedWidth : viewModel.collapsedSize.width,
                height: viewModel.presentationState.isExpandedVisual ? viewModel.expandedHeight : viewModel.collapsedSize.height,
                alignment: .top
            )
            .mask(
                rootShape
                    .allowsHitTesting(false)
            )
            .animation(
                .spring(
                    response: NotchV2DesignTokens.springResponse,
                    dampingFraction: NotchV2DesignTokens.springDampingFraction
                ),
                value: viewModel.presentationState
            )

            SystemEventHUDView(center: viewModel.systemEventCenter)
                .padding(.top, 10)
                .allowsHitTesting(false)
                .clipShape(rootShape)
        }
        .contentShape(rootShape)
        .compositingGroup()
        .onHover(perform: handleHover(_:))
        .onDisappear {
            hoverTask?.cancel()
            hoverTask = nil
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let dy = value.translation.height
                    if gestureStartY == nil {
                        gestureStartY = dy
                    }
                    let progress = min(1, max(-1, (dy - (gestureStartY ?? 0)) / 50))
                    gestureProgress = progress
                }
                .onEnded { value in
                    let dy = value.translation.height - (gestureStartY ?? 0)
                    gestureStartY = nil
                    gestureProgress = 0

                    if dy > 30 && !viewModel.presentationState.isExpandedVisual {
                        onExpansionChange(true)
                        performHaptic()
                    } else if dy < -30 && viewModel.presentationState.isExpandedVisual {
                        onExpansionChange(false)
                        performHaptic()
                    }
                }
        )
    }

    private func performHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    private var backdropLayer: some View {
        AppSurfaceBackdrop()
    }

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()
        hoverTask = nil

        let settings = CompanionDisplaySettingsStore.load()
        guard settings.isEnabled, settings.autoExpand else { return }

        if hovering {
            hoverTask = Task { @MainActor in
                let delay = max(0.15, settings.hoverExpandDelay)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                if viewModel.presentationState != .expanded && viewModel.presentationState != .expanding {
                    onExpansionChange(true)
                }
            }
        } else {
            hoverTask = Task { @MainActor in
                let delay = max(0.08, settings.hoverExpandDelay * 0.45)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                if viewModel.presentationState == .expanded || viewModel.presentationState == .expanding {
                    onExpansionChange(false)
                }
            }
        }
    }
}
