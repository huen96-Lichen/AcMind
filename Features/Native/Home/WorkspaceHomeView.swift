import SwiftUI
import AcMindKit

private enum DashboardRadius {
    static let hero: CGFloat = 30
    static let card: CGFloat = 30
    static let block: CGFloat = 22
    static let icon: CGFloat = 18
    static let control: CGFloat = 22
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
                    .fill(
                        LinearGradient(
                            colors: [
                                AppSurfaceTokens.accentBlue.opacity(0.06),
                                AppSurfaceTokens.accentGreen.opacity(0.015),
                                Color.clear,
                                AppSurfaceTokens.accentPrimary.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(AppSurfaceTokens.separator.opacity(0.14))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }

                fillPath(values: cpu, in: size)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppSurfaceTokens.accentBlue.opacity(0.14),
                                AppSurfaceTokens.accentBlue.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

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
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppSurfaceTokens.accentBlue.opacity(0.11),
                            AppSurfaceTokens.accentPrimary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
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
    @StateObject private var viewModel: SystemStatusViewModel

    init(systemStatusService: SystemStatusService) {
        _viewModel = StateObject(wrappedValue: SystemStatusViewModel(service: systemStatusService))
    }

    private var quickActions: [HomeAction] {
        [
            HomeAction(title: "说入法", icon: "mic.fill", tint: AppSurfaceTokens.accentBlue, kind: .voice),
            HomeAction(title: "采集", icon: "camera.viewfinder", tint: AppSurfaceTokens.accentOrange, kind: .capture),
            HomeAction(title: "收集箱", icon: "tray.full", tint: AppSurfaceTokens.accentGreen, kind: .inbox),
            HomeAction(title: "设置", icon: "gearshape.fill", tint: AppSurfaceTokens.accentPrimary, kind: .settings)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1.5) {
                greetingHeader
                kpiRow
                overviewRow
                infoRow
                sensorRow
                summaryFooter
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .frame(maxWidth: AppSurfaceTokens.Layout.pageMaxWidth, alignment: .leading)
        }
        .background(background)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                AppSurfaceTokens.background,
                Color(NSColor.windowBackgroundColor).opacity(0.95),
                Color(NSColor.controlBackgroundColor).opacity(0.78)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var greetingHeader: some View {
        HStack(alignment: .top, spacing: 5.5) {
            VStack(alignment: .leading, spacing: 0.5) {
                Text(greetingText)
                    .font(.system(size: 17.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text("保持高效创作")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 3) {
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
    }

    private var topSearchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text("搜索与命令")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
        }
        .frame(width: 128, height: 23.5)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppSurfaceTokens.background.opacity(0.94),
                            AppSurfaceTokens.cardBackground.opacity(0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
                    Text("本机状态总览")
                        .font(.system(size: 17.5, weight: .semibold))
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
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text("真实读数")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "上午好，AcMind"
        case 12..<18:
            return "下午好，AcMind"
        default:
            return "晚上好，AcMind"
        }
    }

    private var heroGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DashboardRadius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppSurfaceTokens.accentBlue.opacity(0.20),
                            AppSurfaceTokens.accentPrimary.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
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
                title: "CPU",
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
    }

    private var overviewRow: some View {
        HStack(alignment: .top, spacing: 3.5) {
            DashboardCard(title: "系统状态总览", subtitle: nil, style: .prominent) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        overviewMetric(label: "CPU", value: viewModel.cpuSummary, tint: AppSurfaceTokens.accentBlue)
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
                        trendLegend(title: "CPU", tint: AppSurfaceTokens.accentBlue)
                        trendLegend(title: "内存", tint: AppSurfaceTokens.accentPrimary)
                        trendLegend(title: "网络", tint: AppSurfaceTokens.accentGreen)
                        Spacer(minLength: 0)
                        statusPill(icon: "clock.arrow.circlepath", title: "近 60 秒", tint: AppSurfaceTokens.accentBlue)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
            }
            .layoutPriority(2)

            DashboardCard(title: "进程占用 Top 5", subtitle: nil, style: .regular) {
                HStack(alignment: .center, spacing: 6) {
                    ProcessDonutChart(
                        segments: cpuProcessSegments,
                        totalLabel: viewModel.cpuSummary,
                        subtitle: "CPU 占用"
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

            DashboardCard(title: "状态指示", subtitle: nil, style: .subtle) {
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
                            LinearGradient(
                                colors: [
                                    AppSurfaceTokens.accentOrange.opacity(0.08),
                                    AppSurfaceTokens.cardBackgroundSoft.opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
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
                        compactStatusChip(viewModel.snapshot.thermalState ?? "不可用", tint: AppSurfaceTokens.accentOrange)
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

    private var summaryFooter: some View {
        DashboardCard(padding: 1.5, style: .subtle) {
            HStack(spacing: 1.5) {
                summaryChip(icon: "cpu", title: "CPU", value: viewModel.cpuSummary, tint: AppSurfaceTokens.accentBlue)
                summaryChip(icon: "memorychip", title: "内存", value: viewModel.memorySummary, tint: AppSurfaceTokens.accentPrimary)
                summaryChip(icon: "internaldrive", title: "磁盘", value: viewModel.diskSummary, tint: AppSurfaceTokens.accentOrange)
                summaryChip(icon: "network", title: "网络", value: viewModel.networkSummary, tint: AppSurfaceTokens.accentGreen)
                summaryChip(icon: "powerplug", title: "电源", value: viewModel.batteryStateSummary, tint: AppSurfaceTokens.accentCyan)
                summaryChip(icon: "checkmark.shield", title: "权限", value: permissionFooterText, tint: AppSurfaceTokens.accentGreen)
            }
        }
    }

    private var permissionFooterText: String {
        let unavailableCount = viewModel.snapshot.permissions.filter { $0.isAvailable == false }.count
        if unavailableCount == 0 { return "正常" }
        return "\(unavailableCount) 项待确认"
    }

    private var fanStatusNote: some View {
        HStack(spacing: 5) {
            compactStatusChip(
                currentFanValue == nil ? "只读" : "已接入",
                tint: currentFanValue == nil ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.accentPrimary
            )

            if currentFanValue == nil {
                compactStatusChip("不可控", tint: AppSurfaceTokens.accentOrange)
            } else {
                compactStatusChip("无调速", tint: AppSurfaceTokens.accentPrimary)
            }

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
                ProcessSegment(name: "暂无数据", ratio: 1, displayValue: "0%", color: AppSurfaceTokens.accentSecondary.opacity(0.35))
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
                value: currentTemperatureValue == nil ? "不可用" : "正常",
                accent: currentTemperatureValue == nil ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.accentGreen
            ),
            WorkspaceStatusBadge(
                icon: "network",
                title: "网络",
                value: viewModel.primaryInterfaceSummary == "不可用" ? "异常" : "在线",
                accent: viewModel.primaryInterfaceSummary == "不可用" ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.accentGreen
            ),
            WorkspaceStatusBadge(
                icon: "internaldrive",
                title: "磁盘",
                value: viewModel.diskSummary == "不可用" ? "异常" : "正常",
                accent: viewModel.diskSummary == "不可用" ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.accentBlue
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
                accent: permissionFooterText == "正常" ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange
            )
        ]
    }

    private var batteryBadgeValue: String {
        if viewModel.batterySummary == "无可用电池" || viewModel.batterySummary == "不可用" {
            return "无"
        }
        if viewModel.batteryHealthSummary == "不可用" {
            return "未知"
        }
        return "良好"
    }

    private var batteryBadgeAccent: Color {
        batteryBadgeValue == "良好" ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange
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
        viewModel.networkInterfaceSummary == "不可用" ? "接口不可用" : viewModel.networkInterfaceSummary
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
        return "风扇读数不可用"
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
            return viewModel.snapshot.thermalState ?? "正常"
        }
        return "无可读传感器"
    }

    private var temperatureStatusText: String {
        currentTemperatureValue == nil ? "不可用" : "热状态"
    }

    private var fanPrimaryText: String {
        if let value = currentFanValue {
            return String(format: "%.0f RPM", value)
        }
        return "-- RPM"
    }

    private var fanSecondaryText: String {
        currentFanValue == nil ? "风扇读数不可用" : "仅展示读数"
    }

    private var fanStatusText: String {
        currentFanValue == nil ? "风扇读数不可用" : "风扇读数已接入"
    }

    private func metricGlyph(systemName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DashboardRadius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.14), tint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
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
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.14), tint.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 19.5, height: 19.5)
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
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.55)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
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
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.10),
                            AppSurfaceTokens.cardBackgroundSoft.opacity(0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
                        .fill(item.tint.opacity(0.32))
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
                .background(
                    LinearGradient(
                        colors: [
                            item.tint.opacity(0.08),
                            AppSurfaceTokens.cardBackgroundSoft.opacity(0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
                            .fill(
                                LinearGradient(
                                    colors: [segment.color.opacity(0.9), segment.color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(proxy.size.width * segment.ratio, 8))
                    }
                }
        }
    }

    private func indicatorTile(_ badge: WorkspaceStatusBadge) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4.5) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [badge.accent.opacity(0.16), badge.accent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
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
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(badge.accent.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func statusLineRow(_ badge: WorkspaceStatusBadge) -> some View {
        HStack(spacing: 4.5) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [badge.accent.opacity(0.16), badge.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 19, height: 19)
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
                .fill(
                    LinearGradient(
                        colors: [
                            badge.accent.opacity(0.05),
                            AppSurfaceTokens.cardBackgroundSoft.opacity(0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(badge.accent.opacity(0.08), lineWidth: 1)
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
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.14), tint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.10), lineWidth: 1)
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
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.08),
                            AppSurfaceTokens.cardBackgroundSoft.opacity(0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.08), lineWidth: 1)
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
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.14), tint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.14), lineWidth: 1))
    }

    private func topActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3.5) {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 8.75, weight: .semibold))
            }
            .foregroundStyle(AppSurfaceTokens.primaryText)
            .padding(.horizontal, 7)
            .frame(height: 24.5)
            .background(
                RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.14), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
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
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppSurfaceTokens.background.opacity(0.92),
                                    AppSurfaceTokens.cardBackground.opacity(0.84)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                        .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ action: HomeAction) -> some View {
        VStack(spacing: 2.5) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [action.tint.opacity(0.16), action.tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                Image(systemName: action.icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(action.tint)
            }

            Text(action.title)
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .padding(.vertical, 2.25)
        .frame(maxWidth: .infinity, minHeight: 28)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            action.tint.opacity(0.08),
                            AppSurfaceTokens.cardBackgroundSoft.opacity(0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                .stroke(action.tint.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func sensorList<T>(_ items: [T], placeholder: String) -> some View where T: SensorDisplayRow {
        VStack(alignment: .leading, spacing: 6.5) {
            if items.isEmpty {
                Text(placeholder)
                    .font(.system(size: 11))
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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(item.displaySource)
                    .font(.system(size: 9))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer(minLength: 0)
            Text(item.displayValue)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            if item.isUnavailable {
                Text("不可用")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4.25)
        .background(
            LinearGradient(
                colors: [
                    item.isUnavailable ? AppSurfaceTokens.accentOrange.opacity(0.08) : AppSurfaceTokens.accentBlue.opacity(0.05),
                    AppSurfaceTokens.cardBackgroundSoft.opacity(0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous))
    }

    private func permissionRow(_ item: SystemPermissionSnapshot) -> some View {
        let tint = item.isAvailable == false ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.accentGreen

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4.5) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.16), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 18, height: 18)
                    .overlay {
                        Image(systemName: item.isAvailable == false ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                            .font(.system(size: 7.5, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                Spacer(minLength: 0)
                Circle()
                    .fill(tint)
                    .frame(width: 4, height: 4)
            }
            Text(item.name)
                .font(.system(size: 8.75, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
            Text(item.value ?? "不可用")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            if item.isAvailable == false, let reason = item.unavailableReason {
                Text(reason)
                    .font(.system(size: 7.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6.75)
        .padding(.vertical, 4.5)
        .background(
            LinearGradient(
                colors: [
                    tint.opacity(0.08),
                    AppSurfaceTokens.cardBackgroundSoft.opacity(0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous))
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
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.82))
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
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        AppSurfaceTokens.background.opacity(0.98),
                        AppSurfaceTokens.cardBackground,
                        AppSurfaceTokens.cardBackgroundSoft.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .prominent:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        AppSurfaceTokens.background,
                        AppSurfaceTokens.accentBlue.opacity(0.04),
                        AppSurfaceTokens.cardBackground,
                        AppSurfaceTokens.cardBackgroundSoft.opacity(0.64)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .subtle:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        AppSurfaceTokens.background.opacity(0.76),
                        AppSurfaceTokens.cardBackgroundSoft.opacity(0.74)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var cardStroke: Color {
        switch style {
        case .regular:
            return AppSurfaceTokens.separator.opacity(0.62)
        case .prominent:
            return AppSurfaceTokens.accentBlue.opacity(0.18)
        case .subtle:
            return AppSurfaceTokens.separator.opacity(0.42)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .regular:
            return .black.opacity(0.026)
        case .prominent:
            return AppSurfaceTokens.accentBlue.opacity(0.075)
        case .subtle:
            return .black.opacity(0.012)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .regular: return 9
        case .prominent: return 13
        case .subtle: return 6
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .regular: return 3
        case .prominent: return 5
        case .subtle: return 2
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

        @MainActor
        func perform(using appState: AppState) {
            switch self {
            case .voice:
                NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
            case .capture:
                NotificationCenter.default.post(name: .companionShowCapturePanel, object: nil)
            case .inbox:
                appState.selectSidebarItem(.inbox)
            case .settings:
                appState.selectSidebarItem(.settings)
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
            trendRow(title: "CPU", values: cpu, tint: AppSurfaceTokens.accentBlue)
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
                .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.62))
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
                .stroke(AppSurfaceTokens.cardBackgroundSoft.opacity(0.95), lineWidth: 7)
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
                    LinearGradient(
                        colors: [
                            AppSurfaceTokens.separator.opacity(0.10),
                            AppSurfaceTokens.separator.opacity(0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                Circle()
                    .trim(from: startTrim(for: index), to: endTrim(for: index))
                    .stroke(
                        LinearGradient(
                            colors: [segment.color.opacity(0.82), segment.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppSurfaceTokens.accentBlue.opacity(0.045),
                            AppSurfaceTokens.background.opacity(0.96),
                            AppSurfaceTokens.cardBackground.opacity(0.92),
                            AppSurfaceTokens.cardBackgroundSoft.opacity(0.68)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 34
                    )
                )
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
