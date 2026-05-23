import SwiftUI
import AcMindKit

struct DynamicContinentSystemMonitorPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    private var snapshot: SystemMonitorSnapshot? {
        viewModel.systemMonitorSnapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerBand

            HStack(alignment: .top, spacing: NotchV2DesignTokens.columnGap) {
                summaryCard
                    .frame(width: 160, height: 318, alignment: .topLeading)

                metricsCard
                    .frame(width: 396, height: 318, alignment: .topLeading)

                processesCard
                    .frame(width: 180, height: 318, alignment: .topLeading)
            }
        }
        .padding(.horizontal, NotchV2DesignTokens.pagePadding)
        .padding(.top, NotchV2DesignTokens.contentTopGap)
        .padding(.bottom, NotchV2DesignTokens.contentBottomGap)
        .frame(width: NotchV2DesignTokens.expandedWidth, height: NotchV2DesignTokens.expandedSystemMonitorHeight, alignment: .topLeading)
    }

    private var headerBand: some View {
        HStack(alignment: .center, spacing: 12) {
            NotchSectionHeader("状态", subtitle: "CPU / 内存 / 网络 / 存储 / 电池 / 开机时长")

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                NotchV2StatusPill(
                    icon: "cpu",
                    title: snapshot?.health.title ?? "正在采样",
                    accent: statusTint
                )

                NotchV2StatusPill(
                    icon: "wifi",
                    title: snapshot?.network.activeInterfaceName ?? "网络",
                    accent: NotchV2DesignTokens.cardBackgroundStrong
                )
            }
        }
        .frame(height: 28)
    }

    private var summaryCard: some View {
        NotchV2Card(title: "本机总览", subtitle: "系统健康与解释", symbol: "cpu", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot?.health.title ?? "系统监控")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(2)

                    Text(snapshot?.health.message ?? "正在采样系统状态。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(4)
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator)

                VStack(alignment: .leading, spacing: 8) {
                    summaryRow(title: "CPU", value: formatPercent(snapshot?.cpu.usagePercent), detail: "负载 \(formatLoad(snapshot?.cpu.loadAverage1m))")
                    summaryRow(title: "内存", value: formatPercent(memoryUsagePercent), detail: "压力 \(memoryPressureLabel)")
                    summaryRow(title: "存储", value: formatPercent(snapshot?.storage.usedPercent), detail: "已用 \(formatStorage(snapshot?.storage.freeBytes))")
                    summaryRow(title: "电池", value: batteryLabel, detail: batteryDetail)
                }

                Spacer(minLength: 0)

                NotchV2StatusPill(
                    icon: "timer",
                    title: "开机 \(formatUptime(snapshot?.uptime ?? 0))",
                    accent: NotchV2DesignTokens.cardBackgroundStrong
                )
            }
        }
    }

    private var metricsCard: some View {
        NotchV2Card(title: "核心指标", subtitle: "实时采样", symbol: "chart.bar", padding: 16, fillHeight: true) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                metricTile(title: "CPU", value: formatPercent(snapshot?.cpu.usagePercent), subtitle: "1m \(formatLoad(snapshot?.cpu.loadAverage1m))")
                metricTile(title: "内存", value: memoryUsageText, subtitle: "压力 \(memoryPressureLabel)")
                metricTile(title: "网络", value: networkText, subtitle: networkInterfaceText)
                metricTile(title: "存储", value: formatPercent(snapshot?.storage.usedPercent), subtitle: formatStorage(snapshot?.storage.freeBytes))
                metricTile(title: "电池", value: batteryLabel, subtitle: batteryDetail)
                metricTile(title: "开机", value: formatUptime(snapshot?.uptime ?? 0), subtitle: "系统时长")
            }

            Spacer(minLength: 0)

            if let warnings = snapshot?.health.warnings, warnings.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text("关注项")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.tertiaryText)
                    ForEach(warnings.prefix(2), id: \.self) { warning in
                        NotchV2StatusLine(title: warning)
                    }
                }
            } else {
                Text("当前没有明显异常。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
            }
        }
    }

    private var processesCard: some View {
        NotchV2Card(title: "Top CPU", subtitle: "占用进程", symbol: "list.bullet.rectangle", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 8) {
                if topProcesses.isEmpty == false {
                    ForEach(topProcesses) { process in
                        processRow(process)
                    }
                } else {
                    Text("暂无进程信息。")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }

                Spacer(minLength: 0)

                NotchV2StatusPill(
                    icon: "waveform.path.ecg",
                    title: snapshot?.health.level == .highLoad ? "建议检查后台任务" : "运行正常",
                    accent: statusTint.opacity(0.18)
                )
            }
        }
    }

    private var statusTint: Color {
        guard let level = snapshot?.health.level else {
            return NotchV2DesignTokens.secondaryText
        }
        switch level {
        case .good:
            return NotchV2DesignTokens.accentGreen
        case .attention:
            return Color(red: 1.0, green: 0.78, blue: 0.24)
        case .highLoad:
            return Color(red: 1.0, green: 0.38, blue: 0.33)
        case .unknown:
            return NotchV2DesignTokens.secondaryText
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
        guard let battery = snapshot?.battery else { return "台式机或未检测到电池" }
        if battery.isPluggedIn {
            return battery.isCharging ? "外接电源 · 充电中" : "外接电源"
        }
        if let minutes = battery.timeRemainingMinutes {
            return "剩余 \(minutes) 分钟"
        }
        return "正在放电"
    }

    private var topProcesses: [ProcessStats] {
        snapshot?.topProcesses.prefix(5).map { $0 } ?? []
    }

    private func summaryRow(title: String, value: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .frame(width: 34, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(NotchV2DesignTokens.primaryText)

            Spacer(minLength: 0)

            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.tertiaryText)
        }
    }

    private func metricTile(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.tertiaryText)

            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(NotchV2DesignTokens.innerCardBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NotchV2DesignTokens.innerBorder.opacity(0.45), lineWidth: 1)
        )
    }

    private func processRow(_ process: ProcessStats) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(process.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(formatPercent(process.cpuPercent))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(NotchV2DesignTokens.innerCardBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value)
    }

    private func formatLoad(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
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
