import SwiftUI
import AcMindKit

private enum DashboardRadius {
    static let hero: CGFloat = 26
    static let card: CGFloat = 24
    static let block: CGFloat = 18
    static let icon: CGFloat = 16
    static let control: CGFloat = 18
}

struct WorkspaceHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SystemStatusViewModel(service: .shared)

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
            VStack(alignment: .leading, spacing: 12) {
                topBar
                heroPanel
                kpiRow
                overviewRow
                infoRow
                sensorRow
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: 1360, alignment: .leading)
        }
        .background(background)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color(NSColor.windowBackgroundColor).opacity(0.95),
                Color(NSColor.controlBackgroundColor).opacity(0.78)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("首页")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(viewModel.lastUpdatedText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer(minLength: 0)

            topActionButton(title: "说入法", icon: "mic.fill", tint: AppSurfaceTokens.accentBlue) {
                NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
            }

            topActionButton(title: "采集", icon: "camera.viewfinder", tint: AppSurfaceTokens.accentOrange) {
                NotificationCenter.default.post(name: .companionShowCapturePanel, object: nil)
            }

            topSearchField

            topIconButton(icon: "ellipsis", action: nil)
        }
    }

    private var topSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text("搜索与命令")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
        }
        .frame(width: 210, height: 38)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
    }

    private var heroPanel: some View {
        DashboardCard(padding: 14) {
            HStack(alignment: .center, spacing: 16) {
                heroGlyph

                VStack(alignment: .leading, spacing: 8) {
                    Text("本机状态总览")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        statusPill(icon: "checkmark.circle.fill", title: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor)
                        statusPill(icon: "macwindow", title: windowStateText(appState.mainWindowState), tint: AppSurfaceTokens.accentPrimary)
                        statusPill(icon: "sparkles", title: appState.isAppReady ? "已就绪" : "初始化中", tint: appState.isAppReady ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(viewModel.refreshHint)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text("真实读数")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
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
                .frame(width: 60, height: 60)

            Image(systemName: "cpu.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
    }

    private var kpiRow: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
            spacing: 12
        ) {
            dashboardMetric(
                title: "CPU",
                icon: "cpu",
                value: viewModel.cpuSummary,
                detail: viewModel.loadAverageSummary,
                tint: AppSurfaceTokens.accentBlue
            ) {
                MiniSparkline(values: historyOrCurrent(viewModel.cpuHistory, current: viewModel.snapshot.cpu?.value), tint: AppSurfaceTokens.accentBlue)
            }

            dashboardMetric(
                title: "内存",
                icon: "memorychip",
                value: viewModel.memorySummary,
                detail: viewModel.memoryUsagePercentSummary,
                tint: AppSurfaceTokens.accentPrimary
            ) {
                MiniSparkline(values: historyOrCurrent(viewModel.memoryHistory, current: viewModel.snapshot.memoryUsagePercent), tint: AppSurfaceTokens.accentPrimary)
            }

            dashboardMetric(
                title: "网络",
                icon: "network",
                value: viewModel.networkSummary,
                detail: viewModel.networkInterfaceSummary,
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
                detail: viewModel.batteryStateSummary,
                tint: AppSurfaceTokens.accentCyan
            ) {
                RingGauge(percentage: viewModel.snapshot.battery?.percentage, tint: AppSurfaceTokens.accentCyan)
            }

            dashboardMetric(
                title: "磁盘",
                icon: "internaldrive",
                value: viewModel.diskSummary,
                detail: viewModel.diskDetailSummary,
                tint: AppSurfaceTokens.accentOrange
            ) {
                MiniSparkline(values: historyOrCurrent(viewModel.diskHistory, current: viewModel.snapshot.diskUsagePercent), tint: AppSurfaceTokens.accentOrange)
            }
        }
    }

    private var overviewRow: some View {
        HStack(alignment: .top, spacing: 12) {
            DashboardCard(title: "实时曲线", subtitle: "CPU / 内存 / 网络") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        overviewMetric(label: "CPU", value: viewModel.cpuSummary, tint: AppSurfaceTokens.accentBlue)
                        overviewMetric(label: "内存", value: viewModel.memoryUsagePercentSummary, tint: AppSurfaceTokens.accentPrimary)
                        overviewMetric(label: "网络", value: viewModel.networkSummary, tint: AppSurfaceTokens.accentGreen)
                    }

                    MiniTrendStack(
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

                    HStack(spacing: 8) {
                        statusPill(icon: "clock", title: "刷新 \(viewModel.lastUpdatedText)", tint: AppSurfaceTokens.accentBlue)
                        statusPill(icon: "waveform.path.ecg", title: viewModel.samplingStatusText, tint: viewModel.samplingStatusColor)
                    }
                }
            }

            DashboardCard(title: "进程 Top 5", subtitle: "CPU / 内存") {
                VStack(alignment: .leading, spacing: 12) {
                    processBlock(title: "CPU", processes: viewModel.snapshot.topCPUProcesses, accent: AppSurfaceTokens.accentBlue)
                    processBlock(title: "内存", processes: viewModel.snapshot.topMemoryProcesses, accent: AppSurfaceTokens.accentPrimary)
                }
            }

            DashboardCard(title: "状态", subtitle: "窗口 / 启动 / 可用性") {
                VStack(alignment: .leading, spacing: 10) {
                    indicatorRow(title: "启动阶段", value: appState.initializationPhase.rawValue, accent: AppSurfaceTokens.accentBlue)
                    indicatorRow(title: "主窗口", value: windowStateText(appState.mainWindowState), accent: AppSurfaceTokens.accentGreen)
                    indicatorRow(title: "胶囊窗口", value: windowStateText(appState.capsuleWindowState), accent: AppSurfaceTokens.accentOrange)
                    indicatorRow(title: "可用性", value: appState.isAppReady ? "已就绪" : "等待初始化", accent: appState.isAppReady ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange)
                }
            }
        }
    }

    private var infoRow: some View {
        HStack(alignment: .top, spacing: 12) {
            DashboardCard(title: "网络", subtitle: "速率 / 接口 / Wi‑Fi") {
                infoGrid(columns: 2, items: [
                    InfoTile(label: "下载", value: viewModel.networkDownloadSummary, detail: "MB/s"),
                    InfoTile(label: "上传", value: viewModel.networkUploadSummary, detail: "MB/s"),
                    InfoTile(label: "主接口", value: viewModel.primaryInterfaceSummary, detail: viewModel.primaryInterfaceDetail),
                    InfoTile(label: "Wi‑Fi", value: viewModel.wifiSummary, detail: viewModel.wifiDetail)
                ])
            }

            DashboardCard(title: "电源", subtitle: "电量 / 循环 / 健康") {
                infoGrid(columns: 2, items: [
                    InfoTile(label: "电量", value: viewModel.batterySummary, detail: viewModel.batteryStateSummary),
                    InfoTile(label: "循环", value: viewModel.batteryCycleSummary, detail: "CycleCount"),
                    InfoTile(label: "容量", value: viewModel.batteryCapacitySummary, detail: viewModel.batteryCapacityDetail),
                    InfoTile(label: "健康", value: viewModel.batteryHealthSummary, detail: viewModel.batteryHealthDetail)
                ])
            }

            DashboardCard(title: "权限", subtitle: "缺失即提示") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.snapshot.permissions.prefix(4)) { permission in
                        permissionRow(permission)
                    }

                    if let firstReason = viewModel.snapshot.unavailableReasons.first {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(firstReason.message)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                                .lineLimit(2)
                            Text([firstReason.category, firstReason.detail].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 10))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
                    }
                }
            }
        }
    }

    private var sensorRow: some View {
        HStack(alignment: .top, spacing: 12) {
            DashboardCard(title: "设备温度", subtitle: temperatureStatusText) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 18) {
                        metricGlyph(systemName: "thermometer.medium", tint: AppSurfaceTokens.accentOrange)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(temperaturePrimaryText)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text(temperatureSecondaryText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }

                        Spacer(minLength: 0)

                        MiniSparkline(
                            values: historyOrCurrent(viewModel.temperatureHistory, current: currentTemperatureValue),
                            tint: AppSurfaceTokens.accentOrange
                        )
                        .frame(width: 156, height: 68)
                    }

                    statusStrip(
                        leading: viewModel.temperatureDetailSummary,
                        trailing: viewModel.snapshot.thermalState ?? "不可用"
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            }

            DashboardCard(title: "风扇转速", subtitle: fanStatusText) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 18) {
                        metricGlyph(systemName: "fanblades.fill", tint: AppSurfaceTokens.accentPrimary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(fanPrimaryText)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text(fanSecondaryText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }

                        Spacer(minLength: 0)

                        MiniSparkline(
                            values: historyOrCurrent(viewModel.fanHistory, current: currentFanValue),
                            tint: AppSurfaceTokens.accentPrimary
                        )
                        .frame(width: 156, height: 68)
                    }

                    fanSlider
                }
                .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            }

            DashboardCard(title: "快捷入口", subtitle: "常用操作") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(quickActions) { action in
                        Button {
                            action.perform(using: appState)
                        } label: {
                            actionButton(action)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            }
        }
    }

    private var fanSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.95))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(AppSurfaceTokens.accentSecondary.opacity(0.45))
                    .frame(width: 120, height: 6)

                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(AppSurfaceTokens.accentSecondary.opacity(0.55), lineWidth: 2))
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                    .offset(x: 112)
            }
            .frame(height: 20)

            Text("自动 · helper 后开放手动调节")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var currentTemperatureValue: Double? {
        viewModel.snapshot.temperatureSensors.first(where: { $0.value != nil })?.value ?? viewModel.snapshot.battery?.temperatureC
    }

    private var fanSummaryText: String {
        if let fan = viewModel.fanSensorSummaries.first {
            return fan.displayValue
        }
        return "读速率可以，手动调速要等 privileged helper"
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
        currentFanValue == nil ? "未接入" : "自动"
    }

    private var fanStatusText: String {
        currentFanValue == nil ? "只读预留" : "转速已读取"
    }

    private func metricGlyph(systemName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DashboardRadius.hero, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 56, height: 56)

            Image(systemName: systemName)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(tint)
        }
    }

    private func statusStrip(leading: String, trailing: String) -> some View {
        HStack(spacing: 10) {
            Text(leading)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(trailing)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func dashboardMetric<Accessory: View>(
        title: String,
        icon: String,
        value: String,
        detail: String,
        tint: Color,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        DashboardCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(tint)
                        )
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Text(value)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                }

                accessory()
                    .frame(height: 30)
            }
        }
    }

    private func overviewMetric(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(tint.opacity(0.25))
                .frame(width: 30, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func infoGrid(columns: Int, items: [InfoTile]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Text(item.value)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)
                    Text(item.detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
            }
        }
    }

    private func processBlock(title: String, processes: [SystemProcessSnapshot], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Spacer(minLength: 0)
                Text(processes.isEmpty ? "0" : "\(min(processes.count, 5))")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.10))
                    .clipShape(Capsule(style: .continuous))
            }

            if processes.isEmpty {
                Text("暂无进程排行")
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            } else {
                ForEach(processes.prefix(5)) { process in
                    HStack(spacing: 8) {
                        Text(process.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(String(format: "%.0f%%", process.cpuUsage))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Text(String(format: "%.0f MB", process.memoryUsageMB))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.84))
                    .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func indicatorRow(title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous))
    }

    private func statusPill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.12)))
        .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.18), lineWidth: 1))
    }

    private func topActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(AppSurfaceTokens.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func topIconButton(icon: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackground.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DashboardRadius.control, style: .continuous)
                        .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ action: HomeAction) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous)
                    .fill(action.tint.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: action.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(action.tint)
            }

            Text(action.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.block, style: .continuous))
    }

    private func sensorList<T>(_ items: [T], placeholder: String) -> some View where T: SensorDisplayRow {
        VStack(alignment: .leading, spacing: 8) {
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
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(item.displaySource)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer(minLength: 0)
            Text(item.displayValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            if item.isUnavailable {
                Text("不可用")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(item.isUnavailable ? Color.orange.opacity(0.08) : AppSurfaceTokens.cardBackgroundSoft.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: DashboardRadius.icon, style: .continuous))
    }

    private func permissionRow(_ item: SystemPermissionSnapshot) -> some View {
        HStack {
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Spacer(minLength: 0)
            Text(item.value ?? "不可用")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            if item.isAvailable == false, let reason = item.unavailableReason {
                Text(reason)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.82))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
    @ViewBuilder let content: Content

    init(title: String? = nil, subtitle: String? = nil, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11.5, weight: .medium))
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
                .fill(AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardRadius.card, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

private struct InfoTile: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let detail: String
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
                Text("Battery")
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

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
