import SwiftUI

struct ACWorkspaceShell<Left: View, Center: View, Right: View>: View {
    let title: String
    let subtitle: String
    let trailing: () -> AnyView
    let left: () -> Left
    let center: () -> Center
    let right: () -> Right

    init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> some View = { EmptyView() },
        @ViewBuilder left: @escaping () -> Left,
        @ViewBuilder center: @escaping () -> Center,
        @ViewBuilder right: @escaping () -> Right
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { AnyView(trailing()) }
        self.left = left
        self.center = center
        self.right = right
    }

    var body: some View {
        GeometryReader { geometry in
            let layoutMode = ACLayout.workspaceLayoutMode(for: geometry.size.width)

            VStack(alignment: .leading, spacing: 0) {
                ACPageHeader(title: title, subtitle: subtitle) {
                    trailing()
                }
                .frame(height: ACLayout.pageHeaderHeight)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: ACLayout.panelGap) {
                        switch layoutMode {
                        case .tripleColumn:
                            tripleColumnLayout
                        case .doubleColumn:
                            doubleColumnLayout
                        case .singleColumn:
                            singleColumnLayout
                        }
                    }
                    .padding(.horizontal, ACLayout.pagePaddingX)
                    .padding(.vertical, ACLayout.pagePaddingY)
                    .padding(.bottom, ACLayout.pagePaddingBottom)
                    .frame(maxWidth: ACLayout.workspaceContentMaxWidth, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private var tripleColumnLayout: some View {
        HStack(alignment: .top, spacing: ACLayout.panelGap) {
            left()
                .frame(width: ACLayout.workspaceLeftPanel)
            
            center()
                .frame(minWidth: ACLayout.workspaceMainMin, maxWidth: .infinity, alignment: .topLeading)
            
            right()
                .frame(width: ACLayout.inspectorWidth)
        }
    }
    
    private var doubleColumnLayout: some View {
        HStack(alignment: .top, spacing: ACLayout.panelGap) {
            left()
                .frame(width: ACLayout.workspaceLeftPanel)
            
            center()
                .frame(minWidth: ACLayout.workspaceMainMin, maxWidth: .infinity, alignment: .topLeading)
        }
    }
    
    private var singleColumnLayout: some View {
        VStack(alignment: .leading, spacing: ACLayout.panelGap) {
            center()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
