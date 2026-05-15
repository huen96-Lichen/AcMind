import SwiftUI

enum SuggestedActionType {
    case newTask
    case generateDocument
    case generateChart
    case sendToAgent
    
    var title: String {
        switch self {
        case .newTask: return "新建任务"
        case .generateDocument: return "生成文档"
        case .generateChart: return "生成图表"
        case .sendToAgent: return "发送到 Agent"
        }
    }
    
    var iconName: String {
        switch self {
        case .newTask: return "checklist"
        case .generateDocument: return "doc.text"
        case .generateChart: return "chart.bar"
        case .sendToAgent: return "arrow.right"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .newTask: return InboxColors.accentPurple
        case .generateDocument: return InboxColors.accentBlue
        case .generateChart: return InboxColors.accentGreen
        case .sendToAgent: return InboxColors.accentPurple
        }
    }
}

struct InboxSuggestedActionButton: View {
    let actionType: SuggestedActionType
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: actionType.iconName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(actionType.iconColor)
                    .frame(width: 14, height: 14)
                Text(actionType.title)
                    .font(InboxTypography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(InboxColors.primaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(InboxColors.cardBackground)
            .border(InboxColors.border, width: 1)
            .cornerRadius(10)
        }
    }
}

struct InboxSuggestedActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建议操作")
                .font(InboxTypography.sectionTitle)
                .foregroundColor(InboxColors.primaryText)
            
            HStack(spacing: 8) {
                InboxSuggestedActionButton(actionType: .newTask)
                InboxSuggestedActionButton(actionType: .generateDocument)
                InboxSuggestedActionButton(actionType: .generateChart)
                InboxSuggestedActionButton(actionType: .sendToAgent)
            }
        }
    }
}