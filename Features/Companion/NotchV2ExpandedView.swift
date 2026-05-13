import SwiftUI

struct NotchV2ExpandedView: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        DynamicContinentTemplateV2(viewModel: viewModel)
    }
}
