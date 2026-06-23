import SwiftUI

struct VoiceSettingsCard: View {
    @Binding var isEnabled: Bool
    let isGlobalEnabled: Bool
    @Binding var outputMode: VoiceOutputMode
    @Binding var saveToInbox: Bool
    
    var body: some View {
        CompanionCapabilityCard(
            iconName: "mic.fill",
            iconColor: .purple,
            title: "说入法入口",
            description: "长按 Fn 唤起，把口语清洗或翻译成可直接使用的文稿。",
            isEnabled: isEnabled,
            isGlobalEnabled: isGlobalEnabled,
            toggleEnabled: $isEnabled
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("快捷键")
                        .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)

                    HStack(spacing: 4) {
                        ShortcutKeycap(key: "Fn")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("清洗完成后")
                        .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)

                    Picker("", selection: $outputMode) {
                        ForEach(VoiceOutputMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("保存说入法结果到收集箱", isOn: $saveToInbox)
                    .disabled(!isEnabled)
            }
        }
    }
}
