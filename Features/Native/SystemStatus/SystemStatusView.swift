import SwiftUI
import Combine
import AcMindKit

struct SystemStatusView: View {
    @StateObject private var viewModel = SystemStatusViewModel(service: .shared)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryStrip
                performanceSection
                networkSection
                batterySection
                sensorSection
                permissionsSection
                exceptionsSection
            }
            .padding(.horizontal, AppSurfaceTokens.Layout.pagePadding)
            .padding(.vertical, 24)
            .frame(maxWidth: AppSurfaceTokens.Layout.pageMaxWidth, alignment: .leading)
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var header: some View {
        AppSurfaceCard(title: "状态", subtitle: "主状态中心只展示真实可读的数据，读不到就明确写不可用。") {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        statusGlyph
                        VStack(alignment: .leading, spacing: 3) {
                            Text("状态中心")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text("CPU、内存、磁盘、网络、电池、权限、进程、传感器一次看全")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 8) {
                        statusPill(icon: "clock", title: viewModel.lastUpdatedText, accent: AppSurfaceTokens.cardBackgroundSoft)
                        statusPill(icon: "waveform.path.ecg", title: viewModel.samplingStatusText, accent: viewModel.samplingStatusColor.opacity(0.16))
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(viewModel.samplingStatusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(viewModel.samplingStatusColor)
                    Text(viewModel.refreshHint)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text("白底只读总览")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
        }
    }

    private var summaryStrip: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 180), spacing: 12), count: 3), spacing: 12) {
            summaryCard(title: "CPU", icon: "cpu", value: viewModel.cpuSummary, detail: viewModel.loadAverageSummary, tint: .blue)
            summaryCard(title: "内存", icon: "memorychip", value: viewModel.memorySummary, detail: viewModel.memoryPressureSummary, tint: .purple)
            summaryCard(title: "网络", icon: "network", value: viewModel.networkSummary, detail: viewModel.networkInterfaceSummary, tint: .green)
            summaryCard(title: "电池", icon: "battery.100", value: viewModel.batterySummary, detail: viewModel.batteryStateSummary, tint: .cyan)
            summaryCard(title: "温度", icon: "thermometer", value: viewModel.temperatureSummary, detail: viewModel.temperatureDetailSummary, tint: .orange)
        }
    }

    private var performanceSection: some View {
        AppSurfaceSectionCard(title: "性能", subtitle: "CPU、内存、磁盘和进程排行") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    metricTile(title: "CPU", value: viewModel.cpuSummary, detail: viewModel.loadAverageSummary)
                    metricTile(title: "内存", value: viewModel.memorySummary, detail: viewModel.memoryUsagePercentSummary)
                    metricTile(title: "磁盘", value: viewModel.diskSummary, detail: viewModel.diskDetailSummary)
                    metricTile(title: "最近刷新", value: viewModel.lastUpdatedText, detail: viewModel.refreshHint)
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    processList(title: "CPU 进程", processes: viewModel.snapshot.topCPUProcesses)
                    processList(title: "内存进程", processes: viewModel.snapshot.topMemoryProcesses)
                }
            }
        }
    }

    private var networkSection: some View {
        AppSurfaceSectionCard(title: "网络", subtitle: "速率、主接口和 Wi‑Fi 详情") {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    infoTile(title: "下载", value: viewModel.networkDownloadSummary, detail: "MB/s")
                    infoTile(title: "上传", value: viewModel.networkUploadSummary, detail: "MB/s")
                    infoTile(title: "主接口", value: viewModel.primaryInterfaceSummary, detail: viewModel.primaryInterfaceDetail)
                    infoTile(title: "Wi‑Fi", value: viewModel.wifiSummary, detail: viewModel.wifiDetail)
                }
            }
        }
    }

    private var batterySection: some View {
        AppSurfaceSectionCard(title: "电池", subtitle: "容量、健康、温度、电压、电流和充电功率") {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    infoTile(title: "电量", value: viewModel.batterySummary, detail: viewModel.batteryStateSummary)
                    infoTile(title: "循环", value: viewModel.batteryCycleSummary, detail: "CycleCount")
                    infoTile(title: "容量", value: viewModel.batteryCapacitySummary, detail: viewModel.batteryCapacityDetail)
                    infoTile(title: "温度", value: viewModel.batteryTemperatureSummary, detail: "°C")
                    infoTile(title: "电压", value: viewModel.batteryVoltageSummary, detail: "V")
                    infoTile(title: "电流", value: viewModel.batteryCurrentSummary, detail: "A")
                    infoTile(title: "充电功率", value: viewModel.batteryPowerSummary, detail: "W")
                    infoTile(title: "剩余时间", value: viewModel.batteryTimeSummary, detail: viewModel.batteryTimeDetail)
                    infoTile(title: "健康", value: viewModel.batteryHealthSummary, detail: viewModel.batteryHealthDetail)
                }
            }
        }
    }

    private var sensorSection: some View {
        AppSurfaceSectionCard(title: "传感器", subtitle: "温度、风扇、功耗、电压、电流") {
            VStack(alignment: .leading, spacing: 12) {
                sensorGroup(title: "温度", items: viewModel.snapshot.temperatureSensors, placeholder: "暂无温度传感器")
                sensorGroup(title: "风扇", items: viewModel.fanSensorSummaries, placeholder: "暂无风扇传感器")
                sensorGroup(title: "功耗", items: viewModel.snapshot.powerSensors, placeholder: "暂无功耗传感器")
                sensorGroup(title: "电压", items: viewModel.snapshot.voltageSensors, placeholder: "暂无电压传感器")
                sensorGroup(title: "电流", items: viewModel.snapshot.currentSensors, placeholder: "暂无电流传感器")
                if let thermalState = viewModel.snapshot.thermalState {
                    infoRow(title: "热状态", value: thermalState)
                }
            }
        }
    }

    private var permissionsSection: some View {
        AppSurfaceSectionCard(title: "权限", subtitle: "麦克风、辅助功能、屏幕录制、日历、提醒事项、通知") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.snapshot.permissions) { permission in
                    permissionRow(permission)
                }
            }
        }
    }

    private var exceptionsSection: some View {
        AppSurfaceSectionCard(title: "异常", subtitle: "明确列出所有不可用原因") {
            if viewModel.snapshot.unavailableReasons.isEmpty {
                Text("当前没有不可用项。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.snapshot.unavailableReasons) { reason in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reason.message)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text([reason.category, reason.detail].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 11))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
                    }
                }
            }
        }
    }

    private var statusGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: "cpu")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
    }

    private func statusPill(icon: String, title: String, accent: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(accent))
    }

    private func summaryCard(title: String, icon: String, value: String, detail: String, tint: Color) -> some View {
        AppSurfaceCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint))
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private func metricTile(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous))
    }

    private func infoTile(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous))
    }

    private func processList(title: String, processes: [SystemProcessSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            if processes.isEmpty {
                Text("暂无进程排行")
                    .font(.system(size: 11))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            } else {
                ForEach(processes.prefix(5)) { process in
                    HStack {
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
                    .padding(.vertical, 8)
                    .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous))
    }

    private func sensorGroup<T>(title: String, items: [T], placeholder: String) -> some View where T: SensorDisplayRow {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
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
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous))
    }

    private func sensorRow<T: SensorDisplayRow>(_ item: T) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 11, weight: .medium))
                Text(item.displaySource)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer(minLength: 0)
            Text(item.displayValue)
                .font(.system(size: 11, weight: .semibold))
            if item.isUnavailable {
                Text("不可用")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(item.isUnavailable ? Color.orange.opacity(0.08) : AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
    }

    private func permissionRow(_ item: SystemPermissionSnapshot) -> some View {
        HStack {
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
            Spacer(minLength: 0)
            Text(item.value ?? "不可用")
                .font(.system(size: 11, weight: .semibold))
            if item.isAvailable == false, let reason = item.unavailableReason {
                Text(reason)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
    }

    private func infoRow(title: String, value: String) -> some View {
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
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
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

    private let service: SystemStatusService
    private var cancellables = Set<AnyCancellable>()

    init(service: SystemStatusService = .shared) {
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

    var cpuSummary: String {
        formatPercent(snapshot.cpu?.value)
    }

    var loadAverageSummary: String {
        let values = [snapshot.loadAverage1m, snapshot.loadAverage5m, snapshot.loadAverage15m].compactMap { $0 }
        guard values.isEmpty == false else { return "负载不可用" }
        return values.map { String(format: "%.2f", $0) }.joined(separator: " / ")
    }

    var memorySummary: String {
        formatGB(snapshot.memory?.value)
    }

    var memoryUsagePercentSummary: String {
        snapshot.memoryUsagePercent > 0 ? String(format: "%.0f%%", snapshot.memoryUsagePercent) : "不可用"
    }

    var memoryPressureSummary: String {
        snapshot.unavailableReasons.first(where: { $0.category == "memory" })?.message ?? "内存压力已读取"
    }

    var diskSummary: String {
        snapshot.diskUsagePercent > 0 ? String(format: "%.0f%%", snapshot.diskUsagePercent) : "不可用"
    }

    var diskDetailSummary: String {
        "\(formatGB(snapshot.diskUsedGB)) / \(formatGB(snapshot.diskTotalGB))"
    }

    var networkSummary: String {
        "↓ \(formatMBps(snapshot.networkDownloadMBps)) / ↑ \(formatMBps(snapshot.networkUploadMBps))"
    }

    var networkDownloadSummary: String {
        formatMBps(snapshot.networkDownloadMBps)
    }

    var networkUploadSummary: String {
        formatMBps(snapshot.networkUploadMBps)
    }

    var networkInterfaceSummary: String {
        snapshot.networkInterfaces.first?.interfaceName ?? "主接口不可用"
    }

    var primaryInterfaceSummary: String {
        snapshot.networkInterfaces.first(where: { $0.name == "主接口" })?.interfaceName ?? "不可用"
    }

    var primaryInterfaceDetail: String {
        snapshot.networkInterfaces.first(where: { $0.name == "主接口" })?.isVPN == true ? "VPN / scoped" : "SCDynamicStore"
    }

    var wifiSummary: String {
        snapshot.networkInterfaces.first(where: { $0.ssid != nil })?.ssid ?? "不可用"
    }

    var wifiDetail: String {
        guard let wifi = snapshot.networkInterfaces.first(where: { $0.ssid != nil }) else { return "未连接 Wi‑Fi" }
        var parts: [String] = []
        if let bssid = wifi.bssid { parts.append(bssid) }
        if let rssi = wifi.rssi { parts.append("RSSI \(rssi)") }
        if let transmit = wifi.transmitRateMbps { parts.append("Tx \(String(format: "%.0f", transmit)) Mbps") }
        if let channel = wifi.channel { parts.append(channel) }
        return parts.isEmpty ? "Wi‑Fi 已连接" : parts.joined(separator: " · ")
    }

    var batterySummary: String {
        guard let battery = snapshot.battery else { return "不可用" }
        guard battery.isAvailable else { return battery.unavailableReason ?? "无电池" }
        if let percentage = battery.percentage {
            return String(format: "%.0f%%", percentage)
        }
        return "不可用"
    }

    var batteryStateSummary: String {
        snapshot.battery?.state ?? "无电池"
    }

    var batteryCycleSummary: String {
        snapshot.battery?.cycleCount.map(String.init) ?? "不可用"
    }

    var batteryCapacitySummary: String {
        guard let battery = snapshot.battery, battery.isAvailable else { return "不可用" }
        let current = battery.rawCurrentCapacity ?? battery.maxCapacity
        let max = battery.rawMaxCapacity ?? battery.designCapacity ?? battery.maxCapacity
        guard let current, let max, max > 0 else { return "不可用" }
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
        return "不可用"
    }

    var batteryTimeDetail: String {
        snapshot.battery?.timeToEmptyMinutes != nil ? "剩余时间" : "充满时间"
    }

    var batteryHealthSummary: String {
        if let health = batteryHealthPercentage {
            return String(format: "%.0f%%", health)
        }
        return "不可用"
    }

    var batteryHealthDetail: String {
        "Max / Design"
    }

    var batteryHealthPercentage: Double? {
        guard let battery = snapshot.battery, let max = battery.maxCapacity, let design = battery.designCapacity, design > 0 else { return nil }
        return (max / design) * 100
    }

    var temperatureSummary: String {
        snapshot.temperatureSensors.first.flatMap { sensorSummary($0) } ?? "不可用"
    }

    var temperatureDetailSummary: String {
        snapshot.temperatureSensors.isEmpty ? "无温度传感器" : "\(snapshot.temperatureSensors.count) 个"
    }

    var fanSensorSummaries: [SystemFanRow] {
        snapshot.fanSensors.map { fan in
            SystemFanRow(
                id: fan.id,
                displayName: fan.name,
                displayValue: fan.value.map { String(format: "%.0f RPM", $0) } ?? fan.unavailableReason ?? "不可用",
                displaySource: fan.source,
                isUnavailable: fan.isAvailable == false || fan.value == nil
            )
        }
    }

    private func sensorSummary(_ sensor: SystemSensorSnapshot) -> String {
        guard sensor.isAvailable, let value = sensor.value else { return sensor.unavailableReason ?? "不可用" }
        if sensor.unit == "°C" { return String(format: "%.1f°C", value) }
        if sensor.unit == "W" { return String(format: "%.1fW", value) }
        if sensor.unit == "V" { return String(format: "%.2fV", value) }
        if sensor.unit == "A" { return String(format: "%.2fA", value) }
        return "\(String(format: "%.1f", value)) \(sensor.unit)"
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.0f%%", value)
    }

    private func formatGB(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.1f GB", value)
    }

    private func formatMBps(_ value: Double) -> String {
        String(format: "%.1f MB/s", value)
    }

    private func formatMBps(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.1f MB/s", value)
    }

    private func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "不可用" }
        return String(format: "%.1f°C", value)
    }

    private func formatMetric(_ value: Double?, unit: String) -> String {
        guard let value else { return "不可用" }
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
        guard isAvailable, let value else { return unavailableReason ?? "不可用" }
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
