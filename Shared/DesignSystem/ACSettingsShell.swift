import SwiftUI

struct ACSettingsShell<Sidebar: View, Content: View>: View {
    let header: () -> AnyView
    let sidebar: () -> Sidebar
    let content: () -> Content

    init<Header: View>(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.header = { AnyView(header()) }
        self.sidebar = sidebar
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let layoutMode = ACLayout.settingsLayoutMode(for: geometry.size.width)

            VStack(alignment: .leading, spacing: 0) {
                header()
                    .frame(height: ACLayout.pageHeaderHeight)

                switch layoutMode {
                case .withSidebar:
                    sidebarLayout
                case .stacked:
                    stackedLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private var sidebarLayout: some View {
        HStack(spacing: 0) {
            sidebar()
                .frame(width: ACLayout.secondarySidebarWidth)
            
            Divider()
                .overlay(ACColors.border)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .padding(.horizontal, ACLayout.pagePaddingX)
                .padding(.vertical, ACLayout.pagePaddingY)
                .padding(.bottom, ACLayout.pagePaddingBottom)
                .frame(maxWidth: ACLayout.secondaryPageContentMaxWidth, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private var stackedLayout: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ACLayout.panelGap) {
                sidebar()
                
                Divider()
                    .overlay(ACColors.border)
                
                content()
            }
            .padding(.horizontal, ACLayout.pagePaddingX)
            .padding(.vertical, ACLayout.pagePaddingY)
            .padding(.bottom, ACLayout.pagePaddingBottom)
            .frame(maxWidth: ACLayout.secondaryPageContentMaxWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
