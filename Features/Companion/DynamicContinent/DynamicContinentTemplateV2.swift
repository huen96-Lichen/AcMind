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
    static let expandedWidth: CGFloat = NotchV2DesignTokens.expandedWidth
    static let expandedHeight: CGFloat = NotchV2DesignTokens.expandedOverviewHeight
    static let topBarHeight: CGFloat = NotchV2DesignTokens.topBarHeight
    static let topBarY: CGFloat = 28
    static let topBarHorizontalPadding: CGFloat = 56
    static let centerAvoidWidth: CGFloat = NotchV2DesignTokens.notchSafeZoneWidth
    static let centerAvoidHeight: CGFloat = NotchV2DesignTokens.notchSafeZoneHeight
    static let pageHorizontalPadding: CGFloat = 22
    static let pageBottomPadding: CGFloat = 16
    static let columnGap: CGFloat = 14
    static let rowGap: CGFloat = 14
    static let leftColumnWidth: CGFloat = 180
    static let centerColumnWidth: CGFloat = 300
    static let rightColumnWidth: CGFloat = 200
    static let cardCornerRadius: CGFloat = NotchV2DesignTokens.cardRadius
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

        VStack(spacing: 0) {
            DynamicContinentTopBar(viewModel: viewModel)
                .zIndex(1)

            Group {
                switch viewModel.effectiveSelectedPage {
                case .overview:
                    DynamicContinentTodayPage(viewModel: viewModel)
                case .music:
                    DynamicContinentMusicPage(viewModel: viewModel)
                case .agent:
                    DynamicContinentAgentPage(viewModel: viewModel)
                case .systemStatus:
                    DynamicContinentSystemStatusPage(viewModel: viewModel)
                case .schedule:
                    DynamicContinentSchedulePage(viewModel: viewModel)
                }
            }
            .zIndex(0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            NotchV2LightStatusStrip(items: viewModel.lightStatusItems)
                .padding(.horizontal, NotchV2DesignTokens.pagePadding)
                .padding(.vertical, 6)
                .frame(height: NotchV2DesignTokens.dashboardFooterHeight)
        }
        .frame(
            width: DynamicContinentLayoutMetrics.expandedWidth,
            height: viewModel.expandedHeight,
            alignment: .top
        )
        .background(
            containerShape
                .fill(DynamicContinentDesignTokens.containerBackground)
                .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
        )
        .clipShape(containerShape)
    }
}
