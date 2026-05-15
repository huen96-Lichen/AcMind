import SwiftUI

struct ClipboardListPanel: View {
    let groupedItems: [String: [ClipboardItem]]
    @Binding var selectedItem: ClipboardItem?
    
    var body: some View {
        VStack(spacing: 12) {
            ClipboardListToolbar()
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(groupedItems.keys.sorted(by: sortGroups), id: \.self) { group in
                        SectionHeader(title: group)
                        
                        ForEach(groupedItems[group] ?? []) { item in
                            ClipboardListRow(
                                item: item,
                                isSelected: selectedItem?.id == item.id
                            )
                            .onTapGesture {
                                selectedItem = item
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sortGroups(_ a: String, _ b: String) -> Bool {
        let order: [String] = ["今天", "昨天", "前天"]
        let indexA = order.firstIndex(of: a) ?? Int.max
        let indexB = order.firstIndex(of: b) ?? Int.max
        return indexA < indexB
    }
}

struct ClipboardListToolbar: View {
    var body: some View {
        HStack(spacing: 8) {
            FilterButton(title: "全部", isSelected: true)
            FilterButton(title: "来源", hasDropdown: true)
            FilterButton(title: "时间", hasDropdown: true)
            FilterButton(title: "类型", hasDropdown: true)
            FilterButton(title: "更多筛选", hasDropdown: true)
            
            Spacer()
            
            HStack(spacing: 6) {
                Text("最新优先")
                    .font(ClipboardTypography.caption)
                    .foregroundColor(ClipboardColors.primaryText)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(ClipboardColors.secondaryText)
            }
            .frame(width: 106, height: 32)
            .background(ClipboardColors.cardBackground)
            .cornerRadius(ClipboardLayout.tinyRadius)
            .overlay(
                RoundedRectangle(cornerRadius: ClipboardLayout.tinyRadius)
                    .stroke(ClipboardColors.border, lineWidth: 1)
            )
        }
        .frame(height: ClipboardLayout.listToolbarHeight)
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let hasDropdown: Bool
    
    init(title: String, isSelected: Bool = false, hasDropdown: Bool = false) {
        self.title = title
        self.isSelected = isSelected
        self.hasDropdown = hasDropdown
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(ClipboardTypography.caption)
            
            if hasDropdown {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
        }
        .padding(.horizontal, isSelected ? 16 : 14)
        .frame(height: 32)
        .background(isSelected ? ClipboardColors.accentBlue : ClipboardColors.cardBackground)
        .foregroundColor(isSelected ? .white : ClipboardColors.primaryText)
        .cornerRadius(ClipboardLayout.tinyRadius)
        .overlay(
            !isSelected ? RoundedRectangle(cornerRadius: ClipboardLayout.tinyRadius)
                .stroke(ClipboardColors.border, lineWidth: 1) : nil
        )
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(ClipboardTypography.bodyMedium)
            .foregroundColor(ClipboardColors.secondaryText)
            .padding(.leading, 14)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }
}

struct ClipboardListRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    @State private var isFavorite = false
    
    var body: some View {
        HStack(spacing: 14) {
            TypeIcon(type: item.type, imageSize: item.imageSize)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(ClipboardTypography.itemTitle)
                    .foregroundColor(ClipboardColors.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                MetadataLine(item: item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            FavoriteButton(isFavorite: $isFavorite)
            
            MoreButton()
        }
        .frame(height: ClipboardLayout.listRowHeight)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ClipboardColors.cardBackground)
        .cornerRadius(ClipboardLayout.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.smallRadius)
                .stroke(isSelected ? ClipboardColors.accentBlue : ClipboardColors.border, lineWidth: 1)
        )
    }
}

struct TypeIcon: View {
    let type: ClipboardItemType
    let imageSize: String?
    
    var body: some View {
        ZStack {
            if type == .image {
                RoundedRectangle(cornerRadius: ClipboardLayout.tinyRadius)
                    .fill(ClipboardColors.imageTypeFill)
                    .frame(width: ClipboardLayout.listRowIconSize, height: ClipboardLayout.listRowIconSize)
                
                Image(systemName: type.icon)
                    .font(.system(size: 22))
                    .foregroundColor(type.iconColor)
            } else {
                RoundedRectangle(cornerRadius: ClipboardLayout.tinyRadius)
                    .fill(type.backgroundColor)
                    .frame(width: ClipboardLayout.listRowIconSize, height: ClipboardLayout.listRowIconSize)
                
                Image(systemName: type.icon)
                    .font(.system(size: 22))
                    .foregroundColor(type.iconColor)
            }
        }
    }
}

struct MetadataLine: View {
    let item: ClipboardItem
    
    var body: some View {
        HStack(spacing: 8) {
            TypeBadge(type: item.type)
            
            Text(item.time)
                .font(ClipboardTypography.caption)
                .foregroundColor(ClipboardColors.secondaryText)
            
            Text("·")
                .font(ClipboardTypography.caption)
                .foregroundColor(ClipboardColors.tertiaryText)
            
            Text(item.source)
                .font(ClipboardTypography.caption)
                .foregroundColor(ClipboardColors.secondaryText)
        }
    }
}

struct TypeBadge: View {
    let type: ClipboardItemType
    
    var body: some View {
        Text(type.displayName)
            .font(ClipboardTypography.mini)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(type.badgeBackgroundColor)
            .foregroundColor(type.badgeTextColor)
            .cornerRadius(6)
    }
}

struct FavoriteButton: View {
    @Binding var isFavorite: Bool
    
    var body: some View {
        Button(action: { isFavorite.toggle() }) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 15))
                .foregroundColor(isFavorite ? ClipboardColors.accentYellow : ClipboardColors.secondaryText)
        }
        .frame(width: 30, height: 30)
    }
}

struct MoreButton: View {
    var body: some View {
        Button(action: {}) {
            Image(systemName: "ellipsis")
                .font(.system(size: 16))
                .foregroundColor(ClipboardColors.primaryText)
        }
        .frame(width: 30, height: 30)
    }
}