import SwiftUI

struct InboxStatusBadge: View {
    let status: InboxItemStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(InboxTypography.caption)
            .fontWeight(.medium)
            .foregroundColor(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .pending: return InboxColors.pendingBackground
        case .completed: return InboxColors.completedBackground
        case .archived: return InboxColors.archivedBackground
        case .collected: return InboxColors.completedBackground
        }
    }
    
    private var textColor: Color {
        switch status {
        case .pending: return InboxColors.pendingText
        case .completed: return InboxColors.completedText
        case .archived: return InboxColors.archivedText
        case .collected: return InboxColors.completedText
        }
    }
}