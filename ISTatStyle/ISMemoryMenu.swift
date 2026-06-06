import SwiftUI

// MARK: - Memory Menubar Item

struct ISMemoryMenubarItem: View {
    let used: CGFloat
    let pressure: CGFloat
    let historyData: [CGFloat]
    var mode: DisplayMode = .labelValue

    enum DisplayMode {
        case icon, label, labelValue, percentage
        case verticalGraph, circularGraph, labelGraph
        case singleValueMemory, singleValuePressure
        case usedFree
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .icon:
                Image(systemName: "memorychip")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            case .label:
                Text("MEM")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
            case .labelValue:
                Text("MEM")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                Text("\(Int(used * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(pressureColor)
            case .percentage:
                Text("\(Int(used * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(pressureColor)
            case .verticalGraph:
                ISVerticalBarGraph(values: [used], colors: [pressureColor],
                                   width: 6, height: 14)
            case .circularGraph:
                ISCircularGraph(value: used, color: pressureColor,
                               lineWidth: 2.5, size: 16)
            case .labelGraph:
                Text("MEM")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                memoryHistoryBar
            case .singleValueMemory:
                Text("\(Int(used * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.graphPrimary)
            case .singleValuePressure:
                Text("\(Int(pressure * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(pressureColor)
            case .usedFree:
                Text("12.4")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.graphPrimary)
                Text("/")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textTertiary)
                Text("8.0G")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    private var pressureColor: Color {
        if pressure > 0.8 { return theme.statusRed }
        if pressure > 0.5 { return theme.statusYellow }
        return theme.statusGreen
    }

    private var memoryHistoryBar: some View {
        GeometryReader { geo in
            Path { path in
                guard historyData.count > 1 else { return }
                let step = geo.size.width / CGFloat(historyData.count - 1)
                path.move(to: CGPoint(x: 0, y: geo.size.height * (1 - historyData[0])))
                for i in 1..<historyData.count {
                    path.addLine(to: CGPoint(x: CGFloat(i) * step,
                                             y: geo.size.height * (1 - historyData[i])))
                }
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                path.closeSubpath()
            }
            .fill(theme.graphPrimary.opacity(0.3))

            Path { path in
                guard historyData.count > 1 else { return }
                let step = geo.size.width / CGFloat(historyData.count - 1)
                path.move(to: CGPoint(x: 0, y: geo.size.height * (1 - historyData[0])))
                for i in 1..<historyData.count {
                    path.addLine(to: CGPoint(x: CGFloat(i) * step,
                                             y: geo.size.height * (1 - historyData[i])))
                }
            }
            .stroke(theme.graphPrimary, style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        .frame(width: 30, height: 14)
    }
}

// MARK: - Memory Dropdown Menu

struct ISMemoryMenu: View {
    let appMemory: CGFloat
    let wiredMemory: CGFloat
    let compressedMemory: CGFloat
    let pressure: CGFloat
    let swapUsed: CGFloat
    let pageIns: [CGFloat]
    let pageOuts: [CGFloat]
    let processes: [(name: String, usage: CGFloat)]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ISLayout.sectionGap) {
            // Memory Overview
            ISGraphSection(title: "Memory", subtitle: "16 GB") {
                HStack(spacing: 12) {
                    ISMultiRingGraph(rings: [
                        .init(value: appMemory, color: theme.graphPrimary),
                        .init(value: wiredMemory, color: theme.graphSecondary),
                        .init(value: compressedMemory, color: theme.graphTertiary)
                    ], size: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        legendDot(color: theme.graphPrimary, label: "App",
                                  value: "\(Int(appMemory * 16)) GB")
                        legendDot(color: theme.graphSecondary, label: "Wired",
                                  value: "\(Int(wiredMemory * 16)) GB")
                        legendDot(color: theme.graphTertiary, label: "Compressed",
                                  value: "\(Int(compressedMemory * 16)) GB")
                    }
                }
            }

            ISDivider()

            // Pressure
            ISGraphSection(title: "Memory Pressure") {
                HStack(spacing: 8) {
                    ISCircularGraph(value: pressure, color: pressureColor, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pressureLabel)
                            .font(ISTypography.sectionBody)
                            .foregroundColor(pressureColor)
                        Text("Swap: \(String(format: "%.1f", swapUsed)) GB")
                            .font(ISTypography.sectionCaption)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }

            ISDivider()

            // Pages
            ISGraphSection(title: "Page Activity") {
                ISHistoryGraph(dataPoints: pageIns,
                              color: theme.graphPrimary,
                              secondaryColor: theme.graphTertiary,
                              secondaryData: pageOuts,
                              height: 50)
                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(theme.graphPrimary).frame(width: 6, height: 6)
                        Text("Page Ins")
                            .font(ISTypography.sectionCaption)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(theme.graphTertiary).frame(width: 6, height: 6)
                        Text("Page Outs")
                            .font(ISTypography.sectionCaption)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }

            ISDivider()

            // Swap
            ISMenuRow(label: "Swap Used",
                     value: "\(String(format: "%.1f", swapUsed)) GB",
                     valueColor: swapUsed > 1 ? theme.statusYellow : theme.textSecondary)

            ISDivider()

            // Processes
            ISSectionHeader(title: "Processes")
            ForEach(0..<processes.count, id: \.self) { i in
                ISProcessRow(name: processes[i].name,
                            value: "\(String(format: "%.1f", processes[i].usage)) GB",
                            color: theme.graphPrimary)
            }
        }
    }

    private var pressureColor: Color {
        if pressure > 0.8 { return theme.statusRed }
        if pressure > 0.5 { return theme.statusYellow }
        return theme.statusGreen
    }

    private var pressureLabel: String {
        if pressure > 0.8 { return "Critical" }
        if pressure > 0.5 { return "High" }
        if pressure > 0.25 { return "Moderate" }
        return "Normal"
    }

    private func legendDot(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(ISTypography.sectionCaption)
                .foregroundColor(theme.textSecondary)
            Text(value)
                .font(ISTypography.sectionCaption)
                .foregroundColor(theme.textTertiary)
        }
    }
}
