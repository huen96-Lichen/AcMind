import SwiftUI
import AcMindKit

public struct NotchV2RootView: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    private let container: ServiceContainer
    private let musicService: MusicService
    private let toastManager: ToastManager
    private let onExpansionChange: (Bool) -> Void

    init(
        viewModel: NotchV2ViewModel,
        container: ServiceContainer,
        musicService: MusicService,
        toastManager: ToastManager,
        onExpansionChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.container = container
        self.musicService = musicService
        self.toastManager = toastManager
        self.onExpansionChange = onExpansionChange
    }

    public var body: some View {
        Group {
            if viewModel.isExpanded {
                NotchV2ExpandedView(viewModel: viewModel, container: container)
            } else {
                NotchV2CollapsedView(viewModel: viewModel)
            }
        }
        .environmentObject(musicService)
        .environmentObject(toastManager)
        .frame(width: viewModel.isExpanded ? NotchV2DesignTokens.expandedWidth : NotchV2DesignTokens.collapsedWidth,
               height: viewModel.isExpanded ? viewModel.expandedHeight : NotchV2DesignTokens.collapsedHeight,
               alignment: .top)
        .onHover { hovering in
            viewModel.setPanelHovered(hovering)
        }
        .onChange(of: viewModel.isExpanded) { _, newValue in
            onExpansionChange(newValue)
        }
    }
}
