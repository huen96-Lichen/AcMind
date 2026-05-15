import SwiftUI

struct InboxCategoryTabs: View {
    @Binding var selectedIndex: Int
    let tabs: [(String, Int)]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs.indices, id: \.self) { index in
                let (name, count) = tabs[index]
                Button(action: {
                    selectedIndex = index
                }) {
                    HStack(spacing: 6) {
                        Text(name)
                        Text("\(count)")
                    }
                    .font(selectedIndex == index ? InboxTypography.bodyMedium : InboxTypography.body)
                    .fontWeight(selectedIndex == index ? .semibold : .medium)
                    .foregroundColor(selectedIndex == index ? InboxColors.accentBlue : InboxColors.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(selectedIndex == index ? InboxColors.selectedFill : InboxColors.softFill)
                    .cornerRadius(InboxLayout.pillRadius)
                }
                .frame(height: InboxLayout.categoryTabHeight)
            }
        }
    }
}