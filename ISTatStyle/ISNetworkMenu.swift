import SwiftUI

// MARK: - Network Menubar Item

struct ISNetworkMenubarItem: View {
    let download: String
    let upload: String
    let downloadBytes: CGFloat
    let uploadBytes: CGFloat
    let historyData: [CGFloat]
    let isConnected: Bool
    var mode: DisplayMode = .bandwidth

    enum DisplayMode {
        case icon, label, bandwidth, dualValue
        case historyGraph, dots, status, wifi
        case ping
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .icon:
                Image(systemName: "network")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isConnected ? theme.textPrimary : theme.textTertiary)
            case .label:
                Text("NET")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
            case .bandwidth:
                HStack(spacing: 2) {
                    arrowDown
                    Text(download)
                        .font(ISTypography.menubarValue)
                        .foregroundColor(theme.graphPrimary)
                    arrowUp
                    Text(upload)
                        .font(ISTypography.menubarValue)
                        .foregroundColor(theme.graphTertiary)
                }
            case .dualValue:
                VStack(spacing: 0) {
                    HStack(spacing: 2) {
                        arrowDown
                        Text(download)
                            .font(ISTypography.menubarValue)
                            .foregroundColor(theme.graphPrimary)
                    }
                    HStack(spacing: 2) {
                        arrowUp
                        Text(upload)
                            .font(ISTypography.menubarValue)
                            .foregroundColor(theme.graphTertiary)
                    }
                }
            case .historyGraph:
                ISHistoryGraphMenubarNet(dataPoints: historyData,
                                         primary: theme.graphPrimary,
                                         secondary: theme.graphTertiary)
            case .dots:
                ISActivityDots(readActive: downloadBytes > 0,
                              writeActive: uploadBytes > 0,
                              readColor: theme.graphPrimary,
                              writeColor: theme.graphTertiary)
            case .status:
                Circle()
                    .fill(isConnected ? theme.statusGreen : theme.statusRed)
                    .frame(width: 6, height: 6)
            case .wifi:
                Image(systemName: isConnected ? "wifi" : "wifi.slash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isConnected ? theme.textPrimary : theme.textTertiary)
            case .ping:
                Text("23ms")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.statusGreen)
            }
        }
    }

    private var arrowDown: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 7, weight: .bold))
            .foregroundColor(theme.graphPrimary)
    }

    private var arrowUp: some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 7, weight: .bold))
            .foregroundColor(theme.graphTertiary)
    }
}

// MARK: - Network History (Menubar)

private struct ISHistoryGraphMenubarNet: View {
    let dataPoints: [CGFloat]
    let primary: Color
    let secondary: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { path in
                    guard dataPoints.count > 1 else { return }
                    let step = geo.size.width / CGFloat(dataPoints.count - 1)
                    path.move(to: CGPoint(x: 0, y: geo.size.height * (1 - dataPoints[0])))
                    for i in 1..<dataPoints.count {
                        path.addLine(to: CGPoint(x: CGFloat(i) * step,
                                                 y: geo.size.height * (1 - dataPoints[i])))
                    }
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(primary.opacity(0.2))

                Path { path in
                    guard dataPoints.count > 1 else { return }
                    let step = geo.size.width / CGFloat(dataPoints.count - 1)
                    path.move(to: CGPoint(x: 0, y: geo.size.height * (1 - dataPoints[0])))
                    for i in 1..<dataPoints.count {
                        path.addLine(to: CGPoint(x: CGFloat(i) * step,
                                                 y: geo.size.height * (1 - dataPoints[i])))
                    }
                }
                .stroke(primary, style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        .frame(width: 28, height: 14)
    }
}

// MARK: - Network Dropdown Menu

struct ISNetworkMenu: View {
    let interfaceName: String
    let ipAddress: String
    let publicIP: String
    let download: String
    let upload: String
    let totalDownload: String
    let totalUpload: String
    let ping: String
    let downloadHistory: [CGFloat]
    let uploadHistory: [CGFloat]
    let processes: [(name: String, download: String, upload: String)]
    let isConnected: Bool
    let vpnConnected: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ISLayout.sectionGap) {
            // Interface Info
            ISSectionHeader(title: interfaceName,
                          value: isConnected ? "Connected" : "Disconnected")

            ISMenuRow(label: "IP Address", value: ipAddress,
                     icon: "globe")
            ISMenuRow(label: "Public IP", value: publicIP,
                     icon: "globe.americas")

            if vpnConnected {
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 10))
                        .foregroundColor(theme.statusGreen)
                    Text("VPN Connected")
                        .font(ISTypography.sectionCaption)
                        .foregroundColor(theme.statusGreen)
                }
                .padding(.horizontal, ISLayout.menuPaddingH)
            }

            ISDivider()

            // Bandwidth
            ISGraphSection(title: "Bandwidth") {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(theme.graphPrimary)
                            Text("Download")
                                .font(ISTypography.sectionCaption)
                                .foregroundColor(theme.textTertiary)
                        }
                        Text(download)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.graphPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(theme.graphTertiary)
                            Text("Upload")
                                .font(ISTypography.sectionCaption)
                                .foregroundColor(theme.textTertiary)
                        }
                        Text(upload)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.graphTertiary)
                    }
                }
            }

            ISDivider()

            // History
            ISGraphSection(title: "Activity") {
                ISHistoryGraph(dataPoints: downloadHistory,
                              color: theme.graphPrimary,
                              secondaryColor: theme.graphTertiary,
                              secondaryData: uploadHistory)
            }

            ISDivider()

            // Totals
            ISMenuRow(label: "Total Download", value: totalDownload,
                     valueColor: theme.graphPrimary)
            ISMenuRow(label: "Total Upload", value: totalUpload,
                     valueColor: theme.graphTertiary)

            ISDivider()

            // Ping
            ISMenuRow(label: "Ping", value: ping,
                     valueColor: pingColor)

            ISDivider()

            // Processes
            if !processes.isEmpty {
                ISSectionHeader(title: "Processes")
                ForEach(0..<processes.count, id: \.self) { i in
                    HStack {
                        Text(processes[i].name)
                            .font(ISTypography.dataLabel)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(processes[i].download)
                            .font(ISTypography.dataValue)
                            .foregroundColor(theme.graphPrimary)
                        Text(processes[i].upload)
                            .font(ISTypography.dataValue)
                            .foregroundColor(theme.graphTertiary)
                    }
                    .padding(.horizontal, ISLayout.menuPaddingH)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var pingColor: Color {
        guard let ms = Int(ping.filter { $0.isNumber }) else { return theme.textSecondary }
        if ms < 30 { return theme.statusGreen }
        if ms < 100 { return theme.statusYellow }
        return theme.statusRed
    }
}
