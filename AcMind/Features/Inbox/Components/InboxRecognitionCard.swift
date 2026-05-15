import SwiftUI

struct InboxRecognitionCard: View {
    let text: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("内容识别")
                    .font(InboxTypography.sectionTitle)
                    .foregroundColor(InboxColors.primaryText)
                Spacer()
                Button(action: {}) {
                    Text("AI 识别")
                        .font(InboxTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(InboxColors.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(InboxColors.softFill)
                        .cornerRadius(8)
                }
            }
            
            if let text = text {
                Text(text)
                    .font(InboxTypography.body)
                    .foregroundColor(InboxColors.primaryText)
                    .lineSpacing(5)
                    .padding(16)
                    .frame(width: InboxLayout.detailCardWidth)
                    .background(InboxColors.cardBackground)
                    .border(InboxColors.border, width: 1)
                    .cornerRadius(InboxLayout.smallRadius)
            } else {
                Text("暂无识别内容")
                    .font(InboxTypography.body)
                    .foregroundColor(InboxColors.tertiaryText)
                    .padding(16)
                    .frame(width: InboxLayout.detailCardWidth, height: 126)
                    .background(InboxColors.cardBackground)
                    .border(InboxColors.border, width: 1)
                    .cornerRadius(InboxLayout.smallRadius)
            }
        }
    }
}