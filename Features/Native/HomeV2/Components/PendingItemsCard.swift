import SwiftUI

struct PendingItemsCard: View {
    let model: WorkbenchV2DashboardData.PendingItems
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        WorkbenchV2Card(title: model.title, debugName: "PendingItemsCard", state: model.state, layout: layout) {
            VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.sm) {
                if model.items.isEmpty {
                    WorkbenchV2EmptyState(text: "没有待处理项")
                } else {
                    ForEach(model.items.prefix(maxVisibleItems)) { item in
                        HStack(alignment: .top, spacing: WorkbenchV2Tokens.Spacing.sm) {
                            Text(item.priority)
                                .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WorkbenchV2Tokens.Color.accent)
                                .frame(width: 32, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: WorkbenchV2Tokens.Typography.body, weight: .semibold))
                                    .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                                    .lineLimit(1)
                                Text(item.detail)
                                    .font(.system(size: WorkbenchV2Tokens.Typography.caption))
                                    .foregroundStyle(layout.showSecondaryCopy ? WorkbenchV2Tokens.Color.textSecondary : WorkbenchV2Tokens.Color.textSecondary.opacity(0.88))
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    private var maxVisibleItems: Int {
        2
    }
}

#if DEBUG
struct PendingItemsCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PendingItemsCard(model: WorkbenchV2DashboardData.preview().pendingItems, layout: WorkbenchV2Layout.resolve(for: CGSize(width: 360, height: 200)))
            PendingItemsCard(
                model: .init(state: .empty, title: "待处理", items: []),
                layout: WorkbenchV2Layout.resolve(for: CGSize(width: 360, height: 200))
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
