import SwiftUI

// MARK: - Disks Menubar Item

struct ISDisksMenubarItem: View {
    let diskName: String
    let usedPercent: CGFloat
    let readSpeed: String
    let writeSpeed: String
    let readActive: Bool
    let writeActive: Bool
    var mode: DisplayMode = .labelValue

    enum DisplayMode {
        case icon, label, labelValue, percentage
        case verticalGraph, circularGraph, pieGraph
        case labelGraph, usedFree, diskActivity
        case spaceBar
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .icon:
                Image(systemName: "internaldrive")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            case .label:
                Text("DISK")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
            case .labelValue:
                Text("DISK")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                Text("\(Int(usedPercent * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(usedColor)
            case .percentage:
                Text("\(Int(usedPercent * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(usedColor)
            case .verticalGraph:
                ISVerticalBarGraph(values: [usedPercent], colors: [usedColor],
                                   width: 6, height: 14)
            case .circularGraph:
                ISCircularGraph(value: usedPercent, color: usedColor,
                               lineWidth: 2.5, size: 16)
            case .pieGraph:
                ISPieGraph(slices: [(usedPercent, theme.graphPrimary),
                                    (1 - usedPercent, theme.graphBackground)],
                          size: 16)
            case .labelGraph:
                Text("DISK")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                spaceBarMenubar
            case .usedFree:
                Text("256")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.graphPrimary)
                Text("/")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textTertiary)
                Text("512G")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.textSecondary)
            case .diskActivity:
                HStack(spacing: 3) {
                    ISActivityDots(readActive: readActive, writeActive: writeActive,
                                  readColor: theme.graphPrimary, writeColor: theme.graphTertiary)
                    Text(readSpeed)
                        .font(ISTypography.menubarValue)
                        .foregroundColor(theme.graphPrimary)
                }
            case .spaceBar:
                spaceBarMenubar
            }
        }
    }

    private var usedColor: Color {
        if usedPercent > 0.9 { return theme.statusRed }
        if usedPercent > 0.75 { return theme.statusYellow }
        return theme.graphPrimary
    }

    private var spaceBarMenubar: some View {
        ISVerticalBarGraph(values: [usedPercent], colors: [usedColor],
                           width: 24, height: 14, cornerRadius: 2)
    }
}

// MARK: - Disks Dropdown Menu

struct ISDisksMenu: View {
    struct DiskInfo {
        let name: String
        let used: CGFloat
        let total: String
        let usedGB: String
        let freeGB: String
    }

    let disks: [DiskInfo]
    let readSpeed: String
    let writeSpeed: String
    let readHistory: [CGFloat]
    let writeHistory: [CGFloat]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ISLayout.sectionGap) {
            // Disk List
            ForEach(0..<disks.count, id: \.self) { i in
                diskSection(disks[i])
                if i < disks.count - 1 { ISDivider() }
            }

            ISDivider()

            // Activity
            ISGraphSection(title: "Disk Activity") {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Circle().fill(theme.graphPrimary).frame(width: 5, height: 5)
                            Text("Read")
                                .font(ISTypography.sectionCaption)
                                .foregroundColor(theme.textTertiary)
                        }
                        Text(readSpeed)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.graphPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Circle().fill(theme.graphTertiary).frame(width: 5, height: 5)
                            Text("Write")
                                .font(ISTypography.sectionCaption)
                                .foregroundColor(theme.textTertiary)
                        }
                        Text(writeSpeed)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.graphTertiary)
                    }
                }
            }

            ISDivider()

            // Activity History
            ISGraphSection(title: "Activity History") {
                ISHistoryGraph(dataPoints: readHistory,
                              color: theme.graphPrimary,
                              secondaryColor: theme.graphTertiary,
                              secondaryData: writeHistory)
            }
        }
    }

    private func diskSection(_ disk: DiskInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
                Text(disk.name)
                    .font(ISTypography.sectionHeader)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(Int(disk.used * 100))%")
                    .font(ISTypography.sectionBody)
                    .foregroundColor(usedColor(disk.used))
            }

            ISSpaceBar(used: disk.used, color: usedColor(disk.used), height: 5)

            HStack {
                Text("\(disk.usedGB) used")
                    .font(ISTypography.sectionCaption)
                    .foregroundColor(theme.textTertiary)
                Spacer()
                Text("\(disk.freeGB) free")
                    .font(ISTypography.sectionCaption)
                    .foregroundColor(theme.textTertiary)
                Text("/ \(disk.total)")
                    .font(ISTypography.sectionCaption)
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(.horizontal, ISLayout.menuPaddingH)
    }

    private func usedColor(_ percent: CGFloat) -> Color {
        if percent > 0.9 { return theme.statusRed }
        if percent > 0.75 { return theme.statusYellow }
        return theme.graphPrimary
    }
}
