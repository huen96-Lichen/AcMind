import SwiftUI

struct InboxDetailPanel: View {
    let item: InboxItem?
    
    var body: some View {
        if let item = item {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    InboxDetailMainCard(item: item)
                    InboxRecognitionCard(text: item.recognitionText)
                    InboxSuggestedActionsView()
                    InboxMetadataTable(metadata: item.metadata)
                    InboxTagsSection(tags: item.tags)
                }
                .padding(.horizontal, InboxLayout.detailPaddingX)
                .padding(.top, InboxLayout.detailPaddingTop)
                .padding(.bottom, 28)
            }
            .background(InboxColors.pageBackground)
        } else {
            VStack {
                Image(systemName: "inbox")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(InboxColors.tertiaryText)
                    .frame(width: 48, height: 48)
                Text("选择内容查看详情")
                    .font(InboxTypography.body)
                    .foregroundColor(InboxColors.tertiaryText)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(InboxColors.pageBackground)
        }
    }
}