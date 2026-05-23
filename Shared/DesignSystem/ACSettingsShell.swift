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

            ACShellScaffold {
                header()
            } bodyContent: {
                switch layoutMode {
                case .withSidebar:
                    sidebarLayout
                case .stacked:
                    stackedLayout
                }
            }
        }
    }
    
    private var sidebarLayout: some View {
            HStack(spacing: 0) {
                sidebar()
                    .frame(width: ACLayout.secondarySidebarWidth)
                    .background(ACColors.sidebarBackground)
            
            Divider()
                .overlay(ACColors.border)
            
            ACShellScrollContainer(
                maxWidth: ACLayout.secondaryPageContentMaxWidth,
                alignment: .leading,
                spacing: 0
            ) {
                Group {
                    content()
                }
            }
            .background(ACColors.pageBackground)
        }
    }
    
    private var stackedLayout: some View {
        ACShellScrollContainer(
            maxWidth: ACLayout.secondaryPageContentMaxWidth,
            alignment: .leading,
            spacing: ACLayout.panelGap
        ) {
            Group {
                sidebar()
                
                Divider()
                    .overlay(ACColors.border)
                
                content()
            }
        }
        .background(ACColors.pageBackground)
    }
}
