import SwiftUI

struct ContinentConfigHeaderView: View {
    @Binding var selectedSurface: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("灵动胶囊 / 大陆 配置中心")
                    .font(ContinentConfigTypography.pageTitle)
                    .foregroundColor(ContinentConfigTokens.primaryText)
                Text("配置桌面入口与顶部大陆，打造你的专属交互体验")
                    .font(ContinentConfigTypography.pageSubtitle)
                    .foregroundColor(ContinentConfigTokens.secondaryText)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                headerButton(title: "桌面胶囊", isSelected: selectedSurface == "capsule") {
                    selectedSurface = "capsule"
                }
                headerButton(title: "顶部大陆", isSelected: selectedSurface == "continent") {
                    selectedSurface = "continent"
                }
                headerButton(title: "配置中心", isSelected: selectedSurface == "config") {
                    selectedSurface = "config"
                }
            }
        }
    }
    
    private func headerButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? ContinentConfigTokens.accentBlue : ContinentConfigTokens.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    isSelected 
                        ? ContinentConfigTokens.cardBackground
                        : Color.clear,
                    in: Capsule()
                )
                .shadow(color: isSelected ? Color.black.opacity(0.06) : .clear, radius: 12, x: 0, y: 4)
                .overlay(
                    Capsule().stroke(isSelected ? ContinentConfigTokens.border : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
