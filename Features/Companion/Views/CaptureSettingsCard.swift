import SwiftUI

struct CaptureSettingsCard: View {
    @Binding var isEnabled: Bool
    let isGlobalEnabled: Bool
    @Binding var autoSaveToInbox: Bool
    @Binding var textCaptureEnabled: Bool
    @Binding var linkCaptureEnabled: Bool
    @Binding var saveDestinationIndex: Int
    
    var body: some View {
        CompanionCapabilityCard(
            iconName: "tray.and.arrow.down.fill",
            iconColor: .orange,
            title: "随身捕获",
            description: "快速捕获屏幕、文本、链接等内容。",
            isEnabled: isEnabled,
            isGlobalEnabled: isGlobalEnabled,
            toggleEnabled: $isEnabled
        ) {
            HStack(spacing: 24) {
                // Left: Settings
                VStack(alignment: .leading, spacing: 12) {
                    // Screenshot to Inbox
                    Toggle("截图后自动保存到收集箱", isOn: $autoSaveToInbox)
                        .disabled(!isEnabled)
                    
                    // Text Capture
                    Toggle("复制文本后支持快速收集", isOn: $textCaptureEnabled)
                        .disabled(!isEnabled)
                    
                    // Link Capture
                    Toggle("复制链接后支持快速收集", isOn: $linkCaptureEnabled)
                        .disabled(!isEnabled)
                    
                    // Save Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("保存位置")
                            .font(.headline)
                        
                        Picker("", selection: $saveDestinationIndex) {
                            Text("收集箱").tag(0)
                            Text("剪贴板").tag(1)
                            Text("询问").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .disabled(!isEnabled)
                    }
                }
                
                Spacer()
                
                // Right: Flow Preview
                VStack(spacing: 8) {
                    Text("内容流向")
                        .font(.headline)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.textBackgroundColor))
                            .frame(width: 180, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                        
                        VStack {
                            HStack(alignment: .center, spacing: 4) {
                                // Sources
                                HStack(spacing: 2) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 12))
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 12))
                                    Image(systemName: "link")
                                        .font(.system(size: 12))
                                }
                                .foregroundStyle(.secondary)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.accentColor)
                                
                                Image(systemName: "tray")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.orange)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.accentColor)
                                
                                Image(systemName: "brain")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.purple)
                            }
                            
                            Text("截图 / 文本 / 链接 → 收集箱 → AI 整理")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .opacity(isEnabled ? 1.0 : 0.5)
                    .grayscale(isEnabled ? 0 : 0.5)
                }
            }
        }
    }
}
