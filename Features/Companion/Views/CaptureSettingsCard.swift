import SwiftUI
import AcMindKit

struct CaptureSettingsCard: View {
    @Binding var isEnabled: Bool
    let isGlobalEnabled: Bool
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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("捕获后默认去向")
                                .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)

                            Spacer()

                            Text("可配置")
                                .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppSurfaceTokens.cardBackgroundSoft)
                                .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
                        }

                        Text("选择捕获完成后的默认处理方式，支持收集箱、剪贴板或每次询问。")
                            .font(.system(size: AppSurfaceTokens.Typography.caption))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    
                    // Text Capture
                    Toggle("复制文本后支持快速收集", isOn: $textCaptureEnabled)
                        .disabled(!isEnabled)
                    
                    // Link Capture
                    Toggle("复制链接后支持快速收集", isOn: $linkCaptureEnabled)
                        .disabled(!isEnabled)
                    
                    // Save Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("结果去向")
                            .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)

                        Picker("结果去向", selection: $saveDestinationIndex) {
                            ForEach(CompanionCaptureSaveDestination.allCases) { destination in
                                Text(destination.displayName).tag(destination.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(selectedSaveDestinationDescription(for: saveDestinationIndex))
                            .font(.system(size: AppSurfaceTokens.Typography.caption))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
                
                Spacer()
                
                // Right: Flow Preview
                VStack(spacing: 8) {
                    Text("内容流向")
                        .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius)
                            .fill(Color(NSColor.textBackgroundColor))
                            .frame(width: 180, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius)
                                    .stroke(AppSurfaceTokens.separator, lineWidth: 1)
                            )
                        
                        VStack {
                            HStack(alignment: .center, spacing: 4) {
                                // Sources
                                HStack(spacing: 2) {
                                    Image(systemName: "camera")
                                        .font(.system(size: AppSurfaceTokens.Typography.badge))
                                    Image(systemName: "doc.text")
                                        .font(.system(size: AppSurfaceTokens.Typography.badge))
                                    Image(systemName: "link")
                                        .font(.system(size: AppSurfaceTokens.Typography.badge))
                                }
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: AppSurfaceTokens.Typography.badge))
                                    .foregroundStyle(AppSurfaceTokens.accentBlue)
                                
                                Image(systemName: "tray")
                                    .font(.system(size: AppSurfaceTokens.Typography.body))
                                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: AppSurfaceTokens.Typography.badge))
                                    .foregroundStyle(AppSurfaceTokens.accentBlue)
                                
                                Image(systemName: "brain")
                                    .font(.system(size: AppSurfaceTokens.Typography.body))
                                    .foregroundStyle(AppSurfaceTokens.accentCyan)
                            }
                            
                            Text("截图 / 文本 / 链接 → 默认去向 → 后续处理")
                                .font(.system(size: AppSurfaceTokens.Typography.caption))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                    }
                    .opacity(isEnabled ? 1.0 : 0.5)
                    .grayscale(isEnabled ? 0 : 0.5)
                }
            }
        }
    }

    private func selectedSaveDestinationDescription(for index: Int) -> String {
        CompanionCaptureSaveDestination(rawValue: index)?.description ?? "当前设置尚未识别，默认视为收集箱。"
    }
}
