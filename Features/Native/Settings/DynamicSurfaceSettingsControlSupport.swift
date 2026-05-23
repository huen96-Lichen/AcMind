import AppKit
import SwiftUI
import AcMindKit

extension DynamicSurfaceCommercialView {
    var debugBar: some View {
        ACCard(padding: 14) {
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ACColors.accentBlue)
                    Text("高级调试")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                }

                Divider()
                    .frame(height: 18)

                Text("当前模式：\(selectedMode.title)")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)

                Text("当前板块：\(selectedContinentTab.name)")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    debugExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(debugExpanded ? "收起" : "展开")
                        Image(systemName: debugExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.accentBlue)

                ACBadge("LIVE", kind: .blue)
            }
        }
        .frame(height: 56)
    }

    func widgetGroup(title: String, count: Int, items: [SurfaceWidgetItem]) -> some View {
        widgetGroup(title: title, count: count, items: items, columns: 4)
    }

    func widgetGroup(title: String, count: Int, items: [SurfaceWidgetItem], columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                Text("已启用 \(count) 个")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
                spacing: 8
            ) {
                ForEach(items) { item in
                    Button {
                        if selectedWidgetIDs.contains(item.id) {
                            selectedWidgetIDs.remove(item.id)
                        } else {
                            selectedWidgetIDs.insert(item.id)
                        }
                    } label: {
                        SurfaceWidgetChip(item: item, isSelected: selectedWidgetIDs.contains(item.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
