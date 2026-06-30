import SwiftUI

enum WorkbenchV2LayoutMode: String, CaseIterable, Identifiable {
    case regular
    case compact

    var id: String { rawValue }
}

struct WorkbenchV2ResolvedLayout: Equatable {
    let mode: WorkbenchV2LayoutMode
    let availableWidth: CGFloat
    let contentWidth: CGFloat
    let pagePaddingTop: CGFloat
    let pagePaddingLeading: CGFloat
    let pagePaddingBottom: CGFloat
    let pagePaddingTrailing: CGFloat
    let headerHeight: CGFloat
    let headerBottomGap: CGFloat
    let bodyHeight: CGFloat
    let footerHeight: CGFloat
    let dashboardColumnGap: CGFloat
    let dashboardRowGap: CGFloat
    let leftColumnWidth: CGFloat
    let middleColumnWidth: CGFloat
    let rightColumnWidth: CGFloat
    let heroHeight: CGFloat
    let secondaryCardHeight: CGFloat
    let trendHeight: CGFloat
    let topCompositeHeight: CGFloat
    let todayOverviewHeight: CGFloat
    let quickActionsHeight: CGFloat
    let showSecondaryCopy: Bool
}

enum WorkbenchV2Layout {
    static func resolve(for containerSize: CGSize) -> WorkbenchV2ResolvedLayout {
        let effectiveWindowWidth = containerSize.width + WorkbenchV2Metrics.sidebarWidth + WorkbenchV2Metrics.separatorWidth
        // The GeometryReader excludes the title-bar safe area. Width is the stable
        // signal for choosing the dashboard density; using height made the default
        // 1500 x 888 window incorrectly resolve to compact mode.
        let isCompact = effectiveWindowWidth < 1450
        let mode: WorkbenchV2LayoutMode = isCompact ? .compact : .regular
        let availableWidth = max(containerSize.width, 0)
        if isCompact {
            let pagePadding = WorkbenchV2Tokens.Layout.compactInnerPadding
            let headerHeight = WorkbenchV2Tokens.Layout.compactHeaderHeight
            let headerBottomGap = WorkbenchV2Tokens.Layout.containerGap
            let contentWidth = max(availableWidth - WorkbenchV2Tokens.Layout.compactInnerPadding * 2, 0)
            let columnGap = WorkbenchV2Tokens.Layout.compactColumnGap
            let rowGap = WorkbenchV2Tokens.Layout.dashboardRowGap
            let rightWidth = min(WorkbenchV2Tokens.Layout.compactRightColumnWidth, max(contentWidth * 0.26, 260))
            let remainingWidth = max(contentWidth - rightWidth - columnGap * 2, 0)
            let leftWidth = floor(max(remainingWidth * 0.5, 0))
            let middleWidth = max(remainingWidth - leftWidth, 0)
            let heroHeight = WorkbenchV2Tokens.Layout.compactHeroHeight
            let secondaryCardHeight = WorkbenchV2Tokens.Layout.compactSecondaryCardHeight
            let footerHeight = WorkbenchV2Tokens.Layout.compactFooterHeight
            let topCompositeHeight = heroHeight + rowGap + secondaryCardHeight
            let trendHeight = WorkbenchV2Tokens.Layout.compactTrendHeight
            let availableDashboardHeight = max(
                containerSize.height - pagePadding * 2 - headerHeight - headerBottomGap,
                0
            )
            let minimumDashboardHeight = topCompositeHeight + rowGap * 2 + trendHeight + footerHeight
            let dashboardHeight = max(availableDashboardHeight, minimumDashboardHeight)
            let resolvedTrendHeight = max(
                trendHeight,
                dashboardHeight - topCompositeHeight - rowGap * 2 - footerHeight
            )
            let quickActionsHeight = min(
                WorkbenchV2Tokens.Layout.compactQuickActionsHeight,
                max(144, floor(dashboardHeight * 0.32))
            )
            let todayOverviewHeight = max(dashboardHeight - rowGap - quickActionsHeight, 0)

            return WorkbenchV2ResolvedLayout(
                mode: mode,
                availableWidth: availableWidth,
                contentWidth: contentWidth,
                pagePaddingTop: pagePadding,
                pagePaddingLeading: pagePadding,
                pagePaddingBottom: pagePadding,
                pagePaddingTrailing: pagePadding,
                headerHeight: headerHeight,
                headerBottomGap: headerBottomGap,
                bodyHeight: dashboardHeight,
                footerHeight: footerHeight,
                dashboardColumnGap: columnGap,
                dashboardRowGap: rowGap,
                leftColumnWidth: leftWidth,
                middleColumnWidth: middleWidth,
                rightColumnWidth: rightWidth,
                heroHeight: heroHeight,
                secondaryCardHeight: secondaryCardHeight,
                trendHeight: resolvedTrendHeight,
                topCompositeHeight: topCompositeHeight,
                todayOverviewHeight: todayOverviewHeight,
                quickActionsHeight: quickActionsHeight,
                showSecondaryCopy: false
            )
        }

        let contentWidth = max(availableWidth - WorkbenchV2Tokens.Layout.pagePaddingLeading - WorkbenchV2Tokens.Layout.pagePaddingTrailing, 0)
        let columnGap = WorkbenchV2Tokens.Layout.dashboardColumnGap
        let rowGap = WorkbenchV2Tokens.Layout.dashboardRowGap
        let rightWidth = min(
            WorkbenchV2Tokens.Layout.rightColumnWidth,
            max(contentWidth * 0.26, 292)
        )
        let mainWidth = max(contentWidth - rightWidth - columnGap, 0)
        let leftWidth = floor((mainWidth - columnGap) / 2)
        let middleWidth = max(mainWidth - columnGap - leftWidth, 0)
        let heroHeight = WorkbenchV2Tokens.Layout.heroHeight
        let secondaryCardHeight = WorkbenchV2Tokens.Layout.secondaryCardHeight
        let topCompositeHeight = heroHeight + rowGap + secondaryCardHeight
        let footerHeight = WorkbenchV2Tokens.Layout.footerHeight
        let minimumTrendHeight = WorkbenchV2Tokens.Layout.trendHeight
        let availableDashboardHeight = max(
            containerSize.height
                - WorkbenchV2Tokens.Layout.pagePaddingTop
                - WorkbenchV2Tokens.Layout.pagePaddingBottom
                - WorkbenchV2Tokens.Layout.headerHeight
                - WorkbenchV2Tokens.Layout.headerBottomGap,
            0
        )
        let minimumDashboardHeight = topCompositeHeight + rowGap * 2 + minimumTrendHeight + footerHeight
        let dashboardHeight = max(
            availableDashboardHeight,
            minimumDashboardHeight
        )
        let trendHeight = max(
            minimumTrendHeight,
            dashboardHeight - topCompositeHeight - rowGap * 2 - footerHeight
        )
        let todayOverviewHeight = min(
            WorkbenchV2Tokens.Layout.todayOverviewHeight,
            max(dashboardHeight - WorkbenchV2Tokens.Layout.quickActionsHeight - rowGap, topCompositeHeight)
        )
        let quickActionsHeight = min(
            WorkbenchV2Tokens.Layout.quickActionsHeight,
            max(dashboardHeight - todayOverviewHeight - rowGap, WorkbenchV2Tokens.Layout.quickActionsHeight)
        )

        return WorkbenchV2ResolvedLayout(
            mode: mode,
            availableWidth: availableWidth,
            contentWidth: contentWidth,
            pagePaddingTop: WorkbenchV2Tokens.Layout.pagePaddingTop,
            pagePaddingLeading: WorkbenchV2Tokens.Layout.pagePaddingLeading,
            pagePaddingBottom: WorkbenchV2Tokens.Layout.pagePaddingBottom,
            pagePaddingTrailing: WorkbenchV2Tokens.Layout.pagePaddingTrailing,
            headerHeight: WorkbenchV2Tokens.Layout.headerHeight,
            headerBottomGap: WorkbenchV2Tokens.Layout.headerBottomGap,
            bodyHeight: dashboardHeight,
            footerHeight: WorkbenchV2Tokens.Layout.footerHeight,
            dashboardColumnGap: columnGap,
            dashboardRowGap: rowGap,
            leftColumnWidth: leftWidth,
            middleColumnWidth: middleWidth,
            rightColumnWidth: rightWidth,
            heroHeight: heroHeight,
            secondaryCardHeight: secondaryCardHeight,
            trendHeight: trendHeight,
            topCompositeHeight: topCompositeHeight,
            todayOverviewHeight: todayOverviewHeight,
            quickActionsHeight: quickActionsHeight,
            showSecondaryCopy: true
        )
    }
}
