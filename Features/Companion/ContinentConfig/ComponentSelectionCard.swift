import SwiftUI
import AcMindKit

struct ComponentSelectionCard: View {
    @Binding var selectedWidgetIDs: Set<String>
    
    var body: some View {
        ConfigCardContainer {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("组件选择")
                        .font(ContinentConfigTypography.cardTitle)
                        .foregroundColor(ContinentConfigTokens.primaryText)
                    Text("选择在胶囊与大陆中显示的模块")
                        .font(ContinentConfigTypography.cardSubtitle)
                        .foregroundColor(ContinentConfigTokens.secondaryText)
                }
                .padding(.horizontal, ContinentConfigLayout.cardPadding)
                .padding(.top, 18)
                
                componentSection(
                    title: "胶囊组件",
                    enabledCount: CompanionWidgetCatalog.capsuleWidgets.filter { selectedWidgetIDs.contains($0.id) }.count,
                    totalCount: CompanionWidgetCatalog.capsuleWidgets.count,
                    items: CompanionWidgetCatalog.capsuleWidgets
                )
                
                componentSection(
                    title: "大陆组件",
                    enabledCount: CompanionWidgetCatalog.continentWidgets.filter { selectedWidgetIDs.contains($0.id) }.count,
                    totalCount: CompanionWidgetCatalog.continentWidgets.count,
                    items: CompanionWidgetCatalog.continentWidgets
                )
            }
        }
    }
    
    private func componentSection(title: String, enabledCount: Int, totalCount: Int, items: [CompanionWidgetDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ContinentConfigTokens.primaryText)
                Text("已启用 \(enabledCount) / \(totalCount)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(ContinentConfigTokens.secondaryText)
            }
            .padding(.horizontal, ContinentConfigLayout.cardPadding)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(92), spacing: 24), count: 6),
                alignment: .center,
                spacing: 14
            ) {
                ForEach(items) { item in
                    ComponentTogglePill(
                        item: item,
                        isSelected: selectedWidgetIDs.contains(item.id)
                    ) {
                        toggleWidget(item.id)
                    }
                }
            }
            .padding(.horizontal, ContinentConfigLayout.cardPadding)
        }
    }
    
    private func toggleWidget(_ id: String) {
        if selectedWidgetIDs.contains(id) {
            selectedWidgetIDs.remove(id)
        } else {
            selectedWidgetIDs.insert(id)
        }
    }
}

struct ComponentTogglePill: View {
    let item: CompanionWidgetDefinition
    let isSelected: Bool
    let toggle: () -> Void
    
    var body: some View {
        Button(action: toggle) {
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: item.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(isSelected ? .white : ContinentConfigTokens.secondaryText)
                .padding(.horizontal, 22)
                .padding(.vertical, 5)
                .frame(width: 86, height: 28)
                .background(
                    isSelected 
                        ? ContinentConfigTokens.blackCapsule
                        : ContinentConfigTokens.softFill,
                    in: Capsule()
                )
                .overlay(
                    isSelected 
                        ? Circle()
                            .fill(ContinentConfigTokens.accentBlue)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 30, y: -7)
                        : nil
                )
                
                Text(item.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? ContinentConfigTokens.primaryText : ContinentConfigTokens.tertiaryText)
                    .lineLimit(1)
            }
            .frame(width: 92, height: 44, alignment: .center)
            .opacity(item.isEnabled ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
    }
}