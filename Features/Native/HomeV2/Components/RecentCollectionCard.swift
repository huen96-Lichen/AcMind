import SwiftUI

struct RecentCollectionCard: View {
    let model: WorkbenchV2MockData.RecentCollection
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        WorkbenchV2Card(title: model.title, debugName: "RecentCollectionCard", state: model.state, layout: layout) {
            VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.sm) {
                if model.items.isEmpty {
                    WorkbenchV2EmptyState(text: "暂无最近收集")
                } else {
                    ForEach(model.items) { item in
                        HStack(alignment: .firstTextBaseline, spacing: WorkbenchV2Tokens.Spacing.sm) {
                            VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.xxs) {
                                Text(item.title)
                                    .font(.system(size: WorkbenchV2Tokens.Typography.body, weight: .semibold))
                                Text(item.detail)
                                    .font(.system(size: WorkbenchV2Tokens.Typography.caption))
                                    .foregroundStyle(layout.showSecondaryCopy ? WorkbenchV2Tokens.Color.textSecondary : WorkbenchV2Tokens.Color.textTertiary)
                                    .lineLimit(layout.showSecondaryCopy ? 2 : 1)
                            }
                            Spacer(minLength: 0)
                            Text(item.timeLabel)
                                .font(.system(size: WorkbenchV2Tokens.Typography.caption, design: .monospaced))
                                .foregroundStyle(WorkbenchV2Tokens.Color.textTertiary)
                        }
                    }
                }
            }
        }
    }
}

struct RecentCollectionCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RecentCollectionCard(model: WorkbenchV2MockData.preview().recentCollection, layout: WorkbenchV2Layout.resolve(for: CGSize(width: 360, height: 180)))
            RecentCollectionCard(model: .init(state: .empty, title: "最近收集", items: []), layout: WorkbenchV2Layout.resolve(for: CGSize(width: 360, height: 180)))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
