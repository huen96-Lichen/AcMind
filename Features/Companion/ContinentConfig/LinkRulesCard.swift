import SwiftUI

struct LinkRulesCard: View {
    @Binding var capsuleEnabled: Bool
    @Binding var continentEnabled: Bool
    @Binding var capsuleToContinentEnabled: Bool
    @Binding var continentToCapsuleEnabled: Bool
    
    var body: some View {
        ConfigCardContainer {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("联动规则")
                        .font(ContinentConfigTypography.cardTitle)
                        .foregroundColor(ContinentConfigTokens.primaryText)
                    Text("四个核心开关，保持桌面与顶部的联动关系")
                        .font(ContinentConfigTypography.cardSubtitle)
                        .foregroundColor(ContinentConfigTokens.secondaryText)
                }
                .padding(.horizontal, ContinentConfigLayout.cardPadding)
                .padding(.top, 18)
                .frame(height: 48)
                
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(116)),
                        GridItem(.fixed(116))
                    ],
                    spacing: 14
                ) {
                    RuleToggleCard(
                        title: "启用灵动胶囊",
                        subtitle: "桌面入口",
                        symbolName: "capsule",
                        isOn: $capsuleEnabled
                    )
                    RuleToggleCard(
                        title: "启用灵动大陆",
                        subtitle: "顶部停靠",
                        symbolName: "dock.top",
                        isOn: $continentEnabled
                    )
                    RuleToggleCard(
                        title: "拖到顶部切换",
                        subtitle: "胶囊 → 大陆",
                        symbolName: "arrow.up.to.line.compact",
                        isOn: $capsuleToContinentEnabled
                    )
                    RuleToggleCard(
                        title: "长按拖回桌面",
                        subtitle: "大陆 → 胶囊",
                        symbolName: "arrow.down.to.line.compact",
                        isOn: $continentToCapsuleEnabled
                    )
                }
                .padding(.horizontal, 26)
                .padding(.top, 14)
            }
        }
    }
}

struct RuleToggleCard: View {
    let title: String
    let subtitle: String
    let symbolName: String
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(Color(hex: "#F1F5F9"))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: symbolName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ContinentConfigTokens.accentBlue)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ContinentConfigTokens.primaryText)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(ContinentConfigTokens.secondaryText)
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(ContinentConfigTokens.accentBlue)
                    .frame(width: 34, height: 20)
            }
            
            HStack(spacing: 4) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isOn ? ContinentConfigTokens.accentBlue : ContinentConfigTokens.secondaryText)
                Text(isOn ? "已启用" : "未启用")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(ContinentConfigTokens.secondaryText)
            }
        }
        .padding(12)
        .frame(width: 116, height: 116)
        .background(ContinentConfigTokens.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ContinentConfigTokens.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.025), radius: 8, x: 0, y: 2)
    }
}