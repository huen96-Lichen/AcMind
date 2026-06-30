import SwiftUI

struct CompanionSettingsHeader: View {
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左侧：标题与说明
            VStack(alignment: .leading, spacing: 4) {
                Text("随身")
                    .font(.system(size: AppSurfaceTokens.Typography.pageTitle, weight: .bold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                
                Text("AcWork 跨页面、跨应用、可随时调用的系统能力域。")
                    .font(.system(size: AppSurfaceTokens.Typography.body))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            
            Spacer()
            
            // 右侧：总开关
            HStack(spacing: 8) {
                Text("启用随身能力")
                    .font(.system(size: AppSurfaceTokens.Typography.body))
                    .foregroundStyle(isEnabled ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
            }
        }
        .padding(.bottom, AppSurfaceTokens.Spacing.xs)
        .frame(height: 72)
    }
}
