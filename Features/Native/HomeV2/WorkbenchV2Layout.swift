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
        let isCompact = effectiveWindowWidth < 1380
        let mode: WorkbenchV2LayoutMode = isCompact ? .compact : .regular
        let availableWidth = max(containerSize.width, 0)
        if isCompact {
            let pagePadding = WorkbenchV2Tokens.Layout.compactInnerPadding
            let headerHeight = WorkbenchV2Tokens.Layout.compactHeaderHeight
            let headerBottomGap = WorkbenchV2Tokens.Layout.containerGap
            let contentWidth = max(availableWidth - WorkbenchV2Tokens.Layout.compactInnerPadding * 2, 0)
            let columnGap = WorkbenchV2Tokens.Layout.compactColumnGap
            let rowGap = WorkbenchV2Tokens.Layout.dashboardRowGap
            let rightWidth = min(WorkbenchV2Tokens.Layout.compactRightColumnWidth, max(contentWidth * 0.28, 236))
            let remainingWidth = max(contentWidth - rightWidth - columnGap * 2, 0)
            let leftWidth = max(remainingWidth * 0.52, 0)
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
            let dashboardHeight = availableDashboardHeight
            let resolvedTrendHeight = max(
                trendHeight,
                dashboardHeight - topCompositeHeight - rowGap * 2 - footerHeight
            )
            let rightContentHeight = dashboardHeight - footerHeight - rowGap
            let todayOverviewHeight = min(
                WorkbenchV2Tokens.Layout.compactTodayOverviewHeight,
                rightContentHeight - rowGap - WorkbenchV2Tokens.Layout.compactQuickActionsHeight
            )
            let quickActionsHeight = rightContentHeight - todayOverviewHeight - rowGap

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
        let usableWidth = max(contentWidth - columnGap * 2, 0)
        let widthWeight: CGFloat = 1.04 + 0.98 + 0.92
        let leftWidth = floor(usableWidth * 1.04 / widthWeight)
        let middleWidth = floor(usableWidth * 0.98 / widthWeight)
        let rightWidth = max(usableWidth - leftWidth - middleWidth, 0)
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
        let dashboardHeight = availableDashboardHeight
        let trendHeight = max(
            minimumTrendHeight,
            dashboardHeight - topCompositeHeight - rowGap * 2 - footerHeight
        )
        let rightContentHeight = dashboardHeight - footerHeight - rowGap
        let todayOverviewHeight = min(
            WorkbenchV2Tokens.Layout.todayOverviewHeight,
            rightContentHeight - rowGap - WorkbenchV2Tokens.Layout.quickActionsHeight
        )
        let quickActionsHeight = rightContentHeight - todayOverviewHeight - rowGap

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
