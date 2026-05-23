import SwiftUI

struct ACShellScaffold<Header: View, BodyContent: View>: View {
    let header: () -> Header
    let bodyContent: () -> BodyContent

    init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder bodyContent: @escaping () -> BodyContent
    ) {
        self.header = header
        self.bodyContent = bodyContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
                .frame(height: ACLayout.pageHeaderHeight)

            bodyContent()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct ACShellScrollContainer<Content: View>: View {
    let maxWidth: CGFloat
    let alignment: Alignment
    let spacing: CGFloat
    let content: () -> Content

    init(
        maxWidth: CGFloat = .infinity,
        alignment: Alignment = .leading,
        spacing: CGFloat = ACLayout.panelGap,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxWidth = maxWidth
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .padding(.horizontal, ACLayout.pagePaddingX)
            .padding(.vertical, ACLayout.pagePaddingY)
            .padding(.bottom, ACLayout.pagePaddingBottom)
            .frame(maxWidth: maxWidth, alignment: alignment)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct ACWorkspaceShell<Left: View, Center: View, Right: View>: View {
    let title: String
    let subtitle: String?
    let trailing: () -> AnyView
    let left: () -> Left
    let center: () -> Center
    let right: () -> Right

    init(
        title: String,
        subtitle: String? = nil,
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
            let contentMaxWidth: CGFloat = layoutMode == .tripleColumn ? ACLayout.workspaceContentMaxWidth : .infinity
            let contentAlignment: Alignment = layoutMode == .tripleColumn ? .center : .leading

            ACShellScaffold {
                ACPageHeader(title: title, subtitle: subtitle) {
                    trailing()
                }
            } bodyContent: {
                ACShellScrollContainer(
                    maxWidth: contentMaxWidth,
                    alignment: contentAlignment,
                    spacing: ACLayout.panelGap
                ) {
                    Group {
                        switch layoutMode {
                        case .tripleColumn:
                            tripleColumnLayout
                        case .doubleColumn:
                            doubleColumnLayout
                        case .singleColumn:
                            singleColumnLayout
                        }
                    }
                }
            }
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
            left()
                .frame(maxWidth: .infinity, alignment: .topLeading)

            center()
                .frame(maxWidth: .infinity, alignment: .topLeading)

            right()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
