import SwiftUI

struct InboxMetadataTable: View {
    let metadata: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("元数据")
                .font(InboxTypography.sectionTitle)
                .foregroundColor(InboxColors.primaryText)
            
            VStack(spacing: 0) {
                ForEach(Array(metadata.enumerated()), id: \.offset) { index, entry in
                    let key = entry.key
                    let value = entry.value
                    HStack {
                        Text(key)
                            .font(InboxTypography.caption)
                            .foregroundColor(InboxColors.secondaryText)
                        Spacer()
                        Text(value)
                            .font(InboxTypography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(InboxColors.primaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    
                    if index < metadata.count - 1 {
                        Divider()
                            .background(InboxColors.softBorder)
                    }
                }
            }
            .frame(width: InboxLayout.detailCardWidth)
            .background(InboxColors.cardBackground)
            .border(InboxColors.border, width: 1)
            .cornerRadius(InboxLayout.smallRadius)
        }
    }
}
