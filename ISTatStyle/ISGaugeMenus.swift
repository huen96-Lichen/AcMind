import SwiftUI

// MARK: - Sensors Menubar Item

struct ISSensorsMenubarItem: View {
    let value: String
    let label: String
    var mode: DisplayMode = .labelValue

    enum DisplayMode {
        case icon, label, labelValue, value, dualValue
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .icon:
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            case .label:
                Text(label)
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
            case .labelValue:
                Text(label)
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                Text(value)
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.textPrimary)
            case .value:
                Text(value)
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.textPrimary)
            case .dualValue:
                VStack(spacing: 0) {
                    Text(value)
                        .font(ISTypography.menubarValue)
                        .foregroundColor(theme.graphPrimary)
                    Text(label)
                        .font(ISTypography.menubarLabel)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
    }
}

// MARK: - Sensors Dropdown Menu

struct ISSensorsMenu: View {
    struct SensorItem {
        let name: String
        let value: String
        let unit: String
        let type: SensorType
        let level: CGFloat
    }

    enum SensorType {
        case temperature, fan, voltage, power
    }

    let sensors: [SensorItem]
    let fanSpeeds: [(name: String, rpm: Int, maxRPM: Int)]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ISLayout.sectionGap) {
            // Temperature Sensors
            let tempSensors = sensors.filter { $0.type == .temperature }
            if !tempSensors.isEmpty {
                ISSectionHeader(title: "Temperatures")
                ForEach(0..<tempSensors.count, id: \.self) { i in
                    sensorRow(tempSensors[i])
                }
            }

            if !tempSensors.isEmpty && !fanSpeeds.isEmpty { ISDivider() }

            // Fans
            if !fanSpeeds.isEmpty {
                ISSectionHeader(title: "Fans")
                ForEach(0..<fanSpeeds.count, id: \.self) { i in
                    HStack {
                        Text(fanSpeeds[i].name)
                            .font(ISTypography.sectionBody)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text("\(fanSpeeds[i].rpm) RPM")
                            .font(ISTypography.dataValue)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.horizontal, ISLayout.menuPaddingH)
                    .padding(.vertical, 2)
                    ISSpaceBar(used: CGFloat(fanSpeeds[i].rpm) / CGFloat(fanSpeeds[i].maxRPM),
                              color: theme.graphPrimary, height: 3)
                        .padding(.horizontal, ISLayout.menuPaddingH)
                }
            }

            // Other sensors
            let otherSensors = sensors.filter { $0.type != .temperature }
            if !otherSensors.isEmpty {
                if !tempSensors.isEmpty || !fanSpeeds.isEmpty { ISDivider() }
                ForEach(0..<otherSensors.count, id: \.self) { i in
                    sensorRow(otherSensors[i])
                }
            }
        }
    }

    private func sensorRow(_ sensor: SensorItem) -> some View {
        HStack {
            Text(sensor.name)
                .font(ISTypography.sectionBody)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text("\(sensor.value)\(sensor.unit)")
                .font(ISTypography.dataValue)
                .foregroundColor(sensorColor(sensor))
        }
        .padding(.horizontal, ISLayout.menuPaddingH)
        .padding(.vertical, 2)
    }

    private func sensorColor(_ sensor: SensorItem) -> Color {
        switch sensor.type {
        case .temperature:
            if sensor.level > 0.85 { return theme.statusRed }
            if sensor.level > 0.65 { return theme.statusYellow }
            return theme.textSecondary
        default:
            return theme.textSecondary
        }
    }
}

// MARK: - GPU Menubar Item

struct ISGPUMenubarItem: View {
    let usage: CGFloat
    let memoryUsage: CGFloat
    let fps: Int?
    var mode: DisplayMode = .labelValue

    enum DisplayMode {
        case icon, label, labelValue, percentage
        case verticalGraph, circularGraph, historyGraph
        case fpsLabel, fpsValue, fpsLabelValue
        case labelGraphProcessor, labelGraphMemory
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .icon:
                Image(systemName: "gpu")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            case .label:
                Text("GPU")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
            case .labelValue:
                Text("GPU")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                Text("\(Int(usage * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.graphPrimary)
            case .percentage:
                Text("\(Int(usage * 100))%")
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.graphPrimary)
            case .verticalGraph:
                ISVerticalBarGraph(values: [usage], colors: [theme.graphPrimary],
                                   width: 6, height: 14)
            case .circularGraph:
                ISCircularGraph(value: usage, color: theme.graphPrimary,
                               lineWidth: 2.5, size: 16)
            case .historyGraph:
                Text("GPU")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
            case .fpsLabel:
                Text("FPS")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
            case .fpsValue:
                if let fps {
                    Text("\(fps)")
                        .font(ISTypography.menubarValue)
                        .foregroundColor(fpsColor(fps))
                }
            case .fpsLabelValue:
                Text("FPS")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                if let fps {
                    Text("\(fps)")
                        .font(ISTypography.menubarValue)
                        .foregroundColor(fpsColor(fps))
                }
            case .labelGraphProcessor:
                Text("GPU")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                ISVerticalBarGraph(values: [usage, memoryUsage],
                                   colors: [theme.graphPrimary, theme.graphSecondary],
                                   width: 8, height: 14)
            case .labelGraphMemory:
                Text("GPU")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                ISVerticalBarGraph(values: [memoryUsage], colors: [theme.graphSecondary],
                                   width: 6, height: 14)
            }
        }
    }

    private func fpsColor(_ fps: Int) -> Color {
        if fps >= 60 { return theme.statusGreen }
        if fps >= 30 { return theme.statusYellow }
        return theme.statusRed
    }
}

// MARK: - GPU Dropdown Menu

struct ISGPUMenu: View {
    let processorUsage: CGFloat
    let memoryUsage: CGFloat
    let memoryTotal: String
    let memoryUsed: String
    let fps: Int?
    let gpuType: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ISLayout.sectionGap) {
            ISSectionHeader(title: gpuType)

            // Usage
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    ISCircularGraph(value: processorUsage, color: theme.graphPrimary, size: 44)
                    Text("Processor")
                        .font(ISTypography.sectionCaption)
                        .foregroundColor(theme.textTertiary)
                }
                VStack(spacing: 4) {
                    ISCircularGraph(value: memoryUsage, color: theme.graphSecondary, size: 44)
                    Text("Memory")
                        .font(ISTypography.sectionCaption)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .padding(.horizontal, ISLayout.menuPaddingH)

            ISDivider()

            ISMenuRow(label: "VRAM Used", value: memoryUsed,
                     valueColor: theme.graphSecondary)
            ISMenuRow(label: "VRAM Total", value: memoryTotal)

            if let fps {
                ISDivider()
                ISMenuRow(label: "FPS", value: "\(fps)",
                         valueColor: fpsColor(fps))
            }
        }
    }

    private func fpsColor(_ fps: Int) -> Color {
        if fps >= 60 { return theme.statusGreen }
        if fps >= 30 { return theme.statusYellow }
        return theme.statusRed
    }
}

// MARK: - Load Menubar Item

struct ISLoadMenubarItem: View {
    let load1: String
    let load5: String
    let load15: String
    var mode: DisplayMode = .labelValue

    enum DisplayMode {
        case label, labelValue, value
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .label:
                Text("LOAD")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
            case .labelValue:
                Text("LOAD")
                    .font(ISTypography.menubarLabel)
                    .foregroundColor(theme.textPrimary)
                Text(load1)
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.textPrimary)
            case .value:
                Text(load1)
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.textPrimary)
            }
        }
    }
}

// MARK: - Weather Menubar Item

struct ISWeatherMenubarItem: View {
    let temperature: String
    let condition: String
    let icon: String
    var mode: DisplayMode = .singleValue

    enum DisplayMode {
        case singleValue, dualValue, icon
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .singleValue:
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.statusYellow)
                Text(temperature)
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.textPrimary)
            case .dualValue:
                VStack(spacing: 0) {
                    HStack(spacing: 2) {
                        Image(systemName: icon)
                            .font(.system(size: 8))
                            .foregroundColor(theme.statusYellow)
                        Text(temperature)
                            .font(ISTypography.menubarValue)
                            .foregroundColor(theme.textPrimary)
                    }
                    Text(condition)
                        .font(ISTypography.menubarLabel)
                        .foregroundColor(theme.textTertiary)
                }
            case .icon:
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.statusYellow)
            }
        }
    }
}

// MARK: - Time Menubar Item

struct ISTimeMenubarItem: View {
    let time: String
    let date: String?
    var mode: DisplayMode = .singleValue

    enum DisplayMode {
        case singleValue, dualValue
    }

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ISLayout.menubarItemSpacing) {
            switch mode {
            case .singleValue:
                Text(time)
                    .font(ISTypography.menubarValue)
                    .foregroundColor(theme.textPrimary)
            case .dualValue:
                VStack(spacing: 0) {
                    Text(time)
                        .font(ISTypography.menubarValue)
                        .foregroundColor(theme.textPrimary)
                    if let date {
                        Text(date)
                            .font(ISTypography.menubarLabel)
                            .foregroundColor(theme.textTertiary)
                    }
                }
            }
        }
    }
}
