import SwiftUI
import Combine
import AcMindKit

struct SystemStatusView: View {
    @StateObject private var viewModel: SystemStatusViewModel
    @StateObject private var fanControlService: SystemFanControlService
    @StateObject private var helperInstaller = SystemHardwareHelperInstaller()
    private let permissionManager: PermissionManager
    @State private var pulsePhase = false
    @State private var showSecondaryDetails = false
    @State private var selectedFanIndex: Int = 0
    @State private var fanPercentDraft: Double = 50
    @State private var fanControlMessage: String?
    @State private var fanRefreshTask: Task<Void, Never>?

    private enum DashboardLayout {
        static let heroCardHeight: CGFloat = 224
        static let sideCardWidth: CGFloat = 224
        static let statusMatrixHeight: CGFloat = 82
        static let permissionStripHeight: CGFloat = 42
    }

    init(
        systemStatusService: SystemStatusService,
        fanControlService: SystemFanControlService? = nil,
        permissionManager: PermissionManager = PermissionManager()
    ) {
        self.permissionManager = permissionManager
        _viewModel = StateObject(wrappedValue: SystemStatusViewModel(service: systemStatusService))
        _fanControlService = StateObject(wrappedValue: fanControlService ?? SystemFanControlService())
    }

    var body: some View {
        WorkspacePageShell(
            title: "状态",
            subtitle: "真实采样 · \(viewModel.lastUpdatedText) · \(viewModel.refreshHint)",
            headerActions: AnyView(dashboardHeaderActions),
            leadingRailWidth: 0,
            trailingRailWidth: 0,
            leadingRail: { EmptyView() },
            content: {
                dashboardContent
            },
            trailingRail: { EmptyView() }
        )
        .onAppear { viewModel.startMonitoring() }
        .onAppear {
            helperInstaller.refreshStatus()
            startFanControlPolling()
        }
        .onDisappear { viewModel.stopMonitoring() }
        .onDisappear {
            fanRefreshTask?.cancel()
            fanRefreshTask = nil
        }
        .onChange(of: viewModel.snapshot.fanControlStates) {
            syncFanControlDraftFromSnapshot()
        }
    }

    private func startFanControlPolling() {
        fanRefreshTask?.cancel()
        fanRefreshTask = Task { @MainActor in
            await fanControlService.refresh()
            helperInstaller.refreshStatus()
            syncFanControlDraftFromSnapshot()

            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard Task.isCancelled == false else { break }
                helperInstaller.refreshStatus()
                await fanControlService.refresh()
                syncFanControlDraftFromSnapshot()
            }
        }
    }

    private var dashboardHeaderActions: some View {
        HStack(spacing: 6) {
            dashboardTopBadge(icon: "mic.fill", title: "说入法")
            dashboardTopBadge(icon: "magnifyingglass", title: "搜索")
            dashboardTopBadge(icon: "bolt.horizontal.circle", title: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor)
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceSectionSpacing) {
                dashboardOverviewHeader
                dashboardHealthSection
                dashboardTrendSection
                dashboardDiagnosticsSection
                dashboardCapabilitySection
            }
            .padding(AppSurfaceTokens.Layout.workspacePagePadding)
            .frame(maxWidth: AppSurfaceTokens.Layout.workspaceMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private var dashboardOverviewHeader: some View {
        AppSurfaceCard(title: "系统总览", subtitle: "关键硬件与采样状态", padding: AppSurfaceTokens.Layout.workspaceCardPadding) {
            VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                AppSurfaceSummaryStrip(chips: [
                    AppSurfaceSummaryChip(title: "处理器", value: viewModel.cpuSummary, tint: .blue),
                    AppSurfaceSummaryChip(title: "内存", value: viewModel.memoryUsagePercentSummary, tint: .purple),
                    AppSurfaceSummaryChip(title: "网络", value: viewModel.networkSummary, tint: .green)
                ])

                HStack(spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                    overviewMetric(title: "磁盘", value: viewModel.diskSummary, tint: .orange)
                    overviewMetric(title: "电源", value: viewModel.hasBattery ? viewModel.batterySummary : viewModel.thermalThrottleSummary, tint: viewModel.hasBattery ? .cyan : .red)
                    overviewMetric(title: "采样", value: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor)
                }

            }
        }
    }

    private func overviewMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: AppSurfaceTokens.Typography.controlStrong, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSurfaceTokens.Spacing.sm)
        .padding(.vertical, AppSurfaceTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var dashboardHealthSection: some View {
        VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
            SectionHeader(
                title: "健康总览",
                description: "处理器、内存、网络、磁盘和电源的当前状态。",
                status: viewModel.healthSectionStatus,
                actions: [SectionHeaderAction(title: "刷新", icon: "arrow.clockwise") { viewModel.refresh() }]
            )

            GeometryReader { proxy in
                let columns = proxy.size.width < 560 ? 1 : 2

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: AppSurfaceTokens.Layout.workspaceGridSpacing), count: columns), spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                    MetricCard(
                        label: "处理器",
                        primaryValue: viewModel.cpuSummary,
                        unit: "%",
                        trend: viewModel.loadAverageSummary,
                        state: viewModel.cpuStateSummary,
                        lastUpdated: viewModel.lastUpdatedText,
                        tint: .blue
                    ) {
                        DashboardSparklineChart(values: viewModel.cpuHistory, tint: .blue, lineWidth: 2.4)
                            .frame(width: 52, height: 52)
                    }

                    MetricCard(
                        label: "内存",
                        primaryValue: viewModel.memorySummary,
                        unit: "GB",
                        trend: viewModel.memoryPressureSummary == "—" ? viewModel.memoryUsagePercentSummary : viewModel.memoryPressureSummary,
                        state: viewModel.memoryStateSummary,
                        lastUpdated: viewModel.lastUpdatedText,
                        tint: .purple
                    ) {
                        DashboardRingGauge(progress: viewModel.snapshot.memoryUsagePercent, tint: .purple, label: viewModel.memoryUsagePercentSummary)
                            .frame(width: 52, height: 52)
                    }

                    MetricCard(
                        label: "网络",
                        primaryValue: viewModel.networkSummary,
                        trend: viewModel.networkInterfaceSummary,
                        state: viewModel.networkStateSummary,
                        lastUpdated: viewModel.lastUpdatedText,
                        tint: .green
                    ) {
                        DashboardSparklineChart(values: viewModel.networkHistory, tint: .green, lineWidth: 2.2)
                            .frame(width: 52, height: 52)
                    }

                    MetricCard(
                        label: "磁盘",
                        primaryValue: viewModel.diskSummary,
                        unit: "%",
                        trend: viewModel.diskTrendSummary,
                        state: viewModel.diskStateSummary,
                        lastUpdated: viewModel.lastUpdatedText,
                        tint: .orange
                    ) {
                        DashboardRingGauge(progress: viewModel.snapshot.diskUsagePercent, tint: .orange, label: viewModel.diskSummary)
                            .frame(width: 52, height: 52)
                    }

                    if viewModel.hasBattery {
                        MetricCard(
                            label: "电源",
                            primaryValue: viewModel.batterySummary,
                            unit: "%",
                            trend: viewModel.batteryStateSummary,
                            state: viewModel.batteryTimeDetail,
                            lastUpdated: viewModel.lastUpdatedText,
                            tint: .cyan
                        ) {
                            DashboardRingGauge(progress: viewModel.snapshot.batteryLevel, tint: .cyan, label: viewModel.batterySummary)
                                .frame(width: 52, height: 52)
                        }
                    } else {
                        MetricCard(
                            label: "热状态",
                            primaryValue: viewModel.thermalThrottleSummary,
                            trend: viewModel.thermalThrottleDetail,
                            state: viewModel.thermalStateSummary,
                            lastUpdated: viewModel.lastUpdatedText,
                            tint: .red
                        ) {
                            DashboardRingGauge(progress: nil, tint: .red, label: "—")
                                .frame(width: 52, height: 52)
                        }
                    }
                }
            }
            .frame(height: viewModel.hasBattery ? 340 : 280)
        }
    }

    private var dashboardTrendSection: some View {
        VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
            SectionHeader(
                title: "趋势区",
                description: "60 秒窗口内的真实趋势和关键关联指标。",
                status: viewModel.trendSectionStatus
            )

            dashboardOverviewCard
        }
    }

    private var dashboardDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
            SectionHeader(
                title: "诊断区",
                description: "进程、传感器、接口和功率来源。",
                status: viewModel.diagnosticSectionStatus
            )

            dashboardUtilityGrid
            dashboardBottomRow
        }
    }

    private var dashboardCapabilitySection: some View {
        VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
            SectionHeader(
                title: "权限与能力",
                description: "哪些数据因硬件、系统或授权不可用。",
                status: viewModel.capabilitySectionStatus
            )

            StateContainer(phase: viewModel.capabilityContainerPhase(refreshAction: { viewModel.refresh() })) {
                VStack(alignment: .leading, spacing: 10) {
                    dashboardPermissionStateStrip
                    ForEach(viewModel.snapshot.permissions.filter { $0.isAvailable == false }.prefix(3)) { permission in
                        PermissionStatusCard(permission: permission) {
                            openPermissionSettings(for: permission)
                        }
                    }
                    dashboardHelperInstallerCard
                    dashboardCapabilityReasonList
                }
            }
        }
    }

    private var dashboardLeadingRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AppSurfaceSummaryStrip(chips: [
                    AppSurfaceSummaryChip(title: "处理器", value: viewModel.cpuSummary, tint: .blue),
                    AppSurfaceSummaryChip(title: "内存", value: viewModel.memorySummary, tint: .purple),
                    AppSurfaceSummaryChip(title: "磁盘", value: viewModel.diskSummary, tint: .orange)
                ])

                AppSurfaceCard(title: "系统总览", subtitle: "轻量总览", padding: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        dashboardMiniLine(title: "处理器", value: viewModel.cpuSummary)
                        dashboardMiniLine(title: "内存", value: viewModel.memorySummary)
                        dashboardMiniLine(title: "网络", value: viewModel.networkSummary)
                        if viewModel.hasBattery {
                            dashboardMiniLine(title: "电池", value: viewModel.batterySummary)
                        }
                        dashboardMiniLine(title: "磁盘", value: viewModel.diskSummary)
                    }
                }

                AppSurfaceCard(title: "硬件传感器", subtitle: "SMC 实时", padding: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.hasTemperatureData, let sensor = viewModel.snapshot.temperatureSensors.first(where: { $0.isAvailable && $0.value != nil }) {
                            let color = temperatureColor(sensor.value ?? 0)
                            dashboardMiniLineColored(title: "温度", value: viewModel.temperaturePrimaryValue, tint: color)
                        } else {
                            dashboardMiniLine(title: "温度", value: "采样中")
                        }

                        if viewModel.hasFanData {
                            dashboardMiniLine(title: "风扇", value: viewModel.fanPrimaryValue)
                        } else {
                            dashboardMiniLine(title: "风扇", value: "采样中")
                        }

                        if viewModel.hasGPUData {
                            dashboardMiniLine(title: "显卡", value: viewModel.gpuSummary)
                        } else {
                            dashboardMiniLine(title: "显卡", value: "采样中")
                        }

                        if viewModel.hasThermalThrottleData {
                            dashboardMiniLineColored(title: "热节流", value: viewModel.thermalThrottleSummary, tint: .red)
                        } else {
                            dashboardMiniLine(title: "热节流", value: viewModel.thermalThrottleDetail)
                        }
                    }
                }

                AppSurfaceCard(title: "采样状态", subtitle: "只读", padding: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        StatusBadge(text: "刷新 \(viewModel.refreshHint)", tone: .info, icon: "arrow.clockwise", compact: true)
                        StatusBadge(text: "更新时间 \(viewModel.lastUpdatedText)", tone: .neutral, icon: "clock", compact: true)
                        StatusBadge(text: "采样 \(viewModel.samplingStatusText)", tone: .success, icon: "circle.dotted", compact: true)
                    }
                }

                AppSurfaceCard(title: "磁盘设备", subtitle: "IORegistry 主路径", padding: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            dashboardMiniStat(
                                title: "设备数",
                                value: viewModel.diskIODeviceCountSummary,
                                detail: "本机卷统计",
                                tint: .orange
                            )
                            dashboardMiniStat(
                                title: "当前领先",
                                value: viewModel.diskIODeviceSummary,
                                detail: viewModel.diskIODeviceDetailSummary,
                                tint: .orange
                            )
                            dashboardMiniStat(
                                title: "来源",
                                value: viewModel.diskIODeviceSourceSummary,
                                detail: "native / fallback",
                                tint: .orange
                            )
                        }

                        dashboardDiskDeviceList(devices: viewModel.snapshot.diskIODevices)

                        VStack(alignment: .leading, spacing: 3) {
                            dashboardStatusRow(
                                title: "来源",
                                value: viewModel.diskIODeviceSourceSummary,
                                tint: .orange,
                                icon: "info.circle"
                            )
                            dashboardStatusRow(
                                title: "状态",
                                value: viewModel.diskStateSummary,
                                tint: .orange,
                                icon: "internaldrive"
                            )
                            dashboardStatusRow(
                                title: "信息",
                                value: viewModel.diskStateDetail,
                                tint: .orange,
                                icon: "text.alignleft"
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private var dashboardTrailingRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AppSurfaceSummaryStrip(chips: [
                    AppSurfaceSummaryChip(title: "采样", value: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor),
                    AppSurfaceSummaryChip(title: "权限", value: viewModel.permissionFooterSummary, tint: AppSurfaceTokens.accentBlue),
                    AppSurfaceSummaryChip(title: "热节流", value: viewModel.thermalThrottleSummary, tint: AppSurfaceTokens.accentOrange)
                ])

                AppSurfaceCard(title: "状态指示", subtitle: "图标化状态矩阵", padding: 5) {
                    VStack(alignment: .leading, spacing: 4) {
                        dashboardStatusMatrix
                        .frame(height: DashboardLayout.statusMatrixHeight, alignment: .topLeading)
                        dashboardPermissionStateStrip
                            .frame(height: DashboardLayout.permissionStripHeight, alignment: .topLeading)
                    }
                }
            }
            .padding(16)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private var dashboardKpiRow: some View {
        let columns = viewModel.hasBattery
            ? Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 5)
            : Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 4)

        return LazyVGrid(columns: columns, spacing: 4) {
            dashboardKpiCard(
                title: "处理器",
                icon: "cpu",
                tint: .blue,
                mainValue: viewModel.cpuSummary,
                detail: viewModel.loadAverageSummary,
                chart: {
                    DashboardSparklineChart(values: viewModel.cpuHistory, tint: .blue, lineWidth: 2.4)
                }
            )
            dashboardKpiCard(
                title: "内存",
                icon: "memorychip",
                tint: .purple,
                mainValue: viewModel.memorySummary,
                detail: viewModel.memoryPressureSummary,
                chart: {
                    DashboardRingGauge(progress: viewModel.snapshot.memoryUsagePercent, tint: .purple, label: viewModel.memoryUsagePercentSummary)
                }
            )
            dashboardKpiCard(
                title: "网络",
                icon: "network",
                tint: .green,
                mainValue: viewModel.networkSummary,
                detail: viewModel.networkInterfaceSummary,
                chart: {
                    DashboardSparklineChart(values: viewModel.networkHistory, tint: .green, lineWidth: 2.4)
                }
            )
            if viewModel.hasBattery {
                dashboardKpiCard(
                    title: "电池",
                    icon: "battery.100",
                    tint: .cyan,
                    mainValue: viewModel.batterySummary,
                    detail: viewModel.batteryStateSummary,
                    chart: {
                        DashboardRingGauge(progress: viewModel.snapshot.batteryLevel, tint: .cyan, label: viewModel.batterySummary)
                    }
                )
            }
            dashboardKpiCard(
                title: "磁盘",
                icon: "internaldrive",
                tint: .orange,
                mainValue: viewModel.diskSummary,
                detail: viewModel.diskCurrentVolumeSummary,
                chart: {
                    VStack(spacing: 6) {
                        DashboardRingGauge(progress: viewModel.snapshot.diskUsagePercent, tint: .orange, label: viewModel.diskSummary)
                            .frame(height: 30)
                        if viewModel.snapshot.diskVolumes.isEmpty == false {
                            if let currentVolume = viewModel.snapshot.diskVolumes.first(where: { $0.isCurrent }) {
                                dashboardDiskCurrentVolumeStrip(currentVolume)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                let currentVolumes = viewModel.snapshot.diskVolumes.filter { $0.isCurrent }
                                let internalVolumes = viewModel.snapshot.diskVolumes.filter { $0.isInternal && !$0.isCurrent }
                                let removableVolumes = viewModel.snapshot.diskVolumes.filter { $0.isRemovable }
                                let otherVolumes = viewModel.snapshot.diskVolumes.filter { !$0.isCurrent && !$0.isInternal && !$0.isRemovable }

                                if currentVolumes.isEmpty == false {
                                    dashboardDiskVolumeGroup(title: "当前卷", volumes: currentVolumes.prefix(1))
                                }
                                if internalVolumes.isEmpty == false {
                                    dashboardDiskVolumeGroup(title: "内部卷", volumes: internalVolumes.prefix(2))
                                }
                                if removableVolumes.isEmpty == false {
                                    dashboardDiskVolumeGroup(title: "可移动卷", volumes: removableVolumes.prefix(2))
                                }
                                if otherVolumes.isEmpty == false {
                                    dashboardDiskVolumeGroup(title: "其他卷", volumes: otherVolumes.prefix(1))
                                }
                            }
                        }
                        if viewModel.diskReadHistory.count > 2 {
                            DashboardSparklineChart(values: viewModel.diskReadHistory, tint: .teal, lineWidth: 1.8)
                                .frame(height: 18)
                        }
                        if viewModel.snapshot.topDiskIOProcesses.isEmpty == false {
                            LazyVGrid(columns: [GridItem(.flexible(minimum: 0))], spacing: 2) {
                                ForEach(Array(viewModel.snapshot.topDiskIOProcesses.prefix(3))) { process in
                                    dashboardDiskProcessChip(process)
                                }
                            }
                        }
                    }
                }
            )
        }
    }

    private var dashboardOverviewCard: some View {
        AppSurfaceCard(title: "系统状态总览", subtitle: "近 60 秒真实趋势与少量关键指标", padding: 6) {
            let metricColumnCount = viewModel.hasGPUData ? 5 : 4

            VStack(alignment: .leading, spacing: 5) {
                AcTrendChart(values: viewModel.cpuHistory, tint: .blue, lineWidth: 2.4)
                .frame(height: 76)

                HStack(alignment: .center, spacing: 5) {
                    dashboardLegendChip(title: "处理器", tint: .blue)
                    dashboardLegendChip(title: "内存", tint: .purple)
                    dashboardLegendChip(title: "网络", tint: .green)
                    if viewModel.hasBattery {
                        dashboardLegendChip(title: "电池", tint: .cyan)
                    }
                    if viewModel.hasTemperatureData {
                        dashboardLegendChip(title: "温度", tint: .orange)
                    }
                    if viewModel.hasThermalThrottleData {
                        dashboardLegendChip(title: "热节流", tint: .red)
                    }
                    dashboardLegendChip(title: "磁盘", tint: .orange)
                    Spacer(minLength: 0)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: metricColumnCount), spacing: 3) {
                    dashboardMetricChip(title: "负载", value: viewModel.loadAverageSummary, tint: .blue)
                    dashboardMetricChip(title: "内存", value: viewModel.memoryUsagePercentSummary, tint: .purple)
                    dashboardMetricChip(title: "磁盘", value: viewModel.diskSummary, tint: .orange)
                    if viewModel.hasGPUData {
                        dashboardMetricChip(title: "显卡", value: viewModel.gpuSummary, tint: .indigo)
                    }
                    dashboardMetricChip(title: "热状态", value: viewModel.thermalThrottleSummary, tint: .red)
                }

                VStack(spacing: 8) {
                    AcProgressRow(
                        title: "内存",
                        value: viewModel.snapshot.memoryUsagePercent > 0 ? viewModel.snapshot.memoryUsagePercent : nil,
                        trailingText: viewModel.memoryUsagePercentSummary,
                        tint: .purple
                    )
                    AcProgressRow(
                        title: "磁盘",
                        value: viewModel.snapshot.diskUsagePercent > 0 ? viewModel.snapshot.diskUsagePercent : nil,
                        trailingText: viewModel.diskSummary,
                        tint: .orange
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dashboardSummaryStrip: some View {
        HStack(alignment: .center, spacing: 4) {
            StatusBadge(text: "采样 \(viewModel.samplingStatusText)", tone: .info, icon: "circle.dotted", compact: true)
            StatusBadge(text: "刷新 \(viewModel.refreshHint)", tone: .neutral, icon: "arrow.clockwise", compact: true)
            StatusBadge(text: "权限 \(viewModel.permissionFooterSummary)", tone: .neutral, icon: "checkmark.shield", compact: true)
            StatusBadge(text: "热节流 \(viewModel.thermalThrottleSummary)", tone: .warning, icon: "flame.fill", compact: true)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private var dashboardSecondaryDetailsSection: some View {
        DisclosureGroup(isExpanded: $showSecondaryDetails) {
            VStack(alignment: .leading, spacing: 4) {
                dashboardUtilityGrid
                dashboardBottomRow
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                Text("次级信息")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text("温度 / 风扇 / 进程 / 快捷操作")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .padding(.top, 2)
    }

    private var dashboardPermissionStateStrip: some View {
        let permissions = Array(viewModel.snapshot.permissions.prefix(6))
        let authorizedCount = permissions.filter { SystemStatusLabelFormatter.permissionStateLabel(for: $0) == "已授权" }.count
        let unavailableCount = permissions.filter { SystemStatusLabelFormatter.permissionStateLabel(for: $0) == "不可用" }.count
        let unknownCount = permissions.filter { SystemStatusLabelFormatter.permissionStateLabel(for: $0) == "未知" }.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("权限快照")
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                Spacer(minLength: 0)
                Text(viewModel.permissionFooterSummary)
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                StatusBadge(text: "已授权 \(authorizedCount)", tone: .success, icon: "checkmark.circle.fill", compact: true)
                StatusBadge(text: "不可用 \(unavailableCount)", tone: .warning, icon: "exclamationmark.triangle.fill", compact: true)
                StatusBadge(text: "未知 \(unknownCount)", tone: .neutral, icon: "questionmark.circle", compact: true)
            }
        }
    }

    private var dashboardCapabilityReasonList: some View {
        let reasons = Array(viewModel.snapshot.unavailableReasons.prefix(6))
        let groupedReasons = Dictionary(grouping: reasons, by: { $0.category })

        return VStack(alignment: .leading, spacing: 8) {
            if reasons.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    StatusBadge(text: "无明确不可用项", tone: .success, icon: "checkmark.circle.fill", compact: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前没有硬件、授权或系统层面的降级原因。")
                            .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Text("出现不可用项时，这里会列出来源、类别和细节。")
                            .font(.system(size: AppSurfaceTokens.Typography.caption))
                            .foregroundStyle(AppSurfaceTokens.tertiaryText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                )
            } else {
                ForEach(groupedReasons.keys.sorted(), id: \.self) { category in
                    if let categoryReasons = groupedReasons[category] {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                StatusBadge(text: category.uppercased(), tone: .warning, icon: "exclamationmark.triangle.fill", compact: true)
                                Text("\(categoryReasons.count) 项")
                                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                                Spacer(minLength: 0)
                            }

                            ForEach(categoryReasons) { reason in
                                HStack(alignment: .top, spacing: 8) {
                                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                        .fill(AppSurfaceTokens.accentOrange.opacity(0.14))
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundStyle(AppSurfaceTokens.accentOrange)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reason.message)
                                            .font(.system(size: AppSurfaceTokens.Typography.body, weight: .semibold))
                                            .foregroundStyle(AppSurfaceTokens.primaryText)
                                        if let detail = reason.detail {
                                            Text(detail)
                                                .font(.system(size: AppSurfaceTokens.Typography.caption))
                                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                                        .stroke(AppSurfaceTokens.accentOrange.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                                .fill(AppSurfaceTokens.cardBackgroundSoft)
                        )
                    }
                }
            }
        }
    }

    private func openPermissionSettings(for permission: SystemPermissionSnapshot) {
        if let kind = permission.appPermissionKind {
            permissionManager.openSettingsFor(kind)
        } else {
            permissionManager.openPrivacySettings()
        }
    }

    private var dashboardUtilityGrid: some View {
        HStack(alignment: .top, spacing: 4) {
            AppSurfaceCard(title: "网络", subtitle: "速率 · 接口 · Wi‑Fi", padding: 5, fillHeight: true) {
                VStack(alignment: .leading, spacing: 3) {
                    DashboardSparklineChart(values: viewModel.networkHistory, tint: .green, lineWidth: 2.2)
                        .frame(height: 30)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 2), spacing: 3) {
                        dashboardMiniStat(title: "下载", value: viewModel.networkDownloadSummary, detail: "MB/s", tint: .green)
                        dashboardMiniStat(title: "上传", value: viewModel.networkUploadSummary, detail: "MB/s", tint: .green)
                        dashboardMiniStat(title: "延迟", value: viewModel.networkLatencySummary, detail: viewModel.networkLatencyDetail, tint: .mint)
                        dashboardMiniStat(title: "域名解析", value: viewModel.networkDNSLookupSummary, detail: viewModel.networkDNSLookupDetail, tint: .yellow)
                        dashboardMiniStat(title: "质量", value: viewModel.networkServiceQualitySummary, detail: viewModel.networkServiceQualityDetail, tint: .teal)
                        dashboardMiniStat(title: "公网", value: viewModel.publicIPAddressSummary, detail: viewModel.publicIPAddressDetail, tint: .indigo)
                        dashboardMiniStat(title: "主接口", value: viewModel.primaryInterfaceSummary, detail: viewModel.primaryInterfaceDetail, tint: .blue)
                        dashboardMiniStat(title: "Wi‑Fi", value: viewModel.wifiSummary, detail: viewModel.wifiDetail, tint: .cyan)
                    }
                }
            }

            AppSurfaceCard(title: "蓝牙", subtitle: "设备与电量", padding: 5, fillHeight: true) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                            .fill(AppSurfaceTokens.accentBlue.opacity(0.14))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.accentBlue)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.bluetoothSummary)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                                .lineLimit(1)
                            Text(viewModel.bluetoothDetailSummary)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }

                    if viewModel.hasBluetoothData {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 2), spacing: 3) {
                            ForEach(Array(viewModel.snapshot.bluetoothDevices.prefix(4))) { device in
                                dashboardBluetoothDeviceChip(device)
                            }
                        }
                    } else {
                        dashboardPulsingPlaceholder(icon: "dot.radiowaves.left.and.right", color: .blue)
                    }
                }
            }

            if viewModel.hasBattery {
                AppSurfaceCard(title: "电源", subtitle: "电池与功率", padding: 5, fillHeight: true) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            DashboardRingGauge(progress: viewModel.snapshot.batteryLevel, tint: .cyan, label: viewModel.batterySummary)
                                .frame(width: 50, height: 50)

                            VStack(alignment: .leading, spacing: 2) {
                                dashboardMiniLine(title: "状态", value: viewModel.batteryStateSummary)
                                dashboardMiniLine(title: "健康", value: viewModel.batteryHealthSummary)
                                dashboardMiniLine(title: "功率", value: viewModel.batteryPowerSummary)
                                dashboardMiniLine(title: "时间", value: viewModel.batteryTimeSummary)
                            }
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 2), spacing: 3) {
                            dashboardMiniStat(title: "循环", value: viewModel.batteryCycleSummary, detail: "CycleCount", tint: .orange)
                            dashboardMiniStat(title: "容量", value: viewModel.batteryCapacitySummary, detail: viewModel.batteryCapacityDetail, tint: .purple)
                            dashboardMiniStat(title: "电压", value: viewModel.batteryVoltageSummary, detail: "V", tint: .blue)
                            dashboardMiniStat(title: "电流", value: viewModel.batteryCurrentSummary, detail: "A", tint: .green)
                        }
                    }
                }
            } else {
                AppSurfaceCard(title: "供电", subtitle: "外接电源", padding: 6, fillHeight: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "powerplug.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.accentGreen)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("外接供电")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.primaryText)
                                if let powerSummary = viewModel.snapshot.powerSensors.first(where: { $0.isAvailable && $0.value != nil }) {
                                    Text(String(format: "%.1f %@", powerSummary.value ?? 0, powerSummary.unit))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                                }
                            }
                        }
                    }
                }
            }

            AppSurfaceCard(title: "权限", subtitle: "紧凑状态矩阵", padding: 5, fillHeight: true) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 2), spacing: 3) {
                    ForEach(Array(viewModel.snapshot.permissions.prefix(6))) { permission in
                        dashboardPermissionCell(permission)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var dashboardBottomRow: some View {
        HStack(alignment: .top, spacing: 4) {
            AppSurfaceCard(title: "设备温度", subtitle: viewModel.hasTemperatureData ? "\(viewModel.snapshot.temperatureSensors.count) 个传感器" : "SMC", padding: 4, fillHeight: true) {
                VStack(alignment: .leading, spacing: 1) {
                    if viewModel.hasTemperatureData {
                        if let primarySensor = viewModel.snapshot.temperatureSensors.first(where: { $0.isAvailable && $0.value != nil }) {
                            let color = temperatureColor(primarySensor.value ?? 0)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(viewModel.temperaturePrimaryValue)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(color)
                                Text(primarySensor.name)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                            }
                        }

                        DashboardSparklineChart(values: viewModel.temperatureHistory, tint: temperatureColor(viewModel.snapshot.temperatureSensors.first(where: { $0.value != nil })?.value ?? 0), lineWidth: 2.0)
                            .frame(height: 20)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.hasTemperatureData)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 2), count: 2), spacing: 2) {
                            ForEach(Array(viewModel.snapshot.temperatureSensors.prefix(3))) { sensor in
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(AppSurfaceTokens.accentOrange.opacity(0.8))
                                        .frame(width: 5, height: 5)
                                    Text(sensor.name)
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text(sensor.value.map { String(format: "%.1f", $0) } ?? "—")
                                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(AppSurfaceTokens.primaryText)
                                        .lineLimit(1)
                                    Text(sensor.unit)
                                        .font(.system(size: 8.5, weight: .medium))
                                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                                )
                            }
                        }
                    } else {
                        dashboardPulsingPlaceholder(icon: "thermometer.medium", color: .orange)
                    }
                }
            }

            AppSurfaceCard(title: "风扇转速", subtitle: viewModel.hasFanData ? "\(viewModel.snapshot.fanSensors.count) 个风扇" : "SMC", padding: 4, fillHeight: true) {
                VStack(alignment: .leading, spacing: 1) {
                    if viewModel.hasFanData {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(viewModel.fanPrimaryValue)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text(viewModel.fanStatusText)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }

                        DashboardSparklineChart(values: viewModel.fanHistory, tint: .blue, lineWidth: 2.0)
                            .frame(height: 20)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 2), count: 2), spacing: 2) {
                            ForEach(Array(viewModel.fanSensorSummaries.prefix(3))) { fan in
                                dashboardFanChip(fan)
                            }
                        }

                        if fanControlCandidates.isEmpty == false {
                            dashboardFanControlPanel
                        } else {
                            dashboardFanControlUnavailable
                        }
                    } else {
                        dashboardPulsingPlaceholder(icon: "fanblades", color: .blue)
                    }
                }
            }

            AppSurfaceCard(title: "进程占用 Top 5", subtitle: "处理器实时排序", padding: 4, fillHeight: true) {
                dashboardProcessList(processes: viewModel.snapshot.topProcesses)
            }

            AppSurfaceCard(title: "快速操作", subtitle: "短按钮，不拉高卡片", padding: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 2), count: 2), spacing: 2) {
                        dashboardQuickAction(title: "说入法", icon: "mic.fill") {
                            (NSApp.delegate as? AppDelegate)?.showVoicePanel()
                        }
                        dashboardQuickAction(title: "截图", icon: "camera.viewfinder") {
                            (NSApp.delegate as? AppDelegate)?.captureAreaScreenshot()
                        }
                        dashboardQuickAction(title: "便笺", icon: "square.and.pencil") {
                            (NSApp.delegate as? AppDelegate)?.showQuickNotePanel()
                        }
                        dashboardQuickAction(title: "主窗口", icon: "rectangle.on.rectangle") {
                            (NSApp.delegate as? AppDelegate)?.showMainWindow()
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func dashboardTopBadge(icon: String, title: String, tint: Color = AppSurfaceTokens.cardBackground) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(title)
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.9))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.55), lineWidth: 1)
        )
    }

    private func dashboardKpiCard<Chart: View>(
        title: String,
        icon: String,
        tint: Color,
        mainValue: String,
        detail: String,
        @ViewBuilder chart: () -> Chart
    ) -> some View {
        AppSurfaceCard(padding: 8) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 5) {
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(tint)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Text(mainValue)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                chart()
                    .frame(height: 26)

                Text(detail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private func dashboardLegendChip(title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppSurfaceTokens.secondaryText)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule(style: .continuous).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private func dashboardMetricChip(title: String, value: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func dashboardMiniLine(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func dashboardMiniLineColored(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppSurfaceTokens.secondaryText.opacity(0.8))
                .frame(width: 4, height: 4)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func dashboardMiniStat(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.55), lineWidth: 1)
        )
    }

    private func dashboardDiskProcessChip(_ process: DiskIOProcessSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(AppSurfaceTokens.secondaryText)
                .frame(width: 4, height: 4)
            Text(SystemStatusLabelFormatter.diskIOProcessSummary(process))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(SystemStatusLabelFormatter.diskIOProcessDetail(process))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func dashboardBluetoothDeviceChip(_ device: SystemBluetoothDeviceSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(device.isConnected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                .frame(width: 4, height: 4)
            Text(device.name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let batteryLevel = device.batteryLevel {
                Text(String(format: "%.0f%%", batteryLevel))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            } else {
                Text(device.isConnected ? "已连接" : "已配对")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func dashboardDiskIODeviceChip(_ device: DiskIODeviceSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(AppSurfaceTokens.accentBlue.opacity(0.85))
                .frame(width: 4, height: 4)
            Text(SystemStatusLabelFormatter.diskIODeviceSummary(device))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(SystemStatusLabelFormatter.diskIODeviceDetail(device))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func dashboardDiskCurrentVolumeStrip(_ volume: DiskVolumeSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(AppSurfaceTokens.accentGreen.opacity(0.9))
                .frame(width: 4, height: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text("当前卷")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                Text(SystemStatusLabelFormatter.diskCurrentVolumeSummary(volume))
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(SystemStatusLabelFormatter.diskCurrentVolumeDetail(volume))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.accentGreen)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
    }

    private func dashboardDiskVolumeChip(_ volume: DiskVolumeSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(volume.isCurrent ? AppSurfaceTokens.accentGreen.opacity(0.9) : (volume.isInternal ? AppSurfaceTokens.accentOrange.opacity(0.85) : AppSurfaceTokens.accentBlue.opacity(0.85)))
                .frame(width: 4, height: 4)
            Text(SystemStatusLabelFormatter.diskVolumeSummary(volume))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(volume.isCurrent ? "当前" : SystemStatusLabelFormatter.diskVolumeDetail(volume))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(volume.isCurrent ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func dashboardDiskVolumeGroup<S: RandomAccessCollection>(title: String, volumes: S) -> some View where S.Element == DiskVolumeSnapshot {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            ForEach(Array(volumes)) { volume in
                dashboardDiskVolumeChip(volume)
            }
        }
    }

    private func dashboardDiskDeviceList(devices: [DiskIODeviceSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if devices.isEmpty {
                dashboardPulsingPlaceholder(icon: "internaldrive", color: .orange)
            } else {
                ForEach(Array(devices.prefix(4))) { device in
                    dashboardDiskIODeviceChip(device)
                }
            }
        }
    }

    private func dashboardProcessList(processes: [SystemProcessSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if processes.isEmpty {
                dashboardPulsingPlaceholder(icon: "list.bullet", color: .blue)
            } else {
                let topProcesses = Array(processes.prefix(5))
                let maxCPU = max(topProcesses.map(\.cpuUsage).max() ?? 1, 1)
                ForEach(Array(topProcesses.enumerated()), id: \.element.id) { index, process in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(process.name)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(String(format: "%.0f%%", process.cpuUsage))
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }

                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 99, style: .continuous)
                                .fill(AppSurfaceTokens.cardBackgroundSoft)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                                        .fill(index == 0 ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.accentGreen.opacity(0.85))
                                        .frame(width: proxy.size.width * CGFloat(min(process.cpuUsage / maxCPU, 1)))
                                }
                        }
                        .frame(height: 5)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                            .fill(AppSurfaceTokens.cardBackgroundSoft)
                    )
                }
            }
        }
    }

    private var dashboardStatusMatrix: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                dashboardStatusRow(title: "处理器", value: viewModel.cpuSummary, tint: .blue, icon: "cpu")
                dashboardStatusRow(title: "内存", value: viewModel.memoryUsagePercentSummary, tint: .purple, icon: "memorychip")
            }
            HStack(spacing: 3) {
                dashboardStatusRow(title: "网络", value: viewModel.networkSummary, tint: .green, icon: "network")
                dashboardStatusRow(title: "磁盘", value: viewModel.diskSummary, tint: .orange, icon: "internaldrive")
            }
            HStack(spacing: 3) {
                if viewModel.hasBattery {
                    dashboardStatusRow(title: "电池", value: viewModel.batterySummary, tint: .cyan, icon: "battery.100")
                } else {
                    dashboardStatusRow(title: "电源", value: "外接供电", tint: .cyan, icon: "powerplug.fill")
                }
                dashboardStatusRow(title: "权限", value: viewModel.permissionFooterSummary, tint: .blue, icon: "checkmark.shield")
            }
            HStack(spacing: 3) {
                dashboardStatusRow(title: "热节流", value: viewModel.thermalThrottleSummary, tint: .red, icon: "flame.fill")
                dashboardStatusRow(title: "来源", value: viewModel.thermalThrottleDetail, tint: .red, icon: "info.circle")
            }
        }
    }

    private func dashboardStatusRow(title: String, value: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .frame(width: 15, height: 15)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                )
            Text(title)
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func dashboardPermissionCell(_ item: SystemPermissionSnapshot) -> some View {
        let statusText = SystemStatusLabelFormatter.permissionStateLabel(for: item)
        let statusTint = dashboardPermissionTint(statusText: statusText)

        return HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(statusTint.opacity(0.14))
            .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: dashboardPermissionIcon(for: item.name))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                Text(statusText)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
    }

    private func dashboardQuickAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                    )
                Text(title)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dashboardFanChip(_ fan: SystemFanRow) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(AppSurfaceTokens.secondaryText)
                .frame(width: 5, height: 5)
            Text(fan.displayName)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(fan.displayValue)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private var dashboardFanControlPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("手动调速")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Spacer(minLength: 0)
                Text(fanControlSummary)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Picker("风扇", selection: Binding(
                get: { selectedFanIndex },
                set: { newValue in
                    selectedFanIndex = newValue
                    syncFanControlDraftFromSnapshot()
                }
            )) {
                ForEach(fanControlCandidates, id: \.fanIndex) { fan in
                    Text(fan.name).tag(fan.fanIndex)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Slider(value: Binding(
                get: { fanPercentDraft },
                set: { newValue in
                    fanPercentDraft = newValue
                }
            ), in: 0...100, step: 1)

            HStack(alignment: .center, spacing: 6) {
                Text("\(Int(fanPercentDraft))%")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Spacer(minLength: 0)
                Button("自动") {
                    Task {
                        let success = await fanControlService.setFanAutomatic(fanIndex: selectedFanIndex)
                        fanControlMessage = success ? "已切换到自动" : "自动模式失败"
                    }
                }
                .buttonStyle(.bordered)

                Button("应用") {
                    Task {
                        let success = await fanControlService.setFanPercentage(fanIndex: selectedFanIndex, percentage: fanPercentDraft)
                        fanControlMessage = success ? "已应用 \(Int(fanPercentDraft))%" : "写入失败"
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("重置") {
                    Task {
                        let success = await fanControlService.resetFanControl()
                        fanControlMessage = success ? "已恢复自动" : "重置失败"
                    }
                }
                .buttonStyle(.bordered)
            }

            if let selectedFanControlState {
                Text(fanControlDetailText(for: selectedFanControlState))
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            if let fanControlMessage {
                Text(fanControlMessage)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
        }
        .padding(.top, 4)
    }

    private var dashboardHelperInstallerCard: some View {
        AppSurfaceCard(
            title: "辅助程序安装",
            subtitle: helperInstaller.helperInstallDescription,
            padding: 8
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("温度、风扇和受限状态需要系统级辅助程序才能稳定读取和写入。")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Text("源文件：\(helperInstaller.helperBinaryPath)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Button(helperInstaller.isInstalled ? "重装辅助程序" : "安装辅助程序") {
                        Task {
                            _ = await helperInstaller.install()
                            await fanControlService.refresh()
                            syncFanControlDraftFromSnapshot()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(helperInstaller.isInstalling)

                    if helperInstaller.isInstalled {
                        Button("卸载") {
                            Task {
                                _ = await helperInstaller.uninstall()
                                await fanControlService.refresh()
                                syncFanControlDraftFromSnapshot()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(helperInstaller.isInstalling)
                    }

                    Spacer(minLength: 0)

                    Text(helperInstaller.isRunning ? "已启动" : "未启动")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(helperInstaller.isRunning ? .green : AppSurfaceTokens.secondaryText)
                }

                if let message = helperInstaller.lastMessage {
                    Text(message)
                        .font(.system(size: 8.2, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                }
            }
        }
        .padding(.top, 2)
    }

    private var dashboardFanControlUnavailable: some View {
        Text("当前风扇仅能读取，等辅助程序通道可用后再开放手动调速。")
            .font(.system(size: 8.5, weight: .medium))
            .foregroundStyle(AppSurfaceTokens.secondaryText)
            .padding(.top, 4)
    }

    private var fanControlCandidates: [SystemFanControlState] {
        let liveStates = fanControlService.fanControlStates
        let snapshotStates = viewModel.snapshot.fanControlStates
        let states = liveStates.isEmpty ? snapshotStates : liveStates
        return states.filter { $0.isAvailable }
    }

    private var selectedFanControlState: SystemFanControlState? {
        fanControlCandidates.first(where: { $0.fanIndex == selectedFanIndex }) ?? fanControlCandidates.first
    }

    private var fanControlSummary: String {
        guard fanControlCandidates.isEmpty == false else { return "只读" }
        let automaticCount = fanControlCandidates.filter { $0.isAutomatic }.count
        if automaticCount == fanControlCandidates.count {
            return "\(fanControlCandidates.count) 个风扇 · 自动"
        }
        return "\(fanControlCandidates.count) 个风扇 · 手动可调"
    }

    private func fanControlDetailText(for fan: SystemFanControlState) -> String {
        let rpmText = fan.displayRPM.map { String(format: "%.0f RPM", $0) } ?? "—"
        let percentText = fan.displayPercent.map { "\(Int($0.rounded()))%" } ?? "—"
        let modeText = fan.isAutomatic ? "自动" : "手动"
        return "\(fan.name) · \(rpmText) · \(percentText) · \(modeText)"
    }

    private func syncFanControlDraftFromSnapshot() {
        let states = fanControlCandidates
        guard states.isEmpty == false else {
            fanPercentDraft = 50
            selectedFanIndex = 0
            return
        }

        if states.contains(where: { $0.fanIndex == selectedFanIndex }) == false {
            selectedFanIndex = states[0].fanIndex
        }

        if let selectedFan = states.first(where: { $0.fanIndex == selectedFanIndex }),
           let controlPercent = selectedFan.displayPercent {
            fanPercentDraft = controlPercent
        } else if let selectedFan = states.first,
                  let controlPercent = selectedFan.displayPercent {
            selectedFanIndex = selectedFan.fanIndex
            fanPercentDraft = controlPercent
        }
    }

    private func dashboardSensorChip(_ sensor: SystemSensorSnapshot) -> some View {
        let tempColor = sensor.value.map { temperatureColor($0) } ?? .orange
        return HStack(spacing: 5) {
            Circle()
                .fill(AppSurfaceTokens.secondaryText)
                .frame(width: 5, height: 5)
            Text(sensor.name)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let value = sensor.value {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                Text(sensor.unit)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(tempColor.opacity(0.06))
        )
    }

    private func temperatureColor(_ value: Double) -> Color {
        if value < 50 { return .green }
        if value < 70 { return .orange }
        return .red
    }

    private func dashboardPulsingPlaceholder(icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText.opacity(0.4))
                .opacity(pulsePhase ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulsePhase)

            RoundedRectangle(cornerRadius: 3)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .frame(width: 60, height: 10)
                .opacity(pulsePhase ? 0.8 : 0.2)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.15), value: pulsePhase)

            RoundedRectangle(cornerRadius: 3)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .frame(width: 40, height: 10)
                .opacity(pulsePhase ? 0.6 : 0.15)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.3), value: pulsePhase)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .onAppear { pulsePhase = true }
    }

    private func dashboardFooterChip(title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(
            Capsule(style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private func dashboardPermissionTint(statusText: String) -> Color {
        if statusText == "已授权" {
            return AppSurfaceTokens.secondaryText
        }
        if statusText == "已拒绝" || statusText == "受限" || statusText == "不可用" {
            return AppSurfaceTokens.secondaryText
        }
        if statusText == "未知" {
            return AppSurfaceTokens.secondaryText
        }
        return AppSurfaceTokens.secondaryText
    }

    private func dashboardPermissionIcon(for permissionName: String) -> String {
        switch permissionName {
        case "麦克风": return "mic.fill"
        case "辅助功能": return "accessibility"
        case "屏幕录制": return "display"
        case "日历": return "calendar"
        case "提醒事项": return "checklist"
        case "通知": return "bell"
        default: return "checkmark.shield"
        }
    }
}

private struct DashboardSparklineChart: View {
    let values: [Double]
    let tint: Color
    let lineWidth: CGFloat

    init(values: [Double], tint: Color, lineWidth: CGFloat = 2.2) {
        self.values = values
        self.tint = tint
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)

                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(AppSurfaceTokens.separator.opacity(0.12))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }

                if let path = sparklinePath(in: size) {
                    path.fill(tint.opacity(0.06))

                    path.stroke(
                        tint,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                } else {
                    Text("—")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
    }

    private func sparklinePath(in size: CGSize) -> Path? {
        guard values.count > 1 else { return nil }
        let maxValue = max(values.max() ?? 1, 1)
        let minValue = min(values.min() ?? 0, maxValue - 1)
        let span = max(maxValue - minValue, 0.0001)
        let step = size.width / CGFloat(max(values.count - 1, 1))
        let points = values.enumerated().map { index, value -> CGPoint in
            let x = CGFloat(index) * step
            let normalized = (value - minValue) / span
            let y = size.height - (CGFloat(normalized) * size.height * 0.74) - size.height * 0.12
            return CGPoint(x: x, y: max(6, min(size.height - 6, y)))
        }

        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            let last = points.last ?? first
            path.addLine(to: CGPoint(x: last.x, y: size.height - 4))
            path.addLine(to: CGPoint(x: first.x, y: size.height - 4))
            path.closeSubpath()
        }
    }
}

private struct DashboardRingGauge: View {
    let progress: Double?
    let tint: Color
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppSurfaceTokens.separator.opacity(0.18), lineWidth: 8)

            if let progress {
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(progress / 100.0, 1))))
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.55), tint],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                if progress == nil {
                    Text("—")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
            .padding(.horizontal, 8)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct DashboardTrendChart: View {
    let cpu: [Double]
    let memory: [Double]
    let network: [Double]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)

                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(AppSurfaceTokens.separator.opacity(0.12))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }

                dashboardTrendPath(values: cpu, in: size)
                    .fill(AppSurfaceTokens.separator.opacity(0.08))
                dashboardTrendPath(values: memory, in: size)
                    .fill(AppSurfaceTokens.separator.opacity(0.06))
                dashboardTrendPath(values: network, in: size)
                    .fill(AppSurfaceTokens.separator.opacity(0.05))

                dashboardTrendLine(values: cpu, in: size)
                    .stroke(AppSurfaceTokens.accentBlue, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                dashboardTrendLine(values: memory, in: size)
                    .stroke(AppSurfaceTokens.accentPrimary, style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
                dashboardTrendLine(values: network, in: size)
                    .stroke(AppSurfaceTokens.accentGreen, style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous))
    }

    private func dashboardTrendLine(values: [Double], in size: CGSize) -> Path {
        let points = dashboardTrendPoints(values: values, in: size)
        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func dashboardTrendPath(values: [Double], in size: CGSize) -> Path {
        let points = dashboardTrendPoints(values: values, in: size)
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

    private func dashboardTrendPoints(values: [Double], in size: CGSize) -> [CGPoint] {
        guard values.isEmpty == false else { return [CGPoint(x: 0, y: size.height * 0.7), CGPoint(x: size.width, y: size.height * 0.7)] }
        let minValue = values.min() ?? 0
        let maxValue = max(values.max() ?? 1, minValue + 0.0001)
        let span = max(maxValue - minValue, 0.0001)
        let step = values.count > 1 ? size.width / CGFloat(values.count - 1) : size.width / 2

        return values.enumerated().map { index, value in
            let x = values.count > 1 ? CGFloat(index) * step : size.width / 2
            let normalized = (value - minValue) / span
            let y = size.height - (CGFloat(normalized) * size.height * 0.68) - size.height * 0.14
            return CGPoint(x: x, y: max(6, min(size.height - 6, y)))
        }
    }
}

@MainActor
final class SystemStatusViewModel: ObservableObject {
    @Published private(set) var snapshot = SystemStatusSnapshot()
    @Published private(set) var samplingStatusText = "待机"
    @Published private(set) var samplingStatusColor: Color = .secondary
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var networkHistory: [Double] = []
    @Published private(set) var diskHistory: [Double] = []
    @Published private(set) var temperatureHistory: [Double] = []
    @Published private(set) var fanHistory: [Double] = []
    @Published private(set) var batteryHistory: [Double] = []
    @Published private(set) var gpuHistory: [Double] = []
    @Published private(set) var diskReadHistory: [Double] = []
    @Published private(set) var diskWriteHistory: [Double] = []

    private let service: SystemStatusService
    private var cancellables = Set<AnyCancellable>()

    init(service: SystemStatusService) {
        self.service = service
        service.$snapshot
            .sink { [weak self] snapshot in
                self?.snapshot = snapshot
                self?.appendHistory(from: snapshot)
            }
            .store(in: &cancellables)
    }

    func startMonitoring() {
        service.start()
        samplingStatusText = "采样中"
        samplingStatusColor = .green
    }

    func stopMonitoring() {
        service.stop()
        samplingStatusText = "已停止"
        samplingStatusColor = .secondary
    }

    func refresh() {
        service.refresh()
    }

    var lastUpdatedText: String {
        guard snapshot.lastUpdated != .distantPast else { return "等待刷新" }
        return Self.timeFormatter.string(from: snapshot.lastUpdated)
    }

    var refreshHint: String {
        snapshot.lastUpdated == .distantPast ? "未刷新" : "已刷新"
    }

    var freshnessStatusText: String {
        guard snapshot.lastUpdated != .distantPast else { return "等待采样" }
        if isSnapshotStale {
            return "已过期 \(Int(snapshotAge.rounded()))s"
        }
        return "实时"
    }

    var healthSectionStatus: String {
        "\(freshnessStatusText) · \(permissionSummaryText)"
    }

    var cpuStateSummary: String {
        snapshot.cpu == nil ? "不可用" : "已采样"
    }

    var trendSectionStatus: String {
        snapshot.lastUpdated == .distantPast ? "待采样" : "60 秒"
    }

    var diagnosticSectionStatus: String {
        snapshot.unavailableReasons.isEmpty ? "诊断正常" : "\(snapshot.unavailableReasons.count) 个原因"
    }

    var capabilitySectionStatus: String {
        snapshot.unavailableReasons.isEmpty ? "无降级" : "需要关注"
    }

    func capabilityContainerPhase(refreshAction: @escaping () -> Void) -> StateContainerPhase {
        guard snapshot.lastUpdated != .distantPast else {
            return .loading(message: "正在读取系统状态。")
        }

        guard snapshot.unavailableReasons.isEmpty == false else {
            return .ready
        }

        return .stale(
            title: "\(snapshot.unavailableReasons.count) 项能力需要关注",
            message: "先看来源和原因，再决定是否需要权限、硬件或系统设置。",
            actionTitle: "刷新",
            action: refreshAction
        )
    }

    var hasBattery: Bool {
        guard let battery = snapshot.battery else { return false }
        return battery.isAvailable && battery.percentage != nil
    }

    var hasTemperatureData: Bool {
        snapshot.temperatureSensors.contains(where: { $0.isAvailable && $0.value != nil })
            || snapshot.battery?.temperatureC != nil
    }

    var hasGPUData: Bool {
        snapshot.gpuChipModel != nil
    }

    var hasFanData: Bool {
        snapshot.fanSensors.contains(where: { $0.value != nil })
    }

    var hasNetworkRate: Bool {
        snapshot.networkDownloadMBps != nil || snapshot.networkUploadMBps != nil
    }

    var hasBluetoothData: Bool {
        snapshot.bluetoothDevices.isEmpty == false
    }

    var hasDiskIO: Bool {
        snapshot.diskReadMBps != nil || snapshot.diskWriteMBps != nil
    }

    var hasDiskIODeviceSamples: Bool {
        snapshot.diskIODevices.isEmpty == false
    }

    var cpuSummary: String {
        formatPercent(snapshot.cpu?.value)
    }

    var loadAverageSummary: String {
        let values = [snapshot.loadAverage1m, snapshot.loadAverage5m, snapshot.loadAverage15m].compactMap { $0 }
        guard values.isEmpty == false else { return "—" }
        return values.map { String(format: "%.2f", $0) }.joined(separator: " / ")
    }

    var memorySummary: String {
        formatGB(snapshot.memory?.value)
    }

    var memoryUsagePercentSummary: String {
        snapshot.memoryUsagePercent > 0 ? String(format: "%.0f%%", snapshot.memoryUsagePercent) : "—"
    }

    var memoryPressureSummary: String {
        snapshot.unavailableReasons.first(where: { $0.category == "memory" })?.message ?? "—"
    }

    var memoryStateSummary: String {
        if snapshot.memory == nil {
            return "不可用"
        }
        return memoryPressureSummary == "—" ? "已采样" : memoryPressureSummary
    }

    var diskSummary: String {
        snapshot.diskUsagePercent > 0 ? String(format: "%.0f%%", snapshot.diskUsagePercent) : "—"
    }

    var diskDetailSummary: String {
        SystemStatusLabelFormatter.diskUsageSummary(
            mountPoint: snapshot.diskMountPoint,
            usedGB: snapshot.diskUsedGB,
            totalGB: snapshot.diskTotalGB
        )
    }

    var diskCurrentVolumeSummary: String {
        SystemStatusLabelFormatter.diskCurrentVolumeSummary(snapshot.diskVolumes.first(where: { $0.isCurrent }))
    }

    var diskTrendSummary: String {
        if hasDiskIO {
            return diskIOSummary
        }
        if snapshot.unavailableReasons.contains(where: { $0.id == "disk-io-unavailable" || $0.id == "disk-io-warmup" }) {
            return diskStateDetail
        }
        return diskDetailSummary
    }

    var diskStateSummary: String {
        SystemStatusLabelFormatter.diskIOStateLabel(
            readMBps: snapshot.diskReadMBps,
            writeMBps: snapshot.diskWriteMBps,
            unavailableReasons: snapshot.unavailableReasons.filter { $0.category == "disk" }
        )
    }

    var diskStateDetail: String {
        SystemStatusLabelFormatter.diskIOStateDetail(
            readMBps: snapshot.diskReadMBps,
            writeMBps: snapshot.diskWriteMBps,
            unavailableReasons: snapshot.unavailableReasons.filter { $0.category == "disk" }
        )
    }

    var networkSummary: String {
        guard hasNetworkRate else { return "—" }
        return "↓ \(formatMBps(snapshot.networkDownloadMBps)) / ↑ \(formatMBps(snapshot.networkUploadMBps))"
    }

    var networkDownloadSummary: String {
        formatMBps(snapshot.networkDownloadMBps)
    }

    var networkUploadSummary: String {
        formatMBps(snapshot.networkUploadMBps)
    }

    var networkLatencySummary: String {
        SystemStatusLabelFormatter.networkLatencySummary(snapshot.networkLatencyMs)
    }

    var networkLatencyDetail: String {
        SystemStatusLabelFormatter.networkLatencyQualityLabel(snapshot.networkLatencyMs)
    }

    var networkDNSLookupSummary: String {
        SystemStatusLabelFormatter.networkDNSLookupSummary(snapshot.networkDNSLookupMs)
    }

    var networkDNSLookupDetail: String {
        SystemStatusLabelFormatter.networkDNSLookupQualityLabel(snapshot.networkDNSLookupMs)
    }

    var networkServiceQualitySummary: String {
        SystemStatusLabelFormatter.networkServiceQualitySummary(
            latencyMs: snapshot.networkLatencyMs,
            dnsLookupMs: snapshot.networkDNSLookupMs,
            publicIPAddress: snapshot.publicIPAddress
        )
    }

    var networkServiceQualityDetail: String {
        SystemStatusLabelFormatter.networkServiceQualityDetail(
            latencyMs: snapshot.networkLatencyMs,
            dnsLookupMs: snapshot.networkDNSLookupMs,
            publicIPAddress: snapshot.publicIPAddress
        )
    }

    var publicIPAddressSummary: String {
        snapshot.publicIPAddress ?? "—"
    }

    var publicIPAddressDetail: String {
        snapshot.publicIPAddress == nil ? "等待采样" : "公网 IP"
    }

    var networkInterfaceSummary: String {
        SystemStatusLabelFormatter.networkInterfaceSummary(for: primaryNetworkInterface)
    }

    var networkStateSummary: String {
        if snapshot.unavailableReasons.contains(where: { $0.category == "network" && $0.id == "network-unavailable" }) {
            return "网络不可用"
        }
        if snapshot.unavailableReasons.contains(where: { $0.category == "network" && $0.id == "network-warmup" }) {
            return "等待采样"
        }
        return hasNetworkRate ? "速率已采样" : "等待采样"
    }

    var primaryInterfaceSummary: String {
        SystemStatusLabelFormatter.networkInterfaceSummary(for: snapshot.networkInterfaces.first(where: { $0.name == "主接口" }))
    }

    var primaryInterfaceDetail: String {
        SystemStatusLabelFormatter.networkQualitySummary(for: snapshot.networkInterfaces.first(where: { $0.name == "主接口" }))
    }

    var wifiSummary: String {
        snapshot.networkInterfaces.first(where: { $0.ssid != nil })?.ssid ?? "—"
    }

    var wifiDetail: String {
        guard let wifi = snapshot.networkInterfaces.first(where: { $0.ssid != nil }) else { return "—" }
        let quality = SystemStatusLabelFormatter.networkLinkQualityLabel(for: wifi)
        let metrics = SystemStatusLabelFormatter.networkQualitySummary(for: wifi)
        if metrics == "—" {
            return quality
        }
        return "\(quality) · \(metrics)"
    }

    var batterySummary: String {
        guard let battery = snapshot.battery, battery.isAvailable else { return "—" }
        if let percentage = battery.percentage {
            return String(format: "%.0f%%", percentage)
        }
        return "—"
    }

    var bluetoothSummary: String {
        let devices = snapshot.bluetoothDevices.filter { $0.isAvailable }
        guard devices.isEmpty == false else { return "—" }
        let connected = devices.filter { $0.isConnected }
        if connected.isEmpty == false {
            return "\(connected.count) 连接 / \(devices.count) 设备"
        }
        return "\(devices.count) 设备"
    }

    var bluetoothDetailSummary: String {
        let devices = snapshot.bluetoothDevices.filter { $0.isAvailable }
        guard devices.isEmpty == false else { return "采样中" }
        if let connectedWithBattery = devices.first(where: { $0.isConnected && $0.batteryLevel != nil }) {
            let battery = connectedWithBattery.batteryLevel.map { String(format: "%.0f%%", $0) } ?? "—"
            return "\(connectedWithBattery.name) · \(battery)"
        }
        if let connected = devices.first(where: { $0.isConnected }) {
            return "\(connected.name) · 已连接"
        }
        if let first = devices.first {
            return "\(first.name) · 已配对"
        }
        return "采样中"
    }

    var bluetoothDeviceCountSummary: String {
        snapshot.bluetoothDevices.isEmpty ? "—" : "\(snapshot.bluetoothDevices.count) 个"
    }

    var bluetoothConnectedCountSummary: String {
        let connected = snapshot.bluetoothDevices.filter { $0.isAvailable && $0.isConnected }
        return connected.isEmpty ? "—" : "\(connected.count) 个连接"
    }

    var batteryStateSummary: String {
        guard let state = snapshot.battery?.state, hasBattery else { return "—" }
        return state
    }

    var batteryCycleSummary: String {
        snapshot.battery?.cycleCount.map(String.init) ?? "—"
    }

    var batteryCapacitySummary: String {
        guard let battery = snapshot.battery, battery.isAvailable else { return "—" }
        let current = battery.rawCurrentCapacity ?? battery.maxCapacity
        let max = battery.rawMaxCapacity ?? battery.designCapacity ?? battery.maxCapacity
        guard let current, let max, max > 0 else { return "—" }
        return "\(String(format: "%.0f", current)) / \(String(format: "%.0f", max))"
    }

    var batteryCapacityDetail: String {
        "rawCurrent / rawMax"
    }

    var batteryTemperatureSummary: String {
        formatTemperature(snapshot.battery?.temperatureC)
    }

    var batteryVoltageSummary: String {
        formatMetric(snapshot.battery?.voltageV, unit: "V")
    }

    var batteryCurrentSummary: String {
        formatMetric(snapshot.battery?.amperageA, unit: "A")
    }

    var batteryPowerSummary: String {
        formatMetric(snapshot.battery?.chargerPowerW, unit: "W")
    }

    var batteryTimeSummary: String {
        if let minutes = snapshot.battery?.timeToEmptyMinutes {
            return "\(minutes) min"
        }
        if let minutes = snapshot.battery?.timeToFullChargeMinutes {
            return "\(minutes) min"
        }
        return "—"
    }

    var batteryTimeDetail: String {
        snapshot.battery?.timeToEmptyMinutes != nil ? "剩余时间" : "充满时间"
    }

    private var primaryNetworkInterface: SystemNetworkInterfaceSnapshot? {
        snapshot.networkInterfaces.first(where: { $0.ssid != nil })
            ?? snapshot.networkInterfaces.first(where: { $0.name == "主接口" })
            ?? snapshot.networkInterfaces.first
    }

    var batteryHealthSummary: String {
        if let health = batteryHealthPercentage {
            return String(format: "%.0f%%", health)
        }
        return "—"
    }

    var batteryHealthDetail: String {
        "Max / Design"
    }

    var batteryHealthPercentage: Double? {
        guard let battery = snapshot.battery, let max = battery.maxCapacity, let design = battery.designCapacity, design > 0 else { return nil }
        return (max / design) * 100
    }

    var temperaturePrimaryValue: String {
        if let sensor = snapshot.temperatureSensors.first(where: { $0.isAvailable && $0.value != nil }) {
            return sensorSummary(sensor)
        }
        if let batteryTemperature = snapshot.battery?.temperatureC {
            return formatTemperature(batteryTemperature)
        }
        return "—"
    }

    var temperaturePrimaryDetail: String {
        if let sensor = snapshot.temperatureSensors.first(where: { $0.isAvailable && $0.value != nil }) {
            return sensor.name
        }
        if snapshot.battery?.temperatureC != nil {
            return "Battery"
        }
        return "采样中"
    }

    var temperatureStatusText: String {
        if let thermalState = snapshot.thermalState {
            return thermalState
        }
        if hasTemperatureData { return "已采样" }
        return "采样中"
    }

    var thermalThrottleSummary: String {
        SystemStatusLabelFormatter.thermalThrottleSummary(snapshot.thermalThrottle)
    }

    var thermalThrottleDetail: String {
        SystemStatusLabelFormatter.thermalThrottleDetail(snapshot.thermalThrottle)
    }

    var thermalStateSummary: String {
        snapshot.thermalThrottle?.isAvailable == true ? "已采样" : "不可用"
    }

    var hasThermalThrottleData: Bool {
        snapshot.thermalThrottle?.isAvailable == true
    }

    var fanPrimaryValue: String {
        let values = snapshot.fanSensors.compactMap { $0.value }
        guard values.isEmpty == false else { return "—" }
        let average = values.reduce(0, +) / Double(values.count)
        return String(format: "%.0f RPM", average)
    }

    var fanStatusText: String {
        guard hasFanData else { return "采样中" }
        let controlStates = snapshot.fanControlStates.filter { $0.isAvailable }
        if controlStates.isEmpty == false {
            let automaticCount = controlStates.filter { $0.isAutomatic }.count
            if automaticCount == controlStates.count {
                return "\(controlStates.count) 个风扇 · 自动"
            }
            return "\(controlStates.count) 个风扇 · 可调"
        }

        let automaticCount = snapshot.fanSensors.filter { $0.isAutomatic == true }.count
        if automaticCount == snapshot.fanSensors.count {
            return "\(snapshot.fanSensors.count) 个风扇 · 自动"
        }
        return "\(snapshot.fanSensors.count) 个风扇 · 只读"
    }

    var permissionFooterSummary: String {
        SystemStatusLabelFormatter.permissionOverviewSummary(snapshot.permissions)
    }

    var permissionSummaryText: String {
        let authorized = snapshot.permissions.filter { SystemStatusLabelFormatter.permissionStateLabel(for: $0) == "已授权" }.count
        let unavailable = snapshot.permissions.filter { SystemStatusLabelFormatter.permissionStateLabel(for: $0) == "不可用" }.count
        return "\(authorized) 授权 / \(unavailable) 不可用"
    }

    var snapshotAge: TimeInterval {
        guard snapshot.lastUpdated != .distantPast else { return .greatestFiniteMagnitude }
        return Date().timeIntervalSince(snapshot.lastUpdated)
    }

    var isSnapshotStale: Bool {
        snapshotAge > 12
    }

    var unavailableReasonSummary: String {
        guard snapshot.unavailableReasons.isEmpty == false else { return "无明确不可用项" }
        let categories = Set(snapshot.unavailableReasons.map(\.category))
        return "\(snapshot.unavailableReasons.count) 项 · \(categories.count) 类"
    }

    var temperatureSummary: String {
        snapshot.temperatureSensors.first.flatMap { sensorSummary($0) } ?? "—"
    }

    var temperatureDetailSummary: String {
        snapshot.temperatureSensors.isEmpty ? "—" : "\(snapshot.temperatureSensors.count) 个"
    }

    var fanSensorSummaries: [SystemFanRow] {
        snapshot.fanSensors.map { fan in
            SystemFanRow(
                id: fan.id,
                displayName: fan.name,
                displayValue: fan.value.map { String(format: "%.0f RPM", $0) } ?? "—",
                displaySource: fan.source,
                isUnavailable: fan.isAvailable == false || fan.value == nil
            )
        }
    }

    var gpuSummary: String {
        guard let gpuUsage = snapshot.gpuUsagePercent else { return snapshot.gpuChipModel ?? "—" }
        return String(format: "%.0f%%", gpuUsage)
    }

    var gpuFrequencySummary: String {
        guard let gpuFreq = snapshot.gpuFrequencyMHz else { return "—" }
        return String(format: "%.0f MHz", gpuFreq)
    }

    var gpuChipModelSummary: String {
        snapshot.gpuChipModel ?? "GPU"
    }

    var diskReadSummary: String {
        formatMBps(snapshot.diskReadMBps)
    }

    var diskWriteSummary: String {
        formatMBps(snapshot.diskWriteMBps)
    }

    var diskIOSummary: String {
        guard hasDiskIO else { return "—" }
        return "↓ \(diskReadSummary) / ↑ \(diskWriteSummary)"
    }

    var diskIODeviceSummary: String {
        guard let device = snapshot.diskIODevices.first else { return "—" }
        return SystemStatusLabelFormatter.diskIODeviceSummary(device)
    }

    var diskIODeviceDetailSummary: String {
        guard let device = snapshot.diskIODevices.first else { return "—" }
        return SystemStatusLabelFormatter.diskIODeviceDetail(device)
    }

    var diskIODeviceSourceSummary: String {
        snapshot.diskIODeviceSource ?? "—"
    }

    var diskIODeviceCountSummary: String {
        snapshot.diskIODevices.isEmpty ? "—" : "\(snapshot.diskIODevices.count) 台"
    }

    var systemInfoSummary: String {
        guard let info = snapshot.hardwareInfo else { return "—" }
        return "\(info.cpuCoreCount) 核 · macOS \(info.osVersion)"
    }

    var uptimeSummary: String {
        guard let info = snapshot.hardwareInfo else { return "—" }
        return formatUptime(info.uptimeSeconds)
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func sensorSummary(_ sensor: SystemSensorSnapshot) -> String {
        guard sensor.isAvailable, let value = sensor.value else { return "—" }
        if sensor.unit == "°C" { return String(format: "%.1f°C", value) }
        if sensor.unit == "W" { return String(format: "%.1fW", value) }
        if sensor.unit == "V" { return String(format: "%.2fV", value) }
        if sensor.unit == "A" { return String(format: "%.2fA", value) }
        return "\(String(format: "%.1f", value)) \(sensor.unit)"
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value)
    }

    private func formatGB(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f GB", value)
    }

    private func formatMBps(_ value: Double) -> String {
        String(format: "%.1f MB/s", value)
    }

    private func formatMBps(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f MB/s", value)
    }

    private func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f°C", value)
    }

    private func formatMetric(_ value: Double?, unit: String) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f %@", value, unit)
    }

    private func appendHistory(from snapshot: SystemStatusSnapshot) {
        guard snapshot.lastUpdated != .distantPast else { return }

        if let cpu = snapshot.cpu?.value {
            cpuHistory = Self.appendLimited(cpuHistory, value: cpu)
        }
        if let memoryPercent = snapshot.memoryUsagePercent.nonZeroOrNil {
            memoryHistory = Self.appendLimited(memoryHistory, value: memoryPercent)
        }
        if snapshot.networkDownloadMBps != nil || snapshot.networkUploadMBps != nil {
            let combinedNetwork = (snapshot.networkDownloadMBps ?? 0) + (snapshot.networkUploadMBps ?? 0)
            networkHistory = Self.appendLimited(networkHistory, value: combinedNetwork)
        }
        if snapshot.diskUsagePercent.nonZeroOrNil != nil {
            diskHistory = Self.appendLimited(diskHistory, value: snapshot.diskUsagePercent)
        }
        if let temperature = snapshot.temperatureSensors.first(where: { $0.value != nil })?.value {
            temperatureHistory = Self.appendLimited(temperatureHistory, value: temperature)
        } else if let batteryTemperature = snapshot.battery?.temperatureC {
            temperatureHistory = Self.appendLimited(temperatureHistory, value: batteryTemperature)
        }
        if let fan = snapshot.fanSensors.first(where: { $0.value != nil })?.value {
            fanHistory = Self.appendLimited(fanHistory, value: fan)
        }
        if let battery = snapshot.battery?.percentage {
            batteryHistory = Self.appendLimited(batteryHistory, value: battery)
        }
        if let gpuUsage = snapshot.gpuUsagePercent {
            gpuHistory = Self.appendLimited(gpuHistory, value: gpuUsage)
        }
        if let diskRead = snapshot.diskReadMBps {
            diskReadHistory = Self.appendLimited(diskReadHistory, value: diskRead)
        }
        if let diskWrite = snapshot.diskWriteMBps {
            diskWriteHistory = Self.appendLimited(diskWriteHistory, value: diskWrite)
        }
    }

    private static func appendLimited(_ values: [Double], value: Double, limit: Int = 24) -> [Double] {
        var next = values
        next.append(value)
        if next.count > limit {
            next.removeFirst(next.count - limit)
        }
        return next
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private extension Double {
    var nonZeroOrNil: Double? {
        self > 0 ? self : nil
    }
}

protocol SensorDisplayRow {
    var displayName: String { get }
    var displayValue: String { get }
    var displaySource: String { get }
    var isUnavailable: Bool { get }
}

struct SystemFanRow: Identifiable, SensorDisplayRow {
    let id: String
    let displayName: String
    let displayValue: String
    let displaySource: String
    let isUnavailable: Bool
}

extension SystemSensorSnapshot: SensorDisplayRow {
    var displayName: String { name }
    var displayValue: String {
        guard isAvailable, let value else { return "—" }
        if unit.isEmpty { return String(format: "%.0f", value) }
        if unit == "°C" { return String(format: "%.1f°C", value) }
        if unit == "RPM" { return String(format: "%.0f RPM", value) }
        if unit == "W" { return String(format: "%.1fW", value) }
        if unit == "V" { return String(format: "%.2fV", value) }
        if unit == "A" { return String(format: "%.2fA", value) }
        return "\(String(format: "%.1f", value)) \(unit)"
    }
    var displaySource: String { source }
    var isUnavailable: Bool { isAvailable == false }
}
