import SwiftUI

// MARK: - Preview Demo

struct ISPreviewDemo: View {
    @State private var isDarkMode = true
    @State private var selectedTab = 0

    private var theme: ISTheme { isDarkMode ? .dark : .light }

    // Sample Data
    private let cpuHistory: [CGFloat] = [0.28, 0.31, 0.35, 0.39, 0.42, 0.45, 0.48, 0.5, 0.47, 0.44, 0.41, 0.38, 0.36, 0.34, 0.33, 0.35, 0.37, 0.4, 0.43, 0.46]

    private let networkHistory: [CGFloat] = [0.16, 0.19, 0.18, 0.21, 0.26, 0.31, 0.29, 0.27, 0.25, 0.28, 0.34, 0.37, 0.33, 0.3, 0.27, 0.22, 0.2, 0.18, 0.17, 0.16]
    private let memoryHistory: [CGFloat] = [0.42, 0.43, 0.44, 0.45, 0.47, 0.48, 0.5, 0.52, 0.53, 0.55, 0.56, 0.58, 0.6, 0.61, 0.63, 0.62, 0.61, 0.6, 0.59, 0.58]

    private let processes = [
        ("Safari", CGFloat(0.23)),
        ("Xcode", CGFloat(0.18)),
        ("Chrome", CGFloat(0.12)),
        ("Finder", CGFloat(0.05)),
        ("Terminal", CGFloat(0.03))
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("iStat Menus Style")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Toggle(isOn: $isDarkMode) {
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .foregroundStyle(isDarkMode ? .yellow : .orange)
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.horizontal, ISLayout.menuPaddingH)
            .padding(.vertical, 10)

            // Tab Bar
            HStack(spacing: 8) {
                tabButton(0, "Menubar")
                tabButton(1, "CPU")
                tabButton(2, "Memory")
                tabButton(3, "Network")
            }
            .padding(.horizontal, ISLayout.menuPaddingH)

            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case 0:
                        menubarDemo
                    case 1:
                        cpuMenuDemo
                    case 2:
                        memoryMenuDemo
                    case 3:
                        networkMenuDemo
                    default:
                        menubarDemo
                    }
                }
                .padding(ISLayout.menuPaddingH)
            }
        }
        .frame(width: 380, height: 700)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: ISLayout.cornerRadius))
        .iStatTheme(theme)
    }

    private func tabButton(_ index: Int, _ title: String) -> some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            Text(title)
                .font(ISTypography.sectionBody)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: ISLayout.cornerRadius)
                        .fill(selectedTab == index ? theme.accent : theme.surface)
                )
                .foregroundStyle(selectedTab == index ? .white : theme.textPrimary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menubar Demo

    private var menubarDemo: some View {
        VStack(spacing: 16) {
            sectionTitle("Menubar Items")

            // Simulated menubar
            HStack(spacing: 10) {
                ISCPUMenubarItem(
                    usage: 0.45,
                    systemUsage: 0.12,
                    coreUsages: [0.3, 0.5, 0.2, 0.6, 0.4, 0.3, 0.7, 0.5],
                    historyData: cpuHistory,
                    mode: .historyGraph
                )

                ISMemoryMenubarItem(
                    used: 0.72,
                    pressure: 0.45,
                    historyData: memoryHistory,
                    mode: .labelValue
                )

                ISNetworkMenubarItem(
                    download: "12.4 MB/s",
                    upload: "3.2 MB/s",
                    downloadBytes: 12400000,
                    uploadBytes: 3200000,
                    historyData: networkHistory,
                    isConnected: true,
                    mode: .bandwidth
                )

                ISBatteryMenubarItem(
                    level: 0.78,
                    isCharging: true,
                    timeRemaining: "2:30",
                    mode: .horizontalGraph
                )

                ISDisksMenubarItem(
                    diskName: "Macintosh HD",
                    usedPercent: 0.65,
                    readSpeed: "45 MB/s",
                    writeSpeed: "23 MB/s",
                    readActive: true,
                    writeActive: false,
                    mode: .diskActivity
                )

                ISWeatherMenubarItem(
                    temperature: "22°",
                    condition: "Sunny",
                    icon: "sun.max.fill",
                    mode: .singleValue
                )

                ISTimeMenubarItem(
                    time: "14:30",
                    date: "Fri Jun 6",
                    mode: .singleValue
                )
            }
            .padding(10)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: ISLayout.cornerRadius))

            // Display modes
            sectionTitle("CPU Display Modes")

            VStack(spacing: 6) {
                modeRow("History Graph") {
                    ISCPUMenubarItem(
                        usage: 0.45,
                        systemUsage: 0.12,
                        coreUsages: [0.3, 0.5, 0.2, 0.6],
                        historyData: cpuHistory,
                        mode: .historyGraph
                    )
                }
                modeRow("Label + Value") {
                    ISCPUMenubarItem(
                        usage: 0.45,
                        systemUsage: 0.12,
                        coreUsages: [],
                        historyData: [],
                        mode: .labelValue
                    )
                }
                modeRow("Cores") {
                    ISCPUMenubarItem(
                        usage: 0.45,
                        systemUsage: 0.12,
                        coreUsages: [0.3, 0.5, 0.2, 0.6, 0.4, 0.3, 0.7, 0.5],
                        historyData: [],
                        mode: .cores
                    )
                }
                modeRow("Circular Graph") {
                    ISCPUMenubarItem(
                        usage: 0.45,
                        systemUsage: 0.12,
                        coreUsages: [],
                        historyData: [],
                        mode: .circularGraph
                    )
                }
                modeRow("Vertical Graph") {
                    ISCPUMenubarItem(
                        usage: 0.45,
                        systemUsage: 0.12,
                        coreUsages: [0.3, 0.5, 0.2, 0.6],
                        historyData: [],
                        mode: .verticalGraph
                    )
                }
            }
            .padding(10)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: ISLayout.cornerRadius))
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(ISTypography.sectionHeader)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modeRow<Content: View>(_ name: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(name)
                .font(ISTypography.sectionCaption)
                .foregroundStyle(theme.textTertiary)
                .frame(width: 100, alignment: .leading)
            Spacer()
            HStack {
                content()
            }
            .padding(6)
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: ISLayout.cornerRadiusSmall))
        }
    }

    // MARK: - CPU Menu Demo

    private var cpuMenuDemo: some View {
        VStack(spacing: 16) {
            sectionTitle("CPU Menu")

            ISMenuContainer(theme: theme) {
                ISCPUMenu(
                    totalUsage: 0.45,
                    systemUsage: 0.12,
                    userUsage: 0.33,
                    coreUsages: [0.3, 0.5, 0.2, 0.6, 0.4, 0.3, 0.7, 0.5,
                                 0.2, 0.4, 0.6, 0.3, 0.5, 0.4, 0.3, 0.4],
                    historyData: cpuHistory,
                    processes: processes
                )
            }
        }
    }

    // MARK: - Memory Menu Demo

    private var memoryMenuDemo: some View {
        VStack(spacing: 16) {
            sectionTitle("Memory Menu")

            ISMenuContainer(theme: theme) {
                ISMemoryMenu(
                    appMemory: 0.45,
                    wiredMemory: 0.15,
                    compressedMemory: 0.08,
                    pressure: 0.35,
                    swapUsed: 0.2,
                    pageIns: (0..<20).map { _ in CGFloat.random(in: 0.1...0.8) },
                    pageOuts: (0..<20).map { _ in CGFloat.random(in: 0.05...0.3) },
                    processes: [
                        ("Safari", 2.3),
                        ("Xcode", 1.8),
                        ("Chrome", 1.2),
                        ("Photos", 0.8),
                        ("Finder", 0.3)
                    ]
                )
            }
        }
    }

    // MARK: - Network Menu Demo

    private var networkMenuDemo: some View {
        VStack(spacing: 16) {
            sectionTitle("Network Menu")

            ISMenuContainer(theme: theme) {
                ISNetworkMenu(
                    interfaceName: "en0 - Wi-Fi",
                    ipAddress: "192.168.1.100",
                    publicIP: "203.0.113.45",
                    download: "12.4 MB/s",
                    upload: "3.2 MB/s",
                    totalDownload: "2.3 GB",
                    totalUpload: "456 MB",
                    ping: "23 ms",
                    downloadHistory: networkHistory,
                    uploadHistory: (0..<20).map { _ in CGFloat.random(in: 0.05...0.3) },
                    processes: [
                        ("Safari", "5.2 MB/s", "120 KB/s"),
                        ("Xcode", "3.1 MB/s", "450 KB/s"),
                        ("Terminal", "1.2 MB/s", "25 KB/s")
                    ],
                    isConnected: true,
                    vpnConnected: true
                )
            }
        }
    }
}

// MARK: - Standalone Component Previews

struct ISGraphComponents_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            ISHistoryGraph(
                dataPoints: [0.2, 0.4, 0.3, 0.6, 0.5, 0.7, 0.4, 0.6, 0.8, 0.5],
                color: .blue,
                secondaryColor: .red,
                secondaryData: [0.1, 0.2, 0.15, 0.3, 0.25, 0.35, 0.2, 0.3, 0.4, 0.25],
                height: 80
            )
            .frame(width: 200)

            VStack(spacing: 12) {
                ISCircularGraph(value: 0.75, color: .blue, size: 50)
                ISCircularGraph(value: 0.45, color: .green, size: 40)
                ISCircularGraph(value: 0.9, color: .red, size: 30)
            }

            ISMultiRingGraph(rings: [
                .init(value: 0.6, color: .blue),
                .init(value: 0.4, color: .cyan),
                .init(value: 0.2, color: .green)
            ], size: 60)

            ISVerticalBarGraph(
                values: [0.3, 0.6, 0.4, 0.8, 0.5],
                colors: [.blue, .cyan, .green, .blue, .cyan],
                width: 30, height: 40
            )
        }
        .padding(30)
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}

struct ISMenuBarItems_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            ISCPUMenubarItem(
                usage: 0.45, systemUsage: 0.12,
                coreUsages: [0.3, 0.5, 0.2, 0.6],
                historyData: [0.2, 0.4, 0.3, 0.6, 0.5, 0.7],
                mode: .historyGraph
            )

            ISMemoryMenubarItem(
                used: 0.72, pressure: 0.45,
                historyData: [0.4, 0.5, 0.6, 0.55, 0.7],
                mode: .labelValue
            )

            ISNetworkMenubarItem(
                download: "12.4", upload: "3.2",
                downloadBytes: 12400000, uploadBytes: 3200000,
                historyData: [0.3, 0.5, 0.2, 0.6, 0.4],
                isConnected: true, mode: .bandwidth
            )

            ISBatteryMenubarItem(
                level: 0.78, isCharging: true,
                timeRemaining: "2:30", mode: .horizontalGraph
            )

            ISTimeMenubarItem(time: "14:30", date: "Jun 6", mode: .singleValue)
        }
        .padding(20)
        .background(Color(white: 0.11))
        .iStatTheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}
