import SwiftUI
import Charts

struct ActivityTrendCard: View {
    let model: WorkbenchV2DashboardData.ActivityTrend
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        WorkbenchV2Card(title: model.title, debugName: "ActivityTrendCard", state: model.state, layout: layout) {
            VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.md) {
                if model.primarySeries.values.isEmpty {
                    WorkbenchTrendEmptyChart(message: model.emptyMessage)
                } else {
                    WorkbenchTrendChart(
                        primarySeries: model.primarySeries,
                        secondarySeries: model.secondarySeries
                    )
                }
            }
        }
    }
}

private struct WorkbenchTrendEmptyChart: View {
    let message: String
    private let timeLabels = ["00:00", "04:00", "08:00", "12:00", "16:00", "20:00", "24:00"]

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.xs) {
            HStack(alignment: .top, spacing: WorkbenchV2Tokens.Spacing.sm) {
                VStack(spacing: 0) {
                    Text("100%")
                    Spacer(minLength: 0)
                    Text("50%")
                    Spacer(minLength: 0)
                    Text("0%")
                }
                .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium, design: .monospaced))
                .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                .frame(width: 34)

                GeometryReader { proxy in
                    ZStack {
                        VStack(spacing: 0) {
                            Divider()
                            Spacer(minLength: 0)
                            Divider()
                            Spacer(minLength: 0)
                            Divider()
                        }
                        .foregroundStyle(WorkbenchV2Tokens.Color.separator.opacity(0.18))

                        placeholderArea(in: proxy.size)
                            .fill(WorkbenchV2Tokens.Color.accent.opacity(0.06))

                        placeholderLine(in: proxy.size)
                            .stroke(
                                WorkbenchV2Tokens.Color.accent.opacity(0.34),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(Array(timeLabels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                    if index < timeLabels.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium, design: .monospaced))
            .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
            .padding(.leading, 42)

            Text(message)
                .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium))
                .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func placeholderLine(in size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * 0.68))
            path.addCurve(
                to: CGPoint(x: size.width * 0.38, y: size.height * 0.50),
                control1: CGPoint(x: size.width * 0.14, y: size.height * 0.58),
                control2: CGPoint(x: size.width * 0.24, y: size.height * 0.76)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.74, y: size.height * 0.42),
                control1: CGPoint(x: size.width * 0.50, y: size.height * 0.30),
                control2: CGPoint(x: size.width * 0.60, y: size.height * 0.48)
            )
            path.addCurve(
                to: CGPoint(x: size.width, y: size.height * 0.34),
                control1: CGPoint(x: size.width * 0.84, y: size.height * 0.34),
                control2: CGPoint(x: size.width * 0.92, y: size.height * 0.54)
            )
        }
    }

    private func placeholderArea(in size: CGSize) -> Path {
        var path = placeholderLine(in: size)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}

struct WorkbenchTrendChart: View {
    let primarySeries: WorkbenchV2DashboardData.TrendSeries
    let secondarySeries: WorkbenchV2DashboardData.TrendSeries

    private var xAxisValues: [Date] {
        guard
            let start = primarySeries.values.first?.timestamp,
            let end = primarySeries.values.last?.timestamp
        else {
            return []
        }

        return stride(from: start, through: end, by: 14_400).map { $0 }
    }

    private func xAxisLabel(for date: Date) -> String {
        guard let start = primarySeries.values.first?.timestamp else {
            return ""
        }

        let hours = Int(date.timeIntervalSince(start) / 3_600)
        return String(format: "%02d:00", hours)
    }

    var body: some View {
        VStack(spacing: WorkbenchV2Tokens.Spacing.xs) {
            Chart {
                ForEach(primarySeries.values) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(primarySeries.tint.opacity(0.12))

                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(primarySeries.tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }

                ForEach(secondarySeries.values) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Secondary", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(secondarySeries.tint.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                }
            }
            .chartXAxis {
                AxisMarks(values: xAxisValues) { _ in
                    AxisGridLine()
                        .foregroundStyle(WorkbenchV2Tokens.Color.separator.opacity(0.18))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(WorkbenchV2Tokens.Color.separator.opacity(0.18))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text("\(Int(number))%")
                                .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium, design: .monospaced))
                                .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(WorkbenchV2Tokens.Color.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous))
            }
            .chartLegend(.hidden)

            HStack(spacing: 0) {
                ForEach(Array(xAxisValues.enumerated()), id: \.offset) { index, date in
                    Text(xAxisLabel(for: date))
                        .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium, design: .monospaced))
                        .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)

                    if index < xAxisValues.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.leading, 36)
            .padding(.trailing, 2)
        }
    }
}

#if DEBUG
struct ActivityTrendCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ActivityTrendCard(model: WorkbenchV2DashboardData.preview().activityTrend, layout: WorkbenchV2Layout.resolve(for: CGSize(width: 927, height: 240)))
            ActivityTrendCard(
                model: .init(
                    state: .empty,
                    title: "活动趋势",
                    primarySeries: .init(name: "主曲线", tint: .blue, values: []),
                    secondarySeries: .init(name: "次曲线", tint: .green, values: []),
                    emptyMessage: "趋势待生成"
                ),
                layout: WorkbenchV2Layout.resolve(for: CGSize(width: 927, height: 240))
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
