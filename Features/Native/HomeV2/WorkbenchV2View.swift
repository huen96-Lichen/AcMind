import SwiftUI
import AppKit

struct WorkbenchV2CurrentFocusActions {
    let continueWork: () -> Void
    let viewDetails: () -> Void
    let selectBackground: () -> Void
}

struct WorkbenchV2QuickActionHandlers {
    let screenshot: () -> Void
    let quickRecord: () -> Void
    let createTask: () -> Void
    let openInbox: () -> Void
    let startAgent: () -> Void
    let importFiles: () -> Void
    let addSchedule: () -> Void
}

@MainActor
struct WorkbenchV2LiveView: View {
    @StateObject private var dashboardViewModel: WorkspaceDashboardViewModel
    @ObservedObject var heroBackgroundStore: WorkbenchV2HeroBackgroundStore

    init(
        repository: any WorkspaceDashboardRepositoryProtocol,
        heroBackgroundStore: WorkbenchV2HeroBackgroundStore = .shared
    ) {
        _dashboardViewModel = StateObject(wrappedValue: WorkspaceDashboardViewModel(repository: repository))
        self.heroBackgroundStore = heroBackgroundStore
    }

    var body: some View {
        WorkbenchV2View(
            dashboardData: .live(from: dashboardViewModel.snapshot),
            debugOverlayEnabled: true,
            heroBackgroundStore: heroBackgroundStore,
            currentFocusActions: .init(
                continueWork: { AppState.shared.navigate(to: .agent) },
                viewDetails: { AppState.shared.navigate(to: .agent) },
                selectBackground: {}
            ),
            quickActionHandlers: .init(
                screenshot: { NotificationCenter.default.post(name: Notification.Name("AcMind.captureScreenshot"), object: nil) },
                quickRecord: { NotificationCenter.default.post(name: .companionShowCapturePanel, object: nil) },
                createTask: { AppState.shared.navigate(to: .agent) },
                openInbox: { AppState.shared.navigateToInbox() },
                startAgent: { AppState.shared.navigate(to: .agent) },
                importFiles: {
                    AppState.shared.navigateToInbox()
                    NotificationCenter.default.post(name: .companionShowCapturePanel, object: nil)
                },
                addSchedule: { AppState.shared.navigate(to: .schedule) }
            )
        )
        .onAppear { dashboardViewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .acmindSourceItemsDidChange)) { _ in
            dashboardViewModel.refresh()
        }
        .task {
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(30))
                guard Task.isCancelled == false else { return }
                dashboardViewModel.refresh()
            }
        }
    }
}

struct WorkbenchV2View: View {
    let dashboardData: WorkbenchV2DashboardData
    let debugOverlayEnabled: Bool
    @ObservedObject var heroBackgroundStore: WorkbenchV2HeroBackgroundStore
    let currentFocusActions: WorkbenchV2CurrentFocusActions
    let quickActionHandlers: WorkbenchV2QuickActionHandlers

#if DEBUG
    @StateObject private var layoutDebugStore = LayoutDebugStore.shared
#endif

    init(
        dashboardData: WorkbenchV2DashboardData,
        debugOverlayEnabled: Bool,
        heroBackgroundStore: WorkbenchV2HeroBackgroundStore = .shared,
        currentFocusActions: WorkbenchV2CurrentFocusActions,
        quickActionHandlers: WorkbenchV2QuickActionHandlers
    ) {
        self.dashboardData = dashboardData
        self.debugOverlayEnabled = debugOverlayEnabled
        self.heroBackgroundStore = heroBackgroundStore
        self.currentFocusActions = currentFocusActions
        self.quickActionHandlers = quickActionHandlers
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkbenchV2Layout.resolve(for: proxy.size)
            let resolvedCurrentFocusActions = WorkbenchV2CurrentFocusActions(
                continueWork: currentFocusActions.continueWork,
                viewDetails: currentFocusActions.viewDetails,
                selectBackground: { heroBackgroundStore.chooseBackground() }
            )

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    WorkbenchHeader(model: dashboardData.header, layout: layout)

                    WorkbenchSummaryStrip(
                        items: [
                            .init(title: "聚焦", value: dashboardData.currentFocus.title, tint: WorkbenchV2Tokens.Color.accent),
                            .init(title: "待办", value: "\(dashboardData.pendingItems.items.count) 项", tint: WorkbenchV2Tokens.Color.accentOrange),
                            .init(title: "今日", value: "\(dashboardData.todayStatus.items.count) 项", tint: WorkbenchV2Tokens.Color.accentGreen),
                            .init(title: "快捷", value: "\(dashboardData.quickActions.actions.count) 个", tint: WorkbenchV2Tokens.Color.textSecondary)
                        ],
                        layout: layout
                    )
                    .padding(.top, WorkbenchV2Tokens.Spacing.sm)

                    WorkbenchV2MainDashboardGrid(
                        model: dashboardData,
                        layout: layout,
                        heroBackgroundStore: heroBackgroundStore,
                        currentFocusActions: resolvedCurrentFocusActions,
                        quickActionHandlers: quickActionHandlers
                    )
                        .frame(height: layout.bodyHeight, alignment: .topLeading)
                        .padding(.top, layout.headerBottomGap)

                }
                .padding(.top, layout.pagePaddingTop)
                .padding(.leading, layout.pagePaddingLeading)
                .padding(.trailing, layout.pagePaddingTrailing)
                .padding(.bottom, layout.pagePaddingBottom)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .background(WorkbenchV2Tokens.Color.background)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .coordinateSpace(name: "AcWorkWindow")
#if DEBUG
            .layoutDebugRegion("WorkbenchV2View")
            .onPreferenceChange(LayoutMeasurementPreferenceKey.self) { measurements in
                layoutDebugStore.update(measurements)
            }
            .overlay {
                if debugOverlayEnabled && layoutDebugStore.isOverlayVisible {
                    LayoutDebugOverlay(measurements: layoutDebugStore.measurements)
                        .allowsHitTesting(false)
                }
            }
#endif
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

private struct WorkbenchV2MainDashboardGrid: View {
    let model: WorkbenchV2DashboardData
    let layout: WorkbenchV2ResolvedLayout
    let heroBackgroundStore: WorkbenchV2HeroBackgroundStore
    let currentFocusActions: WorkbenchV2CurrentFocusActions
    let quickActionHandlers: WorkbenchV2QuickActionHandlers

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: layout.dashboardRowGap) {
                HStack(alignment: .top, spacing: layout.dashboardColumnGap) {
                    CurrentFocusCard(
                        model: model.currentFocus,
                        layout: layout,
                        backgroundImage: heroBackgroundStore.resolvedBackgroundImage,
                        actions: currentFocusActions
                    )
                        .frame(width: layout.leftColumnWidth + layout.dashboardColumnGap + layout.middleColumnWidth, height: layout.heroHeight, alignment: .topLeading)
                        .layoutDebugRegion("CurrentFocusCard")
                }
                .frame(width: layout.leftColumnWidth + layout.dashboardColumnGap + layout.middleColumnWidth, alignment: .topLeading)

                HStack(alignment: .top, spacing: layout.dashboardColumnGap) {
                    PendingItemsCard(model: model.pendingItems, layout: layout)
                        .frame(width: layout.leftColumnWidth, height: layout.secondaryCardHeight, alignment: .topLeading)
                        .layoutDebugRegion("PendingItemsCard")

                    RecentCollectionCard(model: model.recentCollection, layout: layout)
                        .frame(width: layout.middleColumnWidth, height: layout.secondaryCardHeight, alignment: .topLeading)
                        .layoutDebugRegion("RecentCollectionCard")
                }
                .frame(width: layout.leftColumnWidth + layout.dashboardColumnGap + layout.middleColumnWidth, alignment: .topLeading)

                HStack(alignment: .top, spacing: layout.dashboardColumnGap) {
                    ActivityTrendCard(model: model.activityTrend, layout: layout)
                        .frame(width: layout.leftColumnWidth + layout.dashboardColumnGap + layout.middleColumnWidth, height: layout.trendHeight, alignment: .topLeading)
                        .layoutDebugRegion("ActivityTrendCard")
                }
                .frame(width: layout.leftColumnWidth + layout.dashboardColumnGap + layout.middleColumnWidth, alignment: .topLeading)

                DeviceStatusBar(model: model.deviceStatus, layout: layout)
                    .frame(width: layout.contentWidth, height: layout.footerHeight, alignment: .center)
                    .layoutDebugRegion("DeviceStatusBar")
            }
            .frame(width: layout.contentWidth, height: layout.bodyHeight, alignment: .topLeading)

            VStack(alignment: .leading, spacing: layout.dashboardRowGap) {
                TodayOverviewPanel(model: model.todayStatus, layout: layout)
                    .frame(width: layout.rightColumnWidth, height: layout.todayOverviewHeight, alignment: .topLeading)
                    .layoutDebugRegion("TodayOverviewPanel")

                QuickActionsCard(
                    model: model.quickActions,
                    layout: layout,
                    actions: quickActionHandlers
                )
                    .frame(width: layout.rightColumnWidth, height: layout.quickActionsHeight, alignment: .topLeading)
                    .layoutDebugRegion("QuickActionsCard")
            }
            .frame(width: layout.rightColumnWidth, alignment: .topLeading)
            .frame(width: layout.contentWidth, height: layout.bodyHeight, alignment: .topTrailing)
        }
        .frame(width: layout.contentWidth, height: layout.bodyHeight, alignment: .topLeading)
#if DEBUG
        .layoutDebugRegion("MainDashboardGrid")
#endif
    }
}

private struct WorkbenchSummaryStrip: View {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let tint: Color
    }

    let items: [Item]
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        HStack(spacing: WorkbenchV2Tokens.Spacing.sm) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                        .lineLimit(1)

                    Text(item.value)
                        .font(.system(size: layout.mode == .compact ? 11.5 : 12.5, weight: .semibold))
                        .foregroundStyle(item.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WorkbenchV2Tokens.Spacing.sm)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                        .fill(WorkbenchV2Tokens.Color.surfaceSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                        .stroke(item.tint.opacity(0.16), lineWidth: 1)
                )
            }
        }
    }
}

struct WorkbenchV2Card<Content: View>: View {
    let title: String
    let debugName: String?
    let state: WorkbenchV2State
    let layout: WorkbenchV2ResolvedLayout
    let content: Content

    init(
        title: String,
        debugName: String? = nil,
        state: WorkbenchV2State,
        layout: WorkbenchV2ResolvedLayout,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.debugName = debugName
        self.state = state
        self.layout = layout
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: WorkbenchV2Tokens.Spacing.sm) {
                Text(title)
                    .font(.system(size: WorkbenchV2Tokens.Typography.cardTitle, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)

                Spacer(minLength: 0)

                WorkbenchV2StatusPill(state: state)
            }

            content
        }
        .padding(WorkbenchV2Tokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.surface)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous)
                .stroke(WorkbenchV2Tokens.Color.separator, lineWidth: WorkbenchV2Tokens.Border.width)
        )
        .shadow(
            color: Color.black.opacity(WorkbenchV2Tokens.Shadow.opacity),
            radius: WorkbenchV2Tokens.Shadow.radius,
            x: WorkbenchV2Tokens.Shadow.x,
            y: WorkbenchV2Tokens.Shadow.y
        )
    }
}

private struct WorkbenchV2StatusPill: View {
    let state: WorkbenchV2State

    var body: some View {
        Text(state.rawValue.uppercased())
            .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .semibold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }

    private var tint: Color {
        switch state {
        case .empty:
            return WorkbenchV2Tokens.Color.textTertiary
        case .normal:
            return WorkbenchV2Tokens.Color.accent
        case .warning:
            return WorkbenchV2Tokens.Color.accentOrange
        }
    }
}

struct WorkbenchV2EmptyState: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "square.dashed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WorkbenchV2Tokens.Color.textTertiary)
            Text(text)
                .font(.system(size: WorkbenchV2Tokens.Typography.caption))
                .foregroundStyle(WorkbenchV2Tokens.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WorkbenchV2Tokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.surfaceSoft)
        )
    }
}

extension WorkbenchV2View {
#if DEBUG
    init(
        previewDashboardData: WorkbenchV2DashboardData,
        debugOverlayEnabled: Bool,
        heroBackgroundStore: WorkbenchV2HeroBackgroundStore = .shared
    ) {
        self.init(
            dashboardData: previewDashboardData,
            debugOverlayEnabled: debugOverlayEnabled,
            heroBackgroundStore: heroBackgroundStore,
            currentFocusActions: .previewOnly,
            quickActionHandlers: .previewOnly
        )
    }

    init(debugOverlayEnabled: Bool = false) {
        self.init(previewDashboardData: .preview(), debugOverlayEnabled: debugOverlayEnabled)
    }
#endif
}

#if DEBUG
struct WorkbenchV2View_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WorkbenchV2View(previewDashboardData: .preview(), debugOverlayEnabled: false)
                .frame(width: 1500, height: 888)
            WorkbenchV2View(previewDashboardData: .compactWarning(), debugOverlayEnabled: true)
                .frame(width: 1180, height: 720)
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
