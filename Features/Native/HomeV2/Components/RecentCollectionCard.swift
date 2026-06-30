import SwiftUI

struct RecentCollectionCard: View {
    let model: WorkbenchV2DashboardData.RecentCollection
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        WorkbenchV2Card(title: model.title, debugName: "RecentCollectionCard", state: model.state, layout: layout) {
            VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.sm) {
                if model.items.isEmpty {
                    WorkbenchV2EmptyState(text: "最近尚无新增收集")
                } else {
                    ForEach(model.items.prefix(maxVisibleItems)) { item in
                        HStack(alignment: .center, spacing: WorkbenchV2Tokens.Spacing.sm) {
                            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.control, style: .continuous)
                                .fill(WorkbenchV2Tokens.Color.surfaceSoft)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                                )

                            VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.xxs) {
                                Text(item.title)
                                    .font(.system(size: WorkbenchV2Tokens.Typography.body, weight: .semibold))
                                    .lineLimit(1)
                                Text(item.detail)
                                    .font(.system(size: WorkbenchV2Tokens.Typography.caption))
                                    .foregroundStyle(layout.showSecondaryCopy ? WorkbenchV2Tokens.Color.textSecondary : WorkbenchV2Tokens.Color.textSecondary.opacity(0.88))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Text(item.timeLabel)
                                .font(.system(size: WorkbenchV2Tokens.Typography.caption, design: .monospaced))
                                .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary.opacity(0.9))
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
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
struct RecentCollectionCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RecentCollectionCard(model: WorkbenchV2DashboardData.preview().recentCollection, layout: WorkbenchV2Layout.resolve(for: CGSize(width: 360, height: 180)))
            RecentCollectionCard(model: .init(state: .empty, title: "最近收集", items: []), layout: WorkbenchV2Layout.resolve(for: CGSize(width: 360, height: 180)))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
