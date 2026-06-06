import SwiftUI

// MARK: - Battery Menubar Item

struct ISBatteryMenubarItem: View {
    let level: CGFloat
    let isCharging: Bool
    let timeRemaining: String
    var mode: DisplayMode = .icon

    enum DisplayMode {
        case icon, iconFilled, label, labelValue
        case singleValuePercentage, singleValueTime
        case dualValue, horizontalGraph, verticalGraph
        case roundGraph, circularGraph
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .icon:
                batteryIcon
            case .iconFilled:
                batteryFilledIcon
            case .label:
                Text("BAT")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
            case .labelValue:
                Text("BAT")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                Text("\(Int(level * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(batteryColor)
            case .singleValuePercentage:
                Text("\(Int(level * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(batteryColor)
            case .singleValueTime:
                Text(timeRemaining)
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.textPrimary)
            case .dualValue:
                HStack(spacing: 2) {
                    Text("\(Int(level * 100))%")
                        .font(ISTypography.menubarValue)
                        .foregroundColor(batteryColor)
                    Text(timeRemaining)
                        .font(ISTypography.menubarLabel)
                        .foregroundColor(theme.textTertiary)
                }
            case .horizontalGraph:
                horizontalBatteryBar
            case .verticalGraph:
                ISVerticalBarGraph(values: [level], colors: [batteryColor],
                                   width: 6, height: 14)
            case .roundGraph:
                ISCircularGraph(value: level, color: batteryColor,
                               lineWidth: 2.5, size: 16)
            case .circularGraph:
                ISCircularGraph(value: level, color: batteryColor,
                               lineWidth: 2.5, size: 16)
            }
        }
    }

    private var batteryColor: Color {
        if isCharging { return theme.statusGreen }
        if level < 0.1 { return theme.statusRed }
        if level < 0.2 { return theme.statusYellow }
        return theme.graphPrimary
    }

    private var batteryIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(theme.textPrimary, lineWidth: 1)
                .frame(width: 20, height: 10)

            RoundedRectangle(cornerRadius: 1)
                .fill(theme.textPrimary)
                .frame(width: 2, height: 5)
                .offset(x: 11)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(batteryColor)
                    .frame(width: 15 * level, height: 6)
                Spacer(minLength: 0)
            }
            .frame(width: 16, height: 6)
        }
        .frame(width: 24, height: 12)
    }

    private var batteryFilledIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(batteryColor.opacity(0.2))
                .frame(width: 20, height: 10)

            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(batteryColor, lineWidth: 1)
                .frame(width: 20, height: 10)

            RoundedRectangle(cornerRadius: 1)
                .fill(batteryColor)
                .frame(width: 2, height: 5)
                .offset(x: 11)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(batteryColor)
                    .frame(width: 15 * level, height: 6)
                Spacer(minLength: 0)
            }
            .frame(width: 16, height: 6)
        }
        .frame(width: 24, height: 12)
    }

    private var horizontalBatteryBar: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(theme.textPrimary, lineWidth: 0.5)
                .frame(width: 22, height: 8)
                .overlay(
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(batteryColor)
                            .frame(width: 18 * level, height: 4)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 18, height: 4)
                )
            Text("\(Int(level * 100))%")
                .font(ISTypography.menubarValue)
                .foregroundColor(batteryColor)
        }
    }
}

// MARK: - Battery Dropdown Menu

struct ISBatteryMenu: View {
    let level: CGFloat
    let isCharging: Bool
    let health: CGFloat
    let cycles: Int
    let timeRemaining: String
    let condition: String
    let source: String
    let historyData: [CGFloat]
    let airpodsName: String?
    let airpodsLevel: CGFloat?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ISLayout.sectionGap) {
            // Battery Overview
            ISGraphSection(title: "Battery") {
                HStack(spacing: 12) {
                    ISCircularGraph(value: level, color: batteryColor, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        ISMenuRow(label: "Condition", value: condition,
                                 valueColor: conditionColor)
                        ISMenuRow(label: "Source", value: source)
                        ISMenuRow(label: "Time", value: timeRemaining,
                                 valueColor: theme.textPrimary)
                    }
                }
            }

            ISDivider()

            // Health & Cycles
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Health")
                        .font(ISTypography.sectionCaption)
                        .foregroundColor(theme.textTertiary)
                    Text("\(Int(health * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(healthColor)
                }
                .padding(.leading, ISLayout.menuPaddingH)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cycles")
                        .font(ISTypography.sectionCaption)
                        .foregroundColor(theme.textTertiary)
                    Text("\(cycles)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                }
            }

            ISDivider()

            // History
            ISGraphSection(title: "Charge History") {
                ISHistoryGraph(dataPoints: historyData,
                              color: batteryColor,
                              height: 40)
            }

            // AirPods
            if let name = airpodsName, let level = airpodsLevel {
                ISDivider()
                ISGraphSection(title: name) {
                    HStack(spacing: 8) {
                        ISVerticalBarGraph(values: [level], colors: [theme.graphPrimary],
                                           width: 6, height: 20)
                        Text("\(Int(level * 100))%")
                            .font(ISTypography.sectionBody)
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }
        }
    }

    private var batteryColor: Color {
        if isCharging { return theme.statusGreen }
        if level < 0.1 { return theme.statusRed }
        if level < 0.2 { return theme.statusYellow }
        return theme.graphPrimary
    }

    private var conditionColor: Color {
        switch condition {
        case "Normal": return theme.statusGreen
        case "Replace Soon", "Service Battery": return theme.statusYellow
        case "Replace Now": return theme.statusRed
        default: return theme.textSecondary
        }
    }

    private var healthColor: Color {
        if health > 0.8 { return theme.statusGreen }
        if health > 0.5 { return theme.statusYellow }
        return theme.statusRed
    }
}
