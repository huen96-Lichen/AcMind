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
            title: "随身语音",
            description: "语音输入、语音指令，解放双手。",
            isEnabled: isEnabled,
            isGlobalEnabled: isGlobalEnabled,
            toggleEnabled: $isEnabled
        ) {
            HStack(spacing: 24) {
                // Left: Settings
                VStack(alignment: .leading, spacing: 16) {
                    // Shortcut
                    VStack(alignment: .leading, spacing: 8) {
                        Text("快捷键")
                            .font(.headline)
                        
                        HStack(spacing: 4) {
                            ShortcutKeycap(key: "⌥")
                            ShortcutKeycap(key: "Space")
                        }
                    }
                    
                    // Output Mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("转写完成后")
                            .font(.headline)
                        
                        Picker("", selection: $outputMode) {
                            ForEach(VoiceOutputMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Save to Inbox
                    Toggle("保存转写历史到收集箱", isOn: $saveToInbox)
                        .disabled(!isEnabled)
                }
                
                Spacer()
                
                // Right: Waveform Preview
                WaveformPreview(isEnabled: isEnabled)
                    .frame(width: 220)
            }
        }
    }
}