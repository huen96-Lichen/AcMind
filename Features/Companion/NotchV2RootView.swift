import SwiftUI

public struct NotchV2RootView: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    private let onExpansionChange: (Bool) -> Void

    init(viewModel: NotchV2ViewModel, onExpansionChange: @escaping (Bool) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.onExpansionChange = onExpansionChange
    }

    public var body: some View {
        Group {
            if viewModel.isExpanded {
                NotchV2ExpandedView(viewModel: viewModel)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                NotchV2CollapsedView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .frame(width: viewModel.isExpanded ? NotchV2DesignTokens.expandedWidth : NotchV2DesignTokens.collapsedWidth,
               height: viewModel.isExpanded ? viewModel.expandedHeight : NotchV2DesignTokens.collapsedHeight,
               alignment: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: viewModel.isExpanded)
        .onChange(of: viewModel.isExpanded) { _, newValue in
            onExpansionChange(newValue)
        }
    }
}
