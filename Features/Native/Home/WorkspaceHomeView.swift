import SwiftUI
import AcMindKit

private enum DashboardRadius {
    static let hero: CGFloat = AppSurfaceTokens.mainCardRadius
    static let card: CGFloat = AppSurfaceTokens.cardRadius
    static let block: CGFloat = AppSurfaceTokens.secondaryCardRadius
    static let icon: CGFloat = AppSurfaceTokens.inlineBlockRadius
    static let control: CGFloat = AppSurfaceTokens.inlineBlockRadius
}

private enum DashboardCardStyle {
    case regular
    case prominent
    case subtle
}

private struct DashboardTrendChart: View {
    let cpu: [Double]
    let memory: [Double]
    let network: [Double]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)

                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(AppSurfaceTokens.separator.opacity(0.14))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }

                fillPath(values: cpu, in: size)
                    .fill(AppSurfaceTokens.accentBlue.opacity(0.08))

                trendPath(values: cpu, in: size)
                    .stroke(AppSurfaceTokens.accentBlue, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                trendPath(values: memory, in: size)
                    .stroke(AppSurfaceTokens.accentPrimary, style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))

                trendPath(values: network, in: size)
                    .stroke(AppSurfaceTokens.accentGreen, style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))

                endpointGlow(values: cpu, tint: AppSurfaceTokens.accentBlue, in: size)
                endpointGlow(values: memory, tint: AppSurfaceTokens.accentPrimary, in: size)
                endpointGlow(values: network, tint: AppSurfaceTokens.accentGreen, in: size)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.72), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func trendPath(values: [Double], in size: CGSize) -> Path {
        let points = linePoints(values: values.isEmpty ? [0] : values, in: size)
        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func fillPath(values: [Double], in size: CGSize) -> Path {
        let points = linePoints(values: values.isEmpty ? [0] : values, in: size)
        return Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height - 6))
            path.addLine(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: size.height - 6))
            path.closeSubpath()
        }
    }

    @ViewBuilder
    private func endpointGlow(values: [Double], tint: Color, in size: CGSize) -> some View {
        let points = linePoints(values: values.isEmpty ? [0] : values, in: size)
        if let last = points.last {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 16, height: 16)
                .position(last)
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .position(last)
        }
    }

    private func linePoints(values: [Double], in size: CGSize) -> [CGPoint] {
        guard values.isEmpty == false else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, 0.0001)
        let horizontalStep = values.count > 1 ? size.width / CGFloat(values.count - 1) : size.width / 2

        return values.enumerated().map { index, value in
            let x = values.count > 1 ? CGFloat(index) * horizontalStep : size.width / 2
            let normalized = (value - minValue) / span
            let y = size.height - (CGFloat(normalized) * size.height * 0.72) - size.height * 0.14
            return CGPoint(x: x, y: max(6, min(size.height - 6, y)))
        }
    }
}

struct WorkspaceHomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("screenshotQuickStartDismissed") private var screenshotQuickStartDismissed = false
    @StateObject private var viewModel: SystemStatusViewModel
    @StateObject private var dashboardViewModel: WorkspaceDashboardViewModel
    private let permissionManager: PermissionManager
    private let settingsService: SettingsServiceProtocol
    @State private var screenshotSnapshot = SettingsLocalPreferences.screenshotSnapshot()
    @State private var activeScreenshotPresetID: String = ScreenshotPreset.defaultPresets.first?.id ?? "default-save"

    init(
        systemStatusService: SystemStatusService,
        permissionManager: PermissionManager = PermissionManager(),
        settingsService: SettingsServiceProtocol,
        storageService: any StorageServiceProtocol,
        scheduleService: any ScheduleServiceProtocol,
        agentTaskBoardService: any AgentTaskBoardServiceProtocol,
        dashboardRepository: (any WorkspaceDashboardRepositoryProtocol)? = nil
    ) {
        self.permissionManager = permissionManager
        self.settingsService = settingsService
        _viewModel = StateObject(wrappedValue: SystemStatusViewModel(service: systemStatusService))
        let resolvedRepository = dashboardRepository ?? LiveWorkspaceDashboardRepository(
            appState: AppState.shared,
            systemStatusService: systemStatusService,
            storageService: storageService,
            scheduleService: scheduleService,
            agentTaskBoardService: agentTaskBoardService
        )
        _dashboardViewModel = StateObject(wrappedValue: WorkspaceDashboardViewModel(repository: resolvedRepository))
    }

    private var quickActions: [HomeAction] {
        [
            HomeAction(title: "立即截图", icon: "camera.viewfinder", tint: AppSurfaceTokens.secondaryText, kind: .capture),
            HomeAction(title: "说入法", icon: "mic.fill", tint: AppSurfaceTokens.secondaryText, kind: .voice),
            HomeAction(title: "模型设置", icon: "brain", tint: AppSurfaceTokens.secondaryText, kind: .settingsAiModels),
            HomeAction(title: "接口测试", icon: "checkmark.shield", tint: AppSurfaceTokens.secondaryText, kind: .workbenchApiTest)
        ]
    }

    private var navigationActions: [HomeAction] {
        [
            HomeAction(title: SidebarItem.agent.displayName, icon: SidebarItem.agent.icon, tint: AppSurfaceTokens.secondaryText, kind: .agent),
            HomeAction(title: SidebarItem.inbox.displayName, icon: SidebarItem.inbox.icon, tint: AppSurfaceTokens.secondaryText, kind: .inbox),
            HomeAction(title: SidebarItem.schedule.displayName, icon: SidebarItem.schedule.icon, tint: AppSurfaceTokens.secondaryText, kind: .schedule),
            HomeAction(title: SidebarItem.systemStatus.displayName, icon: SidebarItem.systemStatus.icon, tint: AppSurfaceTokens.secondaryText, kind: .systemStatus)
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch dashboardViewModel.snapshot.phase {
                case .loaded:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if shouldShowScreenshotQuickStart {
                                screenshotQuickStartBanner
                            }
                            greetingHeader
                            homeOverviewStrip
                            homePrimaryDeck
                            screenshotCenterStrip
                            overviewRow
                            kpiRow
                            infoRow
                            sensorRow
                            auxiliaryRow
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .frame(maxWidth: AppSurfaceTokens.Layout.pageMaxWidth, minHeight: proxy.size.height, alignment: .topLeading)
                    }

                case .loading:
                    StateContainer(
                        phase: .loading(message: "正在读取工作台、日程、待处理内容和系统状态。")
                    ) {
                        EmptyView()
                    }
                    .padding(14)

                case .empty:
                    StateContainer(
                        phase: .empty(
                            title: "没有工作内容",
                            message: "创建第一条记录后会显示在这里。"
                        )
                    ) {
                        EmptyView()
                    }
                    .padding(14)

                case .error(let message):
                    StateContainer(
                        phase: .failed(
                            title: "工作台加载失败",
                            message: message,
                            actionTitle: "重试"
                        ) {
                            dashboardViewModel.refresh()
                        }
                    ) {
                        EmptyView()
                    }
                    .padding(14)
                }
            }
            .background(AppVisualBackdrop())
        }
        .onAppear {
            viewModel.startMonitoring()
            dashboardViewModel.refresh()
            refreshScreenshotConfiguration()
        }
        .onDisappear { viewModel.stopMonitoring() }
        .onReceive(NotificationCenter.default.publisher(for: .acmindSourceItemsDidChange)) { _ in
            dashboardViewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduleDidChange)) { _ in
            dashboardViewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentTaskBoardDidChange)) { _ in
            dashboardViewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            refreshScreenshotConfiguration()
        }
        .task {
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(30))
                guard Task.isCancelled == false else { return }
                dashboardViewModel.refresh()
            }
        }
    }

    private var shouldShowScreenshotQuickStart: Bool {
        screenshotQuickStartDismissed == false
    }

    private func dismissScreenshotQuickStart() {
        screenshotQuickStartDismissed = true
    }

    private var screenshotQuickStartBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.accentOrange)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous)
                        .fill(AppSurfaceTokens.accentOrange.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("截图入口就在这里")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text("优先点顶部工具栏的“截图”，首页“立即截图”会直接触发全屏截图并进入预览；需要改模式时再进截图工作区。")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        dismissScreenshotQuickStart()
                        postScreenshotCapture(mode: .fullscreen)
                    } label: {
                        Text("立即截图")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        dismissScreenshotQuickStart()
                        appState.navigate(to: .screenshot)
                    } label: {
                        Text("打开截图工作区")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Button {
                dismissScreenshotQuickStart()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(AppSurfaceTokens.cardBackgroundSoft)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭截图入口提示")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                .stroke(AppSurfaceTokens.accentOrange.opacity(0.28), lineWidth: 1)
        )
    }

    private var homePalette: ProductPanelTokens.Palette {
        ProductPanelTokens.palette(for: colorScheme, contrast: colorSchemeContrast)
    }

    private var greetingHeader: some View {
        HStack(alignment: .top, spacing: 5.5) {
            VStack(alignment: .leading, spacing: 0.5) {
                Text(greetingText)
                    .font(.system(size: AppSurfaceTokens.Typography.pageTitle, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text("保持高效创作")
                    .font(.system(size: AppSurfaceTokens.Typography.pageEyebrow, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 3) {
                topActionButton(title: "立即截图", icon: "camera.viewfinder", tint: AppSurfaceTokens.accentOrange) {
                    dismissScreenshotQuickStart()
                    postScreenshotCapture(mode: .fullscreen)
                }

                topActionButton(title: "快速记录", icon: "pencil", tint: AppSurfaceTokens.accentBlue) {
                    NotificationCenter.default.post(name: .companionShowCapturePanel, object: nil)
                }

                topActionButton(title: "说入法", icon: "mic.fill", tint: AppSurfaceTokens.accentPrimary) {
                    NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
                }

                topIconButton(icon: "chevron.down", action: nil)

                topSearchField
            }
        }
#if DEBUG
        .layoutDebugRegion("TopToolbar")
#endif
    }

    private var homePrimaryDeck: some View {
        HStack(alignment: .top, spacing: 14) {
            ProductPanelCard(
                variant: .prominent,
                title: "工作台总览",
                icon: "rectangle.grid.2x2",
                status: appState.isAppReady ? "已就绪" : "初始化中",
                statusTone: appState.isAppReady ? .success : .warning,
                footer: "最后刷新 \(viewModel.lastUpdatedText)"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("当前重点")
                            .font(ProductPanelTokens.Typography.cardCaption)
                            .foregroundStyle(homePalette.textSecondary)
                            .textCase(.uppercase)

                        Text(homePrimaryHeadline)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(homePalette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(homePrimarySummary)
                            .font(ProductPanelTokens.Typography.cardBody)
                            .foregroundStyle(homePalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("下一步")
                            .font(ProductPanelTokens.Typography.cardCaption)
                            .foregroundStyle(homePalette.textSecondary)
                            .textCase(.uppercase)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(navigationActions) { action in
                                Button {
                                    action.perform(using: appState)
                                } label: {
                                    homeActionChip(action)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 10) {
                        homeSummaryPill(title: "当前页面", value: appState.sidebarSelection.displayName, tint: homePalette.accent)
                        homeSummaryPill(title: "窗口", value: windowStateText(appState.mainWindowState), tint: homePalette.info)
                        homeSummaryPill(title: "采样", value: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor)
                    }
                }
            }
            .layoutPriority(2)
#if DEBUG
            .layoutDebugRegion("WorkOverviewCard")
#endif

            VStack(alignment: .leading, spacing: 12) {
                ProductPanelCard(
                    variant: .standard,
                    title: "系统健康",
                    icon: "heart.text.square",
                    status: viewModel.samplingStatusText,
                    statusTone: viewModel.snapshot.unavailableReasons.isEmpty ? .success : .warning,
                    footer: viewModel.refreshHint
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        homeHealthRow(label: "处理器", value: viewModel.cpuSummary, tint: AppSurfaceTokens.secondaryText)
                        homeHealthRow(label: "内存", value: viewModel.memorySummary, tint: AppSurfaceTokens.secondaryText)
                        homeHealthRow(label: "网络", value: viewModel.networkSummary, tint: AppSurfaceTokens.secondaryText)
                        homeHealthRow(label: "磁盘", value: viewModel.diskSummary, tint: AppSurfaceTokens.secondaryText)
                    }
                }

                ProductPanelCard(
                    variant: .warning,
                    title: "风险栏",
                    icon: "exclamationmark.triangle.fill",
                    status: permissionFooterText,
                    statusTone: .warning,
                    footer: dashboardViewModel.snapshot.unavailableReasons.isEmpty ? "没有额外的不可用项" : "采样、权限或硬件状态需要解释"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let firstReason = dashboardViewModel.snapshot.unavailableReasons.first {
                            Text(firstReason.message)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(homePalette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text([firstReason.category, firstReason.detail].compactMap { $0 }.joined(separator: " · "))
                                .font(ProductPanelTokens.Typography.cardCaption)
                                .foregroundStyle(homePalette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("当前没有明确的硬件或权限风险。")
                                .font(ProductPanelTokens.Typography.cardBody)
                                .foregroundStyle(homePalette.textPrimary)
                        }
                    }
                }
            }
            .frame(maxWidth: 332)
#if DEBUG
            .layoutDebugRegion("RightStatusRail")
#endif
        }
    }

    private var screenshotCenterStrip: some View {
        DashboardCard(title: "截图中心", subtitle: "一键入口优先，模式入口次级", style: .prominent) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        dismissScreenshotQuickStart()
                        postScreenshotCapture(mode: .fullscreen)
                    } label: {
                        HStack(alignment: .center, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AppSurfaceTokens.accentOrange.opacity(0.14))
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                            }
                            .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("立即截图")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.primaryText)
                                    .lineLimit(1)
                                Text("直接进入预览，然后再决定复制、保存、固定或重截。")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)

                            VStack(alignment: .trailing, spacing: 6) {
                                Text("默认：全屏")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                                Text(screenshotSnapshot.hotkeyLabel)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.primaryText)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [
                                    AppSurfaceTokens.accentOrange.opacity(0.18),
                                    AppSurfaceTokens.cardBackgroundSoft
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                                .stroke(AppSurfaceTokens.accentOrange.opacity(0.48), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(2)

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            dismissScreenshotQuickStart()
                            appState.navigate(to: .screenshot)
                        } label: {
                            screenshotUtilityChip(title: "截图工作区", icon: "rectangle.grid.2x2", tint: AppSurfaceTokens.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button {
                            dismissScreenshotQuickStart()
                            appState.navigate(to: .screenshotHistory)
                        } label: {
                            screenshotUtilityChip(title: "查看历史", icon: "clock.arrow.circlepath", tint: AppSurfaceTokens.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button {
                            appState.navigate(to: .settings)
                        } label: {
                            screenshotUtilityChip(title: "预设与热键", icon: "gearshape", tint: AppSurfaceTokens.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 166)
                }

                HStack(spacing: 8) {
                    screenshotContextChip(title: "预设", value: screenshotSnapshot.activePreset.name, tint: AppSurfaceTokens.accentBlue)
                    screenshotContextChip(title: "输出", value: screenshotSnapshot.activePreset.defaultOutputAction.displayName, tint: AppSurfaceTokens.accentGreen)
                    screenshotContextChip(title: "热键", value: screenshotSnapshot.hotkeyLabel, tint: AppSurfaceTokens.accentOrange)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("更多模式")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Text("次级入口")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.secondaryText.opacity(0.9))
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6)
                        ],
                        spacing: 6
                    ) {
                        screenshotModeAction(title: "全屏", icon: "rectangle.on.rectangle", mode: .fullscreen, tint: AppSurfaceTokens.accentBlue)
                        screenshotModeAction(title: "区域", icon: "crop", mode: .area, tint: AppSurfaceTokens.accentPrimary)
                        screenshotModeAction(title: "窗口", icon: "macwindow", mode: .window, tint: AppSurfaceTokens.accentGreen)
                        screenshotModeAction(title: "滚动", icon: "scroll", mode: .scroll, tint: AppSurfaceTokens.accentOrange)
                    }
                }

                if dashboardViewModel.snapshot.recentScreenshotItems.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("最近截图")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Text("继续处理")
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.secondaryText.opacity(0.9))
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 120), spacing: 6)
                            ],
                            alignment: .leading,
                            spacing: 6
                        ) {
                            ForEach(dashboardViewModel.snapshot.recentScreenshotItems, id: \.self) { item in
                                Button {
                                    dismissScreenshotQuickStart()
                                    (NSApp.delegate as? AppDelegate)?.openLatestScreenshotPreviewFromMenu()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "camera.viewfinder")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                                        Text(item)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(AppSurfaceTokens.primaryText)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                                            .fill(AppSurfaceTokens.cardBackgroundSoft)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                                            .stroke(AppSurfaceTokens.separator.opacity(0.72), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .help("继续处理最近一次截图")
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var topSearchField: some View {
            HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text("搜索与命令")
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
        }
        .frame(width: 132, height: AppSurfaceTokens.Layout.compactChipHeight)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.68), lineWidth: 1)
        )
    }

    private var heroPanel: some View {
        DashboardCard(padding: 8.5) {
            HStack(alignment: .center, spacing: 11) {
                heroGlyph

                VStack(alignment: .leading, spacing: 6) {
                    Text("工作台总览")
                        .font(.system(size: AppSurfaceTokens.Typography.pageTitle, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5.5) {
                        statusPill(icon: "checkmark.circle.fill", title: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor)
                        statusPill(icon: "macwindow", title: windowStateText(appState.mainWindowState), tint: AppSurfaceTokens.accentPrimary)
                        statusPill(icon: "sparkles", title: appState.isAppReady ? "已就绪" : "初始化中", tint: appState.isAppReady ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3.5) {
                    Text(viewModel.refreshHint)
                        .font(.system(size: AppSurfaceTokens.Typography.controlStrong, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text("工作台实时")
                        .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "上午好，AcWork"
        case 12..<18:
            return "下午好，AcWork"
        default:
            return "晚上好，AcWork"
        }
    }

    private var homeOverviewStrip: some View {
        AppSurfaceSummaryStrip(
            chips: [
                AppSurfaceSummaryChip(
                    title: "当前页面",
                    value: appState.sidebarSelection.displayName,
                    tint: homePalette.accent
                ),
                AppSurfaceSummaryChip(
                    title: "下一步",
                    value: nextActionHint,
                    tint: homePalette.info
                ),
                AppSurfaceSummaryChip(
                    title: "刷新",
                    value: viewModel.refreshHint,
                    tint: AppSurfaceTokens.secondaryText
                )
            ]
        )
    }

    private func homeActionChip(_ action: HomeAction) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                Image(systemName: action.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(action.tint)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(homePalette.textPrimary)
                    .lineLimit(1)
                Text(actionSubtitle(for: action.kind))
                    .font(ProductPanelTokens.Typography.cardCaption)
                    .foregroundStyle(homePalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                .stroke(action.tint.opacity(0.22), lineWidth: 1)
        )
    }

    private func actionSubtitle(for kind: HomeAction.Kind) -> String {
        switch kind {
        case .voice:
            return "打开说入法"
        case .capture:
            return "全屏截图并立即预览 · ⌘⇧4"
        case .inbox:
            return "进入收集箱"
        case .settings:
            return "打开设置"
        case .settingsAiModels:
            return "检查模型与语音配置"
        case .settingsCaptureInput:
            return "配置截图与输入入口"
        case .agent:
            return "进入协作"
        case .schedule:
            return "查看日程"
        case .systemStatus:
            return "查看监控台"
        case .workbenchApiTest:
            return "验证模型接口"
        }
    }

    private func homeSummaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(homePalette.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(homePalette.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
    }

    private func homeHealthRow(label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Capsule(style: .continuous)
                .fill(tint)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(homePalette.textSecondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(homePalette.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
    }

    private var homePrimaryHeadline: String {
        if appState.isAppReady {
            return dashboardViewModel.snapshot.currentFocus
        }
        return "正在初始化系统，先看实时采样与权限状态。"
    }

    private var homePrimarySummary: String {
        let snapshot = dashboardViewModel.snapshot
        return "当前页面是「\(snapshot.currentPage)」，下一步是 \(snapshot.nextStep)。"
    }

    private var heroGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DashboardRadius.hero, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: DashboardRadius.hero, style: .continuous)
                        .stroke(AppSurfaceTokens.accentBlue.opacity(0.12), lineWidth: 1)
                )
                .frame(width: 44, height: 44)

            Image(systemName: "cpu.fill")
                .font(.system(size: 18.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
    }

    private var kpiRow: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 3.5), count: 5),
            spacing: 3.5
        ) {
            dashboardMetric(
                title: "处理器",
                icon: "cpu",
                value: viewModel.cpuSummary,
                detail: cpuCardDetail,
                tint: AppSurfaceTokens.accentBlue
            ) {
                MiniSparkline(values: historyOrCurrent(viewModel.cpuHistory, current: viewModel.snapshot.cpu?.value), tint: AppSurfaceTokens.accentBlue)
            }

            dashboardMetric(
                title: "内存",
                icon: "memorychip",
                value: viewModel.memorySummary,
                detail: memoryCardDetail,
                tint: AppSurfaceTokens.accentPrimary
            ) {
                RingGauge(percentage: viewModel.snapshot.memoryUsagePercent, tint: AppSurfaceTokens.accentPrimary, label: "内存")
            }

            dashboardMetric(
                title: "网络",
                icon: "network",
                value: viewModel.networkSummary,
                detail: networkCardDetail,
                tint: AppSurfaceTokens.accentGreen
            ) {
                MiniSparkline(
                    values: historyOrCurrent(
                        viewModel.networkHistory,
                        current: {
                            guard let download = viewModel.snapshot.networkDownloadMBps,
                                  let upload = viewModel.snapshot.networkUploadMBps else { return nil }
                            return download + upload
                        }()
                    ),
                    tint: AppSurfaceTokens.accentGreen
                )
            }

            dashboardMetric(
                title: "电池",
                icon: "battery.100",
                value: viewModel.batterySummary,
                detail: batteryCardDetail,
                tint: AppSurfaceTokens.accentCyan
            ) {
                RingGauge(percentage: viewModel.snapshot.battery?.percentage, tint: AppSurfaceTokens.accentCyan, label: "电池")
            }

            dashboardMetric(
                title: "磁盘",
                icon: "internaldrive",
                value: viewModel.diskSummary,
                detail: diskCardDetail,
                tint: AppSurfaceTokens.accentOrange
            ) {
                RingGauge(percentage: viewModel.snapshot.diskUsagePercent, tint: AppSurfaceTokens.accentOrange, label: "磁盘")
            }
        }
#if DEBUG
        .layoutDebugRegion("MetricsGrid")
#endif
    }

    private var overviewRow: some View {
        HStack(alignment: .top, spacing: 3.5) {
            DashboardCard(title: "运行总览", subtitle: nil, style: .prominent) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        overviewMetric(label: "处理器", value: viewModel.cpuSummary, tint: AppSurfaceTokens.accentBlue)
                        overviewMetric(label: "内存", value: viewModel.memoryUsagePercentSummary, tint: AppSurfaceTokens.accentPrimary)
                        overviewMetric(label: "网络", value: networkTrendHeadline, tint: AppSurfaceTokens.accentGreen)
                    }

                    DashboardTrendChart(
                        cpu: historyOrCurrent(viewModel.cpuHistory, current: viewModel.snapshot.cpu?.value),
                        memory: historyOrCurrent(viewModel.memoryHistory, current: viewModel.snapshot.memoryUsagePercent),
                        network: historyOrCurrent(
                            viewModel.networkHistory,
                            current: {
                                guard let download = viewModel.snapshot.networkDownloadMBps,
                                      let upload = viewModel.snapshot.networkUploadMBps else { return nil }
                                return download + upload
                            }()
                        )
                    )
                    .frame(height: 68)

                    HStack(spacing: 2.5) {
                        trendLegend(title: "处理器", tint: AppSurfaceTokens.accentBlue)
                        trendLegend(title: "内存", tint: AppSurfaceTokens.accentPrimary)
                        trendLegend(title: "网络", tint: AppSurfaceTokens.accentGreen)
                        Spacer(minLength: 0)
                        statusPill(icon: "clock.arrow.circlepath", title: "近 60 秒", tint: AppSurfaceTokens.accentBlue)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
            }
            .layoutPriority(2)
#if DEBUG
            .layoutDebugRegion("RuntimeOverviewCard")
#endif

            DashboardCard(title: "进程占用前五", subtitle: nil, style: .regular) {
                HStack(alignment: .center, spacing: 6) {
                    ProcessDonutChart(
                        segments: cpuProcessSegments,
                        totalLabel: viewModel.cpuSummary,
                        subtitle: "处理器占用"
                    )
                    .frame(width: 68, height: 68)

                    VStack(alignment: .leading, spacing: 2.5) {
                        ForEach(cpuProcessSegments.prefix(5)) { segment in
                            processLegendRow(segment)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
            }
            .frame(maxWidth: 278)
            .layoutPriority(1)

            DashboardCard(title: "运行提醒", subtitle: nil, style: .subtle) {
                VStack(spacing: 3) {
                    ForEach(statusBadges) { badge in
                        statusLineRow(badge)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
            }
            .frame(maxWidth: 184)
        }
    }

    private var infoRow: some View {
        HStack(alignment: .top, spacing: 4) {
            DashboardCard(title: "网络", subtitle: "速率 / 接口 / Wi‑Fi") {
                infoGrid(columns: 2, items: [
                    InfoTile(label: "下载", value: viewModel.networkDownloadSummary, detail: "MB/s", tint: AppSurfaceTokens.accentBlue),
                    InfoTile(label: "上传", value: viewModel.networkUploadSummary, detail: "MB/s", tint: AppSurfaceTokens.accentGreen),
                    InfoTile(label: "主接口", value: viewModel.primaryInterfaceSummary, detail: viewModel.primaryInterfaceDetail, tint: AppSurfaceTokens.accentPrimary),
                    InfoTile(label: "Wi‑Fi", value: viewModel.wifiSummary, detail: viewModel.wifiDetail, tint: AppSurfaceTokens.accentOrange)
                ])
            }

            DashboardCard(title: "电源", subtitle: "电量 / 循环 / 健康") {
                infoGrid(columns: 2, items: [
                    InfoTile(label: "电量", value: viewModel.batterySummary, detail: viewModel.batteryStateSummary, tint: AppSurfaceTokens.accentCyan),
                    InfoTile(label: "循环", value: viewModel.batteryCycleSummary, detail: "CycleCount", tint: AppSurfaceTokens.accentPrimary),
                    InfoTile(label: "容量", value: viewModel.batteryCapacitySummary, detail: viewModel.batteryCapacityDetail, tint: AppSurfaceTokens.accentOrange),
                    InfoTile(label: "健康", value: viewModel.batteryHealthSummary, detail: viewModel.batteryHealthDetail, tint: AppSurfaceTokens.accentGreen)
                ])
            }

            DashboardCard(title: "权限", subtitle: "缺失即提示") {
                VStack(alignment: .leading, spacing: 4) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                        ForEach(viewModel.snapshot.permissions.prefix(4)) { permission in
                            permissionRow(permission)
                        }
                    }

                    if let firstReason = viewModel.snapshot.unavailableReasons.first {
                        VStack(alignment: .leading, spacing: 2.25) {
                            Text(firstReason.message)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                                .lineLimit(1)
                            Text([firstReason.category, firstReason.detail].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 8))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(5.5)
                        .background(
                            AppSurfaceTokens.cardBackgroundSoft
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
                    }
                }
            }
        }
    }

    private var sensorRow: some View {
        HStack(alignment: .top, spacing: 2.5) {
            DashboardCard(title: "设备温度", subtitle: temperatureStatusText, style: .regular) {
                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(alignment: .center, spacing: 6) {
                        metricGlyph(systemName: "thermometer.medium", tint: AppSurfaceTokens.accentOrange)

                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(temperaturePrimaryText)
                                .font(.system(size: 19.5, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text(temperatureSecondaryText)
                                .font(.system(size: 6.75, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                    }

                    MiniSparkline(
                        values: historyOrCurrent(viewModel.temperatureHistory, current: currentTemperatureValue),
                        tint: AppSurfaceTokens.accentOrange
                    )
                    .frame(height: 16)

                    HStack(spacing: 4) {
                        compactStatusChip(viewModel.temperatureDetailSummary, tint: AppSurfaceTokens.accentOrange)
                        compactStatusChip(
                            SystemStatusLabelFormatter.thermalThrottleStatusText(viewModel.snapshot.thermalThrottle),
                            tint: AppSurfaceTokens.accentOrange
                        )
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            }

            DashboardCard(title: "风扇转速", subtitle: fanStatusText, style: .regular) {
                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(alignment: .center, spacing: 6) {
                        metricGlyph(systemName: "fanblades.fill", tint: AppSurfaceTokens.accentPrimary)

                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(fanPrimaryText)
                                .font(.system(size: 19.5, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text(fanSecondaryText)
                                .font(.system(size: 6.75, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                    }

                    MiniSparkline(
                        values: historyOrCurrent(viewModel.fanHistory, current: currentFanValue),
                        tint: AppSurfaceTokens.accentPrimary
                    )
                    .frame(height: 16)

                    fanStatusNote
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            }

            DashboardCard(title: "快速操作", subtitle: nil, style: .subtle) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 3.5), GridItem(.flexible(), spacing: 3.5)], spacing: 3.5) {
                    ForEach(quickActions) { action in
                        Button {
                            action.perform(using: appState)
                        } label: {
                            actionButton(action)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
            }
            .frame(maxWidth: 188)
        }
    }

    private var auxiliaryRow: some View {
        HStack(alignment: .top, spacing: 12) {
            summaryFooter
                .layoutPriority(2)

            workspaceClosingBoard
                .frame(maxWidth: 332)
                .layoutPriority(1)
        }
    }

    private var summaryFooter: some View {
        DashboardCard(padding: 1.5, style: .subtle) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("工作台总览")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text(viewModel.refreshHint)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("资源")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    AppSurfaceSummaryStrip(
                        chips: [
                            AppSurfaceSummaryChip(title: "处理器", value: viewModel.cpuSummary, tint: AppSurfaceTokens.secondaryText),
                            AppSurfaceSummaryChip(title: "内存", value: viewModel.memorySummary, tint: AppSurfaceTokens.secondaryText),
                            AppSurfaceSummaryChip(title: "磁盘", value: viewModel.diskSummary, tint: AppSurfaceTokens.secondaryText)
                        ]
                    )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("连接与权限")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    AppSurfaceSummaryStrip(
                        chips: [
                            AppSurfaceSummaryChip(title: "网络", value: viewModel.networkSummary, tint: AppSurfaceTokens.secondaryText),
                            AppSurfaceSummaryChip(title: "电源", value: viewModel.batteryStateSummary, tint: AppSurfaceTokens.secondaryText),
                            AppSurfaceSummaryChip(title: "权限", value: permissionFooterText, tint: AppSurfaceTokens.secondaryText)
                        ]
                    )
                }
            }
        }
#if DEBUG
        .layoutDebugRegion("BottomSummary")
#endif
    }

    private var workspaceClosingBoard: some View {
        DashboardCard(title: "当前节奏", subtitle: "把页面、窗口和采样状态收成一块", style: .regular) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    homeSummaryPill(title: "当前页面", value: appState.sidebarSelection.displayName, tint: homePalette.accent)
                    homeSummaryPill(title: "窗口", value: windowStateText(appState.mainWindowState), tint: homePalette.info)
                    homeSummaryPill(title: "采样", value: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor)
                    homeSummaryPill(title: "权限", value: permissionFooterText, tint: homePalette.warning)
                }

                HStack(alignment: .center, spacing: 8) {
                    StatusBadge(text: "最后刷新 \(viewModel.lastUpdatedText)", tone: .info, icon: "clock.arrow.circlepath", compact: true)
                    StatusBadge(text: "建议先处理 \(nextActionHint)", tone: .neutral, icon: "arrow.right.circle", compact: true)
                    Spacer(minLength: 0)
                }
            }
        }
#if DEBUG
        .layoutDebugRegion("CurrentRhythm")
#endif
    }

    private var nextActionHint: String {
        if appState.isAppReady == false {
            return "初始化"
        }
        if viewModel.snapshot.unavailableReasons.isEmpty == false {
            return "风险"
        }
        return "工作"
    }

    private var permissionFooterText: String {
        if dashboardViewModel.snapshot.unavailableReasons.isEmpty {
            return SystemStatusLabelFormatter.healthState(isHealthy: true)
        }
        return dashboardViewModel.snapshot.permissionSummary
    }

    private var fanStatusNote: some View {
        HStack(spacing: 5) {
            compactStatusChip(
                SystemStatusLabelFormatter.availabilityState(
                    isAvailable: currentFanValue != nil,
                    availableText: "已接入",
                    unavailableText: "只读"
                ),
                tint: currentFanValue == nil ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.accentPrimary
            )

            compactStatusChip(
                SystemStatusLabelFormatter.availabilityState(
                    isAvailable: currentFanValue != nil,
                    availableText: "无调速",
                    unavailableText: "不可控"
                ),
                tint: currentFanValue == nil ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.accentPrimary
            )

            Spacer(minLength: 0)
        }
    }

    private var cpuProcessSegments: [ProcessSegment] {
        let palette: [Color] = [
            AppSurfaceTokens.accentBlue,
            AppSurfaceTokens.accentPrimary,
            AppSurfaceTokens.accentGreen,
            AppSurfaceTokens.accentOrange,
            AppSurfaceTokens.accentSecondary
        ]

        let processes = viewModel.snapshot.topCPUProcesses.prefix(5)
        let total = max(processes.reduce(0) { $0 + max($1.cpuUsage, 0) }, 0.01)

        if processes.isEmpty {
            return [
                ProcessSegment(name: "没有数据", ratio: 1, displayValue: "0%", color: AppSurfaceTokens.accentSecondary.opacity(0.35))
            ]
        }

        return processes.enumerated().map { index, process in
            let usage = max(process.cpuUsage, 0)
            return ProcessSegment(
                name: processShortName(process.name),
                ratio: usage / total,
                displayValue: String(format: "%.0f%%", usage),
                color: palette[index % palette.count]
            )
        }
    }

    private var networkTrendHeadline: String {
        if let download = viewModel.snapshot.networkDownloadMBps,
           let upload = viewModel.snapshot.networkUploadMBps {
            return String(format: "↓ %.1f / ↑ %.1f", download, upload)
        }
        return viewModel.networkSummary
    }

    private var statusBadges: [WorkspaceStatusBadge] {
        [
            WorkspaceStatusBadge(
                icon: "sensor.tag.radiowaves.forward.fill",
                title: "传感",
                value: SystemStatusLabelFormatter.availabilityState(isAvailable: currentTemperatureValue != nil),
                accent: currentTemperatureValue == nil ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.secondaryText
            ),
            WorkspaceStatusBadge(
                icon: "network",
                title: "网络",
                value: SystemStatusLabelFormatter.healthState(isHealthy: viewModel.primaryInterfaceSummary != "不可用", healthyText: "在线"),
                accent: viewModel.primaryInterfaceSummary == "不可用" ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.secondaryText
            ),
            WorkspaceStatusBadge(
                icon: "internaldrive",
                title: "磁盘",
                value: SystemStatusLabelFormatter.healthState(isHealthy: viewModel.diskSummary != "不可用"),
                accent: viewModel.diskSummary == "不可用" ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.secondaryText
            ),
            WorkspaceStatusBadge(
                icon: "battery.100",
                title: "电源",
                value: batteryBadgeValue,
                accent: batteryBadgeAccent
            ),
            WorkspaceStatusBadge(
                icon: "hand.raised",
                title: "权限",
                value: permissionFooterText,
                accent: permissionFooterText == "正常" ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.accentOrange
            )
        ]
    }

    private var batteryBadgeValue: String {
        if viewModel.batterySummary == "无可用电池" || viewModel.batterySummary == "不可用" {
            return SystemStatusLabelFormatter.availabilityState(isAvailable: false, availableText: "良好", unavailableText: "无")
        }
        if viewModel.batteryHealthSummary == "不可用" {
            return SystemStatusLabelFormatter.availabilityState(isAvailable: false, availableText: "良好", unavailableText: "未知")
        }
        return SystemStatusLabelFormatter.availabilityState(isAvailable: true, availableText: "良好", unavailableText: "无")
    }

    private var batteryBadgeAccent: Color {
        batteryBadgeValue == "良好" ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.accentOrange
    }

    private var cpuCardDetail: String {
        if let first = viewModel.loadAverageSummary.split(separator: "/").first {
            return "负载 \(first.trimmingCharacters(in: .whitespaces))"
        }
        return viewModel.loadAverageSummary
    }

    private var memoryCardDetail: String {
        viewModel.memoryUsagePercentSummary
    }

    private var networkCardDetail: String {
        SystemStatusLabelFormatter.availabilityState(
            isAvailable: viewModel.networkInterfaceSummary != "不可用",
            availableText: viewModel.networkInterfaceSummary,
            unavailableText: "接口不可用"
        )
    }

    private var batteryCardDetail: String {
        switch viewModel.batteryStateSummary {
        case "正在充电":
            return "充电中"
        case "已连接电源":
            return "已接电源"
        case "未充电":
            return "未充电"
        default:
            return viewModel.batteryStateSummary
        }
    }

    private var diskCardDetail: String {
        viewModel.diskDetailSummary
    }

    private var currentTemperatureValue: Double? {
        viewModel.snapshot.temperatureSensors.first(where: { $0.value != nil })?.value ?? viewModel.snapshot.battery?.temperatureC
    }

    private var fanSummaryText: String {
        if let fan = viewModel.fanSensorSummaries.first {
            return fan.displayValue
        }
        return SystemStatusLabelFormatter.availabilityState(
            isAvailable: false,
            availableText: "风扇读数已接入",
            unavailableText: "风扇读数不可用"
        )
    }

    private var currentFanValue: Double? {
        viewModel.snapshot.fanSensors.first(where: { $0.value != nil })?.value
    }

    private var temperaturePrimaryText: String {
        if let value = currentTemperatureValue {
            return String(format: "%.0f°C", value)
        }
        return "-- °C"
    }

    private var temperatureSecondaryText: String {
        if currentTemperatureValue != nil {
            return SystemStatusLabelFormatter.healthState(
                isHealthy: true,
                healthyText: viewModel.snapshot.thermalState ?? "正常",
                unhealthyText: "异常"
            )
        }
        return "无可读传感器"
    }

    private var temperatureStatusText: String {
        SystemStatusLabelFormatter.availabilityState(
            isAvailable: currentTemperatureValue != nil,
            availableText: "温度状态"
        )
    }

    private var fanPrimaryText: String {
        if let value = currentFanValue {
            return String(format: "%.0f RPM", value)
        }
        return "-- RPM"
    }

    private var fanSecondaryText: String {
        SystemStatusLabelFormatter.availabilityState(
            isAvailable: currentFanValue != nil,
            availableText: "仅展示读数",
            unavailableText: "风扇读数不可用"
        )
    }

    private var fanStatusText: String {
        SystemStatusLabelFormatter.availabilityState(
            isAvailable: currentFanValue != nil,
            availableText: "风扇读数已接入",
            unavailableText: "风扇读数不可用"
        )
    }

    private func metricGlyph(systemName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DashboardRadius.hero, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: DashboardRadius.hero, style: .continuous)
                        .stroke(tint.opacity(0.10), lineWidth: 1)
                )
                .frame(width: 50, height: 50)

            Image(systemName: systemName)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(tint)
        }
    }

    private func statusStrip(labels: [String], tint: Color) -> some View {
        HStack(spacing: 6) {
            ForEach(labels.filter { $0.isEmpty == false }, id: \.self) { label in
                compactStatusChip(label, tint: tint)
            }
            Spacer(minLength: 0)
        }
    }

    private func dashboardMetric<Accessory: View>(
        title: String,
        icon: String,
        value: String,
        detail: String,
        tint: Color,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        DashboardCard(padding: 6, style: .regular) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 5) {
                    RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                        .frame(width: 19.5, height: 19.5)
                        .overlay(
                            RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous)
                                .stroke(tint.opacity(0.10), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(tint)
                        )
                    Text(title)
                        .font(.system(size: 8.75, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Spacer(minLength: 0)
                }

                accessory()
                    .frame(height: 28)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 0.15)

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)
                    metricDetailLine(detail, tint: tint)
                }
            }
        }
    }

    private func metricDetailLine(_ detail: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Capsule(style: .continuous)
                .fill(tint.opacity(0.45))
                .frame(width: 13, height: 3)
            Text(detail)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
    }

    private func overviewMetric(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2.25) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(tint.opacity(0.25))
                .frame(width: 18, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(tint.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func trendLegend(title: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private func infoGrid(columns: Int, items: [InfoTile]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: columns), spacing: 5) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2.75) {
                    Text(item.label)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .fill(AppSurfaceTokens.separator.opacity(0.22))
                        .frame(width: 13, height: 3)

                    Text(item.value)
                        .font(.system(size: 10.75, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)
                    Text(item.detail)
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6.5)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
            }
        }
    }

    private func processLegendRow(_ segment: ProcessSegment) -> some View {
        VStack(alignment: .leading, spacing: 1.5) {
            HStack(spacing: 4.5) {
                Circle()
                    .fill(segment.color)
                    .frame(width: 5, height: 5)
                Text(segment.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(segment.displayValue)
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(AppSurfaceTokens.separator.opacity(0.22))
                .frame(height: 2.5)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 99, style: .continuous)
                            .fill(segment.color)
                            .frame(width: max(proxy.size.width * segment.ratio, 8))
                    }
                }
        }
    }

    private func indicatorTile(_ badge: WorkspaceStatusBadge) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4.5) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(badge.accent.opacity(0.10), lineWidth: 1)
                    )
                    .overlay {
                        Image(systemName: badge.icon)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(badge.accent)
                    }
                Spacer(minLength: 0)
                Circle()
                    .fill(badge.accent)
                    .frame(width: 6, height: 6)
            }

            Text(badge.title)
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            Text(badge.value)
                .font(.system(size: 8.75, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(3.5)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func statusLineRow(_ badge: WorkspaceStatusBadge) -> some View {
        HStack(spacing: 4.5) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .frame(width: 19, height: 19)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(badge.accent.opacity(0.10), lineWidth: 1)
                )
                .overlay {
                    Image(systemName: badge.icon)
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(badge.accent)
                }

            Text(badge.title)
                .font(.system(size: 8.75, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Circle()
                .fill(badge.accent.opacity(0.92))
                .frame(width: 4, height: 4)

            Text(badge.value)
                .font(.system(size: 8.75, weight: .semibold))
                .foregroundStyle(badge.accent)
                .lineLimit(1)
        }
        .padding(.horizontal, 5.75)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 26.5)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func compactStatusChip(_ title: String, tint: Color) -> some View {
        HStack(spacing: 3.5) {
            Circle()
                .fill(tint)
                .frame(width: 3.25, height: 3.25)
            Text(title)
                .font(.system(size: 6.75, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 4.5)
        .padding(.vertical, 2.25)
        .background(
            Capsule(style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
        .clipShape(Capsule(style: .continuous))
    }

    private func summaryChip(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            Text(value)
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2.75)
        .padding(.vertical, 1.75)
        .background(Capsule(style: .continuous).fill(AppSurfaceTokens.cardBackgroundSoft))
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
        .clipShape(Capsule(style: .continuous))
    }

    private func processShortName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 14 else { return trimmed }
        return String(trimmed.prefix(14))
    }

    private func statusPill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 7.5)
        .padding(.vertical, 4)
        .background(Capsule(style: .continuous).fill(AppSurfaceTokens.cardBackgroundSoft))
        .overlay(Capsule(style: .continuous).stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1))
    }

    private func topActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3.5) {
                Image(systemName: icon)
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                Text(title)
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
            }
            .foregroundStyle(AppSurfaceTokens.primaryText)
            .padding(.horizontal, 7)
            .frame(height: 24.5)
            .background(
                RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func topIconButton(icon: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                        .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ action: HomeAction) -> some View {
        VStack(spacing: action.kind == .capture ? 3.5 : 2.5) {
            ZStack {
                Circle()
                    .fill(action.kind == .capture ? AppSurfaceTokens.accentOrange.opacity(0.16) : AppSurfaceTokens.cardBackgroundSoft)
                    .frame(width: action.kind == .capture ? 24 : 22, height: action.kind == .capture ? 24 : 22)
                Image(systemName: action.icon)
                    .font(.system(size: action.kind == .capture ? 10 : 9, weight: .semibold))
                    .foregroundStyle(action.kind == .capture ? AppSurfaceTokens.accentOrange : action.tint)
            }

            Text(action.title)
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            if action.kind == .capture {
                Text("全屏 / 区域 / 窗口 / 滚动")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("⌘⇧4")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.vertical, action.kind == .capture ? 4 : 2.25)
        .frame(maxWidth: .infinity, minHeight: 34)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .fill(action.kind == .capture ? AppSurfaceTokens.accentOrange.opacity(0.08) : AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(action.kind == .capture ? AppSurfaceTokens.accentOrange.opacity(0.55) : AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func screenshotModeAction(title: String, icon: String, mode: ScreenshotMode, tint: Color) -> some View {
        Button {
            postScreenshotCapture(mode: mode)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                        .frame(width: 24, height: 24)
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)

                Text(mode.displayName)
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func screenshotUtilityChip(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.72), lineWidth: 1)
        )
    }

    private func screenshotContextChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.72), lineWidth: 1)
        )
    }

    private func screenshotPresetChip(title: String, subtitle: String, isSelected: Bool, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                .fill(isSelected ? AppSurfaceTokens.cardBackgroundSoft : AppSurfaceTokens.cardBackgroundSoft.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                .stroke(tint.opacity(isSelected ? 1.0 : 0.5), lineWidth: 1)
        )
    }

    private func postScreenshotCapture(mode: ScreenshotMode) {
        dismissScreenshotQuickStart()
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureScreenshot"),
            object: ["mode": mode.rawValue]
        )
    }

    private func refreshScreenshotConfiguration() {
        Task {
            let appSettings = await settingsService.getSettings()
            let snapshot = SettingsLocalPreferences.screenshotSnapshot(from: appSettings)

            await MainActor.run {
                screenshotSnapshot = snapshot
                activeScreenshotPresetID = snapshot.activePreset.id
            }
        }
    }

    private func selectScreenshotPreset(_ preset: ScreenshotPreset) {
        Task {
            var preferences = SettingsLocalPreferences.loadOrDefault()
            preferences.screenshotPresets = preferences.screenshotPresets.isEmpty ? ScreenshotPreset.defaultPresets : preferences.screenshotPresets
            preferences.selectedScreenshotPresetID = preset.id
            preferences.save()
            await MainActor.run {
                refreshScreenshotConfiguration()
            }
        }
    }

    private func sensorList<T>(_ items: [T], placeholder: String) -> some View where T: SensorDisplayRow {
        VStack(alignment: .leading, spacing: 6.5) {
            if items.isEmpty {
                Text(placeholder)
                    .font(.system(size: AppSurfaceTokens.Typography.sectionDesc))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            } else {
                ForEach(items.indices, id: \.self) { index in
                    sensorRow(items[index])
                }
            }
        }
    }

    private func sensorRow<T: SensorDisplayRow>(_ item: T) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(item.displayName)
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(item.displaySource)
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer(minLength: 0)
            Text(item.displayValue)
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            if item.isUnavailable {
                Text("不可用")
                    .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4.25)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous))
    }

    private func permissionRow(_ item: SystemPermissionSnapshot) -> some View {
        PermissionStatusCard(
            permission: item,
            compact: true,
            openSettings: item.isAvailable ? nil : {
                openPermissionSettings(for: item)
            }
        )
    }

    private func openPermissionSettings(for item: SystemPermissionSnapshot) {
        if let kind = item.appPermissionKind {
            permissionManager.openSettingsFor(kind)
        } else {
            permissionManager.openPrivacySettings()
        }
    }

    private func keyValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous))
    }

    private func historyOrCurrent(_ history: [Double], current: Double?) -> [Double] {
        if history.isEmpty {
            if let current {
                return [current]
            }
            return []
        }
        return history
    }

    private func windowStateText(_ state: WindowState) -> String {
        switch state {
        case .closed: return "已关闭"
        case .minimized: return "已最小化"
        case .normal: return "已打开"
        case .fullscreen: return "全屏"
        }
    }
}

private struct DashboardCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let padding: CGFloat
    let style: DashboardCardStyle
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        padding: CGFloat = 16,
        style: DashboardCardStyle = .regular,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.padding = padding
        self.style = style
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4.5) {
            if let title {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
            }

            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if style == .prominent {
                Circle()
                    .fill(AppSurfaceTokens.accentBlue.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .blur(radius: 24)
                    .offset(x: -28, y: -40)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous))
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }

    private var cardFill: AnyShapeStyle {
        switch style {
        case .regular:
            return AnyShapeStyle(AppSurfaceTokens.cardBackgroundSoft)
        case .prominent:
            return AnyShapeStyle(AppSurfaceTokens.cardBackgroundSoft)
        case .subtle:
            return AnyShapeStyle(AppSurfaceTokens.cardBackground.opacity(0.94))
        }
    }

    private var cardStroke: Color {
        switch style {
        case .regular:
            return AppSurfaceTokens.separator.opacity(0.72)
        case .prominent:
            return AppSurfaceTokens.accentBlue.opacity(0.14)
        case .subtle:
            return AppSurfaceTokens.separator.opacity(0.48)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .regular:
            return .black.opacity(0.028)
        case .prominent:
            return AppSurfaceTokens.accentBlue.opacity(0.03)
        case .subtle:
            return .black.opacity(0.012)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .regular: return 4
        case .prominent: return 6
        case .subtle: return 3
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .regular: return 1
        case .prominent: return 2
        case .subtle: return 1
        }
    }
}

private struct InfoTile: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let detail: String
    let tint: Color
}

private struct ProcessSegment: Identifiable {
    let id = UUID()
    let name: String
    let ratio: Double
    let displayValue: String
    let color: Color
}

private struct WorkspaceStatusBadge: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
    let accent: Color
}

private struct HomeAction: Identifiable {
    enum Kind {
        case voice
        case capture
        case inbox
        case settings
        case settingsAiModels
        case settingsCaptureInput
        case agent
        case schedule
        case systemStatus
        case workbenchApiTest

        @MainActor
        func perform(using appState: AppState) {
            switch self {
            case .voice:
                NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
            case .capture:
                NotificationCenter.default.post(
                    name: Notification.Name("AcMind.captureScreenshot"),
                    object: ["mode": ScreenshotMode.fullscreen.rawValue]
                )
            case .inbox:
                appState.navigate(to: .inbox)
            case .settings:
                appState.navigate(to: .settings)
            case .settingsAiModels:
                appState.navigate(to: .settings, settingsCategory: .aiModels)
            case .settingsCaptureInput:
                appState.navigate(to: .settings, settingsCategory: .captureInput)
            case .agent:
                appState.navigate(to: .agent)
            case .schedule:
                appState.navigate(to: .schedule)
            case .systemStatus:
                appState.navigate(to: .systemStatus)
            case .workbenchApiTest:
                appState.navigate(to: .workbench, workbenchToolRoute: .apiTest)
            }
        }
    }

    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let kind: Kind

    @MainActor
    func perform(using appState: AppState) {
        kind.perform(using: appState)
    }
}

private struct MiniSparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let points = linePoints(in: proxy.size)
            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                } else if let point = points.first {
                    Circle()
                        .fill(tint)
                        .frame(width: 5, height: 5)
                        .position(point)
                }
            }
        }
    }

    private func linePoints(in size: CGSize) -> [CGPoint] {
        guard values.isEmpty == false else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, 0.0001)
        let horizontalStep = values.count > 1 ? size.width / CGFloat(values.count - 1) : size.width / 2

        return values.enumerated().map { index, value in
            let x = values.count > 1 ? CGFloat(index) * horizontalStep : size.width / 2
            let normalized = (value - minValue) / span
            let y = size.height - (CGFloat(normalized) * size.height * 0.8) - size.height * 0.1
            return CGPoint(x: x, y: max(4, min(size.height - 4, y)))
        }
    }
}

private struct MiniTrendStack: View {
    let cpu: [Double]
    let memory: [Double]
    let network: [Double]

    var body: some View {
        VStack(spacing: 8) {
            trendRow(title: "处理器", values: cpu, tint: AppSurfaceTokens.accentBlue)
            trendRow(title: "内存", values: memory, tint: AppSurfaceTokens.accentPrimary)
            trendRow(title: "网络", values: network, tint: AppSurfaceTokens.accentGreen)
        }
    }

    private func trendRow(title: String, values: [Double], tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .frame(width: 30, alignment: .leading)
            MiniSparkline(values: values.isEmpty ? [0] : values, tint: tint)
                .frame(height: 28)
                .padding(.vertical, 4)
                .background(AppSurfaceTokens.cardBackground.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous))
        }
    }
}

private struct RingGauge: View {
    let percentage: Double?
    let tint: Color
    let label: String

    init(percentage: Double?, tint: Color, label: String = "Battery") {
        self.percentage = percentage
        self.tint = tint
        self.label = label
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppSurfaceTokens.cardBackground.opacity(0.92), lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat((percentage ?? 0).clamped(to: 0...100) / 100))
                .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(percentageText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
        }
        .padding(2)
    }

    private var percentageText: String {
        guard let percentage else { return "N/A" }
        return String(format: "%.0f%%", percentage)
    }
}

private struct ProcessDonutChart: View {
    let segments: [ProcessSegment]
    let totalLabel: String
    let subtitle: String
    private let lineWidth: CGFloat = 16
    private let gap: Double = 0.008

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AppSurfaceTokens.separator.opacity(0.18),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                Circle()
                    .trim(from: startTrim(for: index), to: endTrim(for: index))
                    .stroke(
                        LinearGradient(
                            colors: [segment.color.opacity(0.90), segment.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Circle()
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .padding(lineWidth + 5)
                .overlay {
                    Circle()
                        .stroke(AppSurfaceTokens.separator.opacity(0.14), lineWidth: 1)
                        .padding(lineWidth + 5)
                }

            VStack(spacing: 3) {
                Text(totalLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
        }
    }

    private func startTrim(for index: Int) -> Double {
        let preceding = segments.prefix(index).reduce(0.0) { $0 + $1.ratio }
        return min(max(preceding + (index == 0 ? 0 : gap), 0), 1)
    }

    private func endTrim(for index: Int) -> Double {
        let preceding = segments.prefix(index + 1).reduce(0.0) { $0 + $1.ratio }
        return min(max(preceding - gap, 0), 1)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

struct WorkspaceDashboardSnapshot: Equatable {
    let phase: WorkspaceDashboardPhase
    let nowLabel: String
    let currentFocus: String
    let nextStep: String
    let pendingItems: [String]
    let recentItems: [String]
    let recentScreenshotItems: [String]
    let scheduleItems: [String]
    let systemMetrics: [String]
    let systemStatusSnapshot: SystemStatusSnapshot?
    let currentPage: String
    let permissionSummary: String
    let unavailableReasons: [SystemStatusUnavailableReason]
}

enum WorkspaceDashboardPhase: Equatable {
    case loading
    case loaded
    case empty
    case error(message: String)
}

@MainActor
protocol WorkspaceDashboardRepositoryProtocol {
    func loadSnapshot() async -> WorkspaceDashboardSnapshot
}

@MainActor
struct LiveWorkspaceDashboardRepository: WorkspaceDashboardRepositoryProtocol {
    let appState: AppState
    let systemStatusService: SystemStatusService
    let storageService: any StorageServiceProtocol
    let scheduleService: any ScheduleServiceProtocol
    let agentTaskBoardService: any AgentTaskBoardServiceProtocol

    func loadSnapshot() async -> WorkspaceDashboardSnapshot {
        let systemStatus = systemStatusService.snapshot
        async let tasksResult = agentTaskBoardService.listTasks(
            filter: TaskFilter(statuses: [.running, .waiting, .pending, .failed], limit: 8)
        )
        async let eventsResult = scheduleService.getEventsForDate(Date())
        async let sourceItemsResult = storageService.listSourceItems(filter: nil)

        let tasks = (try? await tasksResult) ?? []
        let events = ((try? await eventsResult) ?? []).filter { $0.status != .cancelled }
        let scheduleItems = events.map {
            LiveScheduleItem(
                title: $0.title,
                timeRange: $0.displayTimeRange(),
                endAt: $0.endAt,
                isTodo: $0.status == .todo
            )
        }
        let sourceItems = ((try? await sourceItemsResult) ?? [])
            .filter { $0.status != .deleted && $0.status != .archived && $0.status != .exported }
            .sorted { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }

        let focus = resolveFocus(tasks: tasks, events: scheduleItems, sourceItems: sourceItems)
        let pendingItems = buildPendingItems(tasks: tasks, sourceItems: sourceItems)
        return WorkspaceDashboardSnapshot(
            phase: .loaded,
            nowLabel: Self.dateTimeFormatter.string(from: Date()),
            currentFocus: focus.title,
            nextStep: focus.nextStep,
            pendingItems: pendingItems,
            recentItems: sourceItems.prefix(6).map { displayTitle(for: $0) },
            recentScreenshotItems: buildScreenshotItems(from: sourceItems),
            scheduleItems: scheduleItems.prefix(6).map { "\($0.timeRange)  \($0.title)" },
            systemMetrics: buildSystemMetrics(from: systemStatus),
            systemStatusSnapshot: systemStatus,
            currentPage: appState.sidebarSelection.displayName,
            permissionSummary: SystemStatusLabelFormatter.permissionOverviewSummary(systemStatus.permissions),
            unavailableReasons: systemStatus.unavailableReasons
        )
    }

    private func resolveFocus(
        tasks: [AgentTask],
        events: [LiveScheduleItem],
        sourceItems: [SourceItem]
    ) -> (title: String, nextStep: String) {
        if let task = tasks.first(where: { $0.status == .running }) {
            let nextStep = task.steps.indices.contains(task.currentStepIndex)
                ? task.steps[task.currentStepIndex].title
                : "继续当前智能体任务"
            return (task.title, nextStep)
        }
        if let event = events.first(where: { $0.isTodo && $0.endAt >= Date() }) {
            return (event.title, "按 \(event.timeRange) 推进日程")
        }
        if let task = tasks.first(where: { $0.status == .waiting || $0.status == .pending || $0.status == .failed }) {
            let action = task.status == .failed ? "检查失败原因并重试" : "启动这项智能体任务"
            return (task.title, action)
        }
        if let item = sourceItems.first {
            return (displayTitle(for: item), "打开收集箱继续整理")
        }
        return ("没有进行中任务", "从快速记录、日程或智能体创建下一项工作")
    }

    private func buildPendingItems(tasks: [AgentTask], sourceItems: [SourceItem]) -> [String] {
        var items = tasks.prefix(4).map { "\($0.status.displayName)：\($0.title)" }
        if items.count < 6 {
            items.append(contentsOf: sourceItems.prefix(6 - items.count).map {
                "\($0.status.displayName)：\(displayTitle(for: $0))"
            })
        }
        return items
    }

    private func buildScreenshotItems(from sourceItems: [SourceItem]) -> [String] {
        sourceItems
            .filter { $0.source == .screenshot || $0.type == .screenshot }
            .prefix(4)
            .map { item in
                let content = displayTitle(for: item)
                let sourceLabel = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "文字识别" : "截图"
                return "\(sourceLabel) · \(content)"
            }
    }

    private func displayTitle(for item: SourceItem) -> String {
        if let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), title.isEmpty == false {
            return title
        }
        if let preview = item.previewText?.trimmingCharacters(in: .whitespacesAndNewlines), preview.isEmpty == false {
            return String(preview.prefix(48))
        }
        return "\(item.type.displayName)内容"
    }

    private func buildSystemMetrics(from snapshot: SystemStatusSnapshot) -> [String] {
        var metrics: [String] = []
        if let cpu = snapshot.cpu?.value {
            metrics.append(String(format: "处理器 %.0f%%", cpu))
        }
        if snapshot.memoryUsagePercent > 0 {
            metrics.append(String(format: "内存 %.0f%%", snapshot.memoryUsagePercent))
        }
        if let battery = snapshot.battery?.percentage {
            metrics.append(String(format: "电池 %.0f%%", battery))
        }
        if snapshot.diskUsagePercent > 0 {
            metrics.append(String(format: "磁盘 %.0f%%", snapshot.diskUsagePercent))
        }
        return Array(metrics.prefix(4))
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private struct LiveScheduleItem {
        let title: String
        let timeRange: String
        let endAt: Date
        let isTodo: Bool
    }
}

@MainActor
final class WorkspaceDashboardViewModel: ObservableObject {
    @Published private(set) var snapshot: WorkspaceDashboardSnapshot

    private let repository: any WorkspaceDashboardRepositoryProtocol
    private var refreshGeneration = 0

    init(repository: any WorkspaceDashboardRepositoryProtocol) {
        self.repository = repository
        self.snapshot = WorkspaceDashboardSnapshot(
            phase: .loading,
            nowLabel: "",
            currentFocus: "正在读取工作台",
            nextStep: "等待真实数据加载完成",
            pendingItems: [],
            recentItems: [],
            recentScreenshotItems: [],
            scheduleItems: [],
            systemMetrics: [],
            systemStatusSnapshot: nil,
            currentPage: SidebarItem.home.displayName,
            permissionSummary: "正在读取权限状态",
            unavailableReasons: []
        )
        refresh()
    }

    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        Task { [weak self] in
            guard let self else { return }
            let refreshedSnapshot = await repository.loadSnapshot()
            guard generation == refreshGeneration else { return }
            snapshot = refreshedSnapshot
        }
    }
}
