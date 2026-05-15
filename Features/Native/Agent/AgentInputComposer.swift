import SwiftUI

struct AgentInputComposer: View {
    @State private var inputText = ""
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text("输入你的任务或问题，按 Enter 发送，Shift + Enter 换行")
                        .font(.system(size: 14))
                        .foregroundColor(AgentColors.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                
                TextEditor(text: $inputText)
                    .font(.system(size: 14))
                    .foregroundColor(AgentColors.primaryText)
                    .frame(height: 44)
                    .padding(.horizontal, 16)
            }
            .background(AgentColors.cardBackground)
            .cornerRadius(AgentLayout.smallRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AgentLayout.smallRadius)
                    .stroke(AgentColors.border, lineWidth: 1)
            )
            
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 8) {
                    toolbarButton(title: "语音输入", icon: "mic.fill")
                    toolbarButton(title: "上传文件", icon: "paperclip")
                    toolbarButton(title: "调用工具", icon: "wrench")
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    modelSelector
                    sendButton
                }
            }
            .frame(height: 40)
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .background(AgentColors.cardBackground)
        .cornerRadius(AgentLayout.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AgentLayout.cardRadius)
                .stroke(AgentColors.border, lineWidth: 1)
        )
    }
    
    private func toolbarButton(title: String, icon: String) -> some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                
                Text(title)
                    .font(AgentTypography.bodyMedium)
            }
            .foregroundColor(AgentColors.primaryText)
            .frame(height: 36)
            .padding(.horizontal, 14)
            .background(AgentColors.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AgentColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(HoverButtonStyle())
    }
    
    private var modelSelector: some View {
        HStack(spacing: 4) {
            Text("GPT-5")
                .font(AgentTypography.bodyMedium)
                .foregroundColor(AgentColors.primaryText)
            
            Image(systemName: "chevron.down")
                .font(.system(size: 12))
        }
        .frame(width: 92, height: 36)
        .background(AgentColors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AgentColors.border, lineWidth: 1)
        )
        .buttonStyle(HoverButtonStyle())
    }
    
    private var sendButton: some View {
        Button(action: {}) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 15))
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 36)
        .background(AgentColors.accentPurple)
        .cornerRadius(AgentLayout.smallRadius)
        .buttonStyle(SendButtonHoverStyle())
    }
}

struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isHovered ? Color(hex: "#F8F8F8") : AgentColors.cardBackground)
    }
}

struct SendButtonHoverStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isHovered ? 1.05 : 1.0)
            .brightness(configuration.isHovered ? 0.1 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isHovered)
    }
}