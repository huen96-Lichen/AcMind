import SwiftUI
import AcMindKit

struct SystemStatusPage: View {
    @ObservedObject var systemMonitorService: SystemMonitorService

    var body: some View {
        ACSecondaryPageShell(
            header: {
                ACPageHeader(
                    title: "本机状态",
                    subtitle: "查看当前 Mac 的负载、网络、存储、电池与运行状态。"
                ) {
                    ACBadge(healthLabel, kind: healthBadgeKind)
                }
            },
            content: { _ in
                VStack(alignment: .leading, spacing: 12) {
                    healthSummaryCard
                    monitorTableCard
                    phase2Card
                    topProcessesCard
                    explanationCard
                }
                .frame(maxWidth: ACLayout.secondaryPageContentMaxWidth, alignment: .leading)
                .padding(.vertical, 4)
            }
        )
        .onAppear {
            systemMonitorService.setCadence(.expanded)
            if systemMonitorService.snapshot == nil {
                systemMonitorService.refreshOnce()
            }
        }
        .onDisappear {
            systemMonitorService.setCadence(.collapsed)
        }
    }

    private var snapshot: SystemMonitorSnapshot? {
        systemMonitorService.snapshot
    }

    private var healthLabel: String {
        snapshot?.health.title ?? "正在采样"
    }

    private var healthBadgeKind: ACBadge.Kind {
        switch snapshot?.health.level {
        case .good:
            return .green
        case .attention:
            return .orange
        case .highLoad:
            return .red
        case .unknown, nil:
            return .neutral
        }
    }

    private var healthSummaryCard: some View {
        ACCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot?.health.title ?? "系统状态")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ACColors.primaryText)

                        Text(snapshot?.health.message ?? "正在采样系统状态，请稍候。")
                            .font(ACTypography.body)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        ACBadge(formatUptime(snapshot?.uptime ?? 0), kind: .neutral)
                        Text(snapshot?.health.warnings.first ?? "实时监控")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ACColors.secondaryText)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 10) {
                    statusPill(title: "CPU \(formatPercent(snapshot?.cpu.usagePercent))", subtitle: "1m \(formatLoad(snapshot?.cpu.loadAverage1m))")
                    statusPill(title: "内存 \(formatPercent(memoryUsagePercent))", subtitle: memoryPressureLabel)
                    statusPill(title: "存储 \(formatPercent(snapshot?.storage.usedPercent))", subtitle: formatStorage(snapshot?.storage.freeBytes))
                }
            }
        }
    }

    private var monitorTableCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow(title: "实时监控", subtitle: "任务管理器式总览")

                VStack(spacing: 0) {
                    detailRow(title: "CPU", value: formatPercent(snapshot?.cpu.usagePercent), detail: "负载 \(formatLoad(snapshot?.cpu.loadAverage1m))")
                    detailRow(title: "内存", value: memoryUsageText, detail: "压力 \(memoryPressureLabel)")
                    detailRow(title: "网络", value: networkText, detail: networkInterfaceText)
                    detailRow(title: "硬盘", value: formatPercent(snapshot?.storage.usedPercent), detail: "可用 \(formatStorage(snapshot?.storage.freeBytes))")
                    detailRow(title: "电池", value: batteryLabel, detail: batteryDetail)
                    detailRow(title: "开机", value: formatUptime(snapshot?.uptime ?? 0), detail: "系统运行时长")
                }
            }
        }
    }

    private var phase2Card: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow(title: "Phase 2 接口", subtitle: "温度 / 风扇 / 功耗 / GPU")

                VStack(spacing: 0) {
                    detailRow(title: "温度", value: phase2TemperatureValue, detail: phase2TemperatureDetail, valueColor: phase2TemperatureColor)
                    detailRow(title: "风扇", value: phase2FanValue, detail: phase2FanDetail, valueColor: phase2FanColor)
                    detailRow(title: "功耗", value: phase2PowerValue, detail: phase2PowerDetail, valueColor: phase2PowerColor)
                    detailRow(title: "GPU", value: phase2GpuValue, detail: phase2GpuDetail, valueColor: phase2GpuColor)
                }
            }
        }
    }

    private var topProcessesCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow(title: "Top CPU 进程", subtitle: "最多显示 5 个")

                if let processes = snapshot?.topProcesses, processes.isEmpty == false {
                    let maxCPU = max(processes.prefix(5).map(\.cpuPercent).max() ?? 1, 1)
                    VStack(spacing: 8) {
                        ForEach(processes.prefix(5)) { process in
                            processRow(process, maxCPU: maxCPU)
                        }
                    }
                } else {
                    Text("暂无进程采样数据。")
                        .font(ACTypography.body)
                        .foregroundStyle(ACColors.secondaryText)
                }
            }
        }
    }

    private var explanationCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                headerRow(title: "状态说明", subtitle: "先用规则解释当前情况")

                Text(explanationText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ACColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var explanationText: String {
        guard let snapshot else {
            return "正在采样系统状态，稍后会根据 CPU、内存、网络、存储和电池状态给出解释。"
        }

        switch snapshot.health.level {
        case .good:
            return "你的 Mac 当前状态良好。CPU 和内存压力都较低，适合继续进行轻量开发或文档整理。"
        case .attention:
            return "你的 Mac 现在需要留意。建议先观察内存压力、温度、磁盘空间或电池状态，再决定是否继续开启更多任务。"
        case .highLoad:
            return "你的 Mac 当前负载偏高。建议先暂停大任务、检查占用最高的进程，并尽量释放内存或连接电源。"
        case .unknown:
            return "暂时还没有足够的采样数据，系统状态会在几秒内逐渐稳定。"
        }
    }

    private var memoryUsagePercent: Double {
        guard let memory = snapshot?.memory, memory.totalBytes > 0 else { return 0 }
        return Double(memory.usedBytes) / Double(memory.totalBytes) * 100
    }

    private var memoryUsageText: String {
        guard let memory = snapshot?.memory else { return "—" }
        return "\(formatStorage(memory.usedBytes)) / \(formatStorage(memory.totalBytes))"
    }

    private var memoryPressureLabel: String {
        guard let memory = snapshot?.memory else { return "未知" }
        switch memory.pressureLevel {
        case .low: return "低"
        case .moderate: return "中"
        case .high: return "高"
        case .unknown: return "未知"
        }
    }

    private var networkText: String {
        guard let network = snapshot?.network else { return "—" }
        return "↓ \(formatRate(network.downloadBytesPerSecond)) ↑ \(formatRate(network.uploadBytesPerSecond))"
    }

    private var networkInterfaceText: String {
        snapshot?.network.activeInterfaceName ?? "接口未识别"
    }

    private var batteryLabel: String {
        guard let battery = snapshot?.battery else { return "无" }
        return formatPercent(battery.percentage)
    }

    private var batteryDetail: String {
        guard let battery = snapshot?.battery else { return "未检测到电池" }
        if battery.isPluggedIn {
            return battery.isCharging ? "外接电源 · 充电中" : "外接电源"
        }
        if let minutes = battery.timeRemainingMinutes {
            return "剩余 \(minutes) 分钟"
        }
        return "正在放电"
    }

    private var phase2TemperatureValue: String {
        guard let thermal = snapshot?.thermal else { return "未接入" }
        let cpu = thermal.cpuTemperatureCelsius.map { formatTemperature($0) } ?? "—"
        let gpu = thermal.gpuTemperatureCelsius.map { formatTemperature($0) } ?? "—"
        return "CPU \(cpu) · GPU \(gpu)"
    }

    private var phase2TemperatureDetail: String {
        snapshot?.thermal.map { pressureText(for: $0.pressureLevel) } ?? "接口预留"
    }

    private var phase2TemperatureColor: Color {
        switch snapshot?.thermal?.pressureLevel {
        case .critical:
            return .red
        case .serious:
            return .orange
        case .fair:
            return .yellow
        case .nominal, .unknown, nil:
            return ACColors.primaryText
        }
    }

    private var phase2FanValue: String {
        guard let rpm = snapshot?.thermal?.fanSpeedRPM else { return "未接入" }
        return formatRPM(rpm)
    }

    private var phase2FanDetail: String {
        guard let thermal = snapshot?.thermal else { return "接口预留" }
        switch thermal.pressureLevel {
        case .critical:
            return "风扇已接近满速"
        case .serious:
            return "正在快速散热"
        case .fair:
            return "风扇轻微提高转速"
        case .nominal:
            return "转速正常"
        case .unknown:
            return "状态未知"
        }
    }

    private var phase2FanColor: Color {
        switch snapshot?.thermal?.pressureLevel {
        case .critical:
            return .red
        case .serious:
            return .orange
        case .fair:
            return .yellow
        case .nominal, .unknown, nil:
            return ACColors.primaryText
        }
    }

    private var phase2PowerValue: String {
        guard let watts = snapshot?.power?.consumptionWatts else { return "未接入" }
        return formatWatts(watts)
    }

    private var phase2PowerDetail: String {
        guard let watts = snapshot?.power?.consumptionWatts else { return "接口预留" }
        if watts >= 60 {
            return "功耗过高"
        }
        if watts >= 35 {
            return "功耗偏高"
        }
        return "功耗正常"
    }

    private var phase2PowerColor: Color {
        guard let watts = snapshot?.power?.consumptionWatts else { return ACColors.primaryText }
        if watts >= 60 { return .red }
        if watts >= 35 { return .orange }
        return ACColors.primaryText
    }

    private var phase2GpuValue: String {
        guard let gpu = snapshot?.gpu else { return "未接入" }
        let name = gpu.name ?? "GPU"
        let usage = gpu.usagePercent.map { formatPercent($0) } ?? "—"
        return "\(name) · \(usage)"
    }

    private var phase2GpuDetail: String {
        guard let gpu = snapshot?.gpu else { return "接口预留" }
        if let temperature = gpu.temperatureCelsius {
            return "温度 \(formatTemperature(temperature))"
        }
        return "暂无温度采样"
    }

    private var phase2GpuColor: Color {
        guard let gpu = snapshot?.gpu else { return ACColors.primaryText }
        if let usage = gpu.usagePercent, usage >= 95 {
            return .red
        }
        if let usage = gpu.usagePercent, usage >= 85 {
            return .orange
        }
        if let temperature = gpu.temperatureCelsius, temperature >= 92 {
            return .red
        }
        if let temperature = gpu.temperatureCelsius, temperature >= 82 {
            return .orange
        }
        return ACColors.primaryText
    }

    private func headerRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                Text(subtitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    private func detailRow(title: String, value: String, detail: String, valueColor: Color = ACColors.primaryText) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ACColors.secondaryText)
                    .frame(width: 58, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)

            Divider()
                .overlay(ACColors.divider)
        }
        .padding(.horizontal, 2)
    }

    private func statusPill(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ACColors.primaryText)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ACColors.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ACColors.selectedFill.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.cardRadius - 4, style: .continuous))
    }

    private func processRow(_ process: ProcessStats, maxCPU: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)

                    Text(process.memoryBytes.map { formatStorage($0) } ?? "—")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(formatPercent(process.cpuPercent))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ACColors.primaryText)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ACColors.selectedFill.opacity(0.55))
                    Capsule()
                        .fill(ACColors.accentBlue.opacity(0.55))
                        .frame(width: max(20, proxy.size.width * CGFloat(process.cpuPercent / maxCPU)))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ACColors.selectedFill.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func pressureText(for level: ThermalPressureLevel) -> String {
        switch level {
        case .critical:
            return "温度与风扇负载过高"
        case .serious:
            return "温度偏高"
        case .fair:
            return "温度轻微升高"
        case .nominal:
            return "温度正常"
        case .unknown:
            return "状态未知"
        }
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value)
    }

    private func formatLoad(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    private func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f°C", value)
    }

    private func formatRPM(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value) RPM"
    }

    private func formatWatts(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1fW", value)
    }

    private func formatStorage(_ bytes: UInt64?) -> String {
        guard let bytes else { return "—" }
        return formatStorage(bytes)
    }

    private func formatStorage(_ bytes: UInt64) -> String {
        switch bytes {
        case 0..<1_024:
            return "\(bytes)B"
        case 1_024..<1_048_576:
            return String(format: "%.0fKB", Double(bytes) / 1_024.0)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.1fMB", Double(bytes) / 1_048_576.0)
        default:
            return String(format: "%.1fGB", Double(bytes) / 1_073_741_824.0)
        }
    }

    private func formatRate(_ bytesPerSecond: UInt64) -> String {
        switch bytesPerSecond {
        case 0..<1_024:
            return "\(bytesPerSecond)B/s"
        case 1_024..<1_048_576:
            return String(format: "%.0fKB/s", Double(bytesPerSecond) / 1_024.0)
        default:
            return String(format: "%.1fMB/s", Double(bytesPerSecond) / 1_048_576.0)
        }
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "—" }
        let hours = Int(seconds) / 3_600
        let minutes = (Int(seconds) % 3_600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
