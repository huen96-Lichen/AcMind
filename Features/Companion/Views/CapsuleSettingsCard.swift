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
                // Left: Settings
                VStack(alignment: .leading, spacing: 16) {
                    // Display Position
                    VStack(alignment: .leading, spacing: 8) {
                        Text("展示位置")
                            .font(.headline)
                        
                        Picker("位置", selection: $position) {
                            ForEach(CompanionCapsulePosition.allCases, id: \.self) { pos in
                                Text(pos.displayName).tag(pos)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Default Expanded
                    Toggle("启动后默认展开随身面板", isOn: $isExpanded)
                        .disabled(!isEnabled)
                }
                
                Spacer()
                
                // Right: Preview
                CapsulePreview(position: position, isEnabled: isEnabled)
                    .frame(width: 200)
            }
        }
    }
}