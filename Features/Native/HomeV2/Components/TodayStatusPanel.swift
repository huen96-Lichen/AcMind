import SwiftUI

struct TodayStatusPanel: View {
    let model: WorkbenchV2DashboardData.TodayStatus
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        WorkbenchV2Card(title: model.title, state: model.state, layout: layout) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.subtitle)
                    .font(.system(size: WorkbenchV2Tokens.Typography.caption))
                    .foregroundStyle(layout.showSecondaryCopy ? WorkbenchV2Tokens.Color.textSecondary : WorkbenchV2Tokens.Color.textSecondary.opacity(0.88))
                    .lineLimit(layout.showSecondaryCopy ? 2 : 1)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(model.items) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.tint.opacity(0.14))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.label)
                                    .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium))
                                    .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                                Text(item.value)
                                    .font(.system(size: WorkbenchV2Tokens.Typography.body, weight: .semibold))
                                    .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                                .fill(WorkbenchV2Tokens.Color.surfaceSoft)
                        )
                    }
                }
            }
        }
    }
}

#if DEBUG
struct TodayStatusPanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TodayStatusPanel(model: WorkbenchV2DashboardData.preview().todayStatus, layout: WorkbenchV2Layout.resolve(for: CGSize(width: 292, height: 220)))
            TodayStatusPanel(
                model: .init(state: .empty, title: "今日状态", subtitle: "数据尚未同步", items: [], toggles: [], statusBlocks: []),
                layout: WorkbenchV2Layout.resolve(for: CGSize(width: 292, height: 220))
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
