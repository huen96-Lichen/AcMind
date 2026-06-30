import SwiftUI

struct ShortcutSettingsCard: View {
    @Binding var isEnabled: Bool
    let isGlobalEnabled: Bool
    let shortcuts: [CompanionShortcut]
    let voiceEnabled: Bool
    let captureEnabled: Bool
    
    var body: some View {
        CompanionCapabilityCard(
            iconName: "command",
            iconColor: .green,
            title: "随身快捷键",
            description: "全局快捷键，快速触发 AcWork 能力。",
            isEnabled: isEnabled,
            isGlobalEnabled: isGlobalEnabled,
            toggleEnabled: $isEnabled
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // 快捷键列表
                ForEach(shortcuts) { shortcut in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortcut.action)
                                .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            
                            Text(shortcut.description)
                                .font(.system(size: AppSurfaceTokens.Typography.caption))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                        
                        Spacer()

                        HStack(spacing: 4) {
                            ForEach(shortcut.shortcut.split(separator: " "), id: \.self) { key in
                                ShortcutKeycap(key: String(key))
                            }
                        }
                        .opacity(isShortcutEnabled(shortcut: shortcut) ? 1.0 : 0.4)
                    }
                    .padding(.vertical, 8)
                    
                    // 分隔线（最后一项除外）
                    if shortcuts.last?.id != shortcut.id {
                        Divider()
                    }
                }
                
            }
        }
    }
    
    private func isShortcutEnabled(shortcut: CompanionShortcut) -> Bool {
        guard isEnabled, shortcut.isEnabled else { return false }
        
        switch shortcut.action {
        case "说入法":
            return voiceEnabled
        case "截图捕获":
            return captureEnabled
        default:
            return true
        }
    }
}
