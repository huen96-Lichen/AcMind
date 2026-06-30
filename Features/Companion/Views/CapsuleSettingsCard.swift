import SwiftUI

struct CapsuleSettingsCard: View {
    @Binding var isEnabled: Bool
    let isGlobalEnabled: Bool
    @Binding var position: CompanionCapsulePosition
    @Binding var isExpanded: Bool
    
    var body: some View {
        CompanionCapabilityCard(
            iconName: "capsule.portrait.fill",
            iconColor: .blue,
            title: "随身胶囊",
            description: "在屏幕顶部显示随身胶囊，快速访问常用能力。",
            isEnabled: isEnabled,
            isGlobalEnabled: isGlobalEnabled,
            toggleEnabled: $isEnabled
        ) {
            HStack(spacing: 24) {
                // 左侧：设置
                VStack(alignment: .leading, spacing: 16) {
                    // 展示位置
                    VStack(alignment: .leading, spacing: 8) {
                        Text("展示位置")
                            .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                        
                        Picker("位置", selection: $position) {
                            ForEach(CompanionCapsulePosition.allCases, id: \.self) { pos in
                                Text(pos.displayName).tag(pos)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // 默认展开
                    Toggle("启动后默认展开随身入口", isOn: $isExpanded)
                        .disabled(!isEnabled)
                }
                
                Spacer()
                
                // 右侧：预览
                CapsulePreview(position: position, isEnabled: isEnabled)
                    .frame(width: 200)
            }
        }
    }
}
