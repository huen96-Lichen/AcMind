import SwiftUI
import Charts

struct ActivityTrendCard: View {
    let model: WorkbenchV2DashboardData.ActivityTrend
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        WorkbenchV2Card(title: model.title, debugName: "ActivityTrendCard", state: model.state, layout: layout) {
            VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.md) {
                if model.primarySeries.values.isEmpty {
                    WorkbenchV2EmptyState(text: model.emptyMessage)
                        .frame(minHeight: 150)
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

struct WorkbenchTrendChart: View {
    let primarySeries: WorkbenchV2DashboardData.TrendSeries
    let secondarySeries: WorkbenchV2DashboardData.TrendSeries

    var body: some View {
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
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(WorkbenchV2Tokens.Color.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous))
        }
        .chartLegend(.hidden)
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
                    emptyMessage: "暂无趋势数据"
                ),
                layout: WorkbenchV2Layout.resolve(for: CGSize(width: 927, height: 240))
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
