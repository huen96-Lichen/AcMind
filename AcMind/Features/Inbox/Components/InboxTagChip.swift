import SwiftUI

struct InboxTagChip: View {
    let name: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(name)
                .font(InboxTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(InboxColors.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(InboxColors.softFill)
        .cornerRadius(14)
    }
}

struct InboxTagsSection: View {
    let tags: [(String, Color)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("标签")
                    .font(InboxTypography.sectionTitle)
                    .foregroundColor(InboxColors.primaryText)
                Spacer()
                Button(action: {}) {
                    Text("+ 添加标签")
                        .font(InboxTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(InboxColors.primaryText)
                }
            }
            
            HStack(spacing: 8) {
                ForEach(tags, id: \.0) { tag in
                    InboxTagChip(name: tag.0, color: tag.1)
                }
            }
        }
    }
}