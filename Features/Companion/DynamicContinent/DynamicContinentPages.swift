import SwiftUI
import AcMindKit

struct DynamicContinentTodayPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2OverviewPage(viewModel: viewModel)
    }
}

struct DynamicContinentMusicPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2MusicPage(viewModel: viewModel)
    }
}

struct DynamicContinentAgentPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2AgentPage(viewModel: viewModel)
    }
}

struct DynamicContinentSchedulePage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 208, rightColumnWidth: 232) {
            DynamicCard(title: "今日时间线", subtitle: "轻量状态", symbol: "calendar") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach([
                        ("09:00", "产品设计评审"),
                        ("11:00", "需求沟通同步"),
                        ("16:30", "音乐联动评估"),
                        ("18:30", "健身锻炼")
                    ], id: \.0) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.0)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(DynamicContinentDesignTokens.accentPurple)
                                .frame(width: 40, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.1)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text("当前可用")
                                    .font(.system(size: 8, weight: .regular))
                                    .foregroundStyle(DynamicContinentDesignTokens.tertiaryText)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(height: 32, alignment: .topLeading)
                    }
                }
            }
        } centerColumn: {
            VStack(spacing: DynamicContinentLayoutMetrics.rowGap) {
                DynamicCard(title: "当前焦点", subtitle: "执行中", symbol: "target") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("编排音乐联动")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("状态：等待下一条指令")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                            .lineLimit(1)
                        Text("来源：音乐模块")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            NotchV2StatusPill(title: "继续", accent: DynamicContinentDesignTokens.accentPurple)
                            NotchV2StatusPill(title: "查看日志", accent: DynamicContinentDesignTokens.cardBackgroundStrong)
                        }
                    }
                }

                DynamicCard(title: "下一项任务", subtitle: "待开始", symbol: "clock") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("16:30 音乐联动评估")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("还剩 2 项任务")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        } rightColumn: {
            VStack(spacing: DynamicContinentLayoutMetrics.rowGap) {
                DynamicCard(title: "日程负载", subtitle: "快速新增", symbol: "chart.bar", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("今日剩余 2 项")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                                .lineLimit(1)
                            Text("负载状态：稳定")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                                .lineLimit(1)
                        }

                        VStack(spacing: 6) {
                            NotchV2StatusPill(icon: "plus", title: "新增日程", accent: DynamicContinentDesignTokens.innerCardBackground)
                            NotchV2StatusPill(icon: "sparkles", title: "今日总结", accent: DynamicContinentDesignTokens.innerCardBackground)
                        }
                    }
                }

                DynamicCard(title: "快速视图", subtitle: "今日聚焦", symbol: "bolt", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                    VStack(alignment: .leading, spacing: 6) {
                        statusChip("音乐联动", color: .purple)
                        statusChip("任务评审", color: .blue)
                        statusChip("健身锻炼", color: .green)
                    }
                }
            }
        }
    }

    private func statusChip(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(DynamicContinentDesignTokens.innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DynamicContinentSystemStatusPage: View {
    @StateObject private var viewModel = SystemStatusViewModel()

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 200, rightColumnWidth: 224) {
            DynamicCard(title: "设备概览", subtitle: "采样摘要", symbol: "desktopcomputer") {
                VStack(alignment: .leading, spacing: 6) {
                    deviceOverviewRow(title: "最近刷新", value: viewModel.lastUpdateTime.isEmpty ? "等待刷新" : viewModel.lastUpdateTime)
                    deviceOverviewRow(title: "采样状态", value: "运行中")
                    deviceOverviewRow(title: "电池", value: "\(viewModel.batteryLevel)% · \(viewModel.batteryState)")
                    deviceOverviewRow(title: "CPU 核心", value: "\(viewModel.cpuCores)")
                    deviceOverviewRow(title: "内存总量", value: "\(String(format: "%.1f", viewModel.totalMemory)) GB")
                }
            }
        } centerColumn: {
            DynamicCard(title: "核心指标", subtitle: "CPU / 内存 / 磁盘 / 网络 / 电池", symbol: "cpu") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    DynamicMetricCard(title: "CPU 使用率", value: "\(viewModel.cpuUsage)%", icon: "cpu", tint: .blue, trend: .up)
                    DynamicMetricCard(title: "内存使用", value: "\(String(format: "%.1f", viewModel.memoryUsage)) GB", icon: "memorychip", tint: .purple, trend: .stable)
                    DynamicMetricCard(title: "磁盘使用", value: "\(viewModel.diskUsage)%", icon: "internaldrive", tint: .orange, trend: .up)
                    DynamicMetricCard(title: "网络速度", value: "\(viewModel.networkSpeed) MB/s", icon: "network", tint: .green, trend: .down)
                    DynamicMetricCard(title: "电池电量", value: "\(viewModel.batteryLevel)%", icon: "battery.100", tint: .cyan, trend: .stable)
                }
            }
        } rightColumn: {
            VStack(spacing: DynamicContinentLayoutMetrics.rowGap) {
                DynamicCard(title: "进程 Top 5", subtitle: "活跃进程", symbol: "list.bullet.rectangle", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                    DynamicProcessListSection(processes: viewModel.topProcesses)
                }

                DynamicCard(title: "采样状态", subtitle: "当前通道", symbol: "waveform.path.ecg", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                    VStack(alignment: .leading, spacing: 6) {
                        statusChip("CPU 采样", color: .blue)
                        statusChip("内存采样", color: .purple)
                        statusChip("磁盘采样", color: .orange)
                        statusChip("网络采样", color: .green)
                        statusChip("电池采样", color: .cyan)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    private func statusChip(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(DynamicContinentDesignTokens.innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func deviceOverviewRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(height: 32)
    }
}

private struct DynamicMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    let trend: Trend

    enum Trend {
        case up, down, stable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .bottom, spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: trendIcon)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(trendColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DynamicContinentDesignTokens.innerCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DynamicContinentDesignTokens.cardStroke.opacity(0.75), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var trendIcon: String {
        switch trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .up: return .red
        case .down: return .green
        case .stable: return .gray
        }
    }
}

private struct DynamicProcessListSection: View {
    let processes: [SystemProcessSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let rows = Array(processes.prefix(5).enumerated())

            if rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                    Text("等待进程采样")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                        .lineLimit(1)
                    Text("刷新后会显示活跃进程的 CPU 和内存占用。")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            } else {
                ForEach(rows, id: \.offset) { row in
                    let process = row.element
                    HStack(spacing: 8) {
                        Text(process.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                        Text(String(format: "%.0f%%", process.cpuUsage))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                            .lineLimit(1)
                        Text(String(format: "%.0f MB", process.memoryUsageMB))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(DynamicContinentDesignTokens.innerCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}
