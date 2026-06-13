import SwiftUI
import Combine
import AcMindKit

struct SystemStatusView: View {
    @StateObject private var viewModel: SystemStatusViewModel
    @State private var pulsePhase = false
    @State private var showSecondaryDetails = false

    private enum DashboardLayout {
        static let heroCardHeight: CGFloat = 224
        static let sideCardWidth: CGFloat = 224
        static let statusMatrixHeight: CGFloat = 82
        static let permissionStripHeight: CGFloat = 42
    }

    init(systemStatusService: SystemStatusService) {
        _viewModel = StateObject(wrappedValue: SystemStatusViewModel(service: systemStatusService))
    }

    var body: some View {
        WorkspacePageShell(
            title: "状态",
            subtitle: "真实采样 · \(viewModel.lastUpdatedText) · \(viewModel.refreshHint)",
            headerActions: AnyView(dashboardHeaderActions),
            leadingRailWidth: AppSurfaceTokens.Layout.leadingRailWidth,
            trailingRailWidth: DashboardLayout.sideCardWidth,
            leadingRail: {
                dashboardLeadingRail
            },
            content: {
                dashboardContent
            },
            trailingRail: {
                dashboardTrailingRail
            }
        )
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var dashboardHeaderActions: some View {
        HStack(spacing: 6) {
            dashboardTopBadge(icon: "mic.fill", title: "说入法")
            dashboardTopBadge(icon: "magnifyingglass", title: "搜索")
            dashboardTopBadge(icon: "bolt.horizontal.circle", title: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor)
        }
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            dashboardKpiRow
            dashboardOverviewCard
            dashboardSummaryStrip
            dashboardSecondaryDetailsSection
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppSurfaceTokens.background.ignoresSafeArea())
    }

    private var dashboardLeadingRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AppSurfaceCard(title: "系统摘要", subtitle: "轻量概览", padding: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        dashboardMiniLine(title: "CPU", value: viewModel.cpuSummary)
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
                            dashboardMiniLine(title: "GPU", value: viewModel.gpuSummary)
                        } else {
                            dashboardMiniLine(title: "GPU", value: "采样中")
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
                        dashboardPermissionStatePill(title: "刷新", value: viewModel.refreshHint, tint: .blue)
                        dashboardPermissionStatePill(title: "更新时间", value: viewModel.lastUpdatedText, tint: .green)
                        dashboardPermissionStatePill(title: "采样", value: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor)
                    }
                }
            }
            .padding(16)
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private var dashboardTrailingRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AppSurfaceCard(title: "进程占用 Top 5", subtitle: "真实进程", padding: 5) {
                    dashboardProcessList(processes: viewModel.snapshot.topCPUProcesses)
                }

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
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private var dashboardKpiRow: some View {
        let columns = viewModel.hasBattery
            ? Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 5)
            : Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 4)

        return LazyVGrid(columns: columns, spacing: 4) {
            dashboardKpiCard(
                title: "CPU",
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
                detail: viewModel.diskIOSummary,
                chart: {
                    VStack(spacing: 6) {
                        DashboardRingGauge(progress: viewModel.snapshot.diskUsagePercent, tint: .orange, label: viewModel.diskSummary)
                            .frame(height: 30)
                        if viewModel.diskReadHistory.count > 2 {
                            DashboardSparklineChart(values: viewModel.diskReadHistory, tint: .teal, lineWidth: 1.8)
                                .frame(height: 18)
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
                DashboardTrendChart(
                    cpu: viewModel.cpuHistory,
                    memory: viewModel.memoryHistory,
                    network: viewModel.networkHistory
                )
                .frame(height: 76)

                HStack(alignment: .center, spacing: 5) {
                    dashboardLegendChip(title: "CPU", tint: .blue)
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
                        dashboardMetricChip(title: "GPU", value: viewModel.gpuSummary, tint: .indigo)
                    }
                    dashboardMetricChip(title: "热状态", value: viewModel.thermalThrottleSummary, tint: .red)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dashboardSummaryStrip: some View {
        HStack(alignment: .center, spacing: 4) {
            dashboardFooterChip(title: "采样", value: viewModel.samplingStatusText)
            dashboardFooterChip(title: "刷新", value: viewModel.refreshHint)
            dashboardFooterChip(title: "权限", value: viewModel.permissionFooterSummary)
            dashboardFooterChip(title: "热节流", value: viewModel.thermalThrottleSummary)
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
                Text("次级详情")
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
        let totalCount = max(permissions.count, 1)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("权限快照")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                Spacer(minLength: 0)
                Text(viewModel.permissionFooterSummary)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .fill(.green.opacity(0.78))
                        .frame(width: proxy.size.width * CGFloat(authorizedCount) / CGFloat(totalCount))

                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .fill(.orange.opacity(0.78))
                        .frame(width: proxy.size.width * CGFloat(unavailableCount) / CGFloat(totalCount))

                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .fill(AppSurfaceTokens.secondaryText.opacity(0.35))
                        .frame(width: proxy.size.width * CGFloat(unknownCount) / CGFloat(totalCount))

                    if permissions.isEmpty {
                        RoundedRectangle(cornerRadius: 99, style: .continuous)
                            .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
                    }
                }
            }
            .frame(height: 8)
            .background(
                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.72))
            )

            HStack(spacing: 6) {
                dashboardPermissionStatePill(title: "已授权", value: "\(authorizedCount)", tint: .green)
                dashboardPermissionStatePill(title: "不可用", value: "\(unavailableCount)", tint: .orange)
                dashboardPermissionStatePill(title: "未知", value: "\(unknownCount)", tint: .secondary)
            }
        }
    }

    private func dashboardPermissionStatePill(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(tint.opacity(0.8))
                .frame(width: 4, height: 4)
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(tint.opacity(0.08))
        )
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
                        dashboardMiniStat(title: "主接口", value: viewModel.primaryInterfaceSummary, detail: viewModel.primaryInterfaceDetail, tint: .blue)
                        dashboardMiniStat(title: "Wi‑Fi", value: viewModel.wifiSummary, detail: viewModel.wifiDetail, tint: .cyan)
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
                                        .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.88))
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
                    } else {
                        dashboardPulsingPlaceholder(icon: "fanblades", color: .blue)
                    }
                }
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

    private func dashboardTopBadge(icon: String, title: String, tint: Color = AppSurfaceTokens.cardBackgroundSoft) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
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
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule(style: .continuous).fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.72)))
    }

    private func dashboardMetricChip(title: String, value: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.88))
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
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
        )
    }

    private func dashboardMiniLineColored(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint.opacity(0.8))
                .frame(width: 4, height: 4)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(tint.opacity(0.06))
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
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
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
                                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.85))
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
                            .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.72))
                    )
                }
            }
        }
    }

    private var dashboardStatusMatrix: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                dashboardStatusRow(title: "CPU", value: viewModel.cpuSummary, tint: .blue, icon: "cpu")
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
                .fill(tint.opacity(0.14))
                .frame(width: 15, height: 15)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(tint)
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
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.88))
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
                        .foregroundStyle(statusTint)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                Text(statusText)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(statusTint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(statusTint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(statusTint.opacity(0.12), lineWidth: 1)
        )
    }

    private func dashboardQuickAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
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
                    .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.85))
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
                .fill(AppSurfaceTokens.accentGreen.opacity(0.8))
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
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.88))
        )
    }

    private func dashboardSensorChip(_ sensor: SystemSensorSnapshot) -> some View {
        let tempColor = sensor.value.map { temperatureColor($0) } ?? .orange
        return HStack(spacing: 5) {
            Circle()
                .fill(tempColor.opacity(0.8))
                .frame(width: 5, height: 5)
            Text(sensor.name)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let value = sensor.value {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tempColor)
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
                .foregroundStyle(color.opacity(0.4))
                .opacity(pulsePhase ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulsePhase)

            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.1))
                .frame(width: 60, height: 10)
                .opacity(pulsePhase ? 0.8 : 0.2)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.15), value: pulsePhase)

            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.08))
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
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.72))
        )
    }

    private func dashboardPermissionTint(statusText: String) -> Color {
        if statusText == "已授权" {
            return .green
        }
        if statusText == "已拒绝" || statusText == "受限" || statusText == "不可用" {
            return .orange
        }
        if statusText == "未知" {
            return .secondary
        }
        return .blue
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
                    .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.62))

                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(AppSurfaceTokens.separator.opacity(0.12))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }

                if let path = sparklinePath(in: size) {
                    path.fill(
                        LinearGradient(
                            colors: [tint.opacity(0.15), tint.opacity(0.03), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

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
                    .fill(
                        LinearGradient(
                            colors: [
                                AppSurfaceTokens.cardBackgroundSoft.opacity(0.55),
                                AppSurfaceTokens.cardBackgroundSoft.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(AppSurfaceTokens.separator.opacity(0.12))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }

                dashboardTrendPath(values: cpu, in: size)
                    .fill(AppSurfaceTokens.accentBlue.opacity(0.08))
                dashboardTrendPath(values: memory, in: size)
                    .fill(AppSurfaceTokens.accentPrimary.opacity(0.06))
                dashboardTrendPath(values: network, in: size)
                    .fill(AppSurfaceTokens.accentGreen.opacity(0.05))

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

    var lastUpdatedText: String {
        guard snapshot.lastUpdated != .distantPast else { return "等待刷新" }
        return Self.timeFormatter.string(from: snapshot.lastUpdated)
    }

    var refreshHint: String {
        snapshot.lastUpdated == .distantPast ? "未刷新" : "已刷新"
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

    var hasDiskIO: Bool {
        snapshot.diskReadMBps != nil || snapshot.diskWriteMBps != nil
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

    var diskSummary: String {
        snapshot.diskUsagePercent > 0 ? String(format: "%.0f%%", snapshot.diskUsagePercent) : "—"
    }

    var diskDetailSummary: String {
        "\(formatGB(snapshot.diskUsedGB)) / \(formatGB(snapshot.diskTotalGB))"
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

    var networkInterfaceSummary: String {
        snapshot.networkInterfaces.first?.interfaceName ?? "—"
    }

    var primaryInterfaceSummary: String {
        snapshot.networkInterfaces.first(where: { $0.name == "主接口" })?.interfaceName ?? "—"
    }

    var primaryInterfaceDetail: String {
        snapshot.networkInterfaces.first(where: { $0.name == "主接口" })?.isVPN == true ? "VPN / scoped" : "SCDynamicStore"
    }

    var wifiSummary: String {
        snapshot.networkInterfaces.first(where: { $0.ssid != nil })?.ssid ?? "—"
    }

    var wifiDetail: String {
        guard let wifi = snapshot.networkInterfaces.first(where: { $0.ssid != nil }) else { return "—" }
        var parts: [String] = []
        if let rssi = wifi.rssi { parts.append("RSSI \(rssi)") }
        if let transmit = wifi.transmitRateMbps { parts.append("\(String(format: "%.0f", transmit)) Mbps") }
        if let channel = wifi.channel { parts.append(channel) }
        return parts.isEmpty ? "已连接" : parts.joined(separator: " · ")
    }

    var batterySummary: String {
        guard let battery = snapshot.battery, battery.isAvailable else { return "—" }
        if let percentage = battery.percentage {
            return String(format: "%.0f%%", percentage)
        }
        return "—"
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
        let automaticCount = snapshot.fanSensors.filter { $0.isAutomatic == true }.count
        if automaticCount == snapshot.fanSensors.count {
            return "\(snapshot.fanSensors.count) 个风扇 · 自动"
        }
        return "\(snapshot.fanSensors.count) 个风扇 · 只读"
    }

    var permissionFooterSummary: String {
        SystemStatusLabelFormatter.permissionOverviewSummary(snapshot.permissions)
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
