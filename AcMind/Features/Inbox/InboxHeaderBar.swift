import SwiftUI

struct InboxHeaderBar: View {
    @Binding var selectedCategoryIndex: Int
    
    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("收集箱")
                        .font(InboxTypography.pageTitle)
                        .foregroundColor(InboxColors.primaryText)
                    Text("存放你的语音记录、Agent 生成内容、任务和文档，随时整理与使用")
                        .font(InboxTypography.pageSubtitle)
                        .foregroundColor(InboxColors.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(InboxColors.tertiaryText)
                            .frame(width: 14, height: 14)
                            .padding(.leading, 14)
                        TextField("搜索收集内容...", text: .constant(""))
                            .font(InboxTypography.body)
                            .foregroundColor(InboxColors.primaryText)
                            .padding(.horizontal, 10)
                    }
                    .frame(width: InboxLayout.searchWidth, height: InboxLayout.searchHeight)
                    .background(InboxColors.cardBackground)
                    .border(InboxColors.border, width: 1)
                    .cornerRadius(12)
                    
                    Button(action: {}) {
                        Text("+ 新建")
                            .font(InboxTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(width: InboxLayout.newButtonWidth, height: InboxLayout.newButtonHeight)
                    .background(InboxColors.accentBlue)
                    .cornerRadius(8)
                }
            }
            
            HStack {
                InboxCategoryTabs(selectedIndex: $selectedCategoryIndex, tabs: categoryTabs)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Text("最新优先")
                                .font(InboxTypography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(InboxColors.primaryText)
                            Image(systemName: "chevron.down")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(InboxColors.primaryText)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .frame(width: InboxLayout.sortButtonWidth, height: InboxLayout.sortButtonHeight)
                    .background(InboxColors.cardBackground)
                    .border(InboxColors.border, width: 1)
                    .cornerRadius(10)
                    
                    Button(action: {}) {
                        Image(systemName: "slider.horizontal.3")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(InboxColors.primaryText)
                            .frame(width: 15, height: 15)
                    }
                    .frame(width: InboxLayout.filterButtonWidth, height: InboxLayout.sortButtonHeight)
                    .background(InboxColors.cardBackground)
                    .border(InboxColors.border, width: 1)
                    .cornerRadius(10)
                }
            }
        }
        .frame(height: InboxLayout.headerHeight)
        .padding(.horizontal, InboxLayout.workspacePaddingX)
        .padding(.top, 18)
        .background(InboxColors.pageBackground)
    }
}