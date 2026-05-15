import SwiftUI

struct BlockManagementCard: View {
    @Binding var tabs: [CompanionContinentPreviewTab]
    @Binding var selectedTabID: UUID
    
    var body: some View {
        ConfigCardContainer {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("板块管理")
                        .font(ContinentConfigTypography.cardTitle)
                        .foregroundColor(ContinentConfigTokens.primaryText)
                    Text("管理大陆展开态的板块与内容")
                        .font(ContinentConfigTypography.cardSubtitle)
                        .foregroundColor(ContinentConfigTokens.secondaryText)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                
                VStack(spacing: 8) {
                    ForEach(tabs) { tab in
                        BlockManageRow(
                            tab: tab,
                            isSelected: selectedTabID == tab.id
                        ) {
                            selectedTabID = tab.id
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 18)
                
                Button {
                    let nextIndex = tabs.filter { !$0.isDefault }.count + 1
                    let newTab = CompanionContinentPreviewTab(
                        id: UUID(),
                        name: "专注工作",
                        icon: "target",
                        layout: .custom,
                        enabledModules: [.timeline, .quickActions, .weather],
                        isDefault: false
                    )
                    tabs.append(newTab)
                    selectedTabID = newTab.id
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("新建模块")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(ContinentConfigTokens.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ContinentConfigTokens.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(ContinentConfigTokens.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
    }
}

struct BlockManageRow: View {
    let tab: CompanionContinentPreviewTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(blockColor(for: tab.name))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(blockIconColor(for: tab.name))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ContinentConfigTokens.primaryText)
                    Text("\(tab.enabledModules.count) 个内容")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(ContinentConfigTokens.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ContinentConfigTokens.tertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(height: 52)
            .background(
                isSelected 
                    ? Color.black.opacity(0.04)
                    : ContinentConfigTokens.cardBackground,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ContinentConfigTokens.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    private func blockColor(for name: String) -> Color {
        switch name {
        case "今日": return Color(hex: "#FFF3E0")
        case "音乐": return Color(hex: "#FFE8E8")
        case "AI": return Color(hex: "#F1F5F9")
        case "日程": return Color(hex: "#E8F1FF")
        default: return Color(hex: "#E9F8EF")
        }
    }
    
    private func blockIconColor(for name: String) -> Color {
        switch name {
        case "今日": return ContinentConfigTokens.accentOrange
        case "音乐": return ContinentConfigTokens.accentRed
        case "AI": return ContinentConfigTokens.primaryText
        case "日程": return ContinentConfigTokens.accentBlue
        default: return ContinentConfigTokens.accentGreen
        }
    }
}