import SwiftUI
import AcMindKit

struct SystemStatusView: View {
    @StateObject private var viewModel = SystemStatusViewModel()
    @State private var selectedSection: StatusSection = .overview

    enum StatusSection: String, CaseIterable, Identifiable {
        case overview = "总览"
        case cpu = "CPU / GPU"
        case memory = "内存"
        case disk = "磁盘"
        case network = "网络"
        case battery = "电池"
        case process = "进程"
        case sensor = "传感器"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .cpu: return "cpu"
            case .memory: return "memorychip"
            case .disk: return "internaldrive"
            case .network: return "network"
            case .battery: return "battery.100"
            case .process: return "list.bullet.rectangle"
            case .sensor: return "sensor.tag.radiowaves.forward"
            }
        }
    }

    var body: some View {
        HSplitView {
            secondarySidebar
                .frame(width: 200)

            mainContent
        }
        .background(AppSurfaceTokens.background)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    private var secondarySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("系统状态")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            List(StatusSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader
                sectionContent
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sectionHeader: some View {
        HStack {
            Image(systemName: selectedSection.icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(selectedSection.rawValue)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Text("最后更新: \(viewModel.lastUpdateTime)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .overview:
            overviewSection
        case .cpu:
            cpuSection
        case .memory:
            memorySection
        case .disk:
            diskSection
        case .network:
            networkSection
        case .battery:
            batterySection
        case .process:
            processSection
        case .sensor:
            sensorSection
        }
    }

    private var overviewSection: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                MetricCard(title: "CPU 使用率", value: "\(viewModel.cpuUsage)%", icon: "cpu", color: .blue, trend: .up)
                MetricCard(title: "内存使用", value: "\(viewModel.memoryUsage) GB", icon: "memorychip", color: .purple, trend: .stable)
                MetricCard(title: "磁盘使用", value: "\(viewModel.diskUsage)%", icon: "internaldrive", color: .orange, trend: .up)
                MetricCard(title: "网络速度", value: "\(viewModel.networkSpeed) MB/s", icon: "network", color: .green, trend: .down)
            }

            ProcessListSection(processes: viewModel.topProcesses)
        }
    }

    private var cpuSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CPU 信息")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("使用率")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.cpuUsage)%")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("核心数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.cpuCores)")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)
            }
        }
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("内存信息")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已使用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.memoryUsage) GB")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("总容量")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.totalMemory) GB")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)
            }
        }
    }

    private var diskSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("磁盘信息")
                .font(.headline)

            Text("磁盘使用率: \(viewModel.diskUsage)%")
                .font(.body)

            ProgressView(value: Double(viewModel.diskUsage) / 100.0)
                .progressViewStyle(.linear)
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("网络状态")
                .font(.headline)

            HStack(spacing: 16) {
                MetricCard(title: "下载速度", value: "\(viewModel.downloadSpeed) MB/s", icon: "arrow.down", color: .green, trend: .down)
                MetricCard(title: "上传速度", value: "\(viewModel.uploadSpeed) MB/s", icon: "arrow.up", color: .blue, trend: .up)
            }
        }
    }

    private var batterySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("电池状态")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("电量")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.batteryLevel)%")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.batteryState)
                        .font(.title)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)
            }
        }
    }

    private var processSection: some View {
        ProcessListSection(processes: viewModel.topProcesses)
    }

    private var sensorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("传感器信息")
                .font(.headline)

            Text("当前版本先展示系统状态与进程概览，传感器接入后会在这里补全")
                .font(.body)
                .foregroundStyle(.secondary)

            Label("规划中", systemImage: "clock")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .foregroundStyle(.orange)
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Trend

    enum Trend {
        case up, down, stable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)

                Image(systemName: trendIcon)
                    .font(.caption2)
                    .foregroundStyle(trendColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
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

struct ProcessListSection: View {
    let processes: [ProcessInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("进程列表")
                .font(.headline)

            ForEach(processes.prefix(5)) { process in
                HStack {
                    Text(process.name)
                        .font(.body)
                    Spacer()
                    Text("\(process.cpuUsage)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(process.memoryUsage) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(8)
            }
        }
    }
}

struct ProcessInfo: Identifiable {
    let id = UUID()
    let name: String
    let cpuUsage: Int
    let memoryUsage: Int
}

@MainActor
class SystemStatusViewModel: ObservableObject {
    @Published var cpuUsage = 0
    @Published var memoryUsage: Double = 0
    @Published var totalMemory: Double = 16
    @Published var diskUsage = 0
    @Published var networkSpeed = 0
    @Published var downloadSpeed = 0
    @Published var uploadSpeed = 0
    @Published var batteryLevel = 0
    @Published var batteryState = "未知"
    @Published var cpuCores = 8
    @Published var lastUpdateTime = ""
    @Published var topProcesses: [ProcessInfo] = []

    private var timer: Timer?

    func startMonitoring() {
        updateData()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateData()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateData() {
        cpuUsage = Int.random(in: 10...40)
        memoryUsage = Double.random(in: 8...12)
        diskUsage = Int.random(in: 60...80)
        networkSpeed = Int.random(in: 10...100)
        downloadSpeed = Int.random(in: 5...50)
        uploadSpeed = Int.random(in: 1...20)
        batteryLevel = Int.random(in: 50...100)
        batteryState = "充电中"

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        lastUpdateTime = formatter.string(from: Date())

        topProcesses = [
            ProcessInfo(name: "AcMind", cpuUsage: Int.random(in: 5...15), memoryUsage: Int.random(in: 200...500)),
            ProcessInfo(name: "Safari", cpuUsage: Int.random(in: 3...10), memoryUsage: Int.random(in: 500...1000)),
            ProcessInfo(name: "Xcode", cpuUsage: Int.random(in: 2...8), memoryUsage: Int.random(in: 1000...2000)),
            ProcessInfo(name: "Finder", cpuUsage: Int.random(in: 1...3), memoryUsage: Int.random(in: 100...200)),
            ProcessInfo(name: "WindowServer", cpuUsage: Int.random(in: 2...6), memoryUsage: Int.random(in: 200...400))
        ]
    }
}
