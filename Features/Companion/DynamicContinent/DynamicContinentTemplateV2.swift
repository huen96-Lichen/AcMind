import SwiftUI
import AppKit
import AcMindKit

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
    static let topBarHeight: CGFloat = 36
    static let topBarY: CGFloat = 20
    static let topBarHorizontalPadding: CGFloat = 56
    static let centerAvoidWidth: CGFloat = 264
    static let centerAvoidHeight: CGFloat = 36
    static let pageHorizontalPadding: CGFloat = 32
    static let pageBottomPadding: CGFloat = 12
    static let columnGap: CGFloat = 16
    static let rowGap: CGFloat = 16
    static let leftColumnWidth: CGFloat = 160
    static let centerColumnWidth: CGFloat = 396
    static let rightColumnWidth: CGFloat = 180
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
    private let container: ServiceContainer

    init(viewModel: NotchV2ViewModel, container: ServiceContainer) {
        self.viewModel = viewModel
        self.container = container
    }

    var body: some View {
        let containerShape = NotchShape(topCornerRadius: 20, bottomCornerRadius: DynamicContinentLayoutMetrics.containerCornerRadius)

        VStack(spacing: 0) {
            DynamicContinentTopBar(viewModel: viewModel)
                .zIndex(1)

            Color.clear
                .frame(height: 12)

            Group {
                switch viewModel.selectedPage {
                case .overview:
                    DynamicContinentTodayPage(viewModel: viewModel)
                case .music:
                    DynamicContinentMusicPage(viewModel: viewModel)
                case .agent:
                    DynamicContinentAgentPage(viewModel: viewModel, container: container)
                case .schedule:
                    DynamicContinentSchedulePage(viewModel: viewModel)
                case .systemMonitor:
                    DynamicContinentSystemMonitorPage(viewModel: viewModel)
                }
            }
            .zIndex(0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(
            width: DynamicContinentLayoutMetrics.expandedWidth,
            height: viewModel.expandedHeight,
            alignment: .top
        )
        .background(
            containerShape
                .fill(DynamicContinentDesignTokens.containerBackground)
                .shadow(color: .black.opacity(0.55), radius: 28, x: 0, y: 16)
        )
        .overlay(
            containerShape
                .stroke(DynamicContinentDesignTokens.cardStroke, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if viewModel.isExpanded && (NSScreen.main?.safeAreaInsets.top ?? 0) > 28 {
                PhysicalNotchOverlay()
                    .position(
                        x: DynamicContinentLayoutMetrics.expandedWidth / 2,
                        y: DynamicContinentLayoutMetrics.topBarHeight / 2
                    )
                    .allowsHitTesting(false)
            }
        }
        .clipShape(containerShape)
    }
}

private struct PhysicalNotchOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.black)
            .frame(width: 160, height: DynamicContinentLayoutMetrics.topBarHeight)
    }
}
