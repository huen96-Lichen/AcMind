import SwiftUI

struct AgentHeaderBar: View {
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent")
                    .font(AgentTypography.pageTitle)
                    .foregroundColor(AgentColors.primaryText)
                
                Text("任务输入、执行反馈、工具入口和最近任务")
                    .font(AgentTypography.pageSubtitle)
                    .foregroundColor(AgentColors.secondaryText)
            }
            .padding(.leading, AgentLayout.workspacePaddingX)
            
            Spacer()
            
            HStack(alignment: .center, spacing: 12) {
                statusPill
                
                Divider()
                    .frame(height: 24)
                    .foregroundColor(AgentColors.border)
                
                settingsButton
                
                fullscreenButton
            }
            .padding(.trailing, AgentLayout.workspacePaddingX)
        }
        .frame(height: AgentLayout.headerHeight)
        .background(AgentColors.cardBackground)
    }
    
    private var statusPill: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AgentColors.accentGreen)
                    .frame(width: 6, height: 6)
                
                Text("在线 · 待命")
                    .font(AgentTypography.bodyMedium)
                    .foregroundColor(AgentColors.primaryText)
            }
            
            Rectangle()
                .frame(width: 1, height: 16)
                .foregroundColor(AgentColors.border)
            
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8))
                    .foregroundColor(AgentColors.accentPurple)
                
                Text("GPT-5.5 Thinking")
                    .font(AgentTypography.bodyMedium)
                    .foregroundColor(AgentColors.accentPurple)
            }
        }
        .frame(height: 36)
        .padding(.horizontal, 14)
        .background(AgentColors.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AgentColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    private var settingsButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "gear")
                .font(.system(size: 14))
            
            Text("设置")
                .font(AgentTypography.bodyMedium)
        }
        .foregroundColor(AgentColors.primaryText)
        .frame(width: 76, height: 36)
        .background(AgentColors.cardBackground)
        .cornerRadius(AgentLayout.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AgentLayout.smallRadius)
                .stroke(AgentColors.border, lineWidth: 1)
        )
    }
    
    private var fullscreenButton: some View {
        Image(systemName: "square")
            .font(.system(size: 16))
            .foregroundColor(AgentColors.primaryText)
            .frame(width: 40, height: 36)
            .background(AgentColors.cardBackground)
            .cornerRadius(AgentLayout.smallRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AgentLayout.smallRadius)
                    .stroke(AgentColors.border, lineWidth: 1)
            )
    }
}