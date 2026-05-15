import SwiftUI

struct ClipboardCategorySidebar: View {
    @Binding var selectedCategory: ClipboardCategory
    let stats: ClipboardStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            smartCategorySection
            
            favoritesSection
            
            cleanupSection
            
            Spacer()
            
            storageSection
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 18)
        .padding(.horizontal, 14)
        .padding(.bottom, 18)
        .background(ClipboardColors.cardBackground)
        .cornerRadius(ClipboardLayout.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.cardRadius)
                .stroke(ClipboardColors.border, lineWidth: 1)
        )
    }
    
    private var smartCategorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("智能分类")
                .font(ClipboardTypography.sectionTitle)
                .foregroundColor(ClipboardColors.primaryText)
            
            ForEach(ClipboardCategory.allCases) { category in
                CategoryRow(
                    title: category.rawValue,
                    count: category.count,
                    icon: category.icon,
                    isSelected: selectedCategory == category
                )
                .onTapGesture {
                    selectedCategory = category
                }
            }
        }
    }
    
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("收藏")
                .font(ClipboardTypography.sectionTitle)
                .foregroundColor(ClipboardColors.primaryText)
                .padding(.top, 24)
            
            ForEach(ClipboardFavoriteCategory.allCases) { category in
                CategoryRow(
                    title: category.rawValue,
                    count: category.count,
                    icon: category.icon,
                    isSelected: false
                )
            }
        }
    }
    
    private var cleanupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("清理")
                .font(ClipboardTypography.sectionTitle)
                .foregroundColor(ClipboardColors.primaryText)
                .padding(.top, 24)
            
            ForEach(ClipboardCleanupCategory.allCases) { category in
                CategoryRow(
                    title: category.rawValue,
                    count: category.count,
                    icon: category.icon,
                    isSelected: false
                )
            }
        }
    }
    
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("存储使用")
                    .font(ClipboardTypography.caption)
                    .foregroundColor(ClipboardColors.secondaryText)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(ClipboardColors.secondaryText)
                }
            }
            
            StorageProgressBar(used: stats.storageUsed, total: stats.storageTotal)
            
            Text("\(stats.storageUsed) GB / \(stats.storageTotal) GB")
                .font(ClipboardTypography.caption)
                .foregroundColor(ClipboardColors.secondaryText)
        }
        .padding(.top, 24)
    }
}

struct CategoryRow: View {
    let title: String
    let count: Int
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(isSelected ? ClipboardColors.accentBlue : ClipboardColors.secondaryText)
            
            Text(title)
                .font(ClipboardTypography.body)
                .foregroundColor(isSelected ? ClipboardColors.accentBlue : ClipboardColors.secondaryText)
            
            Spacer()
            
            Text("\(count)")
                .font(ClipboardTypography.mini)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? ClipboardColors.accentBlue : ClipboardColors.secondaryText)
        }
        .frame(height: 38)
        .padding(.horizontal, 12)
        .background(isSelected ? ClipboardColors.selectedFill : Color.clear)
        .cornerRadius(ClipboardLayout.tinyRadius)
    }
}

struct StorageProgressBar: View {
    let used: Double
    let total: Double
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return used / total
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(ClipboardColors.border)
                    .frame(height: 5)
                
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(ClipboardColors.accentBlue)
                    .frame(width: geometry.size.width * min(percentage, 1), height: 5)
            }
        }
        .frame(height: 5)
    }
}