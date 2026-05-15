import SwiftUI
import AcMindKit

struct AdvancedDebugBar: View {
    @ObservedObject var coordinator: DynamicSurfaceCoordinator
    let capsulePosition: String
    let continentScreen: String
    let launchSurface: String
    @Binding var debugDisclosureExpanded: Bool
    
    var body: some View {
        DisclosureGroup(isExpanded: $debugDisclosureExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                debugRow(label: "可见形态", value: coordinator.visibilityState.displayName)
                debugRow(label: "拖拽阶段", value: coordinator.dragPhase.displayName)
                debugRow(label: "胶囊位置记忆", value: capsulePosition)
                debugRow(label: "大陆停靠记忆", value: continentScreen)
                debugRow(label: "默认启动形态", value: launchSurface)
                debugRow(label: "顶部热区", value: "96px")
            }
            .padding(.top, 8)
            .padding(.horizontal, ContinentConfigLayout.cardPadding)
            .padding(.bottom, 16)
        } label: {
            HStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ContinentConfigTokens.secondaryText)
                Text("高级调试信息")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ContinentConfigTokens.primaryText)
                Spacer()
                Text("仅开发时展开")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(ContinentConfigTokens.secondaryText)
            }
        }
        .accentColor(ContinentConfigTokens.accentBlue)
        .background(ContinentConfigTokens.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ContinentConfigTokens.border, lineWidth: 1))
    }
    
    private func debugRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ContinentConfigTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(ContinentConfigTokens.primaryText)
        }
    }
}