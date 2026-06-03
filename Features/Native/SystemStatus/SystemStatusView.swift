import SwiftUI
import Combine
import EventKit
import AcMindKit

struct SystemStatusView: View {
    @StateObject private var viewModel = SystemStatusViewModel()

    private let summaryColumns = Array(
        repeating: GridItem(.flexible(minimum: 180), spacing: 12, alignment: .top),
        count: 3
    )

    private let bodyColumns = [
        GridItem(.flexible(minimum: 520), spacing: 16, alignment: .top),
        GridItem(.flexible(minimum: 320), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                summaryStrip
                bodyGrid
            }
            .padding(.horizontal, AppSurfaceTokens.Layout.pagePadding)
            .padding(.vertical, 24)
            .frame(maxWidth: AppSurfaceTokens.Layout.pageMaxWidth, alignment: .leading)
        }
        .background(backgroundLayer.ignoresSafeArea())
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            AppVisualBackdrop()

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    Color.clear,
                    AppSurfaceTokens.background.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 380, height: 380)
                .blur(radius: 70)
                .offset(x: -260, y: -220)

            Circle()
                .fill(AppSurfaceTokens.accentPrimary.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 300, y: -140)

            Circle()
                .fill(AppSurfaceTokens.accentCyan.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 180, y: 260)
        }
    }

    private var headerCard: some View {
        AppSurfaceCard(title: "系统状态", subtitle: "把采样结果做成更紧凑的总览、详情和异常区，减少空白和来回切换。") {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "cpu")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("本机状态")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text("CPU、内存、磁盘、网络、电池、权限一次看全")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    HStack(spacing: 8) {
                        statusPill(
                            icon: "clock",
                            title: viewModel.lastUpdateTime.isEmpty ? "等待刷新" : "更新 \(viewModel.lastUpdateTime)",
                            accent: AppSurfaceTokens.cardBackgroundSoft
                        )
                        statusPill(
                            icon: "waveform.path.ecg",
                            title: viewModel.samplingStatusText,
                            accent: viewModel.samplingStatusColor.opacity(0.16)
                        )
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Text("运行中")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(viewModel.samplingStatusColor)
                    Text("监控中")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text("2 秒刷新一次")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
        }
    }

    private var summaryStrip: some View {
        LazyVGrid(columns: summaryColumns, spacing: 12) {
            SummaryMetricCard(
                title: "CPU 使用率",
                value: "\(viewModel.cpuUsage)%",
                detail: "\(viewModel.cpuCores) 核",
                icon: "cpu",
                tint: .blue,
                progress: Double(viewModel.cpuUsage) / 100.0
            )

            SummaryMetricCard(
                title: "内存",
                value: "\(String(format: "%.1f", viewModel.memoryUsage)) / \(String(format: "%.1f", viewModel.totalMemory)) GB",
                detail: "\(String(format: "%.0f", viewModel.totalMemory > 0 ? (viewModel.memoryUsage / viewModel.totalMemory) * 100 : 0))%",
                icon: "memorychip",
                tint: .purple,
                progress: viewModel.totalMemory > 0 ? viewModel.memoryUsage / viewModel.totalMemory : 0
            )

            SummaryMetricCard(
                title: "磁盘",
                value: "\(String(format: "%.1f", viewModel.diskUsedGB)) / \(String(format: "%.1f", viewModel.diskTotalGB)) GB",
                detail: "\(viewModel.diskUsage)% 使用",
                icon: "internaldrive",
                tint: .orange,
                progress: Double(viewModel.diskUsage) / 100.0
            )

            SummaryMetricCard(
                title: "网络",
                value: "↓ \(viewModel.downloadSpeed) / ↑ \(viewModel.uploadSpeed) MB/s",
                detail: "\(viewModel.networkSpeed) MB/s 合计",
                icon: "network",
                tint: .green,
                progress: min(1, Double(viewModel.networkSpeed) / 25.0)
            )

            SummaryMetricCard(
                title: "电池",
                value: "\(viewModel.batteryLevel)%",
                detail: viewModel.batteryState,
                icon: "battery.100",
                tint: .cyan,
                progress: Double(viewModel.batteryLevel) / 100.0
            )
        }
    }

    private var bodyGrid: some View {
        LazyVGrid(columns: bodyColumns, spacing: 16) {
            VStack(spacing: 16) {
                overviewCard
                processCard
            }

            VStack(spacing: 16) {
                permissionsCard
                samplingCard
                runtimeCard
            }
        }
    }

    private var overviewCard: some View {
        AppSurfaceSectionCard(
            title: "设备概览",
            subtitle: "按类别集中呈现关键硬件与当前采样结果"
        ) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                DetailTile(title: "CPU", value: "\(viewModel.cpuUsage)%", detail: "\(viewModel.cpuCores) 核")
                DetailTile(title: "内存", value: "\(String(format: "%.1f", viewModel.memoryUsage)) GB", detail: "\(String(format: "%.0f", viewModel.totalMemory > 0 ? (viewModel.memoryUsage / viewModel.totalMemory) * 100 : 0))% / \(String(format: "%.1f", viewModel.totalMemory)) GB")
                DetailTile(title: "磁盘", value: "\(String(format: "%.1f", viewModel.diskUsagePercent))%", detail: "\(String(format: "%.1f", viewModel.diskUsedGB)) / \(String(format: "%.1f", viewModel.diskTotalGB)) GB")
                DetailTile(title: "网络", value: "↓ \(viewModel.downloadSpeed) / ↑ \(viewModel.uploadSpeed)", detail: "MB/s")
                DetailTile(title: "电池", value: "\(viewModel.batteryLevel)%", detail: viewModel.batteryState)
                DetailTile(title: "更新", value: viewModel.lastUpdateTime.isEmpty ? "--:--:--" : viewModel.lastUpdateTime, detail: viewModel.samplingStatusText)
            }
        }
    }

    private var processCard: some View {
        AppSurfaceSectionCard(
            title: "活跃进程",
            subtitle: "按 CPU 与内存排过序的前 5 个进程"
        ) {
            ProcessListSection(processes: viewModel.topProcesses)
        }
    }

    private var permissionsCard: some View {
        AppSurfaceSectionCard(
            title: "权限状态",
            subtitle: "默认突出异常项，方便先处理问题"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Button("打开系统设置") {
                        viewModel.openPrivacySettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                SystemStatusPermissionRow(
                    title: "辅助功能",
                    detail: viewModel.accessibilityPermissionStatus.displayName,
                    isWarning: viewModel.accessibilityPermissionStatus != .authorized,
                    accent: .purple
                )

                SystemStatusPermissionRow(
                    title: "麦克风",
                    detail: viewModel.microphonePermissionStatus.displayName,
                    isWarning: viewModel.microphonePermissionStatus != .authorized,
                    accent: .red
                )

                SystemStatusPermissionRow(
                    title: "屏幕录制",
                    detail: viewModel.screenRecordingPermissionStatus.displayName,
                    isWarning: viewModel.screenRecordingPermissionStatus != .authorized,
                    accent: .orange
                )

                SystemStatusPermissionRow(
                    title: "日历",
                    detail: viewModel.calendarPermissionStatusText,
                    isWarning: viewModel.calendarPermissionStatusText != "已授权",
                    accent: .blue
                )

                SystemStatusPermissionRow(
                    title: "提醒事项",
                    detail: viewModel.remindersPermissionStatusText,
                    isWarning: viewModel.remindersPermissionStatusText != "已授权",
                    accent: .green
                )
            }
        }
    }

    private var samplingCard: some View {
        AppSurfaceSectionCard(
            title: "采样通道",
            subtitle: "当前页面展示的系统采样源"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ChannelChip(title: "CPU", value: "\(viewModel.cpuUsage)%", accent: .blue)
                ChannelChip(title: "内存", value: "\(String(format: "%.1f", viewModel.memoryUsage)) GB", accent: .purple)
                ChannelChip(title: "磁盘", value: "\(viewModel.diskUsage)%", accent: .orange)
                ChannelChip(title: "网络", value: "\(viewModel.networkSpeed) MB/s", accent: .green)
                ChannelChip(title: "电池", value: "\(viewModel.batteryLevel)%", accent: .cyan)
            }
        }
    }

    private var runtimeCard: some View {
        AppSurfaceSectionCard(
            title: "运行摘要",
            subtitle: "把一些不适合放在主指标里的状态单独收拢"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(title: "当前状态", value: viewModel.samplingStatusText)
                infoRow(title: "最近刷新", value: viewModel.lastUpdateTime.isEmpty ? "等待刷新" : viewModel.lastUpdateTime)
                infoRow(title: "总内存", value: "\(String(format: "%.1f", viewModel.totalMemory)) GB")
                infoRow(title: "总磁盘", value: "\(String(format: "%.1f", viewModel.diskTotalGB)) GB")
                infoRow(title: "电池健康", value: batteryHealthText)
            }
        }
    }

    private var batteryHealthText: String {
        if let health = viewModel.batteryInfo.healthPercentage {
            return "\(Int(health.rounded()))%"
        }
        return "未知"
    }

    private func statusPill(icon: String, title: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(accent)
        )
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
    }
}

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color
    let progress: Double

    var body: some View {
        AppSurfaceCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                            .fill(tint.opacity(0.14))
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 8) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(AppSurfaceTokens.cardBackgroundSoft)
                            Capsule(style: .continuous)
                                .fill(tint)
                                .frame(width: max(6, proxy.size.width * max(0, min(1, progress))))
                        }
                    }
                    .frame(height: 5)

                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }
}

private struct DetailTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous))
    }
}

private struct SystemStatusPermissionRow: View {
    let title: String
    let detail: String
    let isWarning: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isWarning ? accent : .green)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Spacer(minLength: 0)

            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isWarning ? accent : AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isWarning ? accent.opacity(0.08) : AppSurfaceTokens.cardBackgroundSoft.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
    }
}

private struct ChannelChip: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct ProcessListSection: View {
    let processes: [SystemProcessSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let rows = Array(processes.prefix(5).enumerated())

            ForEach(rows, id: \.offset) { row in
                let process = row.element
                HStack(spacing: 10) {
                    Text(process.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)

                    Text(String(format: "%.0f%%", process.cpuUsage))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)

                    Text(String(format: "%.0f MB", process.memoryUsageMB))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }
}

@MainActor
class SystemStatusViewModel: ObservableObject {
    @Published var cpuUsage = 0
    @Published var memoryUsage: Double = 0
    @Published var totalMemory: Double = 16
    @Published var memoryUsagePercent: Double = 0
    @Published var diskUsage = 0
    @Published var diskUsagePercent: Double = 0
    @Published var diskUsedGB: Double = 0
    @Published var diskTotalGB: Double = 0
    @Published var networkSpeed = 0
    @Published var downloadSpeed = 0
    @Published var uploadSpeed = 0
    @Published var batteryLevel = 0
    @Published var batteryState = "未知"
    @Published var batteryInfo = BatteryInfo()
    @Published var microphonePermissionStatus: AppPermissionStatus = .unknown
    @Published var accessibilityPermissionStatus: AppPermissionStatus = .unknown
    @Published var screenRecordingPermissionStatus: AppPermissionStatus = .unknown
    @Published var calendarPermissionStatusText = "待检查"
    @Published var remindersPermissionStatusText = "待检查"
    @Published var cpuCores = 8
    @Published var lastUpdateTime = ""
    @Published var samplingStatusText = "待机"
    @Published var samplingStatusColor: Color = .secondary
    @Published var topProcesses: [SystemProcessSnapshot] = []

    private let service: SystemStatusService
    private let batteryService = BatteryService.shared
    private let permissionManager: PermissionManager
    private var cancellables = Set<AnyCancellable>()
    private let eventStore = EKEventStore()

    init(service: SystemStatusService = SystemStatusService()) {
        self.service = service
        self.permissionManager = ServiceContainer.isInitialized() ? ServiceContainer.shared.permissionManager : PermissionManager()
        cpuCores = ProcessInfo.processInfo.processorCount
        service.$snapshot
            .sink { [weak self] snapshot in
                self?.apply(snapshot)
            }
            .store(in: &cancellables)

        batteryService.$batteryInfo
            .sink { [weak self] info in
                self?.batteryInfo = info
                self?.batteryState = self?.batteryInfoSummary ?? "未知"
            }
            .store(in: &cancellables)

        permissionManager.$statuses
            .sink { [weak self] _ in
                self?.syncPermissions()
            }
            .store(in: &cancellables)

        syncPermissions()
    }

    func startMonitoring() {
        service.start()
        samplingStatusText = "采样中"
        samplingStatusColor = .green
        Task {
            await permissionManager.refreshAll()
            await MainActor.run {
                self.syncPermissions()
            }
        }
    }

    func stopMonitoring() {
        service.stop()
        samplingStatusText = "已停止"
        samplingStatusColor = .secondary
    }

    func openPrivacySettings() {
        permissionManager.openPrivacySettings()
    }

    private func syncPermissions() {
        microphonePermissionStatus = permissionManager.statuses[.microphone] ?? .unknown
        accessibilityPermissionStatus = permissionManager.statuses[.accessibility] ?? .unknown
        screenRecordingPermissionStatus = permissionManager.statuses[.screenRecording] ?? .unknown
        calendarPermissionStatusText = Self.formatCalendarStatus(EKEventStore.authorizationStatus(for: .event))
        remindersPermissionStatusText = Self.formatCalendarStatus(EKEventStore.authorizationStatus(for: .reminder))
    }

    private static func formatCalendarStatus(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "已授权"
        case .fullAccess: return "已授权"
        case .writeOnly: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限"
        case .notDetermined: return "未确定"
        @unknown default: return "未知"
        }
    }

    private func apply(_ snapshot: SystemStatusSnapshot) {
        guard snapshot.lastUpdated != .distantPast else { return }

        cpuUsage = Int(snapshot.cpuUsage.rounded())
        memoryUsage = snapshot.memoryUsageGB
        totalMemory = snapshot.totalMemoryGB
        memoryUsagePercent = snapshot.memoryUsagePercent
        diskUsage = Int(snapshot.diskUsagePercent.rounded())
        diskUsagePercent = snapshot.diskUsagePercent
        diskUsedGB = snapshot.diskUsedGB
        diskTotalGB = snapshot.diskTotalGB
        networkSpeed = Int((snapshot.networkDownloadMBps + snapshot.networkUploadMBps).rounded())
        downloadSpeed = Int(snapshot.networkDownloadMBps.rounded())
        uploadSpeed = Int(snapshot.networkUploadMBps.rounded())
        batteryLevel = Int(snapshot.batteryLevel.rounded())
        batteryState = batteryInfoSummary
        cpuCores = ProcessInfo.processInfo.processorCount

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        lastUpdateTime = formatter.string(from: snapshot.lastUpdated)
        topProcesses = snapshot.topProcesses
    }

    private var batteryInfoSummary: String {
        if batteryInfo.isCharging {
            return "充电中"
        }
        if batteryInfo.isPluggedIn {
            return "接电"
        }
        if batteryInfo.isInLowPowerMode {
            return "低电量模式"
        }
        if batteryInfo.currentCapacity <= 0 {
            return "无电池"
        }
        return "电池供电"
    }
}
