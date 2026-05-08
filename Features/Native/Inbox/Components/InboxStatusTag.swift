import SwiftUI
import AcMindKit

struct InboxStatusTag: View {
    let status: SourceItemStatus
    
    var body: some View {
        Text(status.displayLabel)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(status.tagColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.tagBgColor)
            .cornerRadius(4)
    }
}
