import SwiftUI

enum ACSecondaryPageLayout {
    case standard
    case withSidebar
}

struct ACSecondaryPageShell<Content: View>: View {
    let layout: ACSecondaryPageLayout
    let header: () -> AnyView
    let content: (CGFloat) -> Content
    
    init<Header: View>(
        layout: ACSecondaryPageLayout = .standard,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping (CGFloat) -> Content
    ) {
        self.layout = layout
        self.header = { AnyView(header()) }
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = layout == .standard && geometry.size.width < ACLayout.Breakpoint.compact
            let contentSpacing = (layout == .withSidebar || isCompact) ? ACLayout.panelGap : 16
            let contentMaxWidth: CGFloat = (layout == .withSidebar || isCompact) ? .infinity : ACLayout.secondaryPageContentMaxWidth
            let contentAlignment: Alignment = (layout == .withSidebar || isCompact) ? .leading : .center

            ACShellScaffold {
                header()
            } bodyContent: {
                ACShellScrollContainer(
                    maxWidth: contentMaxWidth,
                    alignment: contentAlignment,
                    spacing: contentSpacing
                ) {
                    content(geometry.size.width)
                }
            }
        }
    }
}

extension ACSecondaryPageShell where Content == EmptyView {
    init<Header: View>(
        layout: ACSecondaryPageLayout = .standard,
        @ViewBuilder header: @escaping () -> Header
    ) {
        self.layout = layout
        self.header = { AnyView(header()) }
        self.content = { _ in EmptyView() }
    }
}
