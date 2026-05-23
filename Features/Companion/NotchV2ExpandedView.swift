import SwiftUI

struct NotchV2ExpandedView: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    private let container: ServiceContainer

    init(viewModel: NotchV2ViewModel, container: ServiceContainer) {
        self.viewModel = viewModel
        self.container = container
    }

    var body: some View {
        DynamicContinentTemplateV2(viewModel: viewModel, container: container)
    }
}
