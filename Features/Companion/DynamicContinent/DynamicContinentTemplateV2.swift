import SwiftUI
import AppKit

typealias DynamicCard<Content: View> = NotchV2Card<Content>

enum DynamicContinentLayoutMetrics {
    static var menuBarHeight: CGFloat {
        NSStatusBar.system.thickness
    }
    static var collapsedHeight: CGFloat {
        menuBarHeight
    }
    static let expandedWidth: CGFloat = CompanionLayoutTokens.expandedWindowWidth
    static let expandedHeight: CGFloat = CompanionLayoutTokens.expandedWindowHeight
    static let topBarHeight: CGFloat = CompanionLayoutTokens.topBarHeight
    static let topBarY: CGFloat = 28
    static let topBarHorizontalPadding: CGFloat = 56
    static let centerAvoidWidth: CGFloat = NotchV2DesignTokens.notchSafeZoneWidth
    static let centerAvoidHeight: CGFloat = NotchV2DesignTokens.notchSafeZoneHeight
    static let pageHorizontalPadding: CGFloat = CompanionLayoutTokens.pageHorizontalPadding
    static let pageBottomPadding: CGFloat = CompanionLayoutTokens.pageVerticalPadding
    static let columnGap: CGFloat = CompanionLayoutTokens.majorColumnSpacing
    static let rowGap: CGFloat = CompanionLayoutTokens.majorColumnSpacing
    static let leftColumnWidth: CGFloat = CompanionLayoutTokens.templateAColumnWidth
    static let centerColumnWidth: CGFloat = 300
    static let rightColumnWidth: CGFloat = CompanionLayoutTokens.templateAColumnWidth
    static let cardCornerRadius: CGFloat = CompanionLayoutTokens.cardCornerRadius
    static let containerCornerRadius: CGFloat = NotchV2DesignTokens.largeRadius
}

enum DynamicContinentDesignTokens {
    static let containerBackground = NotchV2DesignTokens.rootBackground
    static let cardBackground = NotchV2DesignTokens.panelBackground
    static let cardBackgroundStrong = NotchV2DesignTokens.innerCardBackground
    static let innerCardBackground = NotchV2DesignTokens.innerCardBackground
    static let cardStroke = NotchV2DesignTokens.panelBorder
    static let primaryText = NotchV2DesignTokens.primaryText
    static let secondaryText = NotchV2DesignTokens.secondaryText
    static let tertiaryText = NotchV2DesignTokens.tertiaryText
    static let accentPurple = NotchV2DesignTokens.accentPurple
    static let successGreen = NotchV2DesignTokens.accentGreen
    static let cardShadow = Color.black.opacity(0.35)
}

struct DynamicContinentTopBar: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2TopBar(viewModel: viewModel)
    }
}

struct DynamicContinentTemplateV2: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    @EnvironmentObject private var serviceContainer: ServiceContainer

    var body: some View {
        let containerShape = NotchShape(topCornerRadius: 14, bottomCornerRadius: DynamicContinentLayoutMetrics.containerCornerRadius)
        let statusItems = viewModel.lightStatusItems
        let shouldShowStatusStrip = statusItems.contains(where: { $0.highlighted })

        VStack(spacing: 0) {
            DynamicContinentTopBar(viewModel: viewModel)
                .zIndex(1)

            GeometryReader { proxy in
                let safeContentHeight = max(0, proxy.size.height)
                ScrollView(.vertical, showsIndicators: false) {
                    pageContent
                        .frame(
                            maxWidth: .infinity,
                            minHeight: safeContentHeight,
                            maxHeight: safeContentHeight,
                            alignment: .topLeading
                        )
                }
                .frame(width: proxy.size.width, height: safeContentHeight, alignment: .topLeading)
            }
            .zIndex(0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if shouldShowStatusStrip {
                NotchV2LightStatusStrip(items: statusItems)
                    .padding(.horizontal, NotchV2DesignTokens.pagePadding)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(
            width: DynamicContinentLayoutMetrics.expandedWidth,
            height: viewModel.expandedHeight,
            alignment: .top
        )
        .background(
            containerShape
                .fill(DynamicContinentDesignTokens.containerBackground)
                .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 5)
        )
        .environment(\.colorScheme, .dark)
        .tint(NotchV2DesignTokens.accentBlue)
        .clipShape(containerShape)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch viewModel.effectiveSelectedPage {
        case .overview:
            DynamicContinentTodayPage(viewModel: viewModel)
        case .launcher:
            DynamicContinentLauncherPage(viewModel: viewModel)
        case .music:
            DynamicContinentMusicPage(viewModel: viewModel)
        case .agent:
            DynamicContinentAgentPage(viewModel: viewModel)
        case .systemStatus:
            DynamicContinentSystemStatusPage(viewModel: viewModel)
        case .schedule:
            DynamicContinentSchedulePage(viewModel: viewModel)
        case .settings:
            NotchV2SettingsPage(viewModel: viewModel)
        }
    }
}
