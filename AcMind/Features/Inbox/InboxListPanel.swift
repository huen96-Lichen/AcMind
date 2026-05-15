import SwiftUI

struct InboxListPanel: View {
    let items: [InboxItem]
    let selectedItem: InboxItem?
    let onSelectItem: (InboxItem) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("今天")
                    .font(InboxTypography.bodyMedium)
                    .foregroundColor(InboxColors.secondaryText)
                    .padding(.bottom, 10)
                
                ForEach(items.indices, id: \.self) { index in
                    InboxRow(
                        item: items[index],
                        isSelected: selectedItem?.id == items[index].id,
                        onTap: { onSelectItem(items[index]) }
                    )
                    
                    if index < items.count - 1 {
                        Divider()
                            .background(InboxColors.softBorder)
                            .padding(.horizontal, InboxLayout.listRowHorizontalPadding)
                    }
                }
            }
        }
        .padding(.horizontal, InboxLayout.listContentPaddingX)
        .padding(.top, InboxLayout.listTopPadding)
        .background(InboxColors.pageBackground)
    }
}