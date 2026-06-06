import SwiftUI

// MARK: - CPU Menubar Item

struct ISCPUMenubarItem: View {
    let usage: CGFloat
    let systemUsage: CGFloat
    let coreUsages: [CGFloat]
    let historyData: [CGFloat]
    var mode: DisplayMode = .historyGraph

    enum DisplayMode {
        case icon, label, labelValue, percentage
        case verticalGraph, circularGraph, historyGraph, cores
        case labelGraph
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .icon:
                menubarIcon("cpu")
            case .label:
                menubarLabel("CPU")
            case .labelValue:
                menubarLabel("CPU")
                menubarValue("\(Int(usage * 100))%")
            case .percentage:
                menubarValue("\(Int(usage * 100))%")
            case .verticalGraph:
                ISVerticalBarGraph(
                    values: coreUsages.isEmpty ? [usage] : coreUsages,
                    colors: [theme.graphPrimary],
                    width: 12, height: 14
                )
            case .circularGraph:
                ISCircularGraph(value: usage, color: theme.graphPrimary,
                               lineWidth: 2.5, size: 16)
            case .historyGraph:
                ISHistoryGraphMenubar(dataPoints: historyData,
                                      primary: theme.graphPrimary,
                                      secondary: theme.graphTertiary)
            case .cores:
                cpuCoreBars
            case .labelGraph:
                menubarLabel("CPU")
                ISHistoryGraphMenubar(dataPoints: historyData,
                                      primary: theme.graphPrimary,
                                      secondary: theme.graphTertiary)
            }
        }
    }

    private var cpuCoreBars: some View {
        HStack(spacing: 1) {
            ForEach(0..<min(coreUsages.count, 10), id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i % 2 == 0 ? theme.graphPrimary : theme.statusGreen)
                    .frame(width: 2, height: 14 * coreUsages[i])
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(height: 14)
    }

    private func menubarIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(theme.textPrimary)
    }

    private func menubarLabel(_ text: String) -> some View {
        Text(text)
            .font(ISTypography.menubarLabel)
            .foregroundColor(theme.textPrimary)
    }

    private func menubarValue(_ text: String) -> some View {
        Text(text)
            .font(ISTypography.menubarValue)
            .foregroundColor(theme.textPrimary)
    }
}

// MARK: - CPU History Graph (Menubar-sized)

private struct ISHistoryGraphMenubar: View {
    let dataPoints: [CGFloat]
    let primary: Color
    let secondary: Color

    var body: some View {
        GeometryReader { geo in
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
            .fill(primary.opacity(0.3))

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
        .frame(width: 30, height: 14)
    }
}

// MARK: - CPU Dropdown Menu

struct ISCPUMenu: View {
    let totalUsage: CGFloat
    let systemUsage: CGFloat
    let userUsage: CGFloat
    let coreUsages: [CGFloat]
    let historyData: [CGFloat]
    let processes: [(name: String, usage: CGFloat)]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ISLayout.sectionGap) {
            // CPU Section
            ISGraphSection(title: "CPU", subtitle: "\(Int(totalUsage * 100))%") {
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        ISCircularGraph(value: totalUsage, color: theme.graphPrimary)
                        VStack(alignment: .leading, spacing: 4) {
                            ISMenuRow(label: "User", value: "\(Int(userUsage * 100))%",
                                      valueColor: theme.graphPrimary)
                            ISMenuRow(label: "System", value: "\(Int(systemUsage * 100))%",
                                      valueColor: theme.graphTertiary)
                        }
                    }
                }
            }

            ISDivider()

            // History Graph
            ISGraphSection(title: "History") {
                ISHistoryGraph(dataPoints: historyData,
                              color: theme.graphPrimary,
                              secondaryColor: theme.graphTertiary,
                              secondaryData: historyData.map { $0 * 0.3 })
            }

            ISDivider()

            // Core Usage
            ISGraphSection(title: "Core Usage") {
                coreGrid
            }

            ISDivider()

            // Processes
            ISSectionHeader(title: "Processes")
            ForEach(0..<processes.count, id: \.self) { i in
                ISProcessRow(name: processes[i].name,
                            value: "\(Int(processes[i].usage * 100))%",
                            color: theme.graphPrimary,
                            showBar: true,
                            barValue: processes[i].usage)
            }
        }
    }

    private var coreGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<coreUsages.count, id: \.self) { i in
                VStack(spacing: 2) {
                    ISCircularGraph(value: coreUsages[i],
                                   color: i < coreUsages.count / 2 ? theme.statusGreen : theme.accent,
                                   lineWidth: 2, size: 32)
                    Text("C\(i)")
                        .font(ISTypography.graphLabel)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
    }
}
