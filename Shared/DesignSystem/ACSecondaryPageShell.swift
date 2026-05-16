import SwiftUI

enum ACSecondaryPageLayout {
    case standard
    case withSidebar
}

struct ACSecondaryPageShell<Content: View>: View {
    let layout: ACSecondaryPageLayout
    let header: () -> AnyView
    let content: () -> Content
    
    init<Header: View>(
        layout: ACSecondaryPageLayout = .standard,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.layout = layout
        self.header = { AnyView(header()) }
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
                .frame(height: ACLayout.pageHeaderHeight)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: layout == .withSidebar ? ACLayout.panelGap : 16) {
                    content()
                }
                .padding(.horizontal, ACLayout.pagePaddingX)
                .padding(.vertical, ACLayout.pagePaddingY)
                .padding(.bottom, ACLayout.pagePaddingBottom)
                .frame(
                    maxWidth: layout == .withSidebar ? .infinity : ACLayout.secondaryPageContentMaxWidth,
                    alignment: layout == .withSidebar ? .leading : .center
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension ACSecondaryPageShell where Content == EmptyView {
    init<Header: View>(
        layout: ACSecondaryPageLayout = .standard,
        @ViewBuilder header: @escaping () -> Header
    ) {
        self.layout = layout
        self.header = { AnyView(header()) }
        self.content = { EmptyView() }
    }
}
