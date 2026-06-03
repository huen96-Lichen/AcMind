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

            ZStack(alignment: .top) {
                if viewModel.presentationState.isExpandedVisual {
                    NotchV2ExpandedView(viewModel: viewModel)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: NotchV2DesignTokens.transitionInsertScale, anchor: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                            )
                        )
                        .allowsHitTesting(true)
                } else {
                    NotchV2CollapsedView(viewModel: viewModel)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                                removal: .opacity.combined(with: .scale(scale: NotchV2DesignTokens.transitionRemoveScale, anchor: .top))
                            )
                        )
                        .allowsHitTesting(true)
                }
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

            SystemEventHUDView()
                .padding(.top, 10)
                .allowsHitTesting(false)
        }
        .clipShape(rootShape)
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
        LinearGradient(
            colors: [NotchV2DesignTokens.backdropGradientTop, NotchV2DesignTokens.backdropGradientBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()
        hoverTask = nil

        let settings = CompanionDisplaySettingsStore.load()
        guard settings.isEnabled, settings.autoExpand else { return }

        if hovering {
            hoverTask = Task { @MainActor in
                let delay = max(0.2, settings.hoverExpandDelay)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                onExpansionChange(true)
            }
        } else {
            hoverTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                onExpansionChange(false)
            }
        }
    }
}
