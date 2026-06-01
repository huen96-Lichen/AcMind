import SwiftUI

public struct NotchV2RootView: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    private let onExpansionChange: (Bool) -> Void
    @State private var hoverTask: Task<Void, Never>?

    init(viewModel: NotchV2ViewModel, onExpansionChange: @escaping (Bool) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.onExpansionChange = onExpansionChange
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Group {
                if viewModel.presentationState.isExpandedVisual {
                    NotchV2ExpandedView(viewModel: viewModel)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: NotchV2DesignTokens.transitionInsertScale, anchor: .top)),
                                removal: .opacity.combined(with: .scale(scale: NotchV2DesignTokens.transitionRemoveScale, anchor: .top))
                            )
                        )
                } else {
                    NotchV2CollapsedView(viewModel: viewModel)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 1.0, anchor: .center)),
                                removal: .opacity.combined(with: .scale(scale: NotchV2DesignTokens.transitionRemoveScale, anchor: .center))
                            )
                        )
                }
            }
            .frame(width: viewModel.presentationState.isExpandedVisual ? NotchV2DesignTokens.expandedWidth : viewModel.collapsedSize.width,
                   height: viewModel.presentationState.isExpandedVisual ? viewModel.expandedHeight : viewModel.collapsedSize.height,
                   alignment: .top)
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
        .onHover(perform: handleHover(_:))
        .onDisappear {
            hoverTask?.cancel()
            hoverTask = nil
        }
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
