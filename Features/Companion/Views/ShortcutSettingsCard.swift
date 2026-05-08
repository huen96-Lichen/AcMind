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
            description: "全局快捷键，快速触发 AcMind 能力。",
            isEnabled: isEnabled,
            isGlobalEnabled: isGlobalEnabled,
            toggleEnabled: $isEnabled
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // Shortcut List
                ForEach(shortcuts) { shortcut in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortcut.action)
                                .font(.body)
                            
                            Text(shortcut.description)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
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
                    
                    // Divider (except last)
                    if shortcuts.last?.id != shortcut.id {
                        Divider()
                    }
                }
                
                // Note
                Text("* 快捷键在后续版本中可自定义")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .padding(.top, 12)
            }
        }
    }
    
    private func isShortcutEnabled(shortcut: CompanionShortcut) -> Bool {
        guard isEnabled else { return false }
        
        switch shortcut.action {
        case "随身语音":
            return voiceEnabled
        case "截图捕获":
            return captureEnabled
        default:
            return true
        }
    }
}